<#
.SYNOPSIS
    Detection script: Scheduled Task existence check.

.DESCRIPTION
    Detects whether a specific scheduled task exists.

.NOTES
    Author  : Jatin Makhija
    Site    : cloudinfra.net
    Version : 1.0.0

    Exit codes:
      0 = Task exists (no remediation required)
      1 = Task does not exist (remediation required)
#>

$taskName = "Cloudinfra-RebootDevice"
$taskStatus = Get-ScheduledTask | Where-Object { $_.TaskName -eq $taskName }
if ($taskStatus) {
    Write-Host "Task already Exists. No Action Needed."
    Exit 0
}
Else {
    Write-Host "Task does not exist, Remediation required"
    Exit 1
}