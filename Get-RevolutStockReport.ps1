#Requires -Version 7.1

[CmdLetBinding(PositionalBinding = $false)]
Param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [ValidateScript({ [IO.Path]::GetExtension($_) -ieq '.csv' })]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $OutTradeFile,

    [Parameter(Mandatory)]
    [string] $OutHoldingFile,

    [Parameter(Mandatory)]
    [string] $OutDividendFile
)

$ErrorActionPreference = 'Stop'

enum ActivityType {
    Buy = 0
    Sell = 1
    StockSplit = 2
    Dividend = 3
    DividendFederalTax = 4
    DividendNRAWithholding = 5
    CashDisbursement = 6
    CashReceipt = 7
}

class Activity {
    [string] $Symbol
    [ActivityType] $ActivityType
    [datetime] $SettleDate
    [decimal] $Quantity
    [decimal] $AdjustedQuantity
    [decimal] $Amount
    [decimal] $AmountPerShare
    [decimal] $AdjustedAmountPerShare
}

class Stock {
    [string] $Symbol
    [datetime] $BuyDate
    [decimal] $Quantity
    [decimal] $AdjustedQuantity
    [decimal] $Amount
    [decimal] $AmountPerShare
    [decimal] $AdjustedAmountPerShare
}

class Trade {
    [string] $Symbol
    [decimal] $Quantity
    [decimal] $AdjustedQuantity
    [datetime] $BuyDate
    [decimal] $BuyAmount
    [decimal] $BuyAmountPerShare
    [decimal] $AdjustedBuyAmountPerShare
    [datetime] $SellDate
    [decimal] $SellAmount
    [decimal] $SellAmountPerShare
    [decimal] $AdjustedSellAmountPerShare
    [decimal] $Profit
}

$activityBySymbol = Get-Content -Path $Path | ConvertFrom-Csv -Delimiter ';' | ForEach-Object -Process {
    $quantity = $_.Quantity ? [decimal]::Parse($_.Quantity) : 0
    $amount = $_.Amount ? [Math]::Abs([decimal]::Parse($_.Amount)) : $null
    $amountPerShare = ($quantity -and $amount) `
        ? [decimal] ($amount / [Math]::Abs($quantity)) `
        : 0
    
    return [Activity] @{
        Symbol = $_.Symbol ? $_.Symbol.Trim() : $null
        ActivityType = [ActivityType]$_.ActivityType
        SettleDate = [DateTime]::Parse($_.SettleDate)
        Quantity = $quantity
        AdjustedQuantity = $quantity
        Amount = $amount
        AmountPerShare = $amountPerShare
        AdjustedAmountPerShare = $amountPerShare
    }
} `
| Where-Object -FilterScript { $_.Symbol } `
| Sort-Object -Property Symbol, SettleDate, ActivityType, Quantity `
| Group-Object -Property Symbol

$holding = @()

$activityBySymbol `
| ForEach-Object -Process {
    [decimal] $lastStockSplitAdded = 0
    [double[]] $stockSplitRatios = @()

    # Adjust quantities, prices and fees based for stock splits
    $reverseGroup = @($_.Group)
    [array]::Reverse($reverseGroup)
    $reverseGroup `
        | Where-Object -Property ActivityType -In 'Buy', 'Sell', 'StockSplit' `
        | ForEach-Object -Process {
        
        if ($lastStockSplitAdded) {
            if ($_.ActivityType -eq 'StockSplit' -and $_.Quantity -lt 0) {
                $stockSplitRatios += $lastStockSplitAdded / [Math]::Abs($_.Quantity)
                $lastStockSplitAdded = 0
            }
            else {
                throw "A stock split stock remove expected to precede a stock split stock add activity ($($_.Symbol))"
            }
        }
        elseif ($_.ActivityType -eq 'StockSplit') {
            if ($_.Quantity -gt 0) {
                $lastStockSplitAdded = $_.Quantity
            }
            else {
                throw "A stock split stock add expected to follow a stock split stock remove activity ($($_.Symbol))"
            }
        }
        else {
            foreach ($stockSplitRatio in $stockSplitRatios) {
                $_.AdjustedQuantity = [decimal]($_.AdjustedQuantity * $stockSplitRatio)
                $_.AdjustedAmountPerShare = [decimal]($_.AdjustedAmountPerShare / $stockSplitRatio)
            }
        }
    }

    $stocks = [Collections.Generic.Queue[Stock]]::new()

    $_.Group `
        | Where-Object -Property ActivityType -EQ 'Buy'
        | ForEach-Object -Process {
            $stocks.Enqueue([Stock] @{
                Symbol = $_.Symbol
                BuyDate = $_.SettleDate
                Quantity = $_.Quantity
                AdjustedQuantity = $_.AdjustedQuantity
                Amount = $_.Amount
                AmountPerShare = $_.AmountPerShare
                AdjustedAmountPerShare = $_.AdjustedAmountPerShare
            })
        }

    $_.Group `
        | Where-Object -Property ActivityType -EQ 'Sell'
        | ForEach-Object -Process {
            $sellRemainder = [Math]::Abs($_.Quantity)
            $adjustedSellRemainder = [Math]::Abs($_.AdjustedQuantity)

            while ($adjustedSellRemainder -gt 0) {
                $oldestStock = $stocks.Peek()

                $soldQuantity = [Math]::Min($sellRemainder, $oldestStock.Quantity)
                $adjustedSoldQuantity = [Math]::Min($adjustedSellRemainder, $oldestStock.AdjustedQuantity)
                
                [Trade] @{
                    Symbol = $_.Symbol
                    Quantity = $soldQuantity
                    AdjustedQuantity = $adjustedSoldQuantity
                    BuyDate = $oldestStock.BuyDate
                    BuyAmount= $oldestStock.Amount * ($adjustedSoldQuantity / $oldestStock.AdjustedQuantity)
                    BuyAmountPerShare = $oldestStock.AmountPerShare
                    AdjustedBuyAmountPerShare = $oldestStock.AdjustedAmountPerShare
                    SellDate = $_.SettleDate
                    SellAmount = $_.Amount * ($adjustedSoldQuantity / [Math]::Abs($_.AdjustedQuantity))
                    SellAmountPerShare = $_.AmountPerShare
                    AdjustedSellAmountPerShare = $_.AdjustedAmountPerShare
                    Profit = $adjustedSoldQuantity * ($_.AdjustedAmountPerShare - $oldestStock.AdjustedAmountPerShare)
                } `
                | Write-Output
                
                $oldestStock.Quantity -= $soldQuantity
                $oldestStock.AdjustedQuantity -= $adjustedSoldQuantity

                $sellRemainder -= $soldQuantity
                $adjustedSellRemainder -= $adjustedSoldQuantity

                if ($oldestStock.AdjustedQuantity -eq 0) {
                    $stocks.Dequeue() | Out-Null
                }
            }
        } `
        | Write-Output

    $holding += $stocks
} `
| ConvertTo-Csv -Delimiter ';' `
| Out-File -FilePath $OutTradeFile -Force

# HOLDING
$holding `
| ConvertTo-Csv -Delimiter ';' `
| Out-File -FilePath $OutHoldingFile -Force

# DIVIDENDS
$activityBySymbol `
| ForEach-Object -Process {
    [decimal] $income = ($_.Group | Where-Object -Property ActivityType -EQ 'Dividend' | Measure-Object -Property Amount -Sum).Sum
    [decimal] $taxes = ($_.Group | Where-Object -Property ActivityType -IN 'DividendNRAWithholding', 'DividendFederalTax' | Measure-Object -Property Amount -Sum).Sum
    
    return [PSCustomObject] @{
        Symbol = $_.Name
        DividendIncome = $income
        DividendTaxes = $taxes
        DividendProfit = $income - $taxes
    }
} `
| ConvertTo-Csv -Delimiter ';' `
| Out-File -FilePath $OutDividendFile -Force