# Get the Desktop paths for the user and public
$UserDesktopPath = [Environment]::GetFolderPath("Desktop")
$PublicDesktopPath = Join-Path -Path $env:Public -ChildPath "Desktop"

# Define an array of shortcut filenames to delete
$ShortcutsToDelete = @("Bitwarden.lnk", "Chrome.lnk", "filezilla.lnk")

# Function to delete shortcuts from a specified path
function Delete-Shortcuts {
    param (
        [string]$DesktopPath
    )
    
    foreach ($Shortcut in $ShortcutsToDelete) {
        $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath $Shortcut

        # Check if the shortcut exists
        if (Test-Path -Path $ShortcutFile) {
            # Remove shortcut
            Remove-Item -Path $ShortcutFile -ErrorAction SilentlyContinue

            # Confirm removal to the user
            if (-not (Test-Path -Path $ShortcutFile)) {
                Write-Output "Shortcut '$Shortcut' successfully deleted from '$DesktopPath'."
            } else {
                Write-Output "Failed to delete the shortcut '$Shortcut' from '$DesktopPath'."
            }
        } else {
            Write-Output "Shortcut '$Shortcut' not found in '$DesktopPath'."
        }
    }
}

# Delete shortcuts from user's Desktop
Delete-Shortcuts -DesktopPath $UserDesktopPath

# Delete shortcuts from Public Desktop
Delete-Shortcuts -DesktopPath $PublicDesktopPath