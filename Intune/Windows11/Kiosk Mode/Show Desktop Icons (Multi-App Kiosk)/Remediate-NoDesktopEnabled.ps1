<#
.SYNOPSIS
Remediates the current user’s Desktop visibility by ensuring NoDesktop is a DWORD set to 0.

.DESCRIPTION
This detection script will remediate NoDesktop registry entry type and value.
The script will work for Intune Detection in SYSTEM context.

Behaviour:
- Creates the Explorer policy key if missing.
- Creates or updates NoDesktop to a DWORD value of 0.
- Exits 0 on success. Exits 1 only when no user is signed in or the user SID cannot be resolved.

.PARAMETER None
This script does not accept parameters.

.INPUTS
None.

.OUTPUTS
None. Writes no objects. Uses exit codes for Intune remediation result.

.NOTES
Author: Jatin Makhija
Version: 1.0.0
LastUpdated: 01-Nov-2025
RunAs: SYSTEM
Idempotent: Yes
TestedOn: Windows 11 23H2 and later

.EXAMPLE
.\Remediate-NoDesktopEnabled.ps1
# Ensures HKU\<UserSID>\...\Explorer\NoDesktop exists as DWORD 0. Returns 0 on success.

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

New-Item -Path $regKeyPath -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path $regKeyPath -Name $valueName -Value 0 -PropertyType DWord -Force | Out-Null

exit 0