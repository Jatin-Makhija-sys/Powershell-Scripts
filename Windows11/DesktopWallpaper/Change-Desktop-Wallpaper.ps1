<# 
.SYNOPSIS 
Change Desktop Wallpaper for a User on Win11
 
.DESCRIPTION 
Below Script will download a wallpaper from a Publicly accessible
location and Update on the device for a particular user
.NOTES     
        Name       : Change-Desktop-Wallpaper.ps1
        Author     : Jatin Makhija  
        Version    : 1.0.0  
        DateCreated: 15-Nov-2023
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>

# Specify the URL of your custom wallpaper
$wallpaperUrl = 'https://cloudinfrasa01.blob.core.windows.net/wallpapers/Cloudinfra-desktop-wall.jpg'

# Specify the local path to the wallpaper folder and file
$wallpaperFolder = "C:\Wallpaper-files"
$localWallpaperPath = Join-Path $wallpaperFolder "wallpaper.jpg"

# Check if the folder exists, and create it if not
if (-not (Test-Path $wallpaperFolder -PathType Container)) {
    New-Item -Path $wallpaperFolder -ItemType Directory -Force
}

# Download the wallpaper
Invoke-WebRequest -Uri $wallpaperUrl -OutFile $localWallpaperPath

# Check if the download was successful
if (Test-Path $localWallpaperPath -PathType Leaf) {
    # Set the registry key for the wallpaper
    $registryPath = 'HKCU:\Control Panel\Desktop'
    $name = 'Wallpaper'
    Set-ItemProperty -Path $registryPath -Name $name -Value $localWallpaperPath

    # Refresh the desktop to apply the changes
    $signature = @"
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@
    $SPI_SETDESKWALLPAPER = 0x0014
    $UPDATE_INI_FILE = 0x01
    $SEND_CHANGE = 0x02
    $null = Add-Type -MemberDefinition $signature -Name WinAPI -Namespace SystemParametersInfoFunctions -PassThru
    [SystemParametersInfoFunctions.WinAPI]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $localWallpaperPath, $UPDATE_INI_FILE -bor $SEND_CHANGE)

    Write-Host "Wallpaper changed successfully."
} else {
    Write-Host "Error: Wallpaper download failed from $wallpaperUrl."
}