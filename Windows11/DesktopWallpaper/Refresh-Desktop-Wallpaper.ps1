<#
.DESCRIPTION
    This script refreshes the desktop wallpaper for the Current User

    Author: Jatin Makhija
    Version: 1.0.1
    Copyright: Cloudinfra.net
#>

# Suppress unintended output
$ErrorActionPreference = "SilentlyContinue"

# Add custom type for SystemParametersInfo if not already defined
if (-not ([System.Management.Automation.PSTypeName]'SystemParametersInfoFunctions.WinAPI').Type) {
    $signature = @"
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@
    $null = Add-Type -MemberDefinition $signature -Name WinAPI -Namespace SystemParametersInfoFunctions -PassThru
}

# Retrieve the wallpaper path from the registry
$wallpaperPath = Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper

# Refresh the desktop wallpaper
$SPI_SETDESKWALLPAPER = 0x0014
$UPDATE_INI_FILE = 0x01
$SEND_CHANGE = 0x02

[SystemParametersInfoFunctions.WinAPI]::SystemParametersInfo(
    $SPI_SETDESKWALLPAPER, 
    0, 
    $wallpaperPath.Wallpaper, 
    $UPDATE_INI_FILE -bor $SEND_CHANGE
)