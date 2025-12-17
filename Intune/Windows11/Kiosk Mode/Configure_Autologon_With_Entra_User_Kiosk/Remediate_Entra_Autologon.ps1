# Remediate_Entra_Autologon.ps1
$ErrorActionPreference = "Stop"

# =========================
# REQUIRED CONFIG
# =========================
$TenantId        = "<YOUR_TENANT_ID_GUID>"
$ClientId        = "<YOUR_APP_REG_CLIENT_ID_GUID>"
$CertThumbprint  = "<CERT_THUMBPRINT_IN_LOCALMACHINE_MY>"

$VaultName       = "<YOUR_KEYVAULT_NAME>"
$SecretName      = "Kiosk-AutoLogon-Password"

$KioskUpn        = "jatin@cloudinfra.onmicrosoft.com"
$KioskDomain     = "AzureAD"

$AutologonExe    = Join-Path $env:ProgramFiles "KioskTools\Sysinternals\Autologon64.exe"

# =========================
# Guardrails
# =========================
if (-not (Test-Path $AutologonExe)) { throw "Autologon64.exe missing at $AutologonExe" }

$cert = Get-ChildItem -Path Cert:\LocalMachine\My |
  Where-Object { $_.Thumbprint -eq $CertThumbprint } |
  Select-Object -First 1
if (-not $cert) { throw "Client certificate not found in LocalMachine\\My for thumbprint $CertThumbprint" }

function ConvertTo-Base64Url([byte[]]$bytes) {
  $b64 = [Convert]::ToBase64String($bytes).TrimEnd("=")
  ($b64 -replace "\+", "-" -replace "/", "_")
}

function New-ClientAssertionJwt {
  param(
    [string]$TenantId,
    [string]$ClientId,
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
  )

  $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
  $now = [DateTimeOffset]::UtcNow

  $thumbSha256 = $Cert.GetCertHash([System.Security.Cryptography.HashAlgorithmName]::SHA256)

  $header = @{
    alg = "PS256"
    typ = "JWT"
    "x5t#S256" = (ConvertTo-Base64Url $thumbSha256)
  } | ConvertTo-Json -Compress

  $payload = @{
    aud = $tokenEndpoint
    iss = $ClientId
    sub = $ClientId
    jti = ([guid]::NewGuid().ToString())
    nbf = [int]$now.ToUnixTimeSeconds()
    exp = [int]$now.AddMinutes(10).ToUnixTimeSeconds()
  } | ConvertTo-Json -Compress

  $encodedHeader  = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($header))
  $encodedPayload = ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($payload))
  $toSign = [Text.Encoding]::UTF8.GetBytes("$encodedHeader.$encodedPayload")

  $rsa = $Cert.GetRSAPrivateKey()
  if (-not $rsa) { throw "Certificate does not have an RSA private key." }

  $sig = $rsa.SignData(
    $toSign,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pss
  )

  $encodedSig = ConvertTo-Base64Url $sig
  "$encodedHeader.$encodedPayload.$encodedSig"
}

# =========================
# 1) Get Key Vault access token (client credentials)
# =========================
$clientAssertion = New-ClientAssertionJwt -TenantId $TenantId -ClientId $ClientId -Cert $cert

$tokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$tokenBody = @{
  client_id             = $ClientId
  scope                 = "https://vault.azure.net/.default"
  grant_type            = "client_credentials"
  client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
  client_assertion      = $clientAssertion
}

$tokenResp = Invoke-RestMethod -Method Post -Uri $tokenUri -Body $tokenBody -ContentType "application/x-www-form-urlencoded"
if (-not $tokenResp.access_token) { throw "Failed to obtain access token for Key Vault." }
$accessToken = $tokenResp.access_token

# =========================
# 2) Read secret value from Key Vault
# =========================
# Get Secret REST API: GET {vaultBaseUrl}/secrets/{secret-name}/{secret-version}?api-version=2025-07-01
$kvUri = "https://$VaultName.vault.azure.net/secrets/$SecretName?api-version=2025-07-01"
$kvResp = Invoke-RestMethod -Method Get -Uri $kvUri -Headers @{ Authorization = "Bearer $accessToken" }
if ([string]::IsNullOrWhiteSpace($kvResp.value)) { throw "Key Vault secret '$SecretName' returned an empty value." }

$password = $kvResp.value

# =========================
# 3) Configure Windows autologon via Autologon CLI
# =========================
# Autologon supports: autologon user domain password
Start-Process -FilePath $AutologonExe -ArgumentList @($KioskUpn, $KioskDomain, $password) -Wait -NoNewWindow

# Cleanup best-effort
$password = $null
$accessToken = $null
[GC]::Collect()
[GC]::WaitForPendingFinalizers()

Write-Output "Remediated:AutologonConfigured"
exit 0