# Script version: 5.0
<#
.SYNOPSIS
Exports Microsoft Teams channel memberships to CSV, including standard,
private, shared, and incoming shared channels.

.DESCRIPTION
Uses Microsoft Graph v1.0 endpoints directly through Invoke-MgGraphRequest:
  GET /teams
  GET /teams/{team-id}/allChannels
  GET /teams/{owning-team-id}/channels/{channel-id}/allMembers
  GET /teams/{owning-team-id}/channels/{channel-id}/sharedWithTeams

Important corrections in this version:
  - Allows empty generic List objects to bind to helper-function parameters.
    This prevents ParameterArgumentValidationErrorEmptyCollectionNotAllowed
    during initial channel discovery.
  - Sends Prefer: include-unknown-enum-members so Graph returns "shared"
    instead of "unknownFutureValue".
  - Uses allChannels to discover channels hosted by a team and channels shared
    with that team.
  - Reads the owning team ID from @odata.id before requesting membership.
  - Correctly distinguishes direct channel membership from indirect membership
    inherited through a team by parsing originalSourceMembershipUrl.
  - Preserves multiple rows for users who have multiple access paths to the
    same shared channel.

Delegated permissions:
  Team.ReadBasic.All
  Channel.ReadBasic.All
  ChannelMember.Read.All
  User.Read.All                 Required unless -SkipUserLookup is used

Application permissions:
  Team.ReadBasic.All
  Channel.ReadBasic.All
  ChannelMember.Read.All
  User.Read.All                 Required unless -SkipUserLookup is used

.NOTES
  Author: Jatin Makhija
  Copyright: Cloudinfra.net
  Version: 1.0

.EXAMPLE
.\Export-AllTeamsChannelMembers-v5.ps1

.EXAMPLE
.\Export-AllTeamsChannelMembers-v5.ps1 `
    -OutputPath "C:\Temp\Teams_Channel_Members.csv"

.EXAMPLE
.\Export-AllTeamsChannelMembers-v5.ps1 `
    -TenantId "00000000-0000-0000-0000-000000000000" `
    -ClientId "11111111-1111-1111-1111-111111111111" `
    -CertificateThumbprint "ABCDEF1234567890ABCDEF1234567890ABCDEF12" `
    -OutputPath "C:\Temp\Teams_Channel_Members.csv"
#>

[CmdletBinding(DefaultParameterSetName = 'Delegated')]
param(
    [Parameter(ParameterSetName = 'Delegated')]
    [Parameter(ParameterSetName = 'AppOnly', Mandatory = $true)]
    [string]$TenantId,

    [Parameter(ParameterSetName = 'AppOnly', Mandatory = $true)]
    [string]$ClientId,

    [Parameter(ParameterSetName = 'AppOnly', Mandatory = $true)]
    [string]$CertificateThumbprint,

    [Parameter()]
    [string]$OutputPath = (Join-Path -Path (Get-Location) -ChildPath (
        "Teams_Channel_Members_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
    )),

    [Parameter()]
    [string]$ErrorLogPath,

    [Parameter()]
    [switch]$SkipUserLookup
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Get-PropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Get-HttpStatusCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -ne $response) {
            $statusCode = $response.StatusCode
            if ($null -ne $statusCode) {
                try {
                    return [int]$statusCode
                }
                catch {
                    if ($null -ne $statusCode.value__) {
                        return [int]$statusCode.value__
                    }
                }
            }
        }
    }
    catch {
        # Fall through to message parsing.
    }

    if ($ErrorRecord.Exception.Message -match '\b(400|401|403|404|408|409|429|500|502|503|504)\b') {
        return [int]$Matches[1]
    }

    return $null
}

function Invoke-GraphGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter()]
        [hashtable]$Headers = @{},

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaximumAttempts = 6
    )

    $attempt = 0

    while ($true) {
        $attempt++

        try {
            $requestParameters = @{
                Method      = 'GET'
                Uri         = $Uri
                ErrorAction = 'Stop'
            }

            if ($null -ne $Headers -and $Headers.Count -gt 0) {
                $requestParameters['Headers'] = $Headers
            }

            return Invoke-MgGraphRequest @requestParameters
        }
        catch {
            $statusCode = Get-HttpStatusCode -ErrorRecord $_
            $isTransient = $statusCode -in @(408, 429, 500, 502, 503, 504)

            if ((-not $isTransient) -or ($attempt -ge $MaximumAttempts)) {
                throw
            }

            $delaySeconds = [int][Math]::Min(60, [Math]::Pow(2, $attempt))
            Write-Warning (
                "Graph request returned HTTP {0}. Retrying in {1} seconds. Attempt {2} of {3}." -f `
                    $statusCode, $delaySeconds, $attempt, $MaximumAttempts
            )
            Start-Sleep -Seconds $delaySeconds
        }
    }
}

function Get-GraphCollection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter()]
        [hashtable]$Headers = @{}
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    while (-not [string]::IsNullOrWhiteSpace($nextLink)) {
        $response = Invoke-GraphGet -Uri $nextLink -Headers $Headers
        $pageItems = Get-PropertyValue -InputObject $response -Name 'value'

        foreach ($item in @($pageItems)) {
            if ($null -ne $item) {
                $items.Add($item)
            }
        }

        $nextLinkValue = Get-PropertyValue -InputObject $response -Name '@odata.nextLink'
        if ($null -eq $nextLinkValue) {
            $nextLink = $null
        }
        else {
            $nextLink = [string]$nextLinkValue
        }
    }

    return $items.ToArray()
}

function Add-ExportError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter()]
        [AllowEmptyString()]
        [string]$TeamName,

        [Parameter()]
        [AllowEmptyString()]
        [string]$TeamId,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ChannelName,

        [Parameter()]
        [AllowEmptyString()]
        [string]$ChannelId,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $statusCode = Get-HttpStatusCode -ErrorRecord $ErrorRecord

    $script:ErrorRows.Add([pscustomobject][ordered]@{
        Timestamp   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Stage       = $Stage
        TeamName    = $TeamName
        TeamId      = $TeamId
        ChannelName = $ChannelName
        ChannelId   = $ChannelId
        StatusCode  = $statusCode
        Error       = $ErrorRecord.Exception.Message
    })
}

function Get-DirectoryUserInfo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$UserId
    )

    $emptyResult = [pscustomobject]@{
        UserPrincipalName = $null
        Mail              = $null
        UserType          = $null
        AccountEnabled    = $null
        LookupStatus      = 'Skipped'
    }

    if ($SkipUserLookup -or [string]::IsNullOrWhiteSpace($UserId)) {
        return $emptyResult
    }

    if ($script:UserCache.ContainsKey($UserId)) {
        return $script:UserCache[$UserId]
    }

    $encodedUserId = [Uri]::EscapeDataString($UserId)
    $userUri = 'https://graph.microsoft.com/v1.0/users/{0}?$select=id,userPrincipalName,mail,userType,accountEnabled' -f $encodedUserId

    try {
        $user = Invoke-GraphGet -Uri $userUri -Headers $script:GraphHeaders
        $result = [pscustomobject]@{
            UserPrincipalName = [string](Get-PropertyValue -InputObject $user -Name 'userPrincipalName')
            Mail              = [string](Get-PropertyValue -InputObject $user -Name 'mail')
            UserType          = [string](Get-PropertyValue -InputObject $user -Name 'userType')
            AccountEnabled    = Get-PropertyValue -InputObject $user -Name 'accountEnabled'
            LookupStatus      = 'Resolved'
        }
    }
    catch {
        $statusCode = Get-HttpStatusCode -ErrorRecord $_
        $lookupStatus = if ($statusCode -eq 404) {
            'NotInHomeTenant'
        }
        elseif ($null -ne $statusCode) {
            "FailedHttp$statusCode"
        }
        else {
            'Failed'
        }

        $result = [pscustomobject]@{
            UserPrincipalName = $null
            Mail              = $null
            UserType          = $null
            AccountEnabled    = $null
            LookupStatus      = $lookupStatus
        }
    }

    $script:UserCache[$UserId] = $result
    return $result
}

function Write-ResultRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Rows
    )

    if (@($Rows).Count -eq 0) {
        return
    }

    $exportParameters = @{
        Path              = $script:OutputPath
        NoTypeInformation = $true
        Encoding          = $script:CsvEncoding
    }

    if ($script:CsvInitialized) {
        $exportParameters['Append'] = $true
    }

    $Rows | Export-Csv @exportParameters
    $script:CsvInitialized = $true
}

function Get-ChannelOwnerInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Channel,

        [Parameter(Mandatory = $true)]
        [string]$ContextTeamId,

        [Parameter(Mandatory = $true)]
        [string]$HomeTenantId
    )

    $odataId = [string](Get-PropertyValue -InputObject $Channel -Name '@odata.id')
    $channelTenantId = [string](Get-PropertyValue -InputObject $Channel -Name 'tenantId')

    $ownerTeamId = $ContextTeamId
    $ownerTenantId = if ([string]::IsNullOrWhiteSpace($channelTenantId)) {
        $HomeTenantId
    }
    else {
        $channelTenantId
    }

    if (-not [string]::IsNullOrWhiteSpace($odataId)) {
        $decodedODataId = [Uri]::UnescapeDataString($odataId)

        if ($decodedODataId -match '/tenants/(?<TenantId>[^/]+)/teams/(?<TeamId>[^/]+)/channels/') {
            $ownerTenantId = [string]$Matches['TenantId']
            $ownerTeamId = [string]$Matches['TeamId']
        }
        elseif ($decodedODataId -match '/teams/(?<TeamId>[^/]+)/channels/') {
            $ownerTeamId = [string]$Matches['TeamId']
        }
    }

    return [pscustomobject]@{
        ODataId       = $odataId
        OwnerTeamId   = $ownerTeamId
        OwnerTenantId = $ownerTenantId
    }
}

function Get-MembershipSourceInfo {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$SourceMembershipUrl,

        [Parameter(Mandatory = $true)]
        [string]$ChannelType,

        [Parameter(Mandatory = $true)]
        [string]$OwnerTeamId,

        [Parameter(Mandatory = $true)]
        [string]$OwnerTenantId,

        [Parameter(Mandatory = $true)]
        [string]$ChannelId
    )

    $result = [ordered]@{
        MembershipPath  = 'Unknown'
        MembershipScope = 'Unknown'
        SourceTenantId  = $null
        SourceTeamId    = $null
        SourceChannelId = $null
    }

    if ([string]::IsNullOrWhiteSpace($SourceMembershipUrl)) {
        switch ($ChannelType.ToLowerInvariant()) {
            'standard' {
                $result.MembershipPath = 'InheritedFromParentTeam'
                $result.MembershipScope = 'Team'
                $result.SourceTenantId = $OwnerTenantId
                $result.SourceTeamId = $OwnerTeamId
            }
            'private' {
                $result.MembershipPath = 'Direct'
                $result.MembershipScope = 'Channel'
                $result.SourceTenantId = $OwnerTenantId
                $result.SourceTeamId = $OwnerTeamId
                $result.SourceChannelId = $ChannelId
            }
            'shared' {
                $result.MembershipPath = 'Direct'
                $result.MembershipScope = 'Channel'
                $result.SourceTenantId = $OwnerTenantId
                $result.SourceTeamId = $OwnerTeamId
                $result.SourceChannelId = $ChannelId
            }
            default {
                $result.MembershipPath = 'DirectOrUnspecified'
                $result.MembershipScope = 'Unknown'
            }
        }

        return [pscustomobject]$result
    }

    $decodedUrl = [Uri]::UnescapeDataString($SourceMembershipUrl)

    if ($decodedUrl -match '/tenants/(?<TenantId>[^/]+)/teams/(?<TeamId>[^/]+)/channels/(?<ChannelId>[^/]+)/members/') {
        $result.MembershipPath = 'Direct'
        $result.MembershipScope = 'Channel'
        $result.SourceTenantId = [string]$Matches['TenantId']
        $result.SourceTeamId = [string]$Matches['TeamId']
        $result.SourceChannelId = [string]$Matches['ChannelId']
    }
    elseif ($decodedUrl -match '/teams/(?<TeamId>[^/]+)/channels/(?<ChannelId>[^/]+)/members/') {
        $result.MembershipPath = 'Direct'
        $result.MembershipScope = 'Channel'
        $result.SourceTenantId = $OwnerTenantId
        $result.SourceTeamId = [string]$Matches['TeamId']
        $result.SourceChannelId = [string]$Matches['ChannelId']
    }
    elseif ($decodedUrl -match '/tenants/(?<TenantId>[^/]+)/teams/(?<TeamId>[^/]+)/members/') {
        $result.MembershipPath = 'IndirectViaTeam'
        $result.MembershipScope = 'Team'
        $result.SourceTenantId = [string]$Matches['TenantId']
        $result.SourceTeamId = [string]$Matches['TeamId']
    }
    elseif ($decodedUrl -match '/teams/(?<TeamId>[^/]+)/members/') {
        $result.MembershipPath = 'IndirectViaTeam'
        $result.MembershipScope = 'Team'
        $result.SourceTenantId = $OwnerTenantId
        $result.SourceTeamId = [string]$Matches['TeamId']
    }

    return [pscustomobject]$result
}

function Add-UniqueString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$List,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if (-not $List.Contains($Value)) {
        $List.Add($Value)
    }
}

# Prepare paths.
$script:OutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Path $script:OutputPath -Parent
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($ErrorLogPath)) {
    $outputBaseName = [IO.Path]::GetFileNameWithoutExtension($script:OutputPath)
    $ErrorLogPath = Join-Path -Path $outputDirectory -ChildPath ($outputBaseName + '_Errors.csv')
}

$script:ErrorLogPath = [IO.Path]::GetFullPath($ErrorLogPath)
$errorDirectory = Split-Path -Path $script:ErrorLogPath -Parent
if (-not (Test-Path -LiteralPath $errorDirectory)) {
    New-Item -Path $errorDirectory -ItemType Directory -Force | Out-Null
}

foreach ($path in @($script:OutputPath, $script:ErrorLogPath)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

$script:CsvEncoding = if ($PSVersionTable.PSVersion.Major -ge 7) {
    'utf8BOM'
}
else {
    'UTF8'
}

$script:CsvInitialized = $false
$script:ErrorRows = [System.Collections.Generic.List[object]]::new()
$script:UserCache = @{}
$script:GraphHeaders = @{
    Prefer = 'include-unknown-enum-members'
}

$resultColumns = @(
    'OwningTeamName',
    'OwningTeamId',
    'OwningTenantId',
    'TeamVisibility',
    'ChannelName',
    'ChannelId',
    'ChannelType',
    'ChannelRelationship',
    'ChannelDescription',
    'ChannelWebUrl',
    'VisibleInTeamNames',
    'VisibleInTeamIds',
    'SharedWithTeamNames',
    'SharedWithTeamIds',
    'MemberDisplayName',
    'MemberRecordId',
    'UserId',
    'UserPrincipalName',
    'Email',
    'DirectoryUserType',
    'AccountEnabled',
    'UserLookupStatus',
    'MemberTenantId',
    'TenantRelationship',
    'ChannelRole',
    'IsChannelOwner',
    'MembershipPath',
    'MembershipScope',
    'SourceTeamName',
    'SourceTeamId',
    'SourceTenantId',
    'SourceChannelId',
    'OriginalSourceMembershipUrl',
    'MemberObjectType'
)

# Install/import Graph authentication module.
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Write-Host 'Microsoft.Graph.Authentication is not installed. Installing it for the current user...'

    try {
        Install-Module -Name Microsoft.Graph.Authentication `
            -Scope CurrentUser `
            -Repository PSGallery `
            -Force `
            -AllowClobber `
            -ErrorAction Stop
    }
    catch {
        throw "Unable to install Microsoft.Graph.Authentication. Install it manually and run the script again. $($_.Exception.Message)"
    }
}

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

$requiredPermissions = @(
    'Team.ReadBasic.All',
    'Channel.ReadBasic.All',
    'ChannelMember.Read.All'
)

if (-not $SkipUserLookup) {
    $requiredPermissions += 'User.Read.All'
}

$connectCommand = Get-Command -Name Connect-MgGraph -ErrorAction Stop
$connectParameters = @{}

if ($connectCommand.Parameters.ContainsKey('ContextScope')) {
    $connectParameters['ContextScope'] = 'Process'
}

if ($connectCommand.Parameters.ContainsKey('NoWelcome')) {
    $connectParameters['NoWelcome'] = $true
}

if ($PSCmdlet.ParameterSetName -eq 'AppOnly') {
    Write-Host 'Connecting to Microsoft Graph using app-only certificate authentication...'
    $connectParameters['TenantId'] = $TenantId
    $connectParameters['ClientId'] = $ClientId
    $connectParameters['CertificateThumbprint'] = $CertificateThumbprint
}
else {
    Write-Host 'Connecting to Microsoft Graph using delegated interactive authentication...'
    $connectParameters['Scopes'] = $requiredPermissions

    if (-not [string]::IsNullOrWhiteSpace($TenantId)) {
        $connectParameters['TenantId'] = $TenantId
    }
}

Connect-MgGraph @connectParameters | Out-Null
$graphContext = Get-MgContext

if ($null -eq $graphContext) {
    throw 'Microsoft Graph authentication did not return a valid context.'
}

$homeTenantId = [string]$graphContext.TenantId
Write-Host ("Connected to tenant: {0}" -f $homeTenantId)

# Retrieve all Teams and build an ID-to-name lookup.
$teamsUri = 'https://graph.microsoft.com/v1.0/teams?$select=id,displayName,description,visibility&$top=100'
Write-Host 'Retrieving Microsoft Teams...'

try {
    $teams = @(Get-GraphCollection -Uri $teamsUri -Headers $script:GraphHeaders)
}
catch {
    Add-ExportError -Stage 'ListTeams' -ErrorRecord $_
    throw "Unable to retrieve Teams. Review Graph permissions and the error details. $($_.Exception.Message)"
}

Write-Host ("Found {0} Teams." -f $teams.Count)

$teamById = @{}
foreach ($team in $teams) {
    $id = [string](Get-PropertyValue -InputObject $team -Name 'id')
    if (-not [string]::IsNullOrWhiteSpace($id)) {
        $teamById[$id] = $team
    }
}

# First pass: discover hosted and incoming channels and de-duplicate by owner.
Write-Host 'Discovering hosted and incoming channels...'
$channelInventory = @{}
$teamIndex = 0

foreach ($team in $teams) {
    $teamIndex++

    $contextTeamId = [string](Get-PropertyValue -InputObject $team -Name 'id')
    $contextTeamName = [string](Get-PropertyValue -InputObject $team -Name 'displayName')

    Write-Progress `
        -Activity 'Discovering Microsoft Teams channels' `
        -Status ("Team {0} of {1}: {2}" -f $teamIndex, $teams.Count, $contextTeamName) `
        -PercentComplete (($teamIndex / [Math]::Max(1, $teams.Count)) * 100)

    if ([string]::IsNullOrWhiteSpace($contextTeamId)) {
        continue
    }

    $encodedContextTeamId = [Uri]::EscapeDataString($contextTeamId)
    $channelsUri = 'https://graph.microsoft.com/v1.0/teams/{0}/allChannels?$select=id,displayName,description,membershipType,webUrl,createdDateTime,tenantId' -f $encodedContextTeamId

    try {
        $channels = @(Get-GraphCollection -Uri $channelsUri -Headers $script:GraphHeaders)
    }
    catch {
        Write-Warning ("Could not retrieve channels for Team '{0}'. {1}" -f $contextTeamName, $_.Exception.Message)
        Add-ExportError `
            -Stage 'ListAllChannels' `
            -TeamName $contextTeamName `
            -TeamId $contextTeamId `
            -ErrorRecord $_
        continue
    }

    foreach ($channel in $channels) {
        $channelId = [string](Get-PropertyValue -InputObject $channel -Name 'id')
        if ([string]::IsNullOrWhiteSpace($channelId)) {
            continue
        }

        $ownerInfo = Get-ChannelOwnerInfo `
            -Channel $channel `
            -ContextTeamId $contextTeamId `
            -HomeTenantId $homeTenantId

        $ownerTeamId = [string]$ownerInfo.OwnerTeamId
        $ownerTenantId = [string]$ownerInfo.OwnerTenantId
        $channelKey = '{0}|{1}|{2}' -f $ownerTenantId.ToLowerInvariant(), $ownerTeamId.ToLowerInvariant(), $channelId.ToLowerInvariant()

        if (-not $channelInventory.ContainsKey($channelKey)) {
            $channelInventory[$channelKey] = [pscustomobject]@{
                Channel                  = $channel
                ChannelId                = $channelId
                ChannelName              = [string](Get-PropertyValue -InputObject $channel -Name 'displayName')
                ChannelDescription       = [string](Get-PropertyValue -InputObject $channel -Name 'description')
                ChannelWebUrl            = [string](Get-PropertyValue -InputObject $channel -Name 'webUrl')
                ChannelType              = [string](Get-PropertyValue -InputObject $channel -Name 'membershipType')
                ODataId                  = [string]$ownerInfo.ODataId
                OwnerTeamId              = $ownerTeamId
                OwnerTenantId            = $ownerTenantId
                VisibleInTeamIds         = [System.Collections.Generic.List[string]]::new()
                VisibleInTeamNames       = [System.Collections.Generic.List[string]]::new()
            }
        }

        $inventoryItem = $channelInventory[$channelKey]
        Add-UniqueString -List $inventoryItem.VisibleInTeamIds -Value $contextTeamId
        Add-UniqueString -List $inventoryItem.VisibleInTeamNames -Value $contextTeamName
    }
}

Write-Progress -Activity 'Discovering Microsoft Teams channels' -Completed
Write-Host ("Found {0} unique hosted or incoming channels." -f $channelInventory.Count)

# Second pass: retrieve shared-team information and all membership paths.
$processedChannels = 0
$privateChannels = 0
$sharedChannels = 0
$incomingSharedChannels = 0
$exportedRows = 0
$channelItems = @($channelInventory.Values | Sort-Object ChannelName)

foreach ($item in $channelItems) {
    $processedChannels++

    $channelId = [string]$item.ChannelId
    $channelName = [string]$item.ChannelName
    $ownerTeamId = [string]$item.OwnerTeamId
    $ownerTenantId = [string]$item.OwnerTenantId
    $channelType = [string]$item.ChannelType

    $ownerTeamName = $null
    $teamVisibility = $null

    if ($teamById.ContainsKey($ownerTeamId)) {
        $ownerTeam = $teamById[$ownerTeamId]
        $ownerTeamName = [string](Get-PropertyValue -InputObject $ownerTeam -Name 'displayName')
        $teamVisibility = [string](Get-PropertyValue -InputObject $ownerTeam -Name 'visibility')
    }

    # Graph should return "shared" because the Prefer header is present. If an
    # older endpoint still returns unknownFutureValue, retrieve the channel
    # directly once more with the same header.
    if ([string]::IsNullOrWhiteSpace($channelType) -or $channelType -eq 'unknownFutureValue') {
        $encodedOwnerTeamIdForType = [Uri]::EscapeDataString($ownerTeamId)
        $encodedChannelIdForType = [Uri]::EscapeDataString($channelId)
        $channelUri = 'https://graph.microsoft.com/v1.0/teams/{0}/channels/{1}?$select=id,displayName,membershipType,tenantId' -f `
            $encodedOwnerTeamIdForType, $encodedChannelIdForType

        try {
            $channelDetails = Invoke-GraphGet -Uri $channelUri -Headers $script:GraphHeaders
            $resolvedType = [string](Get-PropertyValue -InputObject $channelDetails -Name 'membershipType')
            if (-not [string]::IsNullOrWhiteSpace($resolvedType)) {
                $channelType = $resolvedType
            }
        }
        catch {
            Add-ExportError `
                -Stage 'ResolveChannelType' `
                -TeamName $ownerTeamName `
                -TeamId $ownerTeamId `
                -ChannelName $channelName `
                -ChannelId $channelId `
                -ErrorRecord $_
        }
    }

    $encodedOwnerTeamId = [Uri]::EscapeDataString($ownerTeamId)
    $encodedChannelId = [Uri]::EscapeDataString($channelId)

    $sharedTeamByKey = @{}
    $sharedWithTeamNames = [System.Collections.Generic.List[string]]::new()
    $sharedWithTeamIds = [System.Collections.Generic.List[string]]::new()

    if ($channelType -eq 'shared') {
        $sharedChannels++
        $sharedTeamsUri = 'https://graph.microsoft.com/v1.0/teams/{0}/channels/{1}/sharedWithTeams?$select=id,displayName,tenantId,isHostTeam' -f `
            $encodedOwnerTeamId, $encodedChannelId

        try {
            $sharedTeams = @(Get-GraphCollection -Uri $sharedTeamsUri -Headers $script:GraphHeaders)

            foreach ($sharedTeam in $sharedTeams) {
                $sharedTeamId = [string](Get-PropertyValue -InputObject $sharedTeam -Name 'id')
                $sharedTeamName = [string](Get-PropertyValue -InputObject $sharedTeam -Name 'displayName')
                $sharedTeamTenantId = [string](Get-PropertyValue -InputObject $sharedTeam -Name 'tenantId')
                $isHostTeam = [bool](Get-PropertyValue -InputObject $sharedTeam -Name 'isHostTeam')

                if (-not [string]::IsNullOrWhiteSpace($sharedTeamId)) {
                    $sharedTeamTenantKey = if ([string]::IsNullOrWhiteSpace($sharedTeamTenantId)) {
                        $ownerTenantId
                    }
                    else {
                        $sharedTeamTenantId
                    }

                    $sharedKey = '{0}|{1}' -f $sharedTeamTenantKey.ToLowerInvariant(), $sharedTeamId.ToLowerInvariant()
                    $sharedTeamByKey[$sharedKey] = $sharedTeamName
                }

                if ($isHostTeam) {
                    if ([string]::IsNullOrWhiteSpace($ownerTeamName)) {
                        $ownerTeamName = $sharedTeamName
                    }
                }
                else {
                    Add-UniqueString -List $sharedWithTeamIds -Value $sharedTeamId
                    Add-UniqueString -List $sharedWithTeamNames -Value $sharedTeamName
                }
            }
        }
        catch {
            Write-Warning ("Could not retrieve shared-team information for '{0}'. {1}" -f $channelName, $_.Exception.Message)
            Add-ExportError `
                -Stage 'ListSharedWithTeams' `
                -TeamName $ownerTeamName `
                -TeamId $ownerTeamId `
                -ChannelName $channelName `
                -ChannelId $channelId `
                -ErrorRecord $_
        }
    }
    elseif ($channelType -eq 'private') {
        $privateChannels++
    }

    if ([string]::IsNullOrWhiteSpace($ownerTeamName)) {
        $ownerTeamName = if ($ownerTenantId -eq $homeTenantId) {
            "Unresolved Team ($ownerTeamId)"
        }
        else {
            "External Team ($ownerTeamId)"
        }
    }

    $visibleInTeamIdsText = @($item.VisibleInTeamIds) -join ';'
    $visibleInTeamNamesText = @($item.VisibleInTeamNames) -join ';'
    $sharedWithTeamIdsText = @($sharedWithTeamIds) -join ';'
    $sharedWithTeamNamesText = @($sharedWithTeamNames) -join ';'

    $channelRelationship = if (($ownerTenantId -ne $homeTenantId) -or (-not $item.VisibleInTeamIds.Contains($ownerTeamId))) {
        $incomingSharedChannels++
        'IncomingShared'
    }
    else {
        'Hosted'
    }

    Write-Progress `
        -Activity 'Exporting Microsoft Teams channel members' `
        -Status ("Channel {0} of {1}: {2}" -f $processedChannels, $channelItems.Count, $channelName) `
        -PercentComplete (($processedChannels / [Math]::Max(1, $channelItems.Count)) * 100)

    Write-Host ("Processing: {0} > {1} [{2}, {3}]" -f $ownerTeamName, $channelName, $channelType, $channelRelationship)

    $membersUri = 'https://graph.microsoft.com/v1.0/teams/{0}/channels/{1}/allMembers' -f `
        $encodedOwnerTeamId, $encodedChannelId

    try {
        $members = @(Get-GraphCollection -Uri $membersUri -Headers $script:GraphHeaders)
    }
    catch {
        Write-Warning (
            "Could not retrieve members for Team '{0}', Channel '{1}'. {2}" -f `
                $ownerTeamName, $channelName, $_.Exception.Message
        )
        Add-ExportError `
            -Stage 'ListAllChannelMembers' `
            -TeamName $ownerTeamName `
            -TeamId $ownerTeamId `
            -ChannelName $channelName `
            -ChannelId $channelId `
            -ErrorRecord $_
        continue
    }

    $channelRows = [System.Collections.Generic.List[object]]::new()

    foreach ($member in $members) {
        $memberRecordId = [string](Get-PropertyValue -InputObject $member -Name 'id')
        $memberDisplayName = [string](Get-PropertyValue -InputObject $member -Name 'displayName')
        $userId = [string](Get-PropertyValue -InputObject $member -Name 'userId')
        $memberEmail = [string](Get-PropertyValue -InputObject $member -Name 'email')
        $memberTenantId = [string](Get-PropertyValue -InputObject $member -Name 'tenantId')
        $memberObjectType = [string](Get-PropertyValue -InputObject $member -Name '@odata.type')
        $sourceMembershipUrl = [string](
            Get-PropertyValue -InputObject $member -Name '@microsoft.graph.originalSourceMembershipUrl'
        )

        $memberRoles = @(
            @(Get-PropertyValue -InputObject $member -Name 'roles') |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_)
                } |
                ForEach-Object {
                    [string]$_
                }
        )

        $channelRole = if (@($memberRoles).Count -gt 0) {
            $memberRoles -join ';'
        }
        else {
            'Member'
        }

        $isChannelOwner = @($memberRoles | Where-Object { $_ -ieq 'owner' }).Count -gt 0

        $sourceInfo = Get-MembershipSourceInfo `
            -SourceMembershipUrl $sourceMembershipUrl `
            -ChannelType $channelType `
            -OwnerTeamId $ownerTeamId `
            -OwnerTenantId $ownerTenantId `
            -ChannelId $channelId

        $sourceTeamId = [string]$sourceInfo.SourceTeamId
        $sourceTenantId = [string]$sourceInfo.SourceTenantId
        $sourceTeamName = $null

        if (-not [string]::IsNullOrWhiteSpace($sourceTeamId)) {
            if ($teamById.ContainsKey($sourceTeamId)) {
                $sourceTeamName = [string](Get-PropertyValue -InputObject $teamById[$sourceTeamId] -Name 'displayName')
            }
            else {
                $sourceTenantKey = if ([string]::IsNullOrWhiteSpace($sourceTenantId)) {
                    $ownerTenantId
                }
                else {
                    $sourceTenantId
                }

                $sourceKey = '{0}|{1}' -f $sourceTenantKey.ToLowerInvariant(), $sourceTeamId.ToLowerInvariant()
                if ($sharedTeamByKey.ContainsKey($sourceKey)) {
                    $sourceTeamName = [string]$sharedTeamByKey[$sourceKey]
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($sourceTeamName) -and $sourceTeamId -eq $ownerTeamId) {
            $sourceTeamName = $ownerTeamName
        }

        $directoryUser = Get-DirectoryUserInfo -UserId $userId

        $userPrincipalName = [string]$directoryUser.UserPrincipalName
        if ([string]::IsNullOrWhiteSpace($userPrincipalName)) {
            $userPrincipalName = $memberEmail
        }

        $email = $memberEmail
        if ([string]::IsNullOrWhiteSpace($email)) {
            $email = [string]$directoryUser.Mail
        }
        if ([string]::IsNullOrWhiteSpace($email)) {
            $email = $userPrincipalName
        }

        $tenantRelationship = if ([string]::IsNullOrWhiteSpace($memberTenantId)) {
            'Unknown'
        }
        elseif ($memberTenantId -eq $homeTenantId) {
            'HomeTenant'
        }
        else {
            'ExternalTenant'
        }

        $channelRows.Add([pscustomobject][ordered]@{
            OwningTeamName                  = $ownerTeamName
            OwningTeamId                    = $ownerTeamId
            OwningTenantId                  = $ownerTenantId
            TeamVisibility                  = $teamVisibility
            ChannelName                     = $channelName
            ChannelId                       = $channelId
            ChannelType                     = $channelType
            ChannelRelationship             = $channelRelationship
            ChannelDescription              = [string]$item.ChannelDescription
            ChannelWebUrl                   = [string]$item.ChannelWebUrl
            VisibleInTeamNames              = $visibleInTeamNamesText
            VisibleInTeamIds                = $visibleInTeamIdsText
            SharedWithTeamNames             = $sharedWithTeamNamesText
            SharedWithTeamIds               = $sharedWithTeamIdsText
            MemberDisplayName               = $memberDisplayName
            MemberRecordId                  = $memberRecordId
            UserId                          = $userId
            UserPrincipalName               = $userPrincipalName
            Email                           = $email
            DirectoryUserType               = [string]$directoryUser.UserType
            AccountEnabled                  = $directoryUser.AccountEnabled
            UserLookupStatus                = [string]$directoryUser.LookupStatus
            MemberTenantId                  = $memberTenantId
            TenantRelationship              = $tenantRelationship
            ChannelRole                     = $channelRole
            IsChannelOwner                  = $isChannelOwner
            MembershipPath                  = [string]$sourceInfo.MembershipPath
            MembershipScope                 = [string]$sourceInfo.MembershipScope
            SourceTeamName                  = $sourceTeamName
            SourceTeamId                    = $sourceTeamId
            SourceTenantId                  = $sourceTenantId
            SourceChannelId                 = [string]$sourceInfo.SourceChannelId
            OriginalSourceMembershipUrl     = $sourceMembershipUrl
            MemberObjectType                = $memberObjectType
        })
    }

    if ($channelRows.Count -gt 0) {
        Write-ResultRows -Rows $channelRows.ToArray()
        $exportedRows += $channelRows.Count
    }
}

Write-Progress -Activity 'Exporting Microsoft Teams channel members' -Completed

if (-not $script:CsvInitialized) {
    $headerLine = ($resultColumns | ForEach-Object {
        '"' + ($_ -replace '"', '""') + '"'
    }) -join ','

    Set-Content -LiteralPath $script:OutputPath -Value $headerLine -Encoding $script:CsvEncoding
}

if ($script:ErrorRows.Count -gt 0) {
    $script:ErrorRows.ToArray() | Export-Csv `
        -LiteralPath $script:ErrorLogPath `
        -NoTypeInformation `
        -Encoding $script:CsvEncoding
}

Write-Host ''
Write-Host 'Export completed.'
Write-Host ("Teams discovered             : {0}" -f $teams.Count)
Write-Host ("Unique channels processed    : {0}" -f $processedChannels)
Write-Host ("Private channels             : {0}" -f $privateChannels)
Write-Host ("Shared channels              : {0}" -f $sharedChannels)
Write-Host ("Incoming shared channels     : {0}" -f $incomingSharedChannels)
Write-Host ("Membership path rows         : {0}" -f $exportedRows)
Write-Host ("CSV file                     : {0}" -f $script:OutputPath)

if ($script:ErrorRows.Count -gt 0) {
    Write-Warning ("{0} errors were recorded in: {1}" -f $script:ErrorRows.Count, $script:ErrorLogPath)
}
else {
    Write-Host 'Errors                       : 0'
}
