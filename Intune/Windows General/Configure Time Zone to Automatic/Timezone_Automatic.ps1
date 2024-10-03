<#
.SYNOPSIS
    This script checks specific registry paths and values. If the values are missing or incorrect,
    it updates or creates them with the desired values.
    
.DESCRIPTION
    The script loops through a list of registry paths and values. It verifies whether the current values
    match the desired values, and if not, it updates them. If the registry path or value does not exist,
    it creates them.

.PARAMETER $registrySettings
    A list of registry settings that include the path, name, and desired value to check and set.

.NOTES
    Author: Jatin Makhija
    Copyright: Cloudinfra.net
    Version: 1.0
    
.EXAMPLE
    Running the script will check the following:
    - Path: "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
      Name: "Value"
      Desired Value: "Allow"
      
    - Path: "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"
      Name: "Start"
      Desired Value: 3

    It will create or update these registry values if necessary.
#>

# Define the list of registry settings with paths, names, and desired values.
$registrySettings = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; Name = "Value"; DesiredValue = "Allow" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate"; Name = "Start"; DesiredValue = 3 }
)

# Foreach loop
foreach ($setting in $registrySettings) {

    # test if the registry path exists
    if (Test-Path $setting.Path) {

        # get the current value of the registry key
        $currentValue = (Get-ItemProperty -Path $setting.Path -ErrorAction SilentlyContinue).$($setting.Name)

        # If the current value is not the desired value, update it
        if ($currentValue -ne $setting.DesiredValue) {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.DesiredValue
            Write-Host "Updated or created $($setting.Name) in $($setting.Path) with value $($setting.DesiredValue)"
        } else {
            # If the current value is already correct, do nothing
            Write-Host "$($setting.Name) in $($setting.Path) is already set to $($setting.DesiredValue)"
        }

    } else {
        # If the registry path does not exist, log a warning
        Write-Warning "Registry path $($setting.Path) does not exist."
    }
}
