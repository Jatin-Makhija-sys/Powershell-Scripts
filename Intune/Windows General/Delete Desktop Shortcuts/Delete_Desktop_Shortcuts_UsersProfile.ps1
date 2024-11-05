# Get the Desktop path
$DesktopPath = [Environment]::GetFolderPath("Desktop")

# Define an array of shortcut filenames to delete
$ShortcutsToDelete = @("Zoom.lnk", "Teams.lnk", "Slack.lnk")

# Loop through each shortcut name in the array
foreach ($Shortcut in $ShortcutsToDelete) {
    # Construct the full path to the shortcut
    $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath $Shortcut

    # Check if the shortcut exists
    if (Test-Path -Path $ShortcutFile) {
        # Attempt to remove the shortcut, with silent error handling
        Remove-Item -Path $ShortcutFile -ErrorAction SilentlyContinue

        # Confirm removal to the user
        if (-not (Test-Path -Path $ShortcutFile)) {
            Write-Output "Shortcut '$Shortcut' successfully deleted."
        } else {
            Write-Output "Failed to delete the shortcut '$Shortcut'."
        }
    } else {
        Write-Output "Shortcut '$Shortcut' not found."
    }
}
