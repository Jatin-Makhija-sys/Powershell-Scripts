# Uninstall-Autologon.ps1
$ErrorActionPreference = "Stop"

# 1) Disable Winlogon autologon settings
$wl = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

# Disable autologon
New-ItemProperty -Path $wl -Name "AutoAdminLogon" -Value "0" -PropertyType String -Force | Out-Null

# Remove username/domain references (optional but recommended)
Remove-ItemProperty -Path $wl -Name "DefaultUserName" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path $wl -Name "DefaultDomainName" -ErrorAction SilentlyContinue

# Note: we do NOT write DefaultPassword at any point.

# 2) Remove Autologon64.exe
$destDir = Join-Path $env:ProgramFiles "KioskTools\Sysinternals"
$destExe = Join-Path $destDir "Autologon64.exe"

if (Test-Path $destExe) {
  Remove-Item -Path $destExe -Force
}

# Remove directory if empty
if (Test-Path $destDir) {
  $items = Get-ChildItem -Path $destDir -Force -ErrorAction SilentlyContinue
  if (-not $items) {
    Remove-Item -Path $destDir -Force
  }
}

# Remove parent folder if empty
$parent = Split-Path $destDir -Parent
if (Test-Path $parent) {
  $items = Get-ChildItem -Path $parent -Force -ErrorAction SilentlyContinue
  if (-not $items) {
    Remove-Item -Path $parent -Force
  }
}

Write-Output "Disabled AutoAdminLogon and removed Autologon64.exe"
exit 0