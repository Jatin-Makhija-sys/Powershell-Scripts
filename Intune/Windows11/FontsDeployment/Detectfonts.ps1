$fontFiles = @(
  "Alata-Regular.ttf",
  "Monda-Bold.ttf",
  "Monda-Regular.ttf",
  "Paprika-Regular.ttf"
)

$missing = $fontFiles | Where-Object { -not (Test-Path (Join-Path "$env:WINDIR\Fonts" $_)) }

if ($missing.Count -eq 0) { Write-Output "Detected"; exit 0 }
Write-Output ("Missing: " + ($missing -join ", "))
exit 1