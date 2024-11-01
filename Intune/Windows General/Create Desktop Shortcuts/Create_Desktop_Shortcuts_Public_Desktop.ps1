$Applications = @(
    @{ Name = "Zoom"; TargetPath = "C:\Program Files\Zoom\bin\Zoom.exe" },
    @{ Name = "Notepad"; TargetPath = "C:\Windows\System32\notepad.exe" },
    @{ Name = "Calculator"; TargetPath = "C:\Windows\System32\calc.exe" }
)

$PublicDesktopPath = "$env:Public\Desktop"

foreach ($App in $Applications) {
    $ShortcutFile = Join-Path -Path $PublicDesktopPath -ChildPath "$($App.Name).lnk"
    # Check if the shortcut already exists
    if (Test-Path -Path $ShortcutFile) {
        Write-Output "Shortcut for $($App.Name) already exists at $ShortcutFile. Skipping creation."
        continue
    }

    # Verify the target application exists
    if (-Not (Test-Path -Path $App.TargetPath)) {
        Write-Output "Target application for $($App.Name) at $($App.TargetPath) not found. Skipping shortcut creation."
        continue
    }

    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
        $Shortcut.TargetPath = $App.TargetPath
        $Shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($App.TargetPath)  # Set working directory
        $Shortcut.Save()
        Write-Output "Shortcut for $($App.Name) created successfully at $ShortcutFile."
    }
    catch {
        Write-Output "Failed to create shortcut for $($App.Name): $_"
    }
}
Write-Output "Shortcut creation process completed."