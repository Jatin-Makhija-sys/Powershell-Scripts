<#
.SYNOPSIS
Ensures the current user’s Explorer policy key exists and sets NoDesktop to DWORD 0.

.DESCRIPTION
Runs under SYSTEM, targets the signed-in user hive via HKU, and:

.INPUTS
None.

.OUTPUTS
None. Uses exit codes.

.NOTES
Author: Jatin Makhija
Version: 1.0.1
LastUpdated: 01-Nov-2025
RunAs: SYSTEM
Idempotent: Yes

.EXAMPLE
.\Show_Desktop_Icons.ps1
#>

$ErrorActionPreference = 'Stop'

# Mount HKU for SYSTEM context runs
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
# Resolve the signed-in user
$currentUserName = (Get-CimInstance Win32_ComputerSystem).UserName
if (-not $currentUserName) { exit 1 }

try {
    $currentUserSid = (New-Object System.Security.Principal.NTAccount($currentUserName)).
        Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch { exit 1 }

$regKeyPath = "HKU:\$currentUserSid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$valueName  = "NoDesktop"

try {
    # Create Explorer key only if missing
    if (-not (Test-Path -Path $regKeyPath)) {
        New-Item -Path $regKeyPath -Force | Out-Null
    }

    # Set or update NoDesktop to 0
    New-ItemProperty -Path $regKeyPath -Name $valueName -Value 0 -PropertyType DWord -Force | Out-Null
    exit 0
} catch {
    exit 1
}