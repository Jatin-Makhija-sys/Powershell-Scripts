<#
.SYNOPSIS
    Detection script for verifying Outlook Classic default font configuration via MailSettings.

.DESCRIPTION
    This script is designed to be used as a custom detection script for a Win32 app
    in Microsoft Intune. It validates that specific Outlook Classic font related
    registry values under the current user's MailSettings key exist and match the
    expected configuration.

    The script performs two types of checks:

      1. Strict byte level check (Simple values):
         - Verifies that the binary data of the following values matches the
           expected hex string exactly:
             - ComposeFontSimple
             - ReplyFontSimple
             - TextFontSimple

      2. Hard font name check (Complex values):
         - Reads the HTML or CSS content stored in:
             - ComposeFontComplex
             - ReplyFontComplex
             - TextFontComplex
         - Verifies that the content contains the expected font family name
           token (for example "Calibri" or "font-family:"Calibri"").
         - If the expected token is not found for any Complex value, detection fails.

    The script returns:
      - Exit code 0 when:
          * All "Simple" font values match the expected configuration, and
          * All "Complex" font values contain the configured font name token.
      - Exit code 1 when:
          * One or more "Simple" font values do not match, or
          * One or more "Complex" values do not contain the configured font token, or
          * The MailSettings key is missing.

.NOTES
    Author  : Jatin Makhija
    Website : https://cloudinfra.net
    Script  : Outlook Classic default font detection
    Context : Run in user context (HKCU)

    Usage in Intune:
      - App type: Windows app (Win32)
      - Detection rule: Use a custom detection script
      - Upload this script as the detection script.
#>

# Path to the Outlook MailSettings registry key in the current user hive (HKCU)
$regPath = "HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings"

# Expected hex values exported from a reference device.
# These represent the Outlook Classic font configuration for:
#   - Compose, Reply, Text (Simple and Complex variants)
# Only the Simple ones are strictly enforced at byte level.
$expected = @{
    "ComposeFontSimple"  = "3c,00,00,00,1f,00,00,f8,00,00,00,00,a0,00,00,00,00,00,00,00,00,00,00,00,00,22,43,61,6c,69,62,72,69,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"
    "ComposeFontComplex" = "3c,68,74,6d,6c,3e,0d,0a,0d,0a,3c,68,65,61,64,3e,0d,0a,3c,73,74,79,6c,65,3e,0d,0a,0d,0a,20,2f,2a,20,53,74,79,6c,65,20,44,65,66,69,6e,69,74,69,6f,6e,73,20,2a,2f,0d,0a,20,73,70,61,6e,2e,50,65,72,73,6f,6e,61,
6c,43,6f,6d,70,6f,73,65,53,74,79,6c,65,0d,0a,09,7b,6d,73,6f,2d,73,74,79,6c,65,2d,6e,61,6d,65,3a,22,50,65,72,73,6f,6e,61,6c,20,43,6f,6d,70,6f,73,65,20,53,74,79,6c,65,22,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,74,79,70,65,3a,70,65,7
2,73,6f,6e,61,6c,2d,63,6f,6d,70,6f,73,65,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,6e,6f,73,68,6f,77,3a,79,65,73,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,75,6e,68,69,64,65,3a,6e,6f,3b,0d,0a,09,6d,73,6f,2d,61,6e,73,69,2d,66,6f,6e,74
,2d,73,69,7a,65,3a,38,2e,30,70,74,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,73,69,7a,65,3a,31,32,2e,30,70,74,3b,0d,0a,09,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,22,43,61,6c,69,62,72,69,22,2c,73,61,6e,73,2d,73,65,72,69,66,3b,
0d,0a,09,6d,73,6f,2d,61,73,63,69,69,2d,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,43,61,6c,69,62,72,69,3b,0d,0a,09,6d,73,6f,2d,68,61,6e,73,69,2d,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,43,61,6c,69,62,72,69,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2
d,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,22,54,69,6d,65,73,20,4e,65,77,20,52,6f,6d,61,6e,22,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,74,68,65,6d,65,2d,66,6f,6e,74,3a,6d,69,6e,6f,72,2d,62,69,64,69,3b,0d,0a,09,63,6f,6c,6f,72,3a,62,6c,61,63
,6b,3b,0d,0a,09,6d,73,6f,2d,74,68,65,6d,65,63,6f,6c,6f,72,3a,74,65,78,74,31,3b,7d,0d,0a,2d,2d,3e,0d,0a,3c,2f,73,74,79,6c,65,3e,0d,0a,3c,2f,68,65,61,64,3e,0d,0a,0d,0a,3c,2f,68,74,6d,6c,3e,0d,0a"
    "ReplyFontSimple"    = "3c,00,00,00,1f,00,00,f8,01,00,00,00,a0,00,00,00,00,00,00,00,12,4f,1a,00,00,12,43,61,73,74,65,6c,6c,61,72,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"
    "ReplyFontComplex"   = "3c,68,74,6d,6c,3e,0d,0a,0d,0a,3c,68,65,61,64,3e,0d,0a,3c,73,74,79,6c,65,3e,0d,0a,0d,0a,20,2f,2a,20,53,74,79,6c,65,20,44,65,66,69,6e,69,74,69,6f,6e,73,20,2a,2f,0d,0a,20,73,70,61,6e,2e,50,65,72,73,6f,6e,61,6c
,52,65,70,6c,79,53,74,79,6c,65,0d,0a,09,7b,6d,73,6f,2d,73,74,79,6c,65,2d,6e,61,6d,65,3a,22,50,65,72,73,6f,6e,61,6c,20,52,65,70,6c,79,20,53,74,79,6c,65,22,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,74,79,70,65,3a,70,65,72,73,6f,6e,61,
6c,2d,72,65,70,6c,79,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,6e,6f,73,68,6f,77,3a,79,65,73,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,75,6e,68,69,64,65,3a,6e,6f,3b,0d,0a,09,6d,73,6f,2d,61,6e,73,69,2d,66,6f,6e,74,2d,73,69,7a,65,3a,3
8,2e,30,70,74,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,73,69,7a,65,3a,31,32,2e,30,70,74,3b,0d,0a,09,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,22,43,61,73,74,65,6c,6c,61,72,22,2c,73,65,72,69,66,3b,0d,0a,09,6d,73,6f,2d,61,73,63
,69,69,2d,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,43,61,73,74,65,6c,6c,61,72,3b,0d,0a,09,6d,73,6f,2d,68,61,6e,73,69,2d,66,6f,6n,74,2d,66,61,6d,69,6c,79,3a,43,61,73,74,65,6c,6c,61,72,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,
66,61,6d,69,6c,79,3a,22,54,69,6d,65,73,20,4e,65,77,20,52,6f,6d,61,6e,22,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,74,68,65,6d,65,2d,66,6f,6e,74,3a,6d,69,6e,6f,72,2d,62,69,64,69,3b,0d,0a,09,63,6f,6c,6f,72,3a,23,31,32,34,46,31,41,3b,0d,0
a,09,6d,73,6f,2d,74,68,65,6d,65,63,6f,6c,6f,72,3a,61,63,63,65,6e,74,33,3b,0d,0a,09,6d,73,6f,2d,74,68,65,6d,65,73,68,61,64,65,3a,31,39,31,3b,0d,0a,09,66,6f,6n,74,2d,77,65,69,67,68,74,3a,62,6f,6c,64,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69
,2d,66,6f,6e,74,2d,77,65,69,67,68,74,3a,6e,6f,72,6d,61,6c,3b,0d,0a,09,66,6f,6e,74,2d,73,74,79,6c,65,3a,6e,6f,72,6d,61,6c,3b,7d,0d,0a,2d,2d,3e,0d,0a,3c,2f,73,74,79,6c,65,3e,0d,0a,3c,2f,68,65,61,64,3e,0d,0a,0d,0a,3c,2f,68,74,6d,6c,3e,
0d,0a"
    "TextFontSimple"     = "3c,00,00,00,1f,00,00,f8,03,00,00,00,b4,00,00,00,00,00,00,00,e9,71,32,00,00,22,41,70,74,6f,73,20,53,6c,61,62,20,4c,69,67,68,74,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"
    "TextFontComplex"    = "3c,68,74,6d,6c,3e,0d,0a,0d,0a,3c,68,65,61,64,3e,0d,0a,3c,73,74,79,6c,65,3e,0d,0a,0d,0a,20,2f,2a,20,53,74,79,6c,65,20,44,65,66,69,6e,69,74,69,6f,6e,73,20,2a,2f,0d,0a,20,70,2e,4d,73,6f,50,6c,61,69,6e,54,65,78,
74,2c,20,6c,69,2e,4d,73,6f,50,6c,61,69,6e,54,65,78,74,2c,20,64,69,76,2e,4d,73,6f,50,6c,61,69,6e,54,65,78,74,0d,0a,09,7b,6d,73,6f,2d,73,74,79,6c,65,2d,6e,6f,73,68,6f,77,3a,79,65,73,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,70,72,69,6
f,72,69,74,79,3a,39,39,3b,0d,0a,09,6d,73,6f,2d,73,74,79,6c,65,2d,6c,69,6e,6b,3a,22,50,6c,61,69,6e,20,54,65,78,74,20,43,68,61,72,22,3b,0d,0a,09,6d,61,72,67,69,6e,3a,30,63,6d,3b,0d,0a,09,6d,73,6f,2d,70,61,67,69,6e,61,74,69,6f,6e,3a,77
,69,64,6f,77,2d,6f,72,70,68,61,6e,3b,0d,0a,09,66,6f,6e,74,2d,73,69,7a,65,3a,39,2e,30,70,74,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,73,69,7a,65,3a,31,30,2e,35,70,74,3b,0d,0a,09,66,6f,6n,74,2d,66,61,6d,69,6c,79,3a,22,41,
70,74,6f,73,20,53,6c,61,62,20,4c,69,67,68,74,22,2c,73,61,6e,73,2d,73,65,72,69,66,3b,0d,0a,09,6d,73,6f,2d,66,61,72,65,61,73,74,2d,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,41,70,74,6f,73,3b,0d,0a,09,6d,73,6f,2d,66,61,72,65,61,73,74,2d,74,6
8,65,6d,65,2d,66,6f,6e,74,3a,6d,69,6e,6f,72,2d,6c,61,74,69,6e,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,66,61,6d,69,6c,79,3a,22,54,69,6d,65,73,20,4e,65,77,20,52,6f,6d,61,6e,22,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,74,68
,65,6d,65,2d,66,6f,6e,74,3a,6d,69,6e,6f,72,2d,62,69,64,69,3b,0d,0a,09,63,6f,6c,6f,72,3a,23,45,39,37,31,33,32,3b,0d,0a,09,6d,73,6f,2d,74,68,65,6d,65,63,6f,6c,6f,72,3a,61,63,63,65,6e,74,32,3b,0d,0a,09,6d,73,6f,2d,66,6f,6e,74,2d,6b,65,
72,6e,69,6e,67,3a,31,2e,30,70,74,3b,0d,0a,09,6d,73,6f,2d,6c,69,67,61,74,75,72,65,73,3a,73,74,61,6e,64,61,72,64,63,6f,6e,74,65,78,74,75,61,6c,3b,0d,0a,09,6d,73,6f,2d,66,61,72,65,61,73,74,2d,6c,61,6e,67,75,61,67,65,3a,45,4e,2d,55,53,3
b,0d,0a,09,66,6f,6e,74,2d,77,65,69,67,68,74,3a,62,6f,6c,64,3b,0d,0a,09,6d,73,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,77,65,69,67,68,74,3a,6e,6f,72,6d,61,6c,3b,0d,0a,09,66,6f,6e,74,2d,73,74,79,6c,65,3a,69,74,61,6c,69,63,3b,0d,0a,09,6d,73
,6f,2d,62,69,64,69,2d,66,6f,6e,74,2d,73,74,79,6c,65,3a,6e,6f,72,6d,61,6c,3b,7d,0d,0a,2d,2d,3e,0d,0a,3c,2f,73,74,79,6c,65,3e,0d,0a,3c,2f,68,65,61,64,3e,0d,0a,0d,0a,3c,2f,68,74,6d,6c,3e,0d,0a"
}

# Validate that the expected hashtable exists
if (-not (Get-Variable -Name expected -ErrorAction SilentlyContinue)) {
    Write-Host "No 'expected' hashtable defined. Paste your exported values block into this script."
    exit 1
}

# Confirm that the MailSettings registry key exists in HKCU
if (-not (Test-Path $regPath)) {
    Write-Host "MailSettings key missing: $regPath"
    exit 1
}

# Define which value names represent Simple versus Complex font settings
$simpleNames  = @("ComposeFontSimple","ReplyFontSimple","TextFontSimple")
$complexNames = @("ComposeFontComplex","ReplyFontComplex","TextFontComplex")

# Provide the actual font names which you have set in Outlook for Complex values.
# These tokens are searched inside the decoded HTML content.
# You can use just the font family name (for example "Calibri") or a more specific snippet
# such as 'font-family:"Calibri"'.
$complexFontTokens = @{
    "ComposeFontComplex" = "calibri"          # update to your actual compose font name
    "ReplyFontComplex"   = "castellar"        # update to your actual reply font name
    "TextFontComplex"    = "aptos slab light" # update to your actual text font name
}

# Track whether all Simple and Complex checks pass
$allSimpleMatch  = $true
$allComplexMatch = $true

Write-Host "Checking Outlook MailSettings under $regPath"
Write-Host ""

# ----------------------------------------------------------------------
# 1. Strict check for Simple values (hex must match exactly)
# ----------------------------------------------------------------------
foreach ($name in $simpleNames) {

    Write-Host "Simple value: $name"

    if (-not $expected.ContainsKey($name)) {
        Write-Host "  No expected value defined for $name in expected. Treating as mismatch."
        $allSimpleMatch = $false
        Write-Host ""
        continue
    }

    try {
        $current = Get-ItemPropertyValue -Path $regPath -Name $name -ErrorAction Stop
    }
    catch {
        Write-Host "  MISSING"
        $allSimpleMatch = $false
        Write-Host ""
        continue
    }

    if ($current -is [byte[]]) {
        $bytes = $current
    }
    elseif ($current -is [string]) {
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($current)
    }
    else {
        Write-Host "  Unsupported registry type: $($current.GetType().FullName)"
        $allSimpleMatch = $false
        Write-Host ""
        continue
    }

    $actualHex   = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ","
    $expectedHex = $expected[$name]

    $actualNorm   = $actualHex.ToLower().Replace(" ","")
    $expectedNorm = $expectedHex.ToLower().Replace(" ","")

    Write-Host "    Expected (norm): $($expectedNorm.Substring(0,[Math]::Min(80,$expectedNorm.Length)))..."
    Write-Host "    Actual   (norm): $($actualNorm.Substring(0,[Math]::Min(80,$actualNorm.Length)))..."
    Write-Host "    Length expected: $($expectedNorm.Length)"
    Write-Host "    Length actual  : $($actualNorm.Length)"

    if ($actualNorm -eq $expectedNorm) {
        Write-Host "    MATCH"
    } else {
        Write-Host "    MISMATCH"
        $allSimpleMatch = $false
    }

    Write-Host ""
}

# ----------------------------------------------------------------------
# 2. Hard check for Complex values
#    - Verifies that decoded HTML contains the expected font token
#    - Any missing token or missing value is treated as failure
# ----------------------------------------------------------------------
foreach ($name in $complexNames) {

    Write-Host "Complex value: $name"

    # Confirm we have a token configured for this value
    $token = $complexFontTokens[$name]
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host "  No font token defined for $name in complexFontTokens. Treating as mismatch."
        $allComplexMatch = $false
        Write-Host ""
        continue
    }

    # Read current registry value
    try {
        $current = Get-ItemPropertyValue -Path $regPath -Name $name -ErrorAction Stop
    }
    catch {
        Write-Host "  MISSING"
        $allComplexMatch = $false
        Write-Host ""
        continue
    }

    # Convert to bytes
    if ($current -is [byte[]]) {
        $bytes = $current
    }
    elseif ($current -is [string]) {
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($current)
    }
    else {
        Write-Host "  Unsupported registry type: $($current.GetType().FullName)"
        $allComplexMatch = $false
        Write-Host ""
        continue
    }

    # Decode as ASCII HTML or CSS
    $html = [System.Text.Encoding]::ASCII.GetString($bytes)

    if ($html.ToLower().Contains($token.ToLower())) {
        Write-Host "  Contains expected font token: '$token'  - MATCH"
    }
    else {
        Write-Host "  Does NOT contain expected font token: '$token'  - MISMATCH"
        $allComplexMatch = $false
    }

    Write-Host ""
}

# ----------------------------------------------------------------------
# Final result
# ----------------------------------------------------------------------
if ($allSimpleMatch -and $allComplexMatch) {
    Write-Host "All Simple and Complex Outlook MailSettings font values match the expected configuration."
    exit 0
}
else {
    Write-Host "One or more Simple or Complex Outlook MailSettings font values do not match the expected configuration."
    exit 1
}