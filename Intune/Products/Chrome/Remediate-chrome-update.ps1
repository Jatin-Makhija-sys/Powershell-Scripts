# Remediate-UpdateChrome.ps1
# Silent upgrade to latest Chrome Enterprise MSI

$ErrorActionPreference = 'Stop'

$workDir = Join-Path $env:ProgramData "ChromeUpdate"
New-Item -Path $workDir -ItemType Directory -Force | Out-Null

$log = Join-Path $workDir ("ChromeMSIInstall_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
$msi = Join-Path $workDir "GoogleChromeEnterprise.msi"

$is64 = [Environment]::Is64BitOperatingSystem

# Prefer official enterprise MSI download endpoints. Keep a small fallback list.
$downloadUrls = if ($is64) {
    @(
        "https://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise64.msi",
        "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
    )
} else {
    @(
        "https://dl.google.com/edgedl/chrome/install/GoogleChromeStandaloneEnterprise.msi",
        "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise.msi"
    )
}

# Ensure TLS 1.2+
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$downloaded = $false
foreach ($url in $downloadUrls) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
        if (Test-Path $msi -PathType Leaf -and (Get-Item $msi).Length -gt 1MB) {
            $downloaded = $true
            break
        }
    } catch {
        # try next URL
    }
}

if (-not $downloaded) {
    throw "Failed to download Chrome Enterprise MSI from all known URLs."
}

# Install/upgrade silently
$arguments = "/i `"$msi`" /qn /norestart /L*V `"$log`""
$p = Start-Process -FilePath "msiexec.exe" -ArgumentList $arguments -Wait -PassThru

# 0 = success, 3010 = success/reboot required
if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
    Write-Output "Chrome MSI install succeeded. ExitCode=$($p.ExitCode). Log=$log"
    exit 0
}

throw "Chrome MSI install failed. ExitCode=$($p.ExitCode). Log=$log"