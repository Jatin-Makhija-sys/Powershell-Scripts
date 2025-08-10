<#
.SYNOPSIS
    Retrieves Universal Print printer share assignment details, 
    including the users and groups each printer is assigned to.

.DESCRIPTION
    This script connects to the Universal Print service in Azure 
    using the UniversalPrintManagement PowerShell module, 
    retrieves all printer shares, and lists:
        - Share name and ID
        - Printer ID
        - Whether the share is available to all users in the organization
        - Specific users and groups with access
        - Counts of assigned users and groups

    The output is displayed in a table format for easy reading, 
    and can be exported to CSV for reporting or auditing.

.REQUIREMENTS
    - UniversalPrintManagement PowerShell module installed
    - Appropriate permissions in Azure to read Universal Print resources
    - Network connectivity to Microsoft 365 Universal Print service

.NOTES
    Author: Jatin Makhija
    Date:   10-08-2025
    Website: TechPress.net
    Tested on: PowerShell 5.1 and PowerShell 7+
    Module Version: UniversalPrintManagement 2.0+

.EXAMPLE
    PS> .\Get-UPPrinterAssignments.ps1
    Connects to Universal Print and lists all printer assignment details.

.EXAMPLE
    PS> .\Get-UPPrinterAssignments.ps1 | Export-Csv -Path .\UPAssignments.csv -NoTypeInformation
    Exports printer assignment details to a CSV file.
#>

# ------------------------------
# 1) Load the Universal Print module
# ------------------------------
Import-Module UniversalPrintManagement -ErrorAction Stop

# ------------------------------
# 2) Connect to Universal Print
# ------------------------------
# Prompts for authentication. Requires an account with Global or Print admin permissions.
Connect-UPService

# ------------------------------
# 3) Retrieve all printer shares
# ------------------------------
# Get-UPPrinterShare returns paged results; .Results contains the actual array of shares.
$shares = (Get-UPPrinterShare).Results

# ------------------------------
# 4) Helper function: Safely get a property from an object
# ------------------------------
# Some module versions may not expose all properties consistently, so this prevents errors.
function Get-Prop {
    param($obj, [string]$name)
    if ($null -ne $obj -and $obj.PSObject.Properties.Match($name).Count -gt 0) { 
        $obj.$name 
    } else { 
        $null 
    }
}

# ------------------------------
# 5) Helper function: Get a readable label for a member
# ------------------------------
# Tries multiple properties to find the most human-friendly value (DisplayName, UPN, etc.).
function Get-MemberLabel {
    param($m)
    foreach ($p in 'DisplayName','UserPrincipalName','Mail','Name','Id') {
        $v = Get-Prop $m $p
        if ($v) { return $v }
    }
    return ''
}

# ------------------------------
# 6) Build a report of printer assignments
# ------------------------------
$report = foreach ($share in $shares) {
    # Get all allowed members (users/groups) for this printer share
    $members = (Get-UPAllowedMember -ShareId $share.Id).Results

    # Separate users and groups — property names can differ between versions
    $users  = $members | Where-Object {
        ($_.MemberType -match 'user') -or ($_.ObjectType -match 'user') -or ($_.Type -match 'user')
    }
    $groups = $members | Where-Object {
        ($_.MemberType -match 'group') -or ($_.ObjectType -match 'group') -or ($_.Type -match 'group')
    }

    # Check if "Allow access to everyone in my organization" is enabled
    $allUsersAccess = $false
    foreach ($candidate in 'AllUsersAccess','AllowAllUsers','AllowAccessToAllUsers','EveryoneAccess') {
        $val = Get-Prop $share $candidate
        if ($null -ne $val) { 
            $allUsersAccess = [bool]$val
            break 
        }
    }

    # Create a custom object for each share
    [PSCustomObject]@{
        ShareName      = $share.DisplayName
        ShareId        = $share.Id
        AllUsersAccess = $allUsersAccess
        AllowedUsers   = ($users  | ForEach-Object { Get-MemberLabel $_ } | Sort-Object -Unique) -join '; '
        AllowedGroups  = ($groups | ForEach-Object { Get-MemberLabel $_ } | Sort-Object -Unique) -join '; '
        UserCount   = ($users  | Measure-Object).Count
        GroupCount  = ($groups | Measure-Object).Count
    }
}

# ------------------------------
# 7) Display the results
# ------------------------------
# Outputs a sorted table. Uncomment Export-Csv line to save to file.
$report | Sort-Object ShareName | Format-Table -AutoSize

# Optional: Export to CSV for reporting
# $report | Export-Csv -NoTypeInformation -Encoding UTF8 -Path C:\temp\UP-PrinterAssignments.csv