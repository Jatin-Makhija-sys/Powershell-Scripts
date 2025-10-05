$TenantId = "<tenantID>"
$ClientId = "<clientID>"
$CertThumbprint = "<certThumbprint>"

$cert = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { (($_.Thumbprint -replace '\s','') ).ToUpper() -eq $CertThumbprint.ToUpper() } |
  Select-Object -First 1

if (-not $cert) { throw "Certificate with thumbprint $CertThumbprint not found in CurrentUser\My." }
if (-not $cert.HasPrivateKey) { throw "Found cert, but it does NOT have a private key. Install a PFX or use CurrentUser\My." }

#Connect using the X509Certificate2 object
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $cert

# Optional sanity check
(Get-MgContext) | Select TenantId, AuthType, AppName