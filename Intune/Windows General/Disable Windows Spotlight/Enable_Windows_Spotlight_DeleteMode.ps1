<#
.SYNOPSIS
    Enables Windows Spotlight for the signed-in user by removing only the
    per-user policy values that disable Spotlight.

.DESCRIPTION
    If the policy key exists, removes these values under:
      HKU\<UserSID>\Software\Policies\Microsoft\Windows\CloudContent

      - DisableWindowsSpotlightFeatures
      - DisableSpotlightCollectionOnDesktop
      - DisableWindowsSpotlightOnSettings
      - DisableWindowsSpotlightOnActionCenter
      - DisableWindowsSpotlightWindowsWelcomeExperience
      - DisableThirdPartySuggestions
      - ConfigureWindowsSpotlight

    If the key is missing, exits successfully without changes.

.NOTES
    Author: Jatin Makhija
    Copyright: cloudinfra.net
    Version: 1.0.4

.EXAMPLE
    # Run as admin or SYSTEM while a user is logged on
    .\Enable_Spotlight_UserScope.ps1
#>

# Fail fast on unexpected errors
$ErrorActionPreference = 'Stop'

# Resolve interactive user and SID
$user = (Get-CimInstance Win32_ComputerSystem).UserName
if (-not $user) { Write-Error "No interactive user detected. Run while a user session is active."; exit 1 }

try {
    $sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch {
    Write-Error "Failed to resolve SID for $user"
    exit 1
}

# Per-user Policies path
$Path = "Registry::HKEY_USERS\$sid\Software\Policies\Microsoft\Windows\CloudContent"

# If the key does not exist, nothing to do
if (-not (Test-Path -Path $Path)) {
    Write-Host "CloudContent key not found for $user. Nothing to remove."
    exit 0
}

# Only the Spotlight-related policy values to remove
$SpotlightPolicyNames = @(
  'DisableWindowsSpotlightFeatures',
  'DisableSpotlightCollectionOnDesktop',
  'DisableWindowsSpotlightOnSettings',
  'DisableWindowsSpotlightOnActionCenter',
  'DisableWindowsSpotlightWindowsWelcomeExperience',
  'DisableThirdPartySuggestions',
  'ConfigureWindowsSpotlight'
)

foreach ($name in $SpotlightPolicyNames) {
    try {
        if (Get-ItemProperty -Path $Path -Name $name -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path $Path -Name $name -ErrorAction Stop
            Write-Host "Removed policy value: $name"
        }
    } catch {
        Write-Warning "Could not remove ${name}: $($_.Exception.Message)"
    }
}

Write-Host "Windows Spotlight policy blocks removed for $user (HKU\$sid)."
Write-Host "Open Settings > Personalization > Background and Lock screen to choose Windows Spotlight."