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
