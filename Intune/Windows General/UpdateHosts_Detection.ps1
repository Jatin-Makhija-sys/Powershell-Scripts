<#
.SYNOPSIS
    This script checks if specified IP address and hostname pairs exist in the Windows hosts file.
    
.DESCRIPTION
    The script reads a list of IP address and hostname pairs and checks if they exist in the Windows hosts file.
    If any entries are missing, the script logs them in a specified file and exits with a status code 1.
    If all entries are found, it exits with a status code 0.

.PARAMETER $HostEntries
    A list of IP address and hostname pairs to check against the hosts file.
    
.PARAMETER $MissingEntriesFilePath
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
$HostEntries = @(
    @{ IPAddress = "192.168.1.23"; Hostname = "cloudinfra.net" },
    @{ IPAddress = "159.233.111.000"; Hostname = "techpress.net" },
    @{ IPAddress = "1.2.3.4"; Hostname = "testsite.com" }
)

# Path to store the missing entries log
$MissingEntriesFilePath = "C:\Windows\Web\MissingEntries.txt"

# Check if the missing entries file exists, and remove it if found
if (Test-Path $MissingEntriesFilePath) {
    Remove-Item -Path $MissingEntriesFilePath -Force
    Write-Output "Deleted existing missing entries file: $MissingEntriesFilePath"
}

# Read the hosts file, excluding comment lines
$HostsFileContent = Get-Content -Path C:\Windows\System32\drivers\etc\hosts | Where-Object {$_ -notmatch "^#"}

# Initialize an array to store missing entries
$MissingEntries = @()

# Check each host entry in the list
foreach ($HostEntry in $HostEntries) {
    $EntryString = "$($HostEntry.IPAddress) $($HostEntry.Hostname)"
    Write-Output "Checking if hosts file contains record: $EntryString"

    if ($HostsFileContent -notcontains $EntryString) {
        Write-Output "Host $EntryString doesn't exist."
        $MissingEntries += $EntryString
    } else {
        Write-Output "Host $EntryString already exists in the hosts file."
    }
}

# Output missing entries to the specified file, if any, and exit with code 1
if ($MissingEntries.Count -gt 0) {
    $MissingEntries | Out-File -FilePath $MissingEntriesFilePath
    Write-Output "Missing entries written to $MissingEntriesFilePath"
    Exit 1
} else {
    # All entries exist, exit with code 0
    Write-Output "All specified hosts are present in the hosts file."
    Exit 0
}