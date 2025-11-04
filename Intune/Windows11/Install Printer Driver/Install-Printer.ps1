<#
.SYNOPSIS
Installs a TCP/IP network printer on Windows by staging a driver, creating a port, and adding a printer.

.DESCRIPTION
This script is designed for Intune Win32 deployments and interactive use. It performs the following steps:
  1) Stages the specified printer driver (.INF) into the Windows Driver Store using pnputil.
  2) Creates a Standard TCP/IP printer port for the given printer IP. 
     - Uses Add-PrinterPort first, then falls back to WMI (Win32_TCPIPPrinterPort), and finally prnport.vbs.
     - Does not require the printer to be reachable at install time.
  3) Ensures the named printer driver exists (installed from the staged package).
  4) Creates the printer queue with the provided name, driver, and port.
  
All actions are logged to:
  %ProgramData%\Microsoft\IntuneManagementExtension\Logs\Install-Printer.log
The log file is cleared at the start of each run so it only contains the latest execution.

.PARAMETER PrinterIP
IPv4 address of the printer, for example 10.1.1.3.

.PARAMETER PrinterName
Display name of the printer queue to create, for example "Office MFP 3rd Floor".

.PARAMETER InfPath
Path to the printer driver INF file. For Intune Win32 packages use a relative path like ".\Driver\x3UNIVX.inf".

.PARAMETER DriverName
Exact printer driver name as it appears in Print Management, for example "Xerox Global Print Driver PCL6".

.PARAMETER PortName
Optional. Name of the TCP/IP port to create or reuse. Defaults to "Port_<PrinterIP>".

.EXAMPLE
.\Install-Printer.ps1 -PrinterIP 10.1.1.3 -PrinterName "Office MFP 3rd Floor" -InfPath ".\Driver\x3UNIVX.inf" -DriverName "Xerox Global Print Driver PCL6"

.EXAMPLE
powershell.exe -ExecutionPolicy Bypass -File .\Install-Printer.ps1 -PrinterIP 10.1.1.3 -PrinterName "Office MFP 3rd Floor" -InfPath ".\Driver\x3UNIVX.inf" -DriverName "Xerox Global Print Driver PS"

.RETURNS
Exit code 0 on success, 1 on failure.

.NOTES
Author: Jatin Makhija (cloudinfra.net)
Version: 1.2.0
Created: 2025-11-04
Tested on: Windows 11 23H2/24H2, Windows 10 22H2
Requirements: Administrator, Print Spooler service running
Logging: Overwrites log each run. Screen output mirrors log entries.

.LINK
N/A
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string]$PrinterIP,
    [Parameter(Mandatory=$true)] [string]$PrinterName,
    [Parameter(Mandatory=$true)] [string]$InfPath,
    [Parameter(Mandatory=$true)] [string]$DriverName,
    [string]$PortName = ("Port_{0}" -f $PrinterIP)
)

# --- Logging (screen + file) ---
$LogDir  = Join-Path $env:ProgramData "Microsoft\IntuneManagementExtension\Logs"
$LogFile = Join-Path $LogDir "Install-Printer.log"
if (-not (Test-Path $LogDir)) { New-Item -Type Directory -Path $LogDir -Force | Out-Null }
# Clear the log each run (keep only the latest)
if (Test-Path $LogFile) { Clear-Content -Path $LogFile -Force -ErrorAction SilentlyContinue }

function Add-LogEntry {
<#
.SYNOPSIS
Writes a timestamped entry to screen and to the Install-Printer.log file.

.PARAMETER Message
Text to log.

.PARAMETER Level
Log level. One of INFO, WARN, or ERROR.
#>
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    # screen
    switch ($Level) {
        'ERROR' { Write-Error $line }
        'WARN'  { Write-Warning $line }
        default { Write-Host $line }
    }
    # file
    Add-Content -Path $LogFile -Value $line
}

try {
    Add-LogEntry ("Starting printer install. IP='{0}', Name='{1}', INF='{2}', Driver='{3}'" -f $PrinterIP,$PrinterName,$InfPath,$DriverName)

    # --- Stage driver with pnputil ---
    if (-not (Test-Path -Path $InfPath)) {
        throw "INF not found at path: $InfPath"
    }

    # Use the correct pnputil for both native and 32-bit PowerShell on 64-bit OS
    $pnputilPathCandidates = @(
        (Join-Path $env:windir 'System32\pnputil.exe'),
        (Join-Path $env:windir 'sysnative\pnputil.exe')  # when 32-bit host on 64-bit OS
    )
    $pnputil = $pnputilPathCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $pnputil) { throw "pnputil.exe not found." }

    Add-LogEntry "Staging driver with pnputil..."
    $pnputilArgs   = @('/add-driver', "`"$InfPath`"", '/install')
    $pnputilOutput = & $pnputil @pnputilArgs 2>&1
    $pnputilExit   = $LASTEXITCODE
    Add-LogEntry ("pnputil exit code: {0}" -f $pnputilExit)
    if ($pnputilOutput) { Add-LogEntry ($pnputilOutput -join [Environment]::NewLine) }

    # Accept 0 (success) and 259 (already staged/up-to-date) as non-fatal
    if ($pnputilExit -notin 0,259) {
        throw ("Driver staging failed (pnputil exit code {0})." -f $pnputilExit)
    }

    # --- Create Standard TCP/IP port (robust, no reachability required) ---
    Add-LogEntry ("Ensuring TCP/IP port exists for {0} (PortName='{1}')." -f $PrinterIP,$PortName)

    # Reuse an existing port with same name or same IP if one already exists
    $existingPort = Get-PrinterPort -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -eq $PortName -or $_.PrinterHostAddress -eq $PrinterIP }
    if ($existingPort) {
        Add-LogEntry ("Printer port already exists: {0}" -f $existingPort.Name)
        $PortName = $existingPort.Name
    } else {
        Add-LogEntry ("Creating TCP/IP port '{0}' for {1}" -f $PortName, $PrinterIP)

        $portCreated = $false

        # Primary: native Add-PrinterPort
        try {
            Add-PrinterPort -Name $PortName -PrinterHostAddress $PrinterIP -ErrorAction Stop
            $portCreated = $true
            Add-LogEntry "Port created via Add-PrinterPort."
        } catch {
            Add-LogEntry ("Add-PrinterPort failed: {0}" -f $_.Exception.Message) 'WARN'
        }

        # Fallback 1: WMI Win32_TCPIPPrinterPort.Create(Name, HostAddress, SNMPEnabled, PortNumber)
        if (-not $portCreated) {
            try {
                $wmiResult = Invoke-WmiMethod -Class Win32_TCPIPPrinterPort -Name Create -ArgumentList @($PortName, $PrinterIP, $false, 9100) -ErrorAction Stop
                if ($null -ne $wmiResult -and $wmiResult.ReturnValue -eq 0) {
                    $portCreated = $true
                    Add-LogEntry "Port created via WMI (Win32_TCPIPPrinterPort)."
                } else {
                    Add-LogEntry ("WMI port create returned code: {0}" -f $wmiResult.ReturnValue) 'WARN'
                }
            } catch {
                Add-LogEntry ("WMI port create failed: {0}" -f $_.Exception.Message) 'WARN'
            }
        }

        # Fallback 2: prnport.vbs (legacy admin script)
        if (-not $portCreated) {
            try {
                $prnport = Join-Path $env:WINDIR 'System32\Printing_Admin_Scripts\en-US\prnport.vbs'
                if (-not (Test-Path $prnport)) {
                    $prnport = Join-Path $env:WINDIR 'System32\Printing_Admin_Scripts\prnport.vbs'
                }
                if (Test-Path $prnport) {
                    $cscript = Join-Path $env:WINDIR 'System32\cscript.exe'
                    $cArgs = @('//nologo', $prnport, '-a', '-r', $PortName, '-h', $PrinterIP, '-o', 'raw', '-n', '9100')
                    $proc = Start-Process -FilePath $cscript -ArgumentList $cArgs -NoNewWindow -Wait -PassThru
                    Add-LogEntry ("prnport.vbs exit code: {0}" -f $proc.ExitCode)
                    if ($proc.ExitCode -eq 0) {
                        $portCreated = $true
                        Add-LogEntry "Port created via prnport.vbs."
                    }
                } else {
                    Add-LogEntry "prnport.vbs not found." 'WARN'
                }
            } catch {
                Add-LogEntry ("prnport.vbs port create failed: {0}" -f $_.Exception.Message) 'WARN'
            }
        }

        # Verify we actually have the port
        $verifyPort = Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
        if (-not $portCreated -or -not $verifyPort) {
            throw "Port '$PortName' could not be created."
        }
        Add-LogEntry "Port created and verified."
    }

    # --- Ensure printer driver is installed (from the staged package) ---
    $driver = Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue
    if (-not $driver) {
        Add-LogEntry ("Adding printer driver '{0}'" -f $DriverName)
        Add-PrinterDriver -Name $DriverName -ErrorAction Stop
        Add-LogEntry "Driver added."
    } else {
        Add-LogEntry "Driver already present."
    }

    # --- Create the printer if missing ---
    $printer = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
    if ($printer) {
        Add-LogEntry ("Printer '{0}' already exists. Skipping creation." -f $PrinterName)
    } else {
        Add-LogEntry ("Creating printer '{0}' on port '{1}' using driver '{2}'." -f $PrinterName,$PortName,$DriverName)
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
        Add-LogEntry "Printer created."
    }

    Add-LogEntry "Completed successfully."
    exit 0
}
catch {
    Add-LogEntry ("ERROR: {0}" -f $_.Exception.Message) 'ERROR'
    exit 1
}