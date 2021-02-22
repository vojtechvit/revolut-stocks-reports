# Revolut stock reporting
A PowerShell script to generate reports on your Revolut stock trades esp. for tax purposes.

## Pre-requisites
1. [PowerShell 7.1](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1) or higher
2. A CSV with your Revolut stock activities exported from your Revolute stock trade statements (a PDF but you can open it e.g. in Microsoft Word to preserve the table formatting in order to copy into Microsoft Excel to process manually & save as a CSV).
   * The CSV should have the following format:
    ```
    TradeDate;SettleDate;ActivityType;Symbol;Quantity;Price;Amount
    29.01.2020 0:00;31.01.2020 0:00;Buy;MSFT;20;168,2199;-3364,4
    ```
   * The supported activity types are:
      1. `Buy`
      2. `Sell`
      3. `StockSplit`
      4. `Dividend`
      5. `DividendFederalTax`
      6. `DividendNRAWithholding`
   * Other activity types will be ignored

## How to run
In `pwsh`:

```powershell
.\CalculateRevolutTaxes.ps1 `
    -Path 'activity.csv' `
    -OutTradeFile 'trades.csv' `
    -OutHoldingFile 'holdings.csv' `
    -OutDividendFile 'dividends.csv'
```

## Output
The script creates three CSV files:

1. _Trades_ - Lists all stock trades with the assumption that the oldest stocks are always sold first
   * This should allow you to report your profit/loss on stock trades
2. _Holdings_ - Lists your holdings (after trades) where each remaining stock purchase is listed individually
   * This should allow you to see how "old" your stocks are. Some tax systems allow you to avoid taxation if you hold stocks long enough.
3. _Dividends_ - Lists your dividend earnings including paid taxes
   * This should allow you to report your profits on dividends

# Important Note
I do not make any guarantees about the correctness or reliability of this unofficial script. Its potential use, e.g. for tax reporting purposes, is completely at your own responsiblity.

That being said, if you find bugs, please feel free to contribute!
