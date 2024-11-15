<# 
.SYNOPSIS 
Remediate WindowsStore and RequirePrivateStoreOnly reg entries
 
.DESCRIPTION 
Below script will Detect if WindowsStore and RequirePrivateStoreOnly
exists and set to the correct value for blocking MS Store App on Windows 10/11.
 
.NOTES     
        Name       : Detection Script for MS Store App
        Author     : Jatin Makhija  
        Version    : 1.0.0  
        DateCreated: 14-Nov-2024
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore"
$regEntry = "RequirePrivateStoreOnly"
$desiredValue = 1

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "Registry path does not exist. Creating it..."
        New-Item -Path $regPath -Force | Out-Null
    } else {
        Write-Host "Registry path exists."
    }

    $currentValue = (Get-ItemProperty -Path $regPath -Name $regEntry -ErrorAction SilentlyContinue).$regEntry

    if ($null -eq $currentValue -or $currentValue -ne $desiredValue) {
        Write-Host "Registry entry is missing or has an incorrect value. Setting it to $desiredValue..."
        Set-ItemProperty -Path $regPath -Name $regEntry -Value $desiredValue -Force
    } else {
        Write-Host "Registry entry exists and has the correct value."
    }
} catch {
    Write-Host "An error occurred during remediation: $_"
    exit 1
}
Write-Host "Remediation completed successfully."
exit 0