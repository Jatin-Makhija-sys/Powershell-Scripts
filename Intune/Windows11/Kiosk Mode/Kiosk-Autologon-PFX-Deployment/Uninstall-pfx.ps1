param(
  [Parameter(Mandatory = $true)]
  [string]$ExpectedThumbprint
)

$ErrorActionPreference = "Stop"

$cert = Get-ChildItem -Path Cert:\LocalMachine\My |
  Where-Object { $_.Thumbprint -eq $ExpectedThumbprint } |
  Select-Object -First 1

if ($cert) {
  Remove-Item -Path ("Cert:\LocalMachine\My\" + $cert.Thumbprint) -Force
}

exit 0