#Requires -Version 7.1

[CmdLetBinding(PositionalBinding = $false)]
Param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [ValidateScript({ [IO.Path]::GetExtension($_) -ieq '.csv' })]
    [string] $Path,

    [ValidateRange(2000, 3000)]
    [int] $Year,

    [Parameter(Mandatory)]
    [string] $OutTradeFile,

    [Parameter(Mandatory)]
    [string] $OutHoldingFile,

    [Parameter(Mandatory)]
    [string] $OutDividendFile
)

$ErrorActionPreference = 'Stop'

enum ActivityType {
    Buy = 0 # Buy
    Sell = 1 # Sell
    StockSplit = 2 # Stock Split
    Dividend = 3 # Dividend
    CashTopUp = 4 # Cash Top-up
    CashWithdrawal = 5 # Cash Withdrawal
    TradeRectification = 6 # Trade Rectification
    CustodyFee = 7 # Custody Fee
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
    [int] $AgeDays
    [decimal] $BuyQuantity
    [decimal] $AdjustedBuyQuantity
    [decimal] $Quantity
    [decimal] $AdjustedQuantity
    [decimal] $BuyAmount
    [decimal] $Amount
    [decimal] $AmountPerShare
    [decimal] $AdjustedAmountPerShare
}

class Trade {
    [string] $Symbol
    [datetime] $BuyDate
    [datetime] $SellDate
    [int] $SellAtAgeDays
    [decimal] $OriginalBuyQuantity
    [decimal] $SellQuantity
    [decimal] $TotalSellQuantity
    [decimal] $AdjustedOriginalBuyQuantity
    [decimal] $AdjustedSellQuantity
    [decimal] $AdjustedTotalSellQuantity
    [decimal] $OriginalBuyAmount
    [decimal] $BuyAmount
    [decimal] $SellAmount
    [decimal] $TotalSellAmount
    [decimal] $BuyAmountPerShare
    [decimal] $SellAmountPerShare
    [decimal] $AdjustedBuyAmountPerShare
    [decimal] $AdjustedSellAmountPerShare
    [decimal] $Profit
    [double] $ProfitPercent
}

$activityBySymbol = Get-Content -Path $Path | ConvertFrom-Csv -Delimiter ',' | ForEach-Object -Process {
    $usCulture = [Globalization.CultureInfo]::CreateSpecificCulture('en-GB')
    $quantity = $_.Quantity ? [decimal]::Parse($_.Quantity, $usCulture) : 0
    $amount = $_.'Total Amount' ? [Math]::Abs([decimal]::Parse($_.'Total Amount'.Replace('(','-').Replace(')',''), $usCulture)) : $null
    $amountPerShare = ($quantity -and $amount) `
        ? [decimal] ($amount / [Math]::Abs($quantity)) `
        : 0
    
    return [Activity] @{
        Symbol = $_.Ticker
        ActivityType = [ActivityType]($_.Type -replace '[^a-zA-Z]', '')
        SettleDate = [DateTime]::Parse($_.Date, $usCulture)
        Quantity = $quantity
        AdjustedQuantity = $quantity
        Amount = $amount
        AmountPerShare = $amountPerShare
        AdjustedAmountPerShare = $amountPerShare
    }
} `
| Where-Object -FilterScript {
    $_.Symbol -and (-not $Year -or $_.SettleDate.Year -le $Year)
} `
| Sort-Object -Property Symbol, SettleDate, ActivityType, Quantity `
| Group-Object -Property Symbol

$holding = @()

$trades = $activityBySymbol `
| ForEach-Object -Process {

    # Adjust quantities, prices and fees based for stock splits
    $currentQuantity = 0
    $_.Group `
        | Where-Object -Property ActivityType -In 'Buy', 'Sell', 'StockSplit' `
        | ForEach-Object -Process {

        $quantity = [Math]::Abs($_.Quantity)

        if ($_.ActivityType -in 'Buy', 'StockSplit') {
            $currentQuantity += $quantity
        }
        else {
            $currentQuantity -= $quantity
        }
    }

    [double[]] $stockSplitRatios = @()
    $reverseGroup = @($_.Group)
    [array]::Reverse($reverseGroup)
    $reverseGroup `
        | Where-Object -Property ActivityType -In 'Buy', 'Sell', 'StockSplit' `
        | ForEach-Object -Process {

        $quantity = [Math]::Abs($_.Quantity)

        if ($_.ActivityType -eq 'StockSplit') {
            $previousQuantity = $currentQuantity - $quantity
            $stockSplitRatios += $currentQuantity / $previousQuantity
            $currentQuantity = $previousQuantity
        }
        else {
            foreach ($stockSplitRatio in $stockSplitRatios) {
                $_.AdjustedQuantity = [decimal]($_.AdjustedQuantity * $stockSplitRatio)
                $_.AdjustedAmountPerShare = [decimal]($_.AdjustedAmountPerShare / $stockSplitRatio)
            }

            if ($_.ActivityType -in 'Buy') {
                $currentQuantity -= $quantity
            }
            else {
                $currentQuantity += $quantity
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
                AgeDays = ([DateTime]::Today - $_.SettleDate).TotalDays
                BuyQuantity = $_.Quantity
                AdjustedBuyQuantity = $_.AdjustedQuantity
                Quantity = $_.Quantity
                AdjustedQuantity = $_.AdjustedQuantity
                BuyAmount = $_.Amount
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
                Write-Debug $_.Symbol
                Write-Debug $_.SettleDate
                Write-Debug $oldestStock.AdjustedAmountPerShare
                [Trade] @{
                    Symbol = $_.Symbol
                    BuyDate = $oldestStock.BuyDate
                    SellAtAgeDays = ($_.SettleDate - $oldestStock.BuyDate).TotalDays
                    SellDate = $_.SettleDate
                    OriginalBuyQuantity = $oldestStock.BuyQuantity
                    SellQuantity = $soldQuantity
                    TotalSellQuantity = [Math]::Abs($_.Quantity)
                    AdjustedOriginalBuyQuantity = $oldestStock.AdjustedBuyQuantity
                    AdjustedSellQuantity = $adjustedSoldQuantity
                    AdjustedTotalSellQuantity = [Math]::Abs($_.AdjustedQuantity)
                    OriginalBuyAmount = $oldestStock.BuyAmount
                    BuyAmount = $oldestStock.BuyAmount * ($adjustedSoldQuantity / $oldestStock.AdjustedBuyQuantity)
                    SellAmount = $_.Amount * ($adjustedSoldQuantity / [Math]::Abs($_.AdjustedQuantity))
                    TotalSellAmount = $_.Amount
                    BuyAmountPerShare = $oldestStock.AmountPerShare
                    SellAmountPerShare = $_.AmountPerShare
                    AdjustedBuyAmountPerShare = $oldestStock.AdjustedAmountPerShare
                    AdjustedSellAmountPerShare = $_.AdjustedAmountPerShare
                    Profit = $adjustedSoldQuantity * ($_.AdjustedAmountPerShare - $oldestStock.AdjustedAmountPerShare)
                    ProfitPercent = [double]($_.AdjustedAmountPerShare / $oldestStock.AdjustedAmountPerShare - 1)
                } `
                | Write-Output

                $oldestStock.Quantity -= $soldQuantity
                $oldestStock.AdjustedQuantity -= $adjustedSoldQuantity
                $oldestStock.Amount = $oldestStock.BuyAmount * ($oldestStock.AdjustedQuantity / $oldestStock.AdjustedBuyQuantity)

                $sellRemainder -= $soldQuantity
                $adjustedSellRemainder -= $adjustedSoldQuantity

                if ($oldestStock.AdjustedQuantity -eq 0) {
                    $stocks.Dequeue() | Out-Null
                }
            }
        } `
        | Write-Output

    $holding += $stocks
}

if ($Year) {
    $trades = $trades | Where-Object -FilterScript {
        $_.SellDate.Year -eq $Year
    }
}

$trades | ConvertTo-Csv -Delimiter ';' `
| Out-File -FilePath $OutTradeFile -Force

# HOLDING
$holding `
| ConvertTo-Csv -Delimiter ';' `
| Out-File -FilePath $OutHoldingFile -Force

# DIVIDENDS
$activityBySymbol `
| ForEach-Object -Process {
    $dividends = $_.Group | Where-Object -Property ActivityType -EQ 'Dividend'

    if ($Year) {
        $dividends = $dividends | Where-Object -FilterScript {
            $_.SettleDate.Year -eq $Year
        }
    }

    [decimal] $profit = ($dividends | Measure-Object -Property Amount -Sum).Sum
    
    return [PSCustomObject] @{
        Symbol = $_.Name
        DividendProfit = $profit
    }
} `
| ConvertTo-Csv -Delimiter ';' `
| Out-File -FilePath $OutDividendFile -Force