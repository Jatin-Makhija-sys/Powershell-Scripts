# Open Registry session in current user’s drive
New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null

# Get the current user SID
$user = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
if (-not $user) { Write-Error "No interactive user detected."; Exit 1 }
$sid = (New-Object System.Security.Principal.NTAccount($user)).Translate([System.Security.Principal.SecurityIdentifier]).Value

# Set the path to the current user's registry location
$regPath = "HKU:\$sid\Software\cloudinfra.net"

# Define expected values and types
$regValues = @{
    "Location" = @{ Data = "United Kingdom"; Type = "String" }
    "Status"   = @{ Data = "1";              Type = "String" }  # String on purpose
}

$typeMap = @{
    "String"       = [Microsoft.Win32.RegistryValueKind]::String
    "DWord"        = [Microsoft.Win32.RegistryValueKind]::DWord
    "QWord"        = [Microsoft.Win32.RegistryValueKind]::QWord
    "Binary"       = [Microsoft.Win32.RegistryValueKind]::Binary
    "MultiString"  = [Microsoft.Win32.RegistryValueKind]::MultiString
    "ExpandString" = [Microsoft.Win32.RegistryValueKind]::ExpandString
}

# Ensure key and values
if (-not (Test-Path $regPath)) {
    try {
        Write-Host "Creating Reg Key"
        New-Item -Path "HKU:\$sid\Software" -Name "cloudinfra.net" -Force | Out-Null
        foreach ($key in $regValues.Keys) {
            $value = $regValues[$key]   # renamed variable
            New-ItemProperty -Path $regPath -Name $key -Value $value.Data -PropertyType $value.Type -Force | Out-Null
        }
        Exit 0
    } catch {
        Write-Host "Error Creating Reg Key"
        Write-Error $_
        Exit 1
    }
}
else {
    Write-Host "Reg Key already exists. Checking values..."
    foreach ($key in $regValues.Keys) {
        $value  = $regValues[$key]   # renamed variable
        $actual = Get-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue

        if ($null -eq $actual) {
            Write-Host "Registry value '$key' does not exist! Creating it..."
            New-ItemProperty -Path $regPath -Name $key -Value $value.Data -PropertyType $value.Type -Force | Out-Null
            continue
        }

        $actualValue = $actual.$key
        $actualType  = (Get-Item -Path $regPath).GetValueKind($key)

        if ($actualType -ne $typeMap[$value.Type] -or $actualValue -ne $value.Data) {
            Write-Host "Incorrect '$key' value or type. Correcting it..."
            Remove-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue
            New-ItemProperty -Path $regPath -Name $key -Value $value.Data -PropertyType $value.Type -Force | Out-Null
        }
    }

    Write-Host "All values are correct or have been remediated. No further action required."
    Exit 0
}