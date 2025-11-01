<#
.SYNOPSIS
Detects whether the current user’s Desktop is enabled by verifying NoDesktop is a DWORD set to 0.

.DESCRIPTION
This detection script will verify NoDesktop registry entry type and value.
The script will work for Intune Detection in SYSTEM context.

Compliance logic:
- Exit 0 (compliant) when NoDesktop exists, is of type DWORD, and equals 0.
- Exit 1 (non-compliant) when the user is not logged on, the key or value is missing, the type is not DWORD, or the value is not 0.

.INPUTS
None.

.OUTPUTS
None. Writes no objects. Uses exit codes for Intune detection.

.NOTES
Author: Jatin Makhija
Version: 1.0.0
LastUpdated: 01-Nov-2025
RunAs: SYSTEM (Intune detection)
TestedOn: Windows 11 23H2 and later

.EXAMPLE
.\Detect-NoDesktopEnabled.ps1
# Returns 0 if HKU\<UserSID>\...\Explorer\NoDesktop is DWORD 0, otherwise returns 1.

.LINK
https://cloudinfra.net/
#>

New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
$currentUserName = (Get-CimInstance Win32_ComputerSystem).UserName
if (-not $currentUserName) { exit 1 }

try {
    $currentUserSid = (New-Object System.Security.Principal.NTAccount($currentUserName)).
        Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch { exit 1 }

$regKeyPath = "HKU:\$currentUserSid\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
$valueName  = "NoDesktop"

try {
    $currentValue = Get-ItemPropertyValue -Path $regKeyPath -Name $valueName -ErrorAction Stop
    $currentKind  = (Get-Item $regKeyPath).GetValueKind($valueName)
} catch { exit 1 }

if ($currentValue -eq 0 -and $currentKind -eq [Microsoft.Win32.RegistryValueKind]::DWord) { exit 0 } else { exit 1 }