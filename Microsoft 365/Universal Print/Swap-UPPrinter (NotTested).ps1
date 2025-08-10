<#
.SYNOPSIS
    Interactively swap a Universal Print printer for an existing printer share.

.DESCRIPTION
    Replaces the underlying printer hardware while keeping the same printer share
    (name, permissions, Intune assignments). Works in Windows PowerShell 5.1+ and PowerShell 7+.
    Uses Out-GridView if available, with a console fallback.

.PREREQUISITES
    - UniversalPrintManagement module
    - Universal Print Administrator or Printer Administrator role
    - New printer registered in Universal Print

.USAGE
    # Normal run
    .\Swap-UPPrinter.ps1

    # Dry-run (WhatIf) — simulates actions without changing anything
    .\Swap-UPPrinter.ps1 -WhatIf

.NOTES
    Author: Jatin Makhija
    Version: 1.0.2
    Last Updated: 2025-08-10
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param()

$ErrorActionPreference = 'Stop'

# --- Logging ---
$logFolder = Join-Path $env:TEMP 'UP-SwapLogs'
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logFolder "UP-Swap-$timestamp.log"
try { Start-Transcript -Path $logPath -Append -ErrorAction SilentlyContinue | Out-Null } catch {}

function Write-Info($msg){ Write-Host "[INFO]  $msg" }
function Write-Warn($msg){ Write-Warning $msg }
function Write-Err ($msg){ Write-Error $msg }

function Test-OutGridViewAvailable {
    return [bool](Get-Command Out-GridView -ErrorAction SilentlyContinue)
}

# Pagers (handle @odata.nextLink)
function Get-AllUPPrinterShares {
    $all = @()
    $resp = Get-UPPrinterShare
    if ($resp) {
        if ($resp.PSObject.Properties.Name -contains 'Results') {
            $all += $resp.Results
            while ($resp.'@odata.nextLink') {
                $resp = Get-UPPrinterShare -Uri $resp.'@odata.nextLink'
                $all += $resp.Results
            }
        } else { $all += $resp }
    }
    return $all
}

function Get-AllUPPrinters {
    $all = @()
    $resp = Get-UPPrinter
    if ($resp) {
        if ($resp.PSObject.Properties.Name -contains 'Results') {
            $all += $resp.Results
            while ($resp.'@odata.nextLink') {
                $resp = Get-UPPrinter -Uri $resp.'@odata.nextLink'
                $all += $resp.Results
            }
        } else { $all += $resp }
    }
    return $all
}

# Console fallback selector
function Select-FromConsole {
    param(
        [Parameter(Mandatory=$true)]$Items,
        [string]$Title = "Select an item",
        [string[]]$DisplayProperties = @('DisplayName','Id')
    )

    if (-not $Items -or $Items.Count -eq 0) { throw "No items available to select." }

    Write-Host "---- $Title ----"
    for ($i=0; $i -lt $Items.Count; $i++) {
        $it = $Items[$i]
        $line = ("{0}. " -f $i)
        foreach ($p in $DisplayProperties) {
            if ($it.PSObject.Properties.Name -contains $p) {
                # Avoid $p: drive syntax — wrap the var name
                $line += "$( $p ): $($it.$p)  "
            }
        }
        Write-Host $line
    }

    do {
        $choiceText = Read-Host "Enter number (0-$($Items.Count-1))"
        $choice = 0
        $ok = [int]::TryParse($choiceText, [ref]$choice)
    } until ($ok -and $choice -ge 0 -and $choice -lt $Items.Count)

    return $Items[$choice]
}

# Ensure module
if (-not (Get-Module -ListAvailable -Name UniversalPrintManagement)) {
    Write-Info "Installing UniversalPrintManagement module for current user..."
    Install-Module UniversalPrintManagement -Scope CurrentUser -Force -ErrorAction Stop
}
Import-Module UniversalPrintManagement -ErrorAction Stop

# Connect
Write-Info "Connecting to Universal Print..."
Connect-UPService

# Data
Write-Info "Fetching printer shares..."
$shares = Get-AllUPPrinterShares | Sort-Object DisplayName
if (-not $shares) { throw "No printer shares found." }

Write-Info "Fetching registered printers..."
$printers = Get-AllUPPrinters | Sort-Object DisplayName
if (-not $printers) { throw "No registered printers found." }

# Pick share
if (Test-OutGridViewAvailable) {
    $share = $shares |
        Select-Object DisplayName, Id, @{n='PrinterId';e={$_.Printer.Id}}, CreatedDateTime |
        Out-GridView -Title "Select the EXISTING Printer Share to keep" -PassThru
} else {
    $share = Select-FromConsole -Items $shares -Title "Select the EXISTING Printer Share to keep" -DisplayProperties @('DisplayName','Id')
}
if (-not $share) { throw "No printer share selected. Aborting." }

# Current linked printer (may be null)
$currentPrinterId = $null
try { $currentPrinterId = $share.Printer.Id } catch {}

# Pick new printer (with optional filter)
$useFilter = Read-Host "Filter printers by name? (y/N)"
$candidatePrinters = $printers
if ($useFilter -match '^(y|yes)$') {
    $flt = Read-Host "Enter part of the printer name to filter"
    if ($flt) {
        $filtered = $printers | Where-Object { $_.DisplayName -like "*$flt*" }
        if ($filtered) { $candidatePrinters = $filtered } else { Write-Warn "No printers matched '$flt'. Showing all." }
    }
}

if (Test-OutGridViewAvailable) {
    $newPrinter = $candidatePrinters |
        Select-Object DisplayName, Id, Manufacturer, Model |
        Out-GridView -Title "Select the NEW Printer to bind to the share: $($share.DisplayName)" -PassThru
} else {
    $newPrinter = Select-FromConsole -Items $candidatePrinters -Title "Select the NEW Printer to bind to the share: $($share.DisplayName)" -DisplayProperties @('DisplayName','Id')
}
if (-not $newPrinter) { throw "No new printer selected. Aborting." }

# Summary (PS5.1-safe null display)
$currentPrinterIdDisplay = if ($null -ne $currentPrinterId -and "$currentPrinterId" -ne "") { $currentPrinterId } else { '<none>' }

Write-Host ""
Write-Host "================= SUMMARY ================="
Write-Host ("Share:          {0}" -f $share.DisplayName)
Write-Host ("ShareId:        {0}" -f $share.Id)
Write-Host ("CurrentPrinter: {0}" -f $currentPrinterIdDisplay)
Write-Host ("NewPrinter:     {0}" -f $newPrinter.DisplayName)
Write-Host ("NewPrinterId:   {0}" -f $newPrinter.Id)
Write-Host "==========================================="
Write-Host ""

$confirm = Read-Host "Proceed with swap? (type YES to continue)"
if ($confirm -ne 'YES') {
    Write-Warn "User cancelled. No changes made."
    try { Stop-Transcript | Out-Null } catch {}
    return
}

# Detect if script was invoked with -WhatIf (common parameter)
$scriptWhatIf = $PSBoundParameters.ContainsKey('WhatIf')

# Swap
try {
    if ($PSCmdlet.ShouldProcess("Share $($share.DisplayName)", "Set-UPPrinterShare -> PrinterId $($newPrinter.Id)")) {
        if ($scriptWhatIf) {
            Set-UPPrinterShare -PrinterShareId $share.Id -PrinterId $newPrinter.Id -WhatIf
        } else {
            Set-UPPrinterShare -PrinterShareId $share.Id -PrinterId $newPrinter.Id
        }
        Write-Info "Swap command submitted."
    }
} catch {
    Write-Err "Failed to swap: $($_.Exception.Message)"
    try { Stop-Transcript | Out-Null } catch {}
    throw
}

# Validate
Start-Sleep -Seconds 2
Write-Info "Validating swap..."
$updatedShare = Get-UPPrinterShare -PrinterShareId $share.Id
$newLinkedPrinterId = $null
try { $newLinkedPrinterId = $updatedShare.Printer.Id } catch {}

if ($newLinkedPrinterId -and ($newLinkedPrinterId -eq $newPrinter.Id)) {
    Write-Host "SUCCESS: Share '$($share.DisplayName)' now points to printer '$($newPrinter.DisplayName)'." -ForegroundColor Green
} else {
    Write-Warn "Validation could not confirm the new linkage. Inspect the share in the portal to verify."
}

# Optional cleanup
if ($currentPrinterId -and $currentPrinterId -ne $newPrinter.Id) {
    $cleanup = Read-Host "Unregister the OLD printer ($currentPrinterId)? (y/N)"
    if ($cleanup -match '^(y|yes)$') {
        try {
            if ($PSCmdlet.ShouldProcess("Old printer $currentPrinterId", "Remove-UPPrinter")) {
                if ($scriptWhatIf) {
                    Remove-UPPrinter -PrinterId $currentPrinterId -WhatIf
                } else {
                    Remove-UPPrinter -PrinterId $currentPrinterId
                }
                Write-Info "Old printer unregistered."
            }
        } catch {
            Write-Warn "Could not remove old printer: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Info "All done. Log saved to: $logPath"
try { Stop-Transcript | Out-Null } catch {}