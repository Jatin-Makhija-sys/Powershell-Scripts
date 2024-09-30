<#
.SYNOPSIS
    This script checks if specified IP address and hostname pairs exist in the Windows hosts file.
    
.DESCRIPTION
    The script reads a list of IP address and hostname pairs and checks if they exist in the Windows hosts file.
    If any entries are missing, the script logs them in a specified file and exits with a status code 1.
    If all entries are found, it exits with a status code 0.

.PARAMETER $hostEntries
    A list of IP address and hostname pairs to check against the hosts file.
    
.PARAMETER $missingEntriesFilePath
    The file path where missing host entries will be saved, if any are not found in the hosts file.

.NOTES
    Author: Jatin Makhija
    Copyright: cloudinfra.net
    Version: 1.0.0
    
.EXAMPLE
    To run the script and check for missing host entries:
    .\Detection_Hosts.ps1
    
    This will check if the specified entries exist in the hosts file, and output any missing entries.

#>
$hostEntries = @(
    @{ ipAddress = "192.168.1.23"; hostname = "cloudinfra.net" },
    @{ ipAddress = "159.233.111.000"; hostname = "techpress.net" },
    @{ ipAddress = "1.2.3.4"; hostname = "testsite.com" }
)

# Path to store the missing entries log
$missingEntriesFilePath = "C:\Windows\Web\MissingEntries.txt"

# Check if the missing entries file exists, and remove it if found
if (Test-Path $missingEntriesFilePath) {
    Remove-Item -Path $missingEntriesFilePath -Force
    Write-Output "Deleted existing missing entries file: $missingEntriesFilePath"
}

# Read the hosts file, excluding comment lines
$hostsFileContent = Get-Content -Path C:\Windows\System32\drivers\etc\hosts | Where-Object {$_ -notmatch "^#"}

# Initialize an array to store missing entries
$missingEntries = @()

# Check each host entry in the list
foreach ($hostEntry in $hostEntries) {
    $entryString = "$($hostEntry.ipAddress) $($hostEntry.hostname)"
    Write-Output "Checking if hosts file contains record: $entryString"

    if ($hostsFileContent -notcontains $entryString) {
        Write-Output "Host $entryString doesn't exist."
        $missingEntries += $entryString
    } else {
        Write-Output "Host $entryString already exists in the hosts file."
    }
}

# Output missing entries to the specified file, if any, and exit with code 1
if ($missingEntries.Count -gt 0) {
    $missingEntries | Out-File -FilePath $missingEntriesFilePath
    Write-Output "Missing entries written to $missingEntriesFilePath"
    Exit 1
} else {
    # All entries exist, exit with code 0
    Write-Output "All specified hosts are present in the hosts file."
    Exit 0
}
