<# 
.SYNOPSIS 
Detect WindowsStore and RequirePrivateStoreOnly reg entries
 
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
$expectedValue = 1

try {
    if (Test-Path -Path $regPath) {
        $regValue = Get-ItemProperty -Path $regPath -Name $regEntry -ErrorAction Stop

        if ($regValue.$regEntry -eq $expectedValue) {
            Write-Host "Registry entry exists and has the expected value."
            exit 0
        } else {
            Write-Host "Registry entry exists but has an unexpected value."
            exit 1
        }
    } else {
        Write-Host "Registry path does not exist."
        exit 1
    }
} catch {
    Write-Host "An error occurred: $_"
    exit 1
}