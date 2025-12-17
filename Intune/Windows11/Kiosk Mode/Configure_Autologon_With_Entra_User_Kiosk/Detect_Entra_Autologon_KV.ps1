# Detect_Entra_Autologon.ps1
$ErrorActionPreference = "Stop"

$ExpectedUpn       = "jatin@cloudinfra.net"
$ExpectedDomain    = "AzureAD"
$AutologonExe      = Join-Path $env:ProgramFiles "KioskTools\Sysinternals\Autologon64.exe"
$ExpectedThumbprint = "523DF5810040D4E3443D69673F7D0DEC2AF9819E"

# Prereq gate: tool not present yet, do not remediate
if (-not (Test-Path $AutologonExe)) {
  Write-Output "PrereqMissing:AutologonExe"
  exit 0
}

# Prereq gate: client cert not present yet, do not remediate
$cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
  Where-Object { $_.Thumbprint -eq $ExpectedThumbprint } |
  Select-Object -First 1

if (-not $cert) {
  Write-Output "PrereqMissing:ClientCert"
  exit 0
}

$wl = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$auto = (Get-ItemProperty -Path $wl -Name AutoAdminLogon -ErrorAction SilentlyContinue).AutoAdminLogon
$user = (Get-ItemProperty -Path $wl -Name DefaultUserName -ErrorAction SilentlyContinue).DefaultUserName
$dom  = (Get-ItemProperty -Path $wl -Name DefaultDomainName -ErrorAction SilentlyContinue).DefaultDomainName

if ($auto -eq "1" -and $user -eq $ExpectedUpn -and $dom -eq $ExpectedDomain) {
  Write-Output "Compliant"
  exit 0
}

Write-Output "NonCompliant:AutologonNotConfiguredOrMismatch"
exit 1