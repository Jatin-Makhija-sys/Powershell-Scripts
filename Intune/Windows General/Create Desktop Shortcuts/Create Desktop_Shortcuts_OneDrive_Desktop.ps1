$Applications = @(
    @{ Name = "Zoom"; TargetPath = "C:\Program Files\Zoom\bin\Zoom.exe" },
    @{ Name = "Notepad"; TargetPath = "C:\Windows\System32\notepad.exe" },
    @{ Name = "Calculator"; TargetPath = "C:\Windows\System32\calc.exe" }
)

$DesktopPath = [Environment]::GetFolderPath("Desktop")

foreach ($App in $Applications) {
    # Define the shortcut file path
    $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath "$($App.Name).lnk"

    # Check if the shortcut already exists
    if (Test-Path -Path $ShortcutFile) {
        Write-Output "Shortcut for $($App.Name) already exists at $ShortcutFile. Skipping creation."
        continue
    }

    # Verify if the target application exists
    if (-Not (Test-Path -Path $App.TargetPath)) {
        Write-Output "The target file for $($App.Name) at $($App.TargetPath) does not exist. Skipping shortcut creation."
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
        Write-Output "An error occurred while creating the shortcut for $($App.Name): $_"
    }
}
Write-Output "Shortcut creation process completed."