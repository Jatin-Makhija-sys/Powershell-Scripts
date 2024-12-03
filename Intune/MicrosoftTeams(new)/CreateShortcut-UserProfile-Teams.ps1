# Define a list of applications and URLs with their target paths and desired shortcut names
$Shortcuts = @(
    @{ Name = "Teams"; TargetPath = "C:\Program Files\WindowsApps\MSTeams_24277.3507.3205.5228_x64__8wekyb3d8bbwe\ms-teams.exe" }
)

$DesktopPath = [Environment]::GetFolderPath("Desktop")

foreach ($App in $Shortcuts) {
    # Define the shortcut file path
    $ShortcutFile = Join-Path -Path $DesktopPath -ChildPath "$($App.Name).lnk"

    # Check if the shortcut already exists
    if (Test-Path -Path $ShortcutFile) {
        Write-Output "Shortcut for $($App.Name) already exists at $ShortcutFile. Skipping creation."
        continue
    }

    $isUrl = $false

    # Check if the target is a URL
    if ($App.TargetPath -and $App.TargetPath -like "http*") {
        $isUrl = $true
    }

    # Validate the target path only if it's not a URL
    if (-Not $isUrl -and $App.TargetPath -and (-Not (Test-Path -Path $App.TargetPath))) {
        Write-Output "The target file for $($App.Name) at $($App.TargetPath) does not exist. Skipping shortcut creation."
        continue
    }

    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
        if ($isUrl) {
            $Shortcut.TargetPath = $App.TargetPath
            $Shortcut.IconLocation = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" # Use Edge as the icon for web links
        } else {
            $Shortcut.TargetPath = $App.TargetPath
            $Shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($App.TargetPath)  # Set working directory
        }
        $Shortcut.Save()
        Write-Output "Shortcut for $($App.Name) created successfully at $ShortcutFile."
    }
    catch {
        Write-Output "An error occurred while creating the shortcut for $($App.Name): $_"
    }
}
Write-Output "Shortcut creation process completed."