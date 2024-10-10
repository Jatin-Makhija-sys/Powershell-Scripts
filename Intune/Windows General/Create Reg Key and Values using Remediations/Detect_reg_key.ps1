<#
.DESCRIPTION
    Below Powershell script will Check the existence of
    cloudinfra.net registry Key and given values.

    Author: Jatin Makhija
    Site: cloudinfra.net
    Version: 1.0.0
#>

# Registry path to check
$regPath = "HKLM:\Software\cloudinfra.net"

# Define registry values and their expected data
$regValues = @{
    "Location" = @{
        Data = "United Kingdom"
        Type = "String"
    }
    "Status" = @{
        Data = "1"
        Type = "String"
    }
    # Placeholder for DWord values checking
    # "ExampleDWord" = @{
    #     Data = 123
    #     Type = "DWord"
    # }
}

# Check if the registry path exists
if (Test-Path $regPath) {
    Write-Host "Registry key already exists. Checking values..."

    foreach ($key in $regValues.Keys) {
        $expectedValue = $regValues[$key].Data
        $expectedType = $regValues[$key].Type

        # Get the actual value from the registry
        $actualValue = Get-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue

        if ($null -eq $actualValue) {
            Write-Host "Registry value '$key' not found!"
            Exit 1
        } elseif ($regValues[$key].Type -eq "DWord") {
            # Convert DWord values to integers for comparison
            if ($actualValue.$key -ne [int]$expectedValue) {
                Write-Host "Registry value '$key' does not match the expected value!"
                Exit 1
            }
        } else {
            # For String and other types, do a direct comparison
            if ($actualValue.$key -ne $expectedValue) {
                Write-Host "Registry value '$key' does not match the expected value!"
                Exit 1
            }
        }
    }

    Write-Host "All registry values match the expected data. No action required."
    Exit 0
} else {
    Write-Host "Registry key does not exist."
    Exit 1
}
