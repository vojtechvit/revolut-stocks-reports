# Revolut stock reporting
A script to generate reports on your Revolut stock trades - typically for tax purposes.

## Features

* **Stock trades report**
    * A summary of all stock trades in the chosen period
    * Each "sell" is paired with the oldest possible "buy" order to calculate the profit of a trade - an approach typically required by tax authorities
    * Stock Split events are supported - "adjusted" quantities, amounts and prices are calculated to show numbers according to the current stock size
* **Stock holdings report**
    * A summary of all stocks you own at the end of the chosen period
    * The granularity is at individual purchases level so you can know how old your stocks are - in some tax systems you may avoid taxes if you sell stocks old enough
* **Dividends report**
    * A summary of all dividend profits in the chosen period

See the [sample outputs](samples) for more detail on what to expect.

### Known limitations

* Stock trade excemptions from taxes on the basis of the stock age are not currently supported

## Pre-requisites
* [PowerShell 7.1](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.1) or higher

## How to run
1. Download the script [Get-RevolutStockReport.ps1](https://raw.githubusercontent.com/vojtechvit/revolut-stocks-reports/main/Get-RevolutStockReport.ps1)
2. Download PDF exports off all your stock activities from Revolut app
   * **Important:** The export must include even all activities prior to the period you are interested in! This is necessary in order to calculate the trade profits correctly!
3. Open the PDFs in Microsoft Word, select the Activity table from each and paste it into a Microsoft Excel spreadsheet to form a complete table of all activities
4. Export the Microsoft Excel activities spreadsheet into CSV
5. Open PowerShell (`pwsh`) and run the following command in the directory where you downloaded the script and your CSV export:

```powershell
# To create reports for the whole history of your activities
.\Get-RevolutStockReport.ps1 `
    -Path 'activities.csv' `
    -OutTradeFile 'trades.csv' `
    -OutHoldingFile 'holdings.csv' `
    -OutDividendFile 'dividends.csv'

# To create reports for a specific calendar year
.\Get-RevolutStockReport.ps1 `
    -Path 'activities.csv' `
    -Year 2022 `
    -OutTradeFile 'trades_2022.csv' `
    -OutHoldingFile 'holdings_2022.csv' `
    -OutDividendFile 'dividends_2022.csv'
```

# Important Note
I do not make any guarantees about the correctness or reliability of this script. Its potential use, e.g. for tax reporting purposes, is completely at your own risk & responsiblity.

That being said, if you find bugs, please feel free to contribute!
