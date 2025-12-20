<#
.SYNOPSIS
  Detection script for "Uninstall Zoom" Win32 app in Intune.

.DESCRIPTION
  Checks for Zoom in common machine-wide and per-user locations.
  - Returns exit code 1 if Zoom is detected (uninstall still needed).
  - Returns exit code 0 if Zoom is NOT detected anywhere (uninstall complete).

.NOTES
  File Name   : Check-ZoomInstallation.ps1
  Author      : Jatin Makhija
  Updated     : 2025-12 (Cloudinfra.net)
#>

$zoomFound = $false

# 1. Check common machine-wide install locations
$machinePaths = @(
    "C:\Program Files\Zoom\bin\Zoom.exe",
    "C:\Program Files\Zoom\bin",
    "C:\Program Files (x86)\Zoom\bin\Zoom.exe",
    "C:\Program Files (x86)\Zoom\bin"
)

foreach ($path in $machinePaths) {
    if (Test-Path -Path $path) {
        Write-Output "Detected Zoom at machine path: $path"
        $zoomFound = $true
        break
    }
}

# 2. Check per-user AppData\Roaming\Zoom if not already found
if (-not $zoomFound) {
    $userRoot = "C:\Users"

    if (Test-Path -Path $userRoot) {
        $excludedUsers = @('Public','Default','Default User','All Users','WDAGUtilityAccount')

        $users = Get-ChildItem -Path $userRoot -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -notin $excludedUsers }

        foreach ($user in $users) {
            $userZoomPaths = @(
                (Join-Path $user.FullName "AppData\Roaming\Zoom\bin\Zoom.exe"),
                (Join-Path $user.FullName "AppData\Roaming\Zoom\bin")
            )

            foreach ($p in $userZoomPaths) {
                if (Test-Path -Path $p) {
                    Write-Output "Detected Zoom for user '$($user.Name)' at: $p"
                    $zoomFound = $true
                    break
                }
            }

            if ($zoomFound) { break }
        }
    }
}

if ($zoomFound) {
    # Zoom is still installed somewhere – app state NOT achieved yet
    Write-Output "Zoom detected on this device – uninstall still required"
    exit 1
} else {
    # Zoom not found anywhere – uninstall state achieved
    Write-Output "Zoom not detected on this device – uninstall complete"
    exit 0
}