<#
.SYNOPSIS
Exports Entra ID (Azure AD) Privileged Identity Management (PIM) directory role
eligibility and assignment schedules to CSV.

.DESCRIPTION
Connects to Microsoft Graph (PowerShell SDK v2+), builds a role map (RoleDefinitionId -> RoleName),
retrieves PIM directory role eligibility and assignment schedules, and resolves each PrincipalId
to a User, Group, or Service Principal (with display name and UPN/Mail/AppId). Outputs two CSV files:

- C:\Temp\PIM_Eligible.csv
- C:\Temp\PIM_Assigned.csv

Notes:
- Uses the v2 SDK, which does not require Select-MgProfile (v1.0 is default).
- Exports *schedules* (who is eligible / assigned). For realized activations/time windows,
  consider the *ScheduleInstance* cmdlets instead.

.REQUIREMENTS
- PowerShell 5.1+ or PowerShell 7.x
- Microsoft Graph PowerShell SDK v2+  (Install-Module Microsoft.Graph -Scope CurrentUser)
- First-run admin consent for scopes
- Network access to login.microsoftonline.com / graph.microsoft.com

.PERMISSIONS
The script connects with:
- RoleManagement.Read.Directory   (read directory role management data)
- Directory.Read.All              (resolve users & groups)
- Application.Read.All            (resolve service principals; optional if not needed)

.OUTPUTS
CSV files with columns:
- RoleName, RoleDefinitionId
- PrincipalType (User | Group | ServicePrincipal | Unknown)
- PrincipalName, PrincipalUPN_Mail
- DirectoryScopeId, MemberType, Status
- StartDateTime, EndDateTime

.EXAMPLE
# Run interactively; will prompt for sign-in
Connect-MgGraph -Scopes "RoleManagement.Read.Directory","Directory.Read.All","Application.Read.All" -NoWelcome
# …then execute the script to produce:
#   C:\Temp\PIM_Eligible.csv
#   C:\Temp\PIM_Assigned.csv

.EXAMPLE
# If you only need GUIDs (faster; no principal resolution), drop extra scopes:
Connect-MgGraph -Scopes "RoleManagement.Read.Directory" -NoWelcome
# …and remove the principal-resolution section from the script.

.TROUBLESHOOTING
- "Select-MgProfile not recognized": Expected on SDK v2; the cmdlet was removed (no action needed).
- Empty or partial CSV: Ensure you used the -All switch on Graph list cmdlets and that your account
  has access to view PIM data.
- 403/Authorization errors: Confirm the scopes above were granted and admin-consented.
- Slow in large tenants: Principal lookups are per-unique ID. Consider batching with:
  Get-MgDirectoryObject -DirectoryObjectId @($ids) to reduce round-trips.

.LIMITATIONS
- Exports *schedules* (eligibility/assignment definitions). Use the corresponding
  *…ScheduleInstance* cmdlets for actual activation occurrences over time.
- Does not expand nested group membership; results reflect the principal recorded on the schedule.

.NOTES
Author   : Jatin Makhija
Version  : 1.0
LastEdit : 2025-08-13
License  : techpress.net

.LINK
Microsoft Graph PowerShell SDK               : https://learn.microsoft.com/graph/powershell/
Role management (directory) API overview     : https://learn.microsoft.com/graph/api/resources/rolemanagement-directory
PIM for directory roles (concepts)           : https://learn.microsoft.com/azure/active-directory/privileged-identity-management/pim-configure
#>


# Connect (v2 SDK – no Select-MgProfile needed)
Connect-MgGraph -Scopes "RoleManagement.Read.Directory","Directory.Read.All","Application.Read.All" -NoWelcome

# Role map (id -> display name)
$role = @{}
(Get-MgRoleManagementDirectoryRoleDefinition -All) | ForEach-Object { $role[$_.Id] = $_.DisplayName }

# Pull schedules
$elig = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All
$asgn = Get-MgRoleManagementDirectoryRoleAssignmentSchedule -All

# Build a principal resolver cache (User/Group/ServicePrincipal)
$principalMap = @{}
$principalIds = @($elig.PrincipalId + $asgn.PrincipalId) | Sort-Object -Unique
foreach ($id in $principalIds) {
    if (-not $id) { continue }
    $u = Get-MgUser -UserId $id -ErrorAction SilentlyContinue
    if ($u) { $principalMap[$id] = [pscustomobject]@{ Type='User';              Name=$u.DisplayName;           UPNorMail=$u.UserPrincipalName }; continue }

    $g = Get-MgGroup -GroupId $id -ErrorAction SilentlyContinue
    if ($g) { $principalMap[$id] = [pscustomobject]@{ Type='Group';             Name=$g.DisplayName;           UPNorMail=$g.Mail }; continue }

    $sp = Get-MgServicePrincipal -ServicePrincipalId $id -ErrorAction SilentlyContinue
    if ($sp){ $principalMap[$id] = [pscustomobject]@{ Type='ServicePrincipal';   Name=$sp.DisplayName;          UPNorMail=$sp.AppId }; continue }

    $principalMap[$id] = [pscustomobject]@{ Type='Unknown'; Name=$id; UPNorMail=$null }
}

# Export Eligible
$elig | Select-Object `
    @{n='RoleName';e={$role[$_.RoleDefinitionId]}},
    RoleDefinitionId,
    @{n='PrincipalType';e={$principalMap[$_.PrincipalId].Type}},
    @{n='PrincipalName';e={$principalMap[$_.PrincipalId].Name}},
    @{n='PrincipalUPN_Mail';e={$principalMap[$_.PrincipalId].UPNorMail}},
    DirectoryScopeId, MemberType, Status, StartDateTime, EndDateTime |
  Export-Csv "C:\Temp\PIM_Eligible.csv" -NoTypeInformation

# Export Assigned
$asgn | Select-Object `
    @{n='RoleName';e={$role[$_.RoleDefinitionId]}},
    RoleDefinitionId,
    @{n='PrincipalType';e={$principalMap[$_.PrincipalId].Type}},
    @{n='PrincipalName';e={$principalMap[$_.PrincipalId].Name}},
    @{n='PrincipalUPN_Mail';e={$principalMap[$_.PrincipalId].UPNorMail}},
    DirectoryScopeId, MemberType, Status, StartDateTime, EndDateTime |
  Export-Csv "C:\Temp\PIM_Assigned.csv" -NoTypeInformation