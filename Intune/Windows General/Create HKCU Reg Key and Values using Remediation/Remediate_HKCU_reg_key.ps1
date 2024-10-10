<#
.DESCRIPTION
    Remediates the cloudinfra.net registry key and values under the current user's context. 
    If it does not exist, it creates it, even if the user does not have direct edit rights.
    
    Author: Jatin Makhija
    Version: 1.0.0
#>

# Open Registry session in current user’s drive
New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

# Get the current user SID
$user = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
$sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

# Set the path to the current user's registry location
$regPath = "HKU:\$sid\Software\cloudinfra.net"

# Define expected values and types
$regValues = @{
    "Location" = @{ Data = "United Kingdom"; Type = "String" }
    "Status" = @{ Data = "1"; Type = "String" }  # Status is a String
}

$typeMap = @{
    "String" = [Microsoft.Win32.RegistryValueKind]::String
    "DWord" = [Microsoft.Win32.RegistryValueKind]::DWord
    "QWord" = [Microsoft.Win32.RegistryValueKind]::QWord
    "Binary" = [Microsoft.Win32.RegistryValueKind]::Binary
    "MultiString" = [Microsoft.Win32.RegistryValueKind]::MultiString
    "ExpandString" = [Microsoft.Win32.RegistryValueKind]::ExpandString
}

# Check if the registry key exists
if (-not (Test-Path $regPath)) {
    try {
        Write-Host "Creating Reg Key"
        New-Item -Path "HKU:\$sid\Software" -Name "cloudinfra.net" -Force | Out-Null
        foreach ($key in $regValues.Keys) {
            New-ItemProperty -Path $regPath -Name $key -Value $value.Data -PropertyType $value.Type -Force | Out-Null
        }
        Exit 0
    } catch {
        Write-Host "Error Creating Reg Key"
        Write-Error $_
        Exit 1
    }
} else {
    Write-Host "Reg Key already exists. Checking values..."

    foreach ($key in $regValues.Keys) {
        $expected = $regValues[$key]
        $actual = Get-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue

        if ($null -eq $actual) {
            Write-Host "Registry value '$key' does not exist! Creating it..."
            New-ItemProperty -Path $regPath -Name $key -Value $expected.Data -PropertyType $expected.Type -Force | Out-Null
            continue
        }

        $actualValue = $actual.$key
        $actualType = (Get-Item -Path $regPath).GetValueKind($key)

        # Check if the actual type and value match the expected type and value
        if ($actualType -ne $typeMap[$expected.Type] -or $actualValue -ne $expected.Data) {
            Write-Host "Incorrect '$key' value or type. Correcting it..."
            # Remove the existing property before adding it again
            Remove-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue
            New-ItemProperty -Path $regPath -Name $key -Value $expected.Data -PropertyType $expected.Type -Force | Out-Null
        }
    }

    Write-Host "All values are correct or have been remediated. No further action required."
    Exit 0
}
