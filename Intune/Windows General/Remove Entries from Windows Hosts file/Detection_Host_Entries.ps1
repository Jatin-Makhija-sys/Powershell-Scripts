<#
.SYNOPSIS
    This script checks if specified IP address and hostname pairs exist in the Windows hosts file.
    
.DESCRIPTION
    The script reads a list of IP address and hostname pairs and checks if they exist in the Windows hosts file.
    If any entries are found, the script logs them in a specified file and exits with a status code 1.
    If no entries are found, it exits with a status code 0.

.PARAMETER $hostEntries
    A list of IP address and hostname pairs to check against the hosts file.
    
.PARAMETER $foundEntriesFilePath
    The file path where found host entries will be saved, if any are found in the hosts file.

.NOTES
    Author: Jatin Makhija
    Copyright: Cloudinfra.net
    Version: 1.0
    
.EXAMPLE
    To run the script and check for existing host entries:
    .\Detection_Host_Entries.ps1
    
    This will check if the specified entries exist in the hosts file, and output any found entries.
#>

$hostEntries = @(
    @{ ipAddress = "192.168.1.23"; hostname = "cloudinfra.net" },
    @{ ipAddress = "159.233.111.000"; hostname = "techpress.net" },
    @{ ipAddress = "1.2.3.4"; hostname = "testsite.com" }
)

# Use $env:Windir Enviornment variable
$windowsDir = $env:Windir

# Build paths dynamically using Join-Path
$hostsFilePath = Join-Path -Path $windowsDir -ChildPath "System32\drivers\etc\hosts"
$foundEntriesFilePath = Join-Path -Path $windowsDir -ChildPath "Web\FoundEntries.txt"

# Check if the found entries file exists, and remove it if found
if (Test-Path $foundEntriesFilePath) {
    Remove-Item -Path $foundEntriesFilePath -Force
    Write-Output "Deleted existing found entries file: $foundEntriesFilePath"
}

# Read the hosts file, excluding comment lines
$hostsFileContent = Get-Content -Path $hostsFilePath | Where-Object {$_ -notmatch "^#"}

# Initialize an array to store found entries
$foundEntries = @()

function Normalize-Entry {
    param (
        [string]$entry
    )
    return ($entry -split '\s+' | ForEach-Object { $_.Trim() }) -join ' '
}

# Check each host entry in the list
foreach ($hostEntry in $hostEntries) {
    # Normalize the entry from $hostEntries
    $entryString = Normalize-Entry "$($hostEntry.ipAddress) $($hostEntry.hostname)"
    Write-Output "Checking if hosts file contains record: $entryString"

    # Normalize each line from the hosts file before comparison
    foreach ($line in $hostsFileContent) {
        $normalizedLine = Normalize-Entry $line

        if ($normalizedLine -eq $entryString) {
            Write-Output "Host $entryString exists."
            $foundEntries += $entryString
            break
        }
    }
}

# Output found entries to the specified file, if any, and exit with code 1
if ($foundEntries.Count -gt 0) {
    $foundEntries | Out-File -FilePath $foundEntriesFilePath
    Write-Output "Found entries written to $foundEntriesFilePath"
    Exit 1
} else {
    # No entries exist, exit with code 0
    Write-Output "None of the specified hosts are present in the hosts file."
    Exit 0
}