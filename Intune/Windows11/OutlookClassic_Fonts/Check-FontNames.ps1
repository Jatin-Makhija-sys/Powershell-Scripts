$regPath = "HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings"
$complexNames = "ComposeFontComplex","ReplyFontComplex","TextFontComplex"

foreach ($name in $complexNames) {
    Write-Host "===== $name ====="
    $bytes = Get-ItemPropertyValue -Path $regPath -Name $name -ErrorAction Stop
    $html  = [System.Text.Encoding]::ASCII.GetString($bytes)
    $html  = $html -replace "\s+"," "  # compress whitespace a bit
    $html.Substring(0,[Math]::Min(400,$html.Length))  # show first 400 chars
    Write-Host "`n"
}