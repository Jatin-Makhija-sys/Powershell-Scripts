<#
.SYNOPSIS
Removes a local printer queue by name on Windows, with simple logging.

.DESCRIPTION
This script removes a specified printer queue using the built-in PrintManagement cmdlets.
It writes progress and results to both screen and a log file:
  %ProgramData%\Microsoft\IntuneManagementExtension\Logs\Uninstall-Printer.log

The log file is overwritten at the start of each run so it only contains entries from the latest execution.
The script exits with code 0 on success and 1 on failure.

.PARAMETER PrinterName
The exact name of the printer queue to remove. Example: "Office MFP 3rd Floor".

.EXAMPLE
.\Uninstall-Printer.ps1 -PrinterName "Office MFP 3rd Floor"

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -File .\Uninstall-Printer.ps1 -PrinterName "Office MFP 3rd Floor"

.NOTES
Author: Jatin Makhija (cloudinfra.net)
Version: 1.0.0
Created: 2025-11-04
Tested on: Windows 10 22H2, Windows 11 23H2/24H2
Requirements: Administrator, Print Spooler service running
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PrinterName
)

# --- Logging (screen + file, overwrite each run) ---
$LogDir  = Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path $LogDir "Uninstall-Printer.log"
if (-not (Test-Path $LogDir)) { New-Item -Type Directory -Path $LogDir -Force | Out-Null }
# Overwrite the log file so it only contains this run's entries
Set-Content -Path $LogFile -Value "" -Force

function Add-LogEntry {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message

    switch ($Level) {
        'ERROR' { Write-Error $line }
        'WARN'  { Write-Warning $line }
        default { Write-Host $line }
    }
    Add-Content -Path $LogFile -Value $line
}

try {
    Add-LogEntry ("Starting printer removal. Name='{0}'" -f $PrinterName)

    $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if (-not $printer) {
        Add-LogEntry ("Printer '{0}' not found. Nothing to remove." -f $PrinterName) 'WARN'
        Add-LogEntry "Completed successfully."
        exit 0
    }

    Add-LogEntry ("Removing printer '{0}'..." -f $PrinterName)
    Remove-Printer -Name $PrinterName -ErrorAction Stop
    Add-LogEntry "Printer removed."

    Add-LogEntry "Completed successfully."
    exit 0
}
catch {
    Add-LogEntry ("ERROR: {0}" -f $_.Exception.Message) 'ERROR'
    exit 1
}