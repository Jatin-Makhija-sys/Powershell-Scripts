<#
.SYNOPSIS
    Force-enable Windows Spotlight for the signed-in user via policy.

.DESCRIPTION
    Sets per-user policy values under:
      HKU\<UserSID>\Software\Policies\Microsoft\Windows\CloudContent
    - All "Turn off ..." flags set to 0 (allow)
    - ConfigureWindowsSpotlight set to 1 (force lock screen Spotlight)
    The key is created only if missing. It is never deleted.

.NOTES
    Author: Jatin Makhija
    Copyright: cloudinfra.net
    Version: 1.2.1
#>

$ErrorActionPreference = 'Stop'

# Resolve interactive user and SID
$user = (Get-CimInstance Win32_ComputerSystem).UserName
if (-not $user) { Write-Error "No interactive user detected. Run while a user session is active."; exit 1 }

try {
    $sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch {
    Write-Error "Failed to resolve SID for $user"; exit 1
}

# Per-user Policies path
$Path = "Registry::HKEY_USERS\$sid\Software\Policies\Microsoft\Windows\CloudContent"

# Only create if missing
if (-not (Test-Path -Path $Path)) {
    New-Item -Path $Path -Force | Out-Null
}

# Values to allow Spotlight and force lock screen Spotlight
$values = @{
  'DisableWindowsSpotlightFeatures'                 = 0
  'DisableSpotlightCollectionOnDesktop'             = 0
  'DisableWindowsSpotlightOnSettings'               = 0
  'DisableWindowsSpotlightOnActionCenter'           = 0
  'DisableWindowsSpotlightWindowsWelcomeExperience' = 0
  'DisableThirdPartySuggestions'                    = 0
  'ConfigureWindowsSpotlight'                       = 1  # force lock screen Spotlight
}

foreach ($name in $values.Keys) {
    New-ItemProperty -Path $Path -Name $name -PropertyType DWord -Value $values[$name] -Force | Out-Null
}

Write-Host "Windows Spotlight allowed and lock screen Spotlight forced for $user (HKU\$sid)."
#Write-Host "If device-scope policy under HKLM blocks Spotlight, update that policy to avoid overwrite at refresh."