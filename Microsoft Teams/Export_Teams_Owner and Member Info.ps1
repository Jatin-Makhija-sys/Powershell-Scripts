<#
.SYNOPSIS
Exports Microsoft Teams owners and members to CSV.

.DESCRIPTION
This script exports Microsoft Teams owners and members using Microsoft Graph.

It creates:
1. Teams_Owners_Members_Detail.csv
   One row per Team user.

2. Teams_Owners_Members_Summary.csv
   One row per Team with owners and members in separate columns.

3. Teams_Owners_Members_Errors.csv
   Any Teams where owners or members could not be read.

.NOTES
Required Microsoft Graph permissions:
- Group.Read.All
- GroupMember.Read.All
- User.Read.All
- Directory.Read.All

This script avoids importing Microsoft.Graph.Groups to prevent Graph assembly conflicts.

.NOTES
    Author: Jatin Makhija
    Copyright: Cloudinfra.net
    Version: 1.0
#>

param(
    [string]$OutputFolder = "",
    [switch]$ForceReconnect
)

$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Ensure-GraphAuthenticationModule {
    $RequiredCommands = @(
        "Connect-MgGraph",
        "Disconnect-MgGraph",
        "Get-MgContext",
        "Invoke-MgGraphRequest"
    )

    $MissingCommands = @()

    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            $MissingCommands += $Command
        }
    }

    if ($MissingCommands.Count -eq 0) {
        Write-Host "Microsoft Graph authentication commands are already available."
        return
    }

    if (-not (Get-Module -ListAvailable -Name "Microsoft.Graph.Authentication")) {
        Write-Host "Installing Microsoft.Graph.Authentication module..."
        Install-Module -Name "Microsoft.Graph.Authentication" -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    }

    try {
        Import-Module "Microsoft.Graph.Authentication" -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not import Microsoft.Graph.Authentication cleanly. Checking whether required commands are already available."

        $StillMissingCommands = @()

        foreach ($Command in $RequiredCommands) {
            if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
                $StillMissingCommands += $Command
            }
        }

        if ($StillMissingCommands.Count -gt 0) {
            throw "Microsoft.Graph.Authentication could not be loaded. Close all PowerShell windows, open a new PowerShell session, and run the script again. Missing commands: $($StillMissingCommands -join ', ')"
        }
    }
}

function Get-GraphProperty {
    param(
        [Parameter(Mandatory = $false)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [hashtable]) {
        if ($InputObject.ContainsKey($Name)) {
            return $InputObject[$Name]
        }
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }
    }

    $Property = $InputObject.PSObject.Properties[$Name]

    if ($null -ne $Property) {
        return $Property.Value
    }

    return $null
}

function Invoke-GraphRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [hashtable]$Headers = @{},

        [int]$MaxRetries = 5
    )

    for ($Attempt = 1; $Attempt -le $MaxRetries; $Attempt++) {
        try {
            if ($null -ne $Headers -and $Headers.Count -gt 0) {
                return Invoke-MgGraphRequest -Method GET -Uri $Uri -Headers $Headers -OutputType PSObject
            }
            else {
                return Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
            }
        }
        catch {
            if ($Attempt -eq $MaxRetries) {
                throw
            }

            $WaitSeconds = [Math]::Min(60, [int][Math]::Pow(2, $Attempt))

            if ($_.Exception.Message -match "429|Too Many Requests|throttl") {
                $WaitSeconds = [Math]::Max($WaitSeconds, 20)
            }

            Write-Warning "Graph request failed. Retrying in $WaitSeconds seconds. Attempt $Attempt of $MaxRetries."
            Start-Sleep -Seconds $WaitSeconds
        }
    }
}

function Invoke-GraphGetAllPages {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [hashtable]$Headers = @{}
    )

    $AllResults = New-Object System.Collections.Generic.List[object]
    $NextUri = $Uri

    while (-not [string]::IsNullOrWhiteSpace($NextUri)) {
        $Response = Invoke-GraphRequestWithRetry -Uri $NextUri -Headers $Headers

        $Values = Get-GraphProperty -InputObject $Response -Name "value"

        if ($null -ne $Values) {
            foreach ($Item in $Values) {
                [void]$AllResults.Add($Item)
            }
        }

        $NextUri = Get-GraphProperty -InputObject $Response -Name "@odata.nextLink"
    }

    return $AllResults
}

function Add-OrUpdateUserInDictionary {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Dictionary,

        [Parameter(Mandatory = $true)]
        [object]$User,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Owner", "Member")]
        [string]$Type
    )

    $UserId = Get-GraphProperty -InputObject $User -Name "id"

    if ([string]::IsNullOrWhiteSpace($UserId)) {
        return
    }

    if (-not $Dictionary.ContainsKey($UserId)) {
        $Dictionary[$UserId] = [ordered]@{
            UserId            = $UserId
            DisplayName       = Get-GraphProperty -InputObject $User -Name "displayName"
            UserPrincipalName = Get-GraphProperty -InputObject $User -Name "userPrincipalName"
            Mail              = Get-GraphProperty -InputObject $User -Name "mail"
            UserType          = Get-GraphProperty -InputObject $User -Name "userType"
            AccountEnabled    = Get-GraphProperty -InputObject $User -Name "accountEnabled"
            JobTitle          = Get-GraphProperty -InputObject $User -Name "jobTitle"
            IsOwner           = $false
            IsMember          = $false
        }
    }

    if ($Type -eq "Owner") {
        $Dictionary[$UserId]["IsOwner"] = $true
    }

    if ($Type -eq "Member") {
        $Dictionary[$UserId]["IsMember"] = $true
    }
}

function Export-CsvSafe {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Headers
    )

    $Rows = @()

    if ($null -ne $Data) {
        if ($Data -is [System.Collections.IEnumerable] -and $Data -isnot [string]) {
            foreach ($Item in $Data) {
                if ($null -ne $Item) {
                    $Rows += $Item
                }
            }
        }
        else {
            $Rows = @($Data)
        }
    }

    if ($Rows.Count -gt 0) {
        $Rows |
            Select-Object $Headers |
            Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    else {
        $EmptyObject = [ordered]@{}

        foreach ($Header in $Headers) {
            $EmptyObject[$Header] = $null
        }

        [PSCustomObject]$EmptyObject |
            Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
}

# ------------------------------------------------------------
# Prepare output folder
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
    $BasePath = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        (Get-Location).Path
    }

    $OutputFolder = Join-Path -Path $BasePath -ChildPath ("Teams_Owners_Members_Export_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
}

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

$DetailCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Owners_Members_Detail.csv"
$SummaryCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Owners_Members_Summary.csv"
$ErrorCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Owners_Members_Errors.csv"

# ------------------------------------------------------------
# Prepare Microsoft Graph
# ------------------------------------------------------------

Write-Section "Preparing Microsoft Graph PowerShell module"

Ensure-GraphAuthenticationModule

$RequiredScopes = @(
    "Group.Read.All",
    "GroupMember.Read.All",
    "User.Read.All",
    "Directory.Read.All"
)

if ($ForceReconnect) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

$GraphContext = Get-MgContext
$NeedsConnection = $false

if ($null -eq $GraphContext) {
    $NeedsConnection = $true
}
else {
    foreach ($Scope in $RequiredScopes) {
        if ($Scope -notin $GraphContext.Scopes) {
            $NeedsConnection = $true
            break
        }
    }
}

if ($NeedsConnection) {
    Write-Section "Connecting to Microsoft Graph"
    Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
}
else {
    Write-Host "Already connected to Microsoft Graph as $($GraphContext.Account)."
}

# ------------------------------------------------------------
# Get all Microsoft Teams
# ------------------------------------------------------------

Write-Section "Getting Microsoft Teams"

$Headers = @{
    "ConsistencyLevel" = "eventual"
}

$TeamsUri = "https://graph.microsoft.com/v1.0/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName,description,mail,mailNickname,visibility,createdDateTime&`$top=999"

try {
    $Teams = @(Invoke-GraphGetAllPages -Uri $TeamsUri -Headers $Headers | Sort-Object displayName)
}
catch {
    throw "Failed to get Microsoft Teams. Error: $($_.Exception.Message)"
}

Write-Host "Found $($Teams.Count) Teams."

# ------------------------------------------------------------
# Export owners and members
# ------------------------------------------------------------

$DetailedExport = New-Object System.Collections.Generic.List[object]
$SummaryExport = New-Object System.Collections.Generic.List[object]
$ErrorExport = New-Object System.Collections.Generic.List[object]

$TotalTeams = $Teams.Count
$CurrentTeamNumber = 0

foreach ($Team in $Teams) {
    $CurrentTeamNumber++

    $TeamId = Get-GraphProperty -InputObject $Team -Name "id"
    $TeamName = Get-GraphProperty -InputObject $Team -Name "displayName"
    $TeamMail = Get-GraphProperty -InputObject $Team -Name "mail"
    $TeamMailNickname = Get-GraphProperty -InputObject $Team -Name "mailNickname"
    $TeamVisibility = Get-GraphProperty -InputObject $Team -Name "visibility"
    $TeamCreatedDate = Get-GraphProperty -InputObject $Team -Name "createdDateTime"

    $ProgressPercent = if ($TotalTeams -gt 0) {
        [int](($CurrentTeamNumber / $TotalTeams) * 100)
    }
    else {
        100
    }

    Write-Progress `
        -Activity "Exporting Teams owners and members" `
        -Status "$CurrentTeamNumber of $TotalTeams - $TeamName" `
        -PercentComplete $ProgressPercent

    Write-Host "Processing Team: $TeamName"

    $Owners = @()
    $Members = @()
    $OwnerError = ""
    $MemberError = ""

    try {
        $OwnersUri = "https://graph.microsoft.com/v1.0/groups/$TeamId/owners/microsoft.graph.user?`$select=id,displayName,userPrincipalName,mail,userType,accountEnabled,jobTitle&`$top=999"
        $Owners = @(Invoke-GraphGetAllPages -Uri $OwnersUri)
    }
    catch {
        $OwnerError = $_.Exception.Message
        Write-Warning "Could not read owners for Team '$TeamName'. Error: $OwnerError"
    }

    try {
        $MembersUri = "https://graph.microsoft.com/v1.0/groups/$TeamId/members/microsoft.graph.user?`$select=id,displayName,userPrincipalName,mail,userType,accountEnabled,jobTitle&`$top=999"
        $Members = @(Invoke-GraphGetAllPages -Uri $MembersUri)
    }
    catch {
        $MemberError = $_.Exception.Message
        Write-Warning "Could not read members for Team '$TeamName'. Error: $MemberError"
    }

    if (-not [string]::IsNullOrWhiteSpace($OwnerError) -or -not [string]::IsNullOrWhiteSpace($MemberError)) {
        [void]$ErrorExport.Add([PSCustomObject]@{
            TeamName    = $TeamName
            TeamId      = $TeamId
            OwnerError  = $OwnerError
            MemberError = $MemberError
        })
    }

    $UsersById = @{}

    foreach ($Member in $Members) {
        Add-OrUpdateUserInDictionary -Dictionary $UsersById -User $Member -Type "Member"
    }

    foreach ($Owner in $Owners) {
        Add-OrUpdateUserInDictionary -Dictionary $UsersById -User $Owner -Type "Owner"
    }

    $TeamUsers = @(
        foreach ($UserRecord in $UsersById.Values) {
            $IsOwner = [bool]$UserRecord["IsOwner"]
            $IsMember = [bool]$UserRecord["IsMember"]

            [PSCustomObject]@{
                TeamName          = $TeamName
                TeamId            = $TeamId
                TeamMail          = $TeamMail
                TeamMailNickname  = $TeamMailNickname
                TeamVisibility    = $TeamVisibility
                TeamCreatedDate   = $TeamCreatedDate
                Role              = if ($IsOwner) { "Owner" } elseif ($IsMember) { "Member" } else { "Unknown" }
                IsOwner           = $IsOwner
                IsMember          = $IsMember
                UserDisplayName   = $UserRecord["DisplayName"]
                UserPrincipalName = $UserRecord["UserPrincipalName"]
                UserMail          = $UserRecord["Mail"]
                UserType          = $UserRecord["UserType"]
                AccountEnabled    = $UserRecord["AccountEnabled"]
                JobTitle          = $UserRecord["JobTitle"]
                UserId            = $UserRecord["UserId"]
            }
        }
    ) | Sort-Object Role, UserDisplayName, UserPrincipalName

    foreach ($TeamUser in $TeamUsers) {
        [void]$DetailedExport.Add($TeamUser)
    }

    $OwnerList = @(
        $UsersById.Values |
        Where-Object { [bool]$_["IsOwner"] -eq $true } |
        Sort-Object { $_["DisplayName"] }, { $_["UserPrincipalName"] }
    )

    $MemberList = @(
        $UsersById.Values |
        Where-Object { [bool]$_["IsMember"] -eq $true } |
        Sort-Object { $_["DisplayName"] }, { $_["UserPrincipalName"] }
    )

    $OwnerDisplayNames = @(
        $OwnerList |
        ForEach-Object { $_["DisplayName"] } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $OwnerUPNs = @(
        $OwnerList |
        ForEach-Object { $_["UserPrincipalName"] } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $MemberDisplayNames = @(
        $MemberList |
        ForEach-Object { $_["DisplayName"] } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $MemberUPNs = @(
        $MemberList |
        ForEach-Object { $_["UserPrincipalName"] } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $Status = if ([string]::IsNullOrWhiteSpace($OwnerError) -and [string]::IsNullOrWhiteSpace($MemberError)) {
        "Success"
    }
    else {
        "Partial"
    }

    [void]$SummaryExport.Add([PSCustomObject]@{
        TeamName           = $TeamName
        TeamId             = $TeamId
        TeamMail           = $TeamMail
        TeamMailNickname   = $TeamMailNickname
        TeamVisibility     = $TeamVisibility
        TeamCreatedDate    = $TeamCreatedDate
        OwnerCount         = $OwnerList.Count
        MemberCount        = $MemberList.Count
        OwnerDisplayNames  = $OwnerDisplayNames
        OwnerUPNs          = $OwnerUPNs
        MemberDisplayNames = $MemberDisplayNames
        MemberUPNs         = $MemberUPNs
        ExportStatus       = $Status
        OwnerError         = $OwnerError
        MemberError        = $MemberError
    })
}

Write-Progress -Activity "Exporting Teams owners and members" -Completed

# ------------------------------------------------------------
# Write CSV files
# ------------------------------------------------------------

Write-Section "Writing CSV files"

$DetailHeaders = @(
    "TeamName",
    "TeamId",
    "TeamMail",
    "TeamMailNickname",
    "TeamVisibility",
    "TeamCreatedDate",
    "Role",
    "IsOwner",
    "IsMember",
    "UserDisplayName",
    "UserPrincipalName",
    "UserMail",
    "UserType",
    "AccountEnabled",
    "JobTitle",
    "UserId"
)

$SummaryHeaders = @(
    "TeamName",
    "TeamId",
    "TeamMail",
    "TeamMailNickname",
    "TeamVisibility",
    "TeamCreatedDate",
    "OwnerCount",
    "MemberCount",
    "OwnerDisplayNames",
    "OwnerUPNs",
    "MemberDisplayNames",
    "MemberUPNs",
    "ExportStatus",
    "OwnerError",
    "MemberError"
)

$ErrorHeaders = @(
    "TeamName",
    "TeamId",
    "OwnerError",
    "MemberError"
)

Export-CsvSafe -Data $DetailedExport -Path $DetailCsvPath -Headers $DetailHeaders
Export-CsvSafe -Data $SummaryExport -Path $SummaryCsvPath -Headers $SummaryHeaders
Export-CsvSafe -Data $ErrorExport -Path $ErrorCsvPath -Headers $ErrorHeaders

Write-Host ""
Write-Host "Export completed successfully." -ForegroundColor Green
Write-Host "Detailed CSV: $DetailCsvPath" -ForegroundColor Green
Write-Host "Summary CSV:  $SummaryCsvPath" -ForegroundColor Green
Write-Host "Errors CSV:   $ErrorCsvPath" -ForegroundColor Green