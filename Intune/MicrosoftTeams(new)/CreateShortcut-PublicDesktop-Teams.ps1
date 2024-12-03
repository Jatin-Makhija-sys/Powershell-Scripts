$Shortcuts = @(
    @{ Name = "Teams"; TargetPath = "C:\Program Files\WindowsApps\MSTeams_24277.3507.3205.5228_x64__8wekyb3d8bbwe\ms-teams.exe" }
)

$PublicDesktopPath = "$env:Public\Desktop"

foreach ($App in $Shortcuts) {
    $ShortcutFile = Join-Path -Path $PublicDesktopPath -ChildPath "$($App.Name).lnk"
    # Check if the shortcut already exists
    if (Test-Path -Path $ShortcutFile) {
        Write-Output "Shortcut for $($App.Name) already exists at $ShortcutFile. Skipping creation."
        continue
    }
    $isUrl = $false
    if ($App.TargetPath -and $App.TargetPath -like "http*") {
        $isUrl = $true
    }

    if (-Not $isUrl -and $App.TargetPath -and (-Not (Test-Path -Path $App.TargetPath))) {
        Write-Output "The target file for $($App.Name) at $($App.TargetPath) does not exist. Skipping shortcut creation."
        continue
    }

    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
        if ($isUrl) {
            # Set properties for a web link shortcut
            $Shortcut.TargetPath = $App.TargetPath
            # Check if Edge is installed before setting the icon
            $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
            if (Test-Path -Path $edgePath) {
                $Shortcut.IconLocation = $edgePath  # Use Edge as the icon for web links
            } else {
                Write-Output "Edge not found. No icon will be set for the web link."
            }
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