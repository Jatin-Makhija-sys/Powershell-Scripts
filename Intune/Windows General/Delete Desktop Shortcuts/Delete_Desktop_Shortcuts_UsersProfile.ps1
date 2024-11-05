$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ShortcutsToDelete = @("filezilla.lnk", "chrome.lnk", "bitwarden.lnk")

foreach ($Shortcut in $ShortcutsToDelete) {
    $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath $Shortcut

    # Check if the shortcut exists
    if (Test-Path -Path $ShortcutFile) {
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