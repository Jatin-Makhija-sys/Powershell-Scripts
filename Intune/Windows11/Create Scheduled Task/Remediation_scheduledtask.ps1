<#
.SYNOPSIS
    Remediation script: Create Cloudinfra-RebootDevice scheduled task if missing.

.DESCRIPTION
    This script checks if the Cloudinfra-RebootDevice schedule task exists on the device or not. 
    If it does not exist. It will create a task named Cloudinfra-RebootDevice.

.NOTES
    Author  : Jatin Makhija
    Site    : cloudinfra.net
    Version : 1.0.0

    Exit codes:
      0 = Task exists or created successfully
      1 = Task creation failed
#>

$taskName   = "Cloudinfra-RebootDevice"
$taskstatus = Get-ScheduledTask | Where-Object { $_.TaskName -eq "Cloudinfra-RebootDevice" }

if (!$taskstatus) {
    try {
        Write-Host "Cloudinfra reboot device task does not Exists. Creating Task."

        $STaction  = New-ScheduledTaskAction -Execute 'c:\windows\system32\shutdown.exe' -Argument '-r -t 0'
        $STtrigger = New-ScheduledTaskTrigger -Daily -At 3am
        $STSet     = New-ScheduledTaskSettingsSet
        $STuser    = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName "Cloudinfra-RebootDevice" -TaskPath "\" -Action $STaction -Settings $STSet -Trigger $STtrigger -Principal $STuser

        Exit 0
    }
    Catch {
        Write-Host "Error in Creating scheduled task"
        Write-Error $_
        Exit 1
    }
}
Else {
    Write-Host "Task already Exists, No Remediation required"
    Exit 0
}