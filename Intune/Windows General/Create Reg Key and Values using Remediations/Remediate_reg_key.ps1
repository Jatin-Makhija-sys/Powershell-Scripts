<#
.DESCRIPTION
    Below Powershell script will Check the existence of
    cloudinfra.net registry Key and values. If it does not exist, It will create it.
    
    Author: Jatin Makhija
    Site: cloudinfra.net
    Version: 1.0.0
#>
# Registry path to check
$regPath = "HKLM:\Software\cloudinfra.net"

# Check if the registry key exists
$value = Test-Path $regPath
if (!$value) {
    try {
        Write-Host "Creating Reg Key"
        # Create the registry key
        New-Item -Path HKLM:\Software -Name cloudinfra.net –Force | Out-Null
        New-ItemProperty -Path $regPath -Name 'Status' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $regPath -Name 'Location' -Value "United Kingdom" -PropertyType String | Out-Null
        Exit 0
    }
    catch {
        Write-Host "Error Creating Reg Key"
        Write-Error $_
        Exit 1
    }
}
else {
    Write-Host "Reg Key already exists. Checking values..."

    # Check and remediate the 'Status' value
    $statusValue = Get-ItemProperty -Path $regPath -Name 'Status' -ErrorAction SilentlyContinue
    if ($statusValue.Status -ne 1) {
        Write-Host "Incorrect 'Status' value. Correcting it..."
        Set-ItemProperty -Path $regPath -Name 'Status' -Value 1 -Force | Out-Null
    }

    # Check and remediate the 'Location' value
    $locationValue = Get-ItemProperty -Path $regPath -Name 'Location' -ErrorAction SilentlyContinue
    if ($locationValue.Location -ne "United Kingdom") {
        Write-Host "Incorrect 'Location' value. Correcting it..."
        Set-ItemProperty -Path $regPath -Name 'Location' -Value "United Kingdom" -Force | Out-Null
    }

    Write-Host "All values are correct or have been remediated. No further action required."
    Exit 0
}