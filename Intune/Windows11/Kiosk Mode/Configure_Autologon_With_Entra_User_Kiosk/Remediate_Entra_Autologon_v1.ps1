$ErrorActionPreference = "Stop"

$KioskUpn      = "jatin@cloudinfra.net"
$KioskDomain   = "AzureAD"
$KioskPassword = "<Entra account Password>"
$AutologonExe  = "C:\Program Files\KioskTools\Sysinternals\Autologon64.exe"

$logDir  = "C:\ProgramData\KioskTools"
$logFile = Join-Path $logDir "Remediate-EntraAutologon.log"
New-Item -Path $logDir -ItemType Directory -Force | Out-Null

"Run started: $(Get-Date -Format s)" | Out-File -FilePath $logFile -Encoding utf8

try {
    if (-not (Test-Path -LiteralPath $AutologonExe)) {
        "ERROR: Autologon missing at $AutologonExe" | Out-File $logFile -Append -Encoding utf8
        exit 1
    }

    "INFO: Running Autologon to configure $KioskDomain\$KioskUpn" | Out-File $logFile -Append -Encoding utf8

    # Run Autologon and capture exit code
    $p = Start-Process -FilePath $AutologonExe `
        -ArgumentList @($KioskUpn, $KioskDomain, $KioskPassword, "/accepteula") `
        -Wait -NoNewWindow -PassThru

    "INFO: Autologon exit code: $($p.ExitCode)" | Out-File $logFile -Append -Encoding utf8

    if ($p.ExitCode -ne 0) {
        "ERROR: Autologon returned non-zero exit code." | Out-File $logFile -Append -Encoding utf8
        exit 1
    }

    # Validate registry state after running
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