<#
.DESCRIPTION
    Checks the existence of the cloudinfra.net registry key and its values.
    Author: Jatin Makhija
    Version: 1.0.0
#>

$regPath = "HKCU:\Software\cloudinfra.net"
$regValues = @{
    "Location" = @{ Data = "United Kingdom"; Type = "String" }
    "Status" = @{ Data = "1"; Type = "Dword" }
}

$typeMap = @{
    "String" = [Microsoft.Win32.RegistryValueKind]::String
    "DWord" = [Microsoft.Win32.RegistryValueKind]::DWord
    "QWord" = [Microsoft.Win32.RegistryValueKind]::QWord
    "Binary" = [Microsoft.Win32.RegistryValueKind]::Binary
    "MultiString" = [Microsoft.Win32.RegistryValueKind]::MultiString
    "ExpandString" = [Microsoft.Win32.RegistryValueKind]::ExpandString
}

if (Test-Path $regPath) {
    Write-Host "Registry key exists. Checking values..."
    foreach ($key in $regValues.Keys) {
        $expected = $regValues[$key]
        $actual = Get-ItemProperty -Path $regPath -Name $key -ErrorAction SilentlyContinue
        
        if ($null -eq $actual) {
            Write-Host "Registry value '$key' does not exist!"
            Exit 1
        }
        
        $actualValue = $actual.$key
        $actualType = (Get-Item -Path $regPath).GetValueKind($key)

        if ($actualType -ne $typeMap[$expected.Type] -or $actualValue -ne $expected.Data) {
            Write-Host "Registry value '$key' is of type $actualType, expected $($expected.Type) or value does not match!"
            Exit 1
        }
    }
    Write-Host "All registry values match the expected data. No action required."
    Exit 0
} else {
    Write-Host "Registry key does not exist."
    Exit 1
}