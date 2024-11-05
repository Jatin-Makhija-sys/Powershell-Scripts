# Define an array of shortcuts to delete
$ShortcutFiles = @(
    "$env:Public\Desktop\Zoom.lnk",
    "$env:Public\Desktop\Teams.lnk",
    "$env:Public\Desktop\OneDrive.lnk"
)

foreach ($ShortcutFile in $ShortcutFiles) {
    if (Test-Path $ShortcutFile) {
        try {
            Remove-Item -Path $ShortcutFile -ErrorAction Stop
            Write-Output "Shortcut successfully deleted: $ShortcutFile"
        } catch {
            Write-Output "Error deleting shortcut: $_"
        }
    } else {
        Write-Output "Shortcut not found: $ShortcutFile"
    }
}