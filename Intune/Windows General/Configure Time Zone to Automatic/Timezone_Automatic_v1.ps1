<#
.SYNOPSIS
    Enables automatic time zone and device location settings on Windows.

.DESCRIPTION
    This script configures the following registry values:

    1. HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate
       Name: Start
       Type: DWORD
       Value: 3 (enables automatic time zone)

    2. HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location
       Name: Value
       Type: String
       Value: Allow (enables device location)

    The script creates the location registry key if it is missing.
    If the Auto Time Zone Updater service registry key is missing,
    the script reports a failure rather than creating a replacement key.

    After applying the changes, the script reads both values to confirm
    that they match the required configuration.

    Successful execution confirms the registry values only. It does not
    confirm that Windows has detected the correct location or updated
    the current time zone.

    Existing policies that block location must be resolved separately.
    The script does not continuously enforce these settings.

.INPUTS
    None. This script does not accept parameters or pipeline input.

.OUTPUTS
    A success or failure message.
    Exit code 0: Both registry values were configured and verified.
    Exit code 1: Configuration or verification failed.

.NOTES
    Author: Jatin Makhija
    Copyright: Cloudinfra.net
    Version: 1.1

    Requirements:
    - Run as SYSTEM through Intune or locally as an administrator.
    - Windows location policies must allow the required location access.

    Intune platform script settings:
    - Run this script using the logged on credentials: No
    - Enforce script signature check: No for an unsigned script;
      use Yes if the script is signed by a trusted publisher.
    - Run script in 64-bit PowerShell host: Yes

    Changes from version 1.0:
    - Added error handling and explicit exit codes.
    - Added creation of the location registry key when missing.
    - Added a check for the existing time zone service registry key.
    - Specified registry value types explicitly.
    - Added verification after writing the registry values.

.EXAMPLE
    .\Timezone_Automatic.ps1

    Run from an elevated PowerShell window to enable automatic time zone
    and device location, then verify the saved registry values.

.LINK
    https://cloudinfra.net/set-time-zone-to-automatic-on-windows-using-intune/
#>

# Treat errors as terminating errors so the catch block can report failure.
$ErrorActionPreference = 'Stop'

# Define the registry paths for automatic time zone and device location.
$TimeZonePath = 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate'
$LocationPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'

try {
    # Confirm that the Windows service registry key exists.
    # Creating an empty key would not restore a missing service.
    if (-not (Test-Path -LiteralPath $TimeZonePath)) {
        throw 'The Auto Time Zone Updater service registry key is missing.'
    }

    # Create the location consent registry key if it does not exist.
    if (-not (Test-Path -LiteralPath $LocationPath)) {
        New-Item -Path $LocationPath -Force | Out-Null
    }

    # Enable device location by setting Value to Allow as a String.
    New-ItemProperty `
        -LiteralPath $LocationPath `
        -Name 'Value' `
        -PropertyType String `
        -Value 'Allow' `
        -Force | Out-Null

    # Enable automatic time zone by setting Start to 3 as a DWORD.
    New-ItemProperty `
        -LiteralPath $TimeZonePath `
        -Name 'Start' `
        -PropertyType DWord `
        -Value 3 `
        -Force | Out-Null

    # Read both registry values to verify the saved configuration.
    $TimeZoneStart = Get-ItemPropertyValue `
        -LiteralPath $TimeZonePath `
        -Name 'Start'

    $LocationValue = Get-ItemPropertyValue `
        -LiteralPath $LocationPath `
        -Name 'Value'

    # Report failure if either value does not match the expected setting.
    if ($TimeZoneStart -ne 3 -or $LocationValue -ne 'Allow') {
        throw 'The registry values did not match the expected configuration.'
    }

    # Report successful configuration to Intune.
    Write-Output 'Automatic time zone and location registry settings configured successfully.'
    exit 0
}
catch {
    # Report the error and return a failure exit code to Intune.
    Write-Output "Configuration failed: $($_.Exception.Message)"
    exit 1
}