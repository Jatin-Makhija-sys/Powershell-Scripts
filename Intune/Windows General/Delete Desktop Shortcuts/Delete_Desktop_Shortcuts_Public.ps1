$ShortcutFiles = @(
    "$env:Public\Desktop\chrome.lnk",
    "$env:Public\Desktop\bitwarden.lnk",
    "$env:Public\Desktop\filezilla.lnk"
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