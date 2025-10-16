<#
.SYNOPSIS
    Disables automatic startup for Microsoft 365 companion apps (Calendar, Files, People) for the current user.

.DESCRIPTION
    This script targets the per-user Startup Task registry for the Microsoft 365 companion apps suite and sets the
    "State" value to 1 for the Calendar, Files, and People components where present. A value of 1 disables the
    startup task. If the base registry path is not found for the current user, the script reports that there is
    nothing to disable and exits successfully. The script is designed for user context execution.

.NOTES
    Author   : Jatin Makhija
    Website  : https://cloudinfra.net
    Version  : 1.0.0
    Context  : Run in USER context (HKCU). Works for per-user installs.
    Behavior : Sets the Startup Task "State" to 1 for each component if present.
    Returns  : Exit code 0 on success or when no action is needed, non-zero on unexpected error.

.EXAMPLE
    .\Disable-M365CompanionStartup.ps1
    Runs the script for the current user and disables startup for any present Microsoft 365 companion components.

#>

$ErrorActionPreference = 'Stop'

# Registry base for the companion suite Startup Tasks (per user)
$base = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.M365Companions_8wekyb3d8bbwe'

# Component startup task subkeys
$components = @(
  'CalendarStartupId',
  'FilesStartupId',
  'PeopleStartupId'
)

# Ensure base exists before proceeding
if (-not (Test-Path $base)) {
  Write-Host "Microsoft 365 companion apps startup registry base not found for this user. Nothing to disable."
  exit 0
}

$changed = $false
foreach ($comp in $components) {
  $path = Join-Path $base $comp
  if (Test-Path $path) {
    try {
      # State: 0 = Enabled, 1 = Disabled
      New-ItemProperty -Path $path -Name 'State' -PropertyType DWord -Value 1 -Force | Out-Null
      Write-Host "Disabled startup for: $comp"
      $changed = $true
    } catch {
      Write-Warning "Failed to set State for $comp. $_"
      exit 2
    }
  } else {
    Write-Host "Startup task not found (likely not installed yet): $comp"
  }
}

if ($changed) {
  Write-Host "Completed. Log off or reboot to confirm the change in Task Manager > Startup."
} else {
  Write-Host "No changes were necessary."
}

exit 0