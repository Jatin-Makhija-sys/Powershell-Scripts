<#
.SYNOPSIS
    This script appends missing host entries from the MissingEntries.txt file into the Windows hosts file.

.DESCRIPTION
    The script reads IP address and hostname pairs from the MissingEntries.txt file and adds them to the Windows hosts file. 
    It ensures the entries are appended to the hosts file if they were previously found missing.

.PARAMETER $MissingEntriesFilePath
    The path to the file that contains missing host entries to be added to the hosts file.

.PARAMETER $HostsFilePath
    The path to the Windows hosts file where missing entries will be appended.

.NOTES
    Author: Jatin Makhija
    Copyright: cloudinfra.net
    Version: 1.0.0

.EXAMPLE
    To run the script:   
    .\AddMissingEntriesToHosts.ps1 
     This will check the MissingEntries.txt file for missing host entries and append them to the hosts file.    
#>

# Define the path to the missing entries file
$MissingEntriesFilePath = "C:\Windows\Web\MissingEntries.txt"

# Check if the missing entries file exists
if (Test-Path $MissingEntriesFilePath) {
    # Read the missing entries from the file
    $MissingEntries = Get-Content -Path $MissingEntriesFilePath

    # Define the path to the hosts file
    $HostsFilePath = "C:\Windows\System32\drivers\etc\hosts"

    # Append each missing entry to the hosts file
    foreach ($Entry in $MissingEntries) {
        Add-Content -Path $HostsFilePath -Value $Entry
        Write-Output "Appended $Entry to the hosts file."
    }
    Write-Output "All missing entries have been added to the hosts file."
    Exit 0
} else {
    # Missing entries file not found
    Write-Output "No missing entries file found at $MissingEntriesFilePath."
    Exit 1
}