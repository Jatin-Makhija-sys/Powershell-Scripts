<#
.SYNOPSIS
Remediation script for Intune Remediations to configure Windows AutoLogon for an Entra ID (AzureAD) user using Sysinternals Autologon64.exe.

.DESCRIPTION
This script runs Autologon64.exe in silent mode to configure Windows automatic sign-in (AutoAdminLogon) for a specified
Entra ID (AzureAD) user (UPN format). It then validates configuration by checking Winlogon registry values:
- AutoAdminLogon
- DefaultUserName
- DefaultDomainName

A device-local log file is written to C:\ProgramData\KioskTools\Remediate-EntraAutologon.log and is overwritten on every run,
so it always contains only the most recent execution details.

.NOTES
Name        : Remediate-EntraAutologon.ps1
Author      : Jatin Makhija
Website     : https://cloudinfra.net
Version     : 1.0
Created     : 2025-12-17

Intune Behavior
- Exit 0 = Remediation succeeded
- Exit 1 = Remediation failed (Intune should report failure)

Requirements
- Windows 10/11
- Autologon64.exe deployed to: C:\Program Files\KioskTools\Sysinternals\Autologon64.exe
- Script should run as SYSTEM (recommended) and in 64-bit PowerShell host

Security Considerations
- This script requires the Entra user password at runtime to configure AutoLogon.
- Autologon stores the password encrypted (LSA secret), but local administrators can still recover it.
- Use a dedicated kiosk account with least privilege and consider password rotation.

Change Log
- 1.0: Initial version with logging, exit code handling, and post-configuration validation.
#>

$ErrorActionPreference = "Stop"

# =====================================================================
# CONFIGURATION
# =====================================================================
$KioskUpn      = "jatin@cloudinfra.net"
$KioskDomain   = "AzureAD"
$KioskPassword = "<Entra account Password>"  # WARNING: Keep this protected. Avoid storing in plaintext where possible.
$AutologonExe  = "C:\Program Files\KioskTools\Sysinternals\Autologon64.exe"

# =====================================================================
# LOGGING (Overwrites on every run)
# =====================================================================
$logDir  = "C:\ProgramData\KioskTools"
$logFile = Join-Path $logDir "Remediate-EntraAutologon.log"
New-Item -Path $logDir -ItemType Directory -Force | Out-Null

"Run started: $(Get-Date -Format s)" | Out-File -FilePath $logFile -Encoding utf8

try {
    # =================================================================
    # PREREQUISITE CHECKS
    # =================================================================
    if (-not (Test-Path -LiteralPath $AutologonExe)) {
        "ERROR: Autologon missing at $AutologonExe" | Out-File $logFile -Append -Encoding utf8
        exit 1
    }

    "INFO: Running Autologon to configure $KioskDomain\$KioskUpn" | Out-File $logFile -Append -Encoding utf8

    # =================================================================
    # REMEDIATION ACTION
    # =================================================================
    # Run Autologon and capture exit code
    $p = Start-Process -FilePath $AutologonExe `
        -ArgumentList @($KioskUpn, $KioskDomain, $KioskPassword, "/accepteula") `
        -Wait -NoNewWindow -PassThru

    "INFO: Autologon exit code: $($p.ExitCode)" | Out-File $logFile -Append -Encoding utf8

    if ($p.ExitCode -ne 0) {
        "ERROR: Autologon returned non-zero exit code." | Out-File $logFile -Append -Encoding utf8
        exit 1
    }

    # =================================================================
    # POST-REMEDIATION VALIDATION
    # =================================================================
    $wl = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    $auto = (Get-ItemProperty -Path $wl -Name AutoAdminLogon -ErrorAction SilentlyContinue).AutoAdminLogon
    $user = (Get-ItemProperty -Path $wl -Name DefaultUserName -ErrorAction SilentlyContinue).DefaultUserName
    $dom  = (Get-ItemProperty -Path $wl -Name DefaultDomainName -ErrorAction SilentlyContinue).DefaultDomainName

    "INFO: Post-check AutoAdminLogon=$auto DefaultUserName=$user DefaultDomainName=$dom" |
        Out-File $logFile -Append -Encoding utf8

    if ($auto -eq "1" -and $user -eq $KioskUpn -and $dom -eq $KioskDomain) {
        "SUCCESS: Autologon configured and validated." | Out-File $logFile -Append -Encoding utf8
        exit 0
    }

    "ERROR: Autologon did not validate after configuration." | Out-File $logFile -Append -Encoding utf8
    exit 1
}
catch {
    "EXCEPTION: $($_.Exception.Message)" | Out-File $logFile -Append -Encoding utf8
    exit 1
}