<#
.DESCRIPTION
    This script will update Wallpaper Reg key for the current user.

    Author: Jatin Makhija
    Version: 1.0.0
    Copyright: Cloudinfra.net
#>

# Create a PSDrive for HKEY_USERS
New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

# Get the current user SID
$user = (Get-WmiObject -Class Win32_ComputerSystem).UserName
$sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

# Set the registry path for the current user's desktop settings
$registryPath = "HKU:\$sid\Control Panel\Desktop"

# Path to the wallpaper folder
$wallpaperFolder = "C:\Windows\Web\Wallpaper"

# Select a random wallpaper
$wallpaperFile = Get-ChildItem -Path $wallpaperFolder -File | Get-Random

# Update the registry with the selected wallpaper
Set-ItemProperty -Path $registryPath -Name "Wallpaper" -Value $wallpaperFile.FullName

Write-Host "Registry updated with wallpaper: $($wallpaperFile.Name)"