# Revolut stock reporting
A PowerShell script to generate reports on your Revolut stock trades esp. for tax purposes.

## Pre-requisites
1. [PowerShell 7.1](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1) or higher
2. A CSV with your Revolut stock activities exported from your Revolute stock trade statements (a PDF but you can open it e.g. in Microsoft Word to preserve the table formatting in order to copy into Microsoft Excel to save as a CSV).
   * The CSV should have the following format:
    ```
    Trade Date;Settle Date;Currency;Activity Type;Symbol / Description;Quantity;Price;Amount
    01/29/2020;01/31/2020;USD;BUY;MSFT - MICROSOFT CORP   COM - TRD MSFT B 20 at 168.2199 Agency.;20;168.2199;(3,364.40)
    ```
   * The supported activity types are:
      Activity Code | Description
      ------------- | ---------------
      BUY | Buy
      SELL | Sell
      SSP | Stock Split
      DIV | Dividend
      DIVFT | Dividend Federal Tax
      DIVNRA | Dividend NRA Withholding Tax
      CDEP | Cash Disbursement
      CSD | Cash Receipt
   * Other activity types will be ignored

## How to run
In `pwsh`:

```powershell
.\Get-RevolutStockReport.ps1 `
    -Path 'activities.csv' `
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
