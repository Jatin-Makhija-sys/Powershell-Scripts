New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

$user = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $user) {
    Write-Host "No interactive user detected. Nothing to uninstall."
    exit 0
}

$sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$regPath = "HKU:\$sid\Software\Microsoft\Office\16.0\Common\MailSettings"

if (Test-Path $regPath) {
    Remove-ItemProperty -Path $regPath `
        -Name "ComposeFontSimple","ComposeFontComplex","ReplyFontSimple","ReplyFontComplex","TextFontSimple","TextFontComplex" `
        -ErrorAction SilentlyContinue
    Write-Host "Outlook MailSettings font values removed from $regPath"
} else {
    Write-Host "MailSettings key not found for $user ($sid). Nothing to uninstall."
}

exit 0