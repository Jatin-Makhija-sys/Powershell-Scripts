<#
.DESCRIPTION
    This script will remove Zoom App deployed using its .exe Installer.
    Author: Jatin Makhija
    Website: Copyright - Cloudinfra.net
    Version: 1.0.0
#>
# Define the user directories in C:\Users
$users = Get-ChildItem C:\Users\ | ForEach-Object { $_.Name }

# Filter the user list to exclude the 'Public' user
$users = $users | Where-Object { $_ -ne 'Public' }

# Create a new PowerShell drive to access the HKEY_USERS registry hive
New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS

# Iterate through each user's directory
foreach ($userDirectory in $users) {
    # Construct the path to the user's AppData\Roaming directory
    $userRoamingPath = "$env:SystemDrive\users\$userDirectory\AppData\Roaming"

    # Check if Zoom is installed in the user's AppData\Roaming directory
    $zoomInstalled = Test-Path -Path (Join-Path $userRoamingPath 'zoom\bin\zoom.exe')

    if ($zoomInstalled) {
        # Zoom is installed for this user
        Write-Output "Zoom is installed for user $userDirectory"

        # Create a user account object and obtain the user's security identifier (SID)
        $userAccount = New-Object System.Security.Principal.NTAccount($userDirectory)
        $userSID = $userAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value

        # Check if there's a Zoom registry key for uninstallation
        if (Test-Path "HKU:\$userSID\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZoomUMX") {
            Write-Output "Removing registry key ZoomUMX for $userSID in HK_USERS"
            Remove-Item "HKU:\$userSID\Software\Microsoft\Windows\CurrentVersion\Uninstall\ZoomUMX" -Force
        }

        # Check if Zoom is running on cloudinfra.net device and terminate it
        $zoomProcesses = Get-Process | Where-Object { $_.Name -eq 'Zoom' }
        if ($zoomProcesses.Count -gt 0) {
            Write-Output "Terminating Zoom processes for user $userDirectory"
            $zoomProcesses | ForEach-Object { Stop-Process -Id $_.Id -Force }
        }

        # Remove the 'zoom' directory in the cloudinfra user's Roaming folder
        Write-Output "Removing 'zoom' folder in $userRoamingPath"
        Remove-Item -Recurse -Path (Join-Path $userRoamingPath 'zoom') -Force -ErrorAction SilentlyContinue

        # Remove the 'zoom' start menu shortcut
        $startMenuPath = Join-Path $userRoamingPath '\Microsoft\Windows\Start Menu\Programs\zoom'
        Write-Output "Removing 'zoom' start menu shortcut"
        Remove-Item -Recurse -Path $startMenuPath -Force -ErrorAction SilentlyContinue
    } else {
        # Zoom is not installed for this user
        Write-Output "Zoom is not installed for user $userDirectory"
    }
}

# Remove the HKU PowerShell drive when done
Remove-PSDrive -Name HKU