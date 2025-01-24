<# 
.SYNOPSIS 
Change Desktop Wallpaper for a User on Win11
 
.DESCRIPTION 
This script selects a random wallpaper from the 
C:\Windows\Web\Wallpaper folder and sets it as the desktop wallpaper.
.NOTES     
        Name       : Rotate-Desktop-Wallpaper.ps1
        Author     : Jatin Makhija  
        Version    : 1.0.3  
        DateCreated: 24-Jan-2025
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>

# Specify the path to the wallpaper folder
$wallpaperFolder = "C:\Windows\Web\Wallpaper"

# Ensure the folder exists
if (-not (Test-Path $wallpaperFolder -PathType Container)) {
    Write-Host "Error: Wallpaper folder does not exist at $wallpaperFolder."
    exit
}

# Select a random wallpaper
$wallpaperFile = Get-ChildItem -Path $wallpaperFolder -File | Get-Random

# Set the registry key for the wallpaper
$registryPath = 'HKCU:\Control Panel\Desktop'
Set-ItemProperty -Path $registryPath -Name "Wallpaper" -Value $wallpaperFile.FullName

# Refresh the desktop to apply the changes
if (-not ([System.Management.Automation.PSTypeName]'SystemParametersInfoFunctions.WinAPI').Type) {
    $signature = @"
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@
    $null = Add-Type -MemberDefinition $signature -Name WinAPI -Namespace SystemParametersInfoFunctions -PassThru
}

$SPI_SETDESKWALLPAPER = 0x0014
$UPDATE_INI_FILE = 0x01
$SEND_CHANGE = 0x02
[SystemParametersInfoFunctions.WinAPI]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperFile.FullName, $UPDATE_INI_FILE -bor $SEND_CHANGE)

Write-Host "Wallpaper changed successfully to: $($wallpaperFile.Name)"