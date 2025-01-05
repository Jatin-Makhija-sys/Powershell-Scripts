<#
.DESCRIPTION
    This script checks if a specified scheduled task exists on the device or not. If it exists, the task is deleted.
    Author: Jatin Makhija
    Site: cloudinfra.net
    Version: 1.2.0
#>

# Define the task name
$TaskName = "Cloudinfra-RebootDevice"

# Check if the scheduled task exists
$taskStatus = Get-ScheduledTask | Where-Object { $_.TaskName -eq $TaskName }

if ($taskStatus) {
    try {
        Write-Host "Task '$TaskName' exists. Deleting the task..." -ForegroundColor Yellow

        # Delete the scheduled task
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

        Write-Host "Task '$TaskName' deleted successfully." -ForegroundColor Green
        Exit 0
    } catch {
        Write-Host "Error deleting the task '$TaskName'." -ForegroundColor Red
        Write-Error $_
        Exit 1
    }
} else {
    Write-Host "Task '$TaskName' does not exist. No action required." -ForegroundColor Green
    Exit 0
}