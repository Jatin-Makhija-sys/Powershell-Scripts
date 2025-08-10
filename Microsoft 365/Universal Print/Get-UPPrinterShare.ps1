<#
.SYNOPSIS
Retrieves and displays all Universal Print printer shares in a formatted table.

.DESCRIPTION
This script connects to the Microsoft Universal Print service, retrieves all printer shares
(including results from multiple pages if applicable), and outputs a clean, formatted table.
It includes only the ShareID, DisplayName, and the creation date of each share.

.PARAMETER None
This script does not require parameters. The signed-in account must have the necessary
permissions to access Universal Print resources.

.REQUIREMENTS
- PowerShell 5.1 or later
- UniversalPrintManagement PowerShell module installed
- Appropriate Microsoft 365/Universal Print license assigned
- Network access to Microsoft Universal Print endpoints

.OUTPUTS
Table format with the following columns:
- ShareID      : Unique identifier for the printer share
- DisplayName  : Friendly name of the printer share
- Share Date   : Date and time when the printer share was created

.EXAMPLE
PS C:\> .\Get-UPPrinterShares.ps1
Connects to Universal Print, retrieves all printer shares, and displays them in a table.

.NOTES
Author   : Jatin Makhija
Website  : https://cloudinfra.net
Created  : 10-Aug-2025
Version  : 1.0

#>

# Connect to the Universal Print service using the currently signed-in account
# This will prompt for sign-in if not already authenticated
Connect-UPService

# Initialize an empty array to store all printer shares
$allPrinterShares = @()

# Retrieve the first page of Universal Print printer shares
$response = Get-UPPrinterShare

# Add the first page of results to the array
$allPrinterShares += $response.Results

# If more than one page of results exists, follow the '@odata.nextLink' property to retrieve them
# Continue looping until no further pages are available
while ($response.'@odata.nextLink') {
    $response = Get-UPPrinterShare -Uri $response.'@odata.nextLink'
    $allPrinterShares += $response.Results
}

# Format and display the output in a table with selected columns:
# - ShareID: The unique identifier (Id) of the printer share
# - DisplayName: The friendly name of the printer share
# - Share Date: The date and time when the printer share was created
$allPrinterShares |
    Select-Object @{Name='ShareID'; Expression={$_.Id}},
                  DisplayName,
                  @{Name='Share Date'; Expression={$_.CreatedDateTime}} |
    Format-Table -AutoSize