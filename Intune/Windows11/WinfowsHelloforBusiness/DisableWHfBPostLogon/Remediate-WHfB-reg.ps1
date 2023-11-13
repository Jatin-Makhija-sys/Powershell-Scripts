<# 
.SYNOPSIS 
Remediate WHfB Registry Keys and values
 
.DESCRIPTION 
This Script will check if WHfB registry keys are created
and set to correct values, if not, it will fix it
.NOTES     
        Name       : Remediate-WHfB.ps1
        Author     : Jatin Makhija  
        Version    : 1.0.0  
        DateCreated: 13-Nov-2023
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>

# Specify the registry key path
$regKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"

# Specify registry entries
$valueNames = @("DisablePostLogonProvisioning", "Enabled")

# Specify the required value
$requiredValue = "1"

# Check if the registry key exists
$regKeyExists = Test-Path -Path $regKeyPath

if ($regKeyExists) {
    # Loop through each specified registry entry
    foreach ($valueName in $valueNames) {
        # Check if the registry entry exists
        $regEntryExists = Get-ItemProperty -Path $regKeyPath -Name $valueName -ErrorAction SilentlyContinue

        if ($regEntryExists) {
            # If the registry entry exists, fetch its current value
            $currentValue = $regEntryExists.$valueName

            # Check if the current value matches the required value
            if ($currentValue -ne $requiredValue) {
                # If the current value does not match the required value, update it
                Set-ItemProperty -Path $regKeyPath -Name $valueName -Value $requiredValue
                Write-Host "Registry entry '$valueName' updated to the required value '$requiredValue'"
            } else {
                Write-Host "Registry entry '$valueName' is already set to the required value."
            }
        } else {
            # If the registry entry does not exist, create it
            New-ItemProperty -Path $regKeyPath -Name $valueName -PropertyType DWORD -Value $requiredValue
            Write-Host "Registry entry '$valueName' created with the required value '$requiredValue'"
        }
    }
} else {
    # If the registry key does not exist, create it along with the specified registry entries
    New-Item -Path $regKeyPath -Force
    foreach ($valueName in $valueNames) {
        New-ItemProperty -Path $regKeyPath -Name $valueName -PropertyType DWORD -Value $requiredValue
        Write-Host "Registry key '$regKeyPath' and entry '$valueName' created with the required value '$requiredValue'"
    }
}

Write-Host "Registry check and update completed."
Exit 0
