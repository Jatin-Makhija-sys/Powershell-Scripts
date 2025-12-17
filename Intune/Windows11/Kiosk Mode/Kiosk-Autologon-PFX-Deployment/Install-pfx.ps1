param(
  [Parameter(Mandatory = $true)]
  [string]$PfxPassword,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedThumbprint
)

$ErrorActionPreference = "Stop"

$pfxPath = Join-Path $PSScriptRoot "Kiosk-KeyVault-ClientAuth.pfx"
if (-not (Test-Path $pfxPath)) { throw "PFX not found: $pfxPath" }

# If already installed, exit cleanly
$existing = Get-ChildItem -Path Cert:\LocalMachine\My |
  Where-Object { $_.Thumbprint -eq $ExpectedThumbprint } |
  Select-Object -First 1

if ($existing) { exit 0 }

$secure = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force

# Import into LocalMachine\My (private key is non-exportable by default unless -Exportable is used)
Import-PfxCertificate -FilePath $pfxPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $secure | Out-Null
# Import-PfxCertificate is the supported PowerShell cmdlet for PFX import. :contentReference[oaicite:1]{index=1}

# Validate import
$installed = Get-ChildItem -Path Cert:\LocalMachine\My |
  Where-Object { $_.Thumbprint -eq $ExpectedThumbprint } |
  Select-Object -First 1

if (-not $installed) { throw "Certificate import did not result in expected thumbprint: $ExpectedThumbprint" }

# Best effort: remove the packaged PFX from the IME cache location (script folder)
Remove-Item -Path $pfxPath -Force -ErrorAction SilentlyContinue

exit 0