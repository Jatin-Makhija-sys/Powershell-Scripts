<#
.DESCRIPTION
    This script checks if a specified scheduled task exists on the device or not. If it exists, the task is not modified. If it does not exist, the task is created.
    Additionally, it ensures that the PowerShell script to be scheduled is copied to the required location.
    Author: Jatin Makhija
    Site: cloudinfra.net
    Version: 1.1.0
#>

# Define configurable variables
$TaskName = "Cloudinfra-RebootDevice" # Name of the scheduled task
$WebFolderPath = "C:\Windows\Web" # Path to the Web folder
$ScriptsFolderPath = "$WebFolderPath\Scripts" # Path to the Scripts folder
$PowerShellScriptName = "RestartWindows.ps1" # Name of the PowerShell script
$PowerShellScriptPath = "$ScriptsFolderPath\$PowerShellScriptName" # Final path to the PowerShell script
$PowerShellExecutable = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" # Path to PowerShell executable
$PowerShellArguments = "-ExecutionPolicy Bypass -File `"$PowerShellScriptPath`""
$TriggerTime = "3:00AM" # Time to run the task
$TaskUser = "NT AUTHORITY\SYSTEM" # User to run the task
$TaskLogonType = "ServiceAccount" # Logon type
$TaskRunLevel = "Highest" # Run level

# Ensure the Scripts folder exists under the Web folder
if (!(Test-Path -Path $ScriptsFolderPath)) {
    try {
        Write-Host "Scripts folder does not exist. Creating folder at '$ScriptsFolderPath'..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $ScriptsFolderPath -Force | Out-Null
        Write-Host "Scripts folder created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to create Scripts folder at '$ScriptsFolderPath'." -ForegroundColor Red
        Write-Error $_
        Exit 1
    }
}

# Ensure the PowerShell script exists in the Scripts folder
if (!(Test-Path -Path $PowerShellScriptPath)) {
    try {
        Write-Host "PowerShell script not found in '$ScriptsFolderPath'. Copying script..." -ForegroundColor Yellow

        # Copy the script from the current folder to the Scripts folder
        $CurrentScriptPath = "./$PowerShellScriptName" # Assuming the script is in the current folder
        Copy-Item -Path $CurrentScriptPath -Destination $PowerShellScriptPath -Force

        Write-Host "PowerShell script copied successfully to '$PowerShellScriptPath'." -ForegroundColor Green
    } catch {
        Write-Host "Failed to copy the PowerShell script to '$PowerShellScriptPath'." -ForegroundColor Red
        Write-Error $_
        Exit 1
    }
}

# Check if the scheduled task exists
$taskStatus = Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName }

if ($taskStatus) {
    Write-Host "Task '$TaskName' already exists. No changes will be made." -ForegroundColor Green
    Exit 0
}

# Create the scheduled task if it does not exist
try {
    Write-Host "Creating task '$TaskName'..." -ForegroundColor Yellow

    # Define the task components
    $STaction  = New-ScheduledTaskAction -Execute $PowerShellExecutable -Argument $PowerShellArguments
    $STtrigger = New-ScheduledTaskTrigger -Daily -At $TriggerTime
    $STSet     = New-ScheduledTaskSettingsSet
    $STuser    = New-ScheduledTaskPrincipal -UserID $TaskUser -LogonType $TaskLogonType -RunLevel $TaskRunLevel

    # Register the scheduled task
    Register-ScheduledTask -TaskName $TaskName -TaskPath "\" -Action $STaction -Settings $STSet -Trigger $STtrigger -Principal $STuser

    Write-Host "Task '$TaskName' created successfully." -ForegroundColor Green
    Exit 0
} catch {
    Write-Host "Error creating the scheduled task." -ForegroundColor Red
    Write-Error $_
    Exit 1
}