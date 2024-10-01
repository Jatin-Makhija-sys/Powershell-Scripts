<#
.SYNOPSIS
    This script removes specific host entries (IP and hostname pairs) found in the FoundEntries.txt file from the Windows hosts file.

.DESCRIPTION
    The script reads IP address and hostname pairs from the FoundEntries.txt file and removes them from the Windows hosts file.
    It ensures that only the specified entries are removed, and all other entries remain unchanged.

.PARAMETER $foundEntriesFilePath
    The path to the file that contains host entries to be removed from the hosts file.

.PARAMETER $hostsFilePath
    The path to the Windows hosts file where entries will be removed.

.NOTES
    Author: Jatin Makhija
    Copyright: cloudinfra.net
    Version: 1.0

.EXAMPLE
    To run the script:   
    .\Remediation_Host_Entries.ps1
    This will check the FoundEntries.txt file for host entries and remove them from the hosts file.    
#>

# Use $env:Windir to dynamically set paths
$windowsDir = $env:Windir

# Define the path to the FoundEntries.txt file using Join-Path
$foundEntriesFilePath = Join-Path -Path $windowsDir -ChildPath "Web\FoundEntries.txt"

# Define the path to the hosts file using Join-Path
$hostsFilePath = Join-Path -Path $windowsDir -ChildPath "System32\drivers\etc\hosts"

function Normalize-Entry {
    param (
        [string]$entry
    )
    return ($entry -replace "\s+", " ").Trim()
}

# Check if the FoundEntries.txt file exists
if (Test-Path $foundEntriesFilePath) {
    $foundEntries = Get-Content -Path $foundEntriesFilePath | ForEach-Object { Normalize-Entry $_ }

    # Read the current contents of the hosts file
    $hostsFileContent = Get-Content -Path $hostsFilePath

    # Initialize an array to store the updated hosts file content
    $updatedHostsFileContent = @()

    foreach ($line in $hostsFileContent) {
        $normalizedLine = Normalize-Entry $line

        # Check if the line is NOT in the found entries list
        if ($foundEntries -notcontains $normalizedLine) {
            # If the line is not found in the list, add it to the updated content
            $updatedHostsFileContent += $line
        } else {
            Write-Output "Removing entry: $normalizedLine"
        }
    }

    # Write the updated content back to the hosts file
    Set-Content -Path $hostsFilePath -Value $updatedHostsFileContent
    Write-Output "Updated hosts file. Entries from FoundEntries.txt have been removed."
    Exit 0
} else {
    # FoundEntries.txt file not found
    Write-Output "No FoundEntries file found at $foundEntriesFilePath."
    Exit 1
}