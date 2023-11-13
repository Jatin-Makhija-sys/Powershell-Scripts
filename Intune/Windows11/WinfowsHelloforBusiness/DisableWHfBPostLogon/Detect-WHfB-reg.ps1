<# 
.SYNOPSIS 
Detect If WHfB registry keys and values exist
 
.DESCRIPTION 
This script will detect if WHfB registry entries are 
created correctly to disable Post Logon WHfB prompt
.NOTES     
        Name       : Detect-WHfB.ps1
        Author     : Jatin Makhija  
        Version    : 1.0.0  
        DateCreated: 13-Nov-2023
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>

# Define the registry path to check
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork"

# Define an array of registry values to check
$valueNames = @("DisablePostLogonProvisioning", "Enabled")

# Define the required value that the registry entries should match
$requiredValue = "1"

# Check if the registry key exists
$regKeyExists = Test-Path -Path $regPath

# If the registry key exists, proceed with checking registry values
if ($regKeyExists) {
    # Loop through each specified registry value
    foreach ($valueName in $valueNames) {
        # Check if the registry entry exists
        $regEntryExists = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue

        # If the registry entry exists, fetch its value
        if ($regEntryExists) {
            $currentValue = Get-ItemProperty -Path $regPath | Select-Object -ExpandProperty $valueName -ErrorAction SilentlyContinue

            # Check if the registry value matches the required value
            if ($currentValue -eq $requiredValue) {
                Write-Host "Registry value '$valueName' exists and matches the required value."
                Exit 0
            } else {
                Write-Host "Registry value '$valueName' exists, but does not match the required value."
                Write-Host "Current value: $currentValue"
                Write-Host "Required value: $requiredValue"
                Exit 1
            }
        } else {
            # If the registry entry does not exist
            Write-Host "Registry value '$valueName' does not exist."
            Exit 1
        }
    }
} else {
    # If the registry key does not exist
    Write-Host "Registry key does not exist."
    Exit 1
}
