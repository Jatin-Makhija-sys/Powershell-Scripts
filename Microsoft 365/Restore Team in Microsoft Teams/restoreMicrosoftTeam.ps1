<#
.SYNOPSIS
Restores all soft-deleted Microsoft Entra groups using Microsoft Graph PowerShell.

.DESCRIPTION
- Connects to Microsoft Graph
- Retrieves all soft-deleted groups that are still restorable
- Optionally previews only
- Restores each group
- Exports a CSV log with the outcome

.NOTES
Requires:
- Microsoft.Graph module
- Delegated permission: Group.ReadWrite.All
- A supported Microsoft Entra admin role, or ownership of the group(s)
    Author: Jatin Makhija
    Copyright: techpress.net
    Version: 1.0

Examples:
.\Restore-AllDeletedGroups.ps1 -PreviewOnly
.\Restore-AllDeletedGroups.ps1
.\Restore-AllDeletedGroups.ps1 -OnlyUnifiedGroups
.\Restore-AllDeletedGroups.ps1 -OnlySecurityGroups
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$PreviewOnly,
    [switch]$OnlyUnifiedGroups,
    [switch]$OnlySecurityGroups,
    [string]$LogPath = ".\Restore-DeletedGroups-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
)

$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO ] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN ] $Message" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK  ] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAIL ] $Message" -ForegroundColor Red
}

try {
    # Ensure required commands exist
    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw "Microsoft Graph PowerShell is not installed. Install it first using: Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    # Connect to Graph
    Write-Info "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Group.ReadWrite.All" -NoWelcome

    # Optional: show current context
    $ctx = Get-MgContext
    Write-Info "Connected to tenant: $($ctx.TenantId)"
    Write-Info "Connected account: $($ctx.Account)"

    # Get all soft-deleted groups
    Write-Info "Retrieving soft-deleted groups..."
    $deletedGroups = Get-MgDirectoryDeletedItemAsGroup -All -Property "id,displayName,deletedDateTime,groupTypes,mailEnabled,securityEnabled"

    if (-not $deletedGroups) {
        Write-Warn "No soft-deleted groups were found."
        return
    }

    # Normalize and classify group types
    $groups = foreach ($g in $deletedGroups) {
        $isUnified = $false
        if ($null -ne $g.GroupTypes -and $g.GroupTypes -contains "Unified") {
            $isUnified = $true
        }

        [PSCustomObject]@{
            Id              = $g.Id
            DisplayName     = $g.DisplayName
            DeletedDateTime = $g.DeletedDateTime
            MailEnabled     = $g.MailEnabled
            SecurityEnabled = $g.SecurityEnabled
            GroupTypes      = if ($g.GroupTypes) { ($g.GroupTypes -join ';') } else { '' }
            GroupClass      = if ($isUnified) { "Microsoft365" } elseif ($g.SecurityEnabled) { "Security" } else { "Other" }
        }
    }

    # Apply optional filters
    if ($OnlyUnifiedGroups -and $OnlySecurityGroups) {
        throw "Use either -OnlyUnifiedGroups or -OnlySecurityGroups, not both."
    }

    if ($OnlyUnifiedGroups) {
        $groups = $groups | Where-Object { $_.GroupClass -eq 'Microsoft365' }
        Write-Info "Filtering to Microsoft 365 groups only."
    }

    if ($OnlySecurityGroups) {
        $groups = $groups | Where-Object { $_.GroupClass -eq 'Security' }
        Write-Info "Filtering to security groups only."
    }

    if (-not $groups) {
        Write-Warn "No matching deleted groups found after applying filters."
        return
    }

    Write-Info "Found $($groups.Count) deleted group(s)."
    $groups |
        Sort-Object DeletedDateTime |
        Format-Table DisplayName, Id, GroupClass, DeletedDateTime -AutoSize

    $results = New-Object System.Collections.Generic.List[object]

    foreach ($group in $groups) {
        $result = [PSCustomObject]@{
            Timestamp       = Get-Date
            DisplayName     = $group.DisplayName
            Id              = $group.Id
            GroupClass      = $group.GroupClass
            DeletedDateTime = $group.DeletedDateTime
            Status          = $null
            Details         = $null
        }

        try {
            if ($PreviewOnly) {
                $result.Status  = "Preview"
                $result.Details = "Preview only. No restore performed."
                Write-Warn "Preview: would restore '$($group.DisplayName)' [$($group.Id)]"
            }
            else {
                if ($PSCmdlet.ShouldProcess("$($group.DisplayName) [$($group.Id)]", "Restore deleted group")) {
                    Write-Info "Restoring '$($group.DisplayName)' [$($group.Id)]..."
                    Restore-MgDirectoryDeletedItem -DirectoryObjectId $group.Id | Out-Null

                    # Basic verification attempt
                    Start-Sleep -Seconds 2
                    try {
                        $null = Get-MgGroup -GroupId $group.Id -ErrorAction Stop
                        $result.Status  = "Restored"
                        $result.Details = "Restore submitted and group lookup succeeded."
                        Write-Ok "Restored '$($group.DisplayName)'"
                    }
                    catch {
                        $result.Status  = "RestoreSubmitted"
                        $result.Details = "Restore submitted. Verification not yet available."
                        Write-Warn "Restore submitted for '$($group.DisplayName)'; verification may take time."
                    }
                }
            }
        }
        catch {
            $result.Status  = "Failed"
            $result.Details = $_.Exception.Message
            Write-Fail "Failed to restore '$($group.DisplayName)': $($_.Exception.Message)"
        }

        $results.Add($result)
    }

    # Export results
    $results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8
    Write-Ok "Log exported to: $LogPath"

    # Summary
    $summary = $results | Group-Object Status | Sort-Object Name
    Write-Host ""
    Write-Host "Summary" -ForegroundColor White
    Write-Host "-------" -ForegroundColor White
    foreach ($item in $summary) {
        Write-Host ("{0,-18} {1,5}" -f $item.Name, $item.Count)
    }
}
catch {
    Write-Fail $_.Exception.Message
    throw
}
finally {
    try {
        Disconnect-MgGraph | Out-Null
    }
    catch {
        # Ignore disconnect failures
    }
}