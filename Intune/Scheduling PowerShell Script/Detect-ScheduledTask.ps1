<#
.DESCRIPTION
    This script checks if a specified scheduled task exists on the device or not.
    Author: Jatin Makhija
    Site: cloudinfra.net
    Version: 1.1.0
#>

# Define the task name
$TaskName = "Cloudinfra-RebootDevice"

# Check if the scheduled task exists
$taskStatus = Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName }

if ($taskStatus) {
    Write-Host "Task '$TaskName' already exists. No action needed." -ForegroundColor Green
    Exit 0
} else {
    Write-Host "Task '$TaskName' does not exist. Remediation required." -ForegroundColor Red
    Exit 1
}