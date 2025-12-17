<#
.SYNOPSIS
Detection script for Intune Remediations to validate Windows AutoLogon configuration for an Entra ID (AzureAD) user.

.DESCRIPTION
This script checks whether Windows AutoLogon is configured for a specific Entra ID user by validating the following
Winlogon registry values:
- AutoAdminLogon
- DefaultUserName
- DefaultDomainName

If Autologon64.exe is missing from the expected path, the script returns NonCompliant so you can identify deployment gaps.

.NOTES
Name        : Detect-EntraAutologon.ps1
Author      : Jatin Makhija
Website     : https://cloudinfra.net
Version     : 1.0
Created     : 2025-12-17

Intune Behavior
- Exit 0 = Compliant (no remediation required)
- Exit 1 = NonCompliant (remediation should run)

Requirements
- Windows 10/11
- Autologon64.exe deployed to: C:\Program Files\KioskTools\Sysinternals\Autologon64.exe
- Script should run in 64-bit PowerShell host (recommended)

Disclaimer
- This detection script does not read or attempt to extract any stored AutoLogon password (LSA secret).
- AutoLogon is a security trade-off; use a dedicated kiosk account with least privilege.
#>

$ErrorActionPreference = "Stop"

# =====================================================================
# CONFIGURATION
# =====================================================================
$ExpectedUpn  = "jatin@cloudinfra.net"
$ExpectedDom  = "AzureAD"
$AutologonExe = "C:\Program Files\KioskTools\Sysinternals\Autologon64.exe"

# =====================================================================
# PREREQUISITE CHECKS
# =====================================================================
# If Autologon tool is missing, flag as non-compliant so you notice deployment gaps
if (-not (Test-Path -LiteralPath $AutologonExe)) {
  Write-Output "NonCompliant:AutologonMissing:$AutologonExe"
  exit 1
}

# =====================================================================
# DETECTION LOGIC
# =====================================================================
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