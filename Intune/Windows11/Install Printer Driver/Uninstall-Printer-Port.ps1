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

    # Capture printer (to get its PortName) before removal
    $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if (-not $printer) {
        Add-LogEntry ("Printer '{0}' not found. Nothing to remove." -f $PrinterName) 'WARN'
        Add-LogEntry "Completed successfully."
        exit 0
    }

    $portNameToCheck = $printer.PortName
    if ([string]::IsNullOrWhiteSpace($portNameToCheck)) {
        Add-LogEntry "Printer has no associated port name (unexpected). Will remove printer only." 'WARN'
    } else {
        Add-LogEntry ("Associated port detected: '{0}'" -f $portNameToCheck)
    }

    # Remove the printer
    Add-LogEntry ("Removing printer '{0}'..." -f $PrinterName)
    Remove-Printer -Name $PrinterName -ErrorAction Stop
    Add-LogEntry "Printer removed."

    # Best-effort port cleanup: remove only if no other printer uses it
    if (-not [string]::IsNullOrWhiteSpace($portNameToCheck)) {
        try {
            $stillInUse = Get-Printer -ErrorAction SilentlyContinue | Where-Object { $_.PortName -eq $portNameToCheck }
            if ($stillInUse) {
                Add-LogEntry ("Port '{0}' is still in use by another printer. Skipping port removal." -f $portNameToCheck) 'WARN'
            } else {
                Add-LogEntry ("Attempting to remove port '{0}'..." -f $portNameToCheck)
                # Validate the port actually exists before attempting removal
                $portObject = Get-PrinterPort -Name $portNameToCheck -ErrorAction SilentlyContinue
                if ($portObject) {
                    Remove-PrinterPort -Name $portNameToCheck -ErrorAction Stop
                    Add-LogEntry ("Port '{0}' removed." -f $portNameToCheck)
                } else
                {
                    Add-LogEntry ("Port '{0}' not found. Nothing to remove." -f $portNameToCheck) 'WARN'
                }
            }
        }
        catch {
            # Do not fail the script if the port cannot be removed (e.g., in use or permission issues)
            Add-LogEntry ("Could not remove port '{0}': {1}" -f $portNameToCheck, $_.Exception.Message) 'WARN'
        }
    }

    Add-LogEntry "Completed successfully."
    exit 0
}
catch {
    Add-LogEntry ("ERROR: {0}" -f $_.Exception.Message) 'ERROR'
    exit 1
}