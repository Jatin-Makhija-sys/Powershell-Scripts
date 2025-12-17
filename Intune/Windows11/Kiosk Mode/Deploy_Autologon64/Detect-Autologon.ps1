$exe = "C:\Program Files\KioskTools\Sysinternals\Autologon64.exe"

if (Test-Path -LiteralPath $exe) {
  Write-Output "Detected Autologon64.exe at $exe"
  exit 0
}

Write-Output "Not detected at $exe"
exit 1