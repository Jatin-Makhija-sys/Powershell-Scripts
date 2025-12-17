# Install-Autologon.ps1
$ErrorActionPreference = "Stop"

$destDir = Join-Path $env:ProgramFiles "KioskTools\Sysinternals"
$destExe = Join-Path $destDir "Autologon64.exe"

New-Item -Path $destDir -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot "Autologon64.exe") -Destination $destExe -Force

Write-Output "Installed Autologon64.exe to $destExe"
exit 0