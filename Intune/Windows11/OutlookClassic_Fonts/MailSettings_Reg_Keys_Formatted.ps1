# Generate a detection-ready $expected hashtable for Outlook MailSettings

$regPath = "HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings"
$valueNames = @(
    "ComposeFontSimple",
    "ComposeFontComplex",
    "ReplyFontSimple",
    "ReplyFontComplex",
    "TextFontSimple",
    "TextFontComplex"
)

if (-not (Test-Path $regPath)) {
    Write-Error "MailSettings key not found at $regPath"
    exit 1
}

Write-Host "`$expected = @{"

foreach ($name in $valueNames) {
    try {
        $val = Get-ItemPropertyValue -Path $regPath -Name $name -ErrorAction Stop
    }
    catch {
        Write-Warning "Value '$name' not found. Skipping."
        continue
    }

    if ($val -is [byte[]]) {
        $bytes = $val
    }
    elseif ($val -is [string]) {
        # Safety: handle string types as UTF-16LE
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($val)
    }
    else {
        Write-Warning "Value '$name' is of unsupported type $($val.GetType().FullName). Skipping."
        continue
    }

    $hex = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ","
    Write-Host "    `"$name`" = `"$hex`""
}

Write-Host "}"