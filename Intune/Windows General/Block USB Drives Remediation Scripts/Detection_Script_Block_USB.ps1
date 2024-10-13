<#
.DESCRIPTION
    This detection script will check if RemovableStorageDevices reg key
    is existing and Deny_All is set to 1 
    Author: Jatin Makhija
    Website: Copyright - Cloudinfra.net
    Version: 1.0.0
#>
#registry key path 
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices"
#Provide registry entry display name 
$valueName = "Deny_All"
#Provide registry entry expected value 
$requiredValue = "1"
$regkeyexists = Test-Path -Path $regPath
if ($regkeyexists) {
   #Check if registry entry named Status exists
   $regentryexists = Get-ItemProperty -Path $regpath -Name $valueName -ErrorAction SilentlyContinue
   if ($regentryexists) {
   #If registry entry named Deny_All exists, then fetch its value
    $currentValue = Get-ItemProperty -Path $regpath | Select-Object -ExpandProperty $valueName -ErrorAction SilentlyContinue
    #Match Status registry entry value with requried value
    if ($currentValue -eq $requiredvalue) {
            Write-Host "Reg value exists and matching the required value."
            Exit 0
        } else {
            Write-Host "Reg value exists, but does not match the required value."
            Write-Host "Current value: $currentValue"
            Write-Host "Required value: $requiredValue"
            Exit 1
        }
    } 
    else {
        Write-Host "Registry value does not exist."
        Exit 1
    }
} 
else {
    Write-Host "Registry key does not exist."
    Exit 1
}