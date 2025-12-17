$ErrorActionPreference = "Stop"

$ExpectedUpn  = "jatin@cloudinfra.net"
$ExpectedDom  = "AzureAD"
$AutologonExe = "C:\Program Files\KioskTools\Sysinternals\Autologon64.exe" 

# If Autologon tool is missing, flag as non-compliant so you notice deployment gaps
if (-not (Test-Path -LiteralPath $AutologonExe)) {
  Write-Output "NonCompliant:AutologonMissing:$AutologonExe"
  exit 1
}

$wl = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$auto = (Get-ItemProperty -Path $wl -Name AutoAdminLogon -ErrorAction SilentlyContinue).AutoAdminLogon
$user = (Get-ItemProperty -Path $wl -Name DefaultUserName -ErrorAction SilentlyContinue).DefaultUserName
$dom  = (Get-ItemProperty -Path $wl -Name DefaultDomainName -ErrorAction SilentlyContinue).DefaultDomainName

if ($auto -eq "1" -and $user -eq $ExpectedUpn -and $dom -eq $ExpectedDom) {
  Write-Output "Compliant"
  exit 0
}

Write-Output "NonCompliant:AutologonNotConfiguredOrMismatch"
exit 1