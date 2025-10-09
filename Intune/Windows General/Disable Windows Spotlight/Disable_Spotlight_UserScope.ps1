<#
.SYNOPSIS
    Disables Windows Spotlight for the signed-in user

.DESCRIPTION
   Disables settings given at 
   https://learn.microsoft.com/en-us/windows/configuration/windows-spotlight/?pivots=windows-11#policy-settings link

.NOTES
    Author: Jatin Makhija
    Copyright: cloudinfra.net
    Version: 1.0.0

.EXAMPLE
    # Run as admin/SYSTEM while a user is logged on
    .\Disable_Spotlight_UserScope.ps1
#>
$user = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $user) { Write-Error "No interactive user detected."; exit 1 }
$sid  = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

$Path = "Registry::HKEY_USERS\$sid\Software\Policies\Microsoft\Windows\CloudContent"
New-Item -Path $Path -Force | Out-Null

# Required policy values (user scope)
$Desired = @{
  DisableWindowsSpotlightFeatures                  = 1
  DisableSpotlightCollectionOnDesktop              = 1
  DisableWindowsSpotlightOnSettings                = 1
  DisableWindowsSpotlightOnActionCenter            = 1
  DisableWindowsSpotlightWindowsWelcomeExperience  = 1
  DisableThirdPartySuggestions                     = 1
  ConfigureWindowsSpotlight                        = 0   # 0 = disabled
}

foreach ($name in $Desired.Keys) {
  New-ItemProperty -Path $Path -Name $name -PropertyType DWord -Value $Desired[$name] -Force | Out-Null
}

Write-Host "Windows Spotlight disabled for $user (HKU\$sid). Sign out/in or restart Explorer to apply UI changes."