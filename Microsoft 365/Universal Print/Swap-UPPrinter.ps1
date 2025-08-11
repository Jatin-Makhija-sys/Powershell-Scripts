<#
.SYNOPSIS
    Swap the registered printer behind an existing Universal Print share.

.DESCRIPTION
    Resolves the existing printer share and the target registered printer by DisplayName
    using the UniversalPrintManagement module, then swaps the printer linked to the share.

.PARAMETER ShareName
    DisplayName of the existing Universal Print share.

.PARAMETER NewPrinterName
    DisplayName of the registered printer you want to swap in.

.REQUIREMENTS
    - PowerShell 5.1/7+
    - Module: UniversalPrintManagement
    - Printer Administrator (or higher) role
    - Signed into the correct tenant

.AUTHOR
    Author   : Jatin Makhija
    Website  : https://techpress.net
    Created  : 11-Aug-2025
    Version  : 1.0
#>

$ShareName        = "EPSON-2810-FirstFloorPrinter"
$NewPrinterName   = "NewEPSONPrinter(Updated Driver)"

Import-Module UniversalPrintManagement; Connect-UPService
$share  = (Get-UPPrinterShare).Results | Where-Object DisplayName -eq $ShareName
$target = (Get-UPPrinter).Results      | Where-Object DisplayName -eq $NewPrinterName
if(!$share -or !$target){ throw "Share or printer not found (check names or paging)." }
Set-UPPrinterShare -ShareId $share.Id -TargetPrinterId $target.Id