<#
.SYNOPSIS
Exports public/standard and private channels for each Microsoft Team to CSV.

.DESCRIPTION
This script exports Microsoft Teams channel inventory using Microsoft Graph.

It creates:
1. Teams_Channels_Detail.csv
   One row per channel.

2. Teams_Channels_Summary.csv
   One row per Team with public/private channel counts and channel names.

3. Teams_Channels_Errors.csv
   Any Teams where channels could not be read.

By default, the script exports:
- Standard channels, shown as Public/Standard
- Private channels

Shared channels are excluded by default. Use -IncludeSharedChannels to include shared channels.

.NOTES
Required Microsoft Graph permissions:
- Group.Read.All
- Channel.ReadBasic.All

.NOTES
    Author: Jatin Makhija
    Copyright: Cloudinfra.net
    Version: 1.0

Important:
This script does not use $top on the /teams/{team-id}/channels endpoint because that endpoint supports $select and $filter, not $top.
#>

param(
    [string]$OutputFolder = "",
    [switch]$ForceReconnect,
    [switch]$IncludeSharedChannels
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
            $ErrorMessage = $_.Exception.Message

            if ($ErrorMessage -match "BadRequest|400") {
                throw
            }

            if ($Attempt -eq $MaxRetries) {
                throw
            }

            $WaitSeconds = [Math]::Min(60, [int][Math]::Pow(2, $Attempt))

            if ($ErrorMessage -match "429|Too Many Requests|throttl") {
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

function Convert-ChannelMembershipType {
    param(
        [string]$MembershipType
    )

    switch ($MembershipType) {
        "standard" { return "Public/Standard" }
        "private"  { return "Private" }
        "shared"   { return "Shared" }
        default    { return $MembershipType }
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

    $OutputFolder = Join-Path -Path $BasePath -ChildPath ("Teams_Channels_Export_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
}

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

$DetailCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Channels_Detail.csv"
$SummaryCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Channels_Summary.csv"
$ErrorCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Channels_Errors.csv"

# ------------------------------------------------------------
# Prepare Microsoft Graph
# ------------------------------------------------------------

Write-Section "Preparing Microsoft Graph PowerShell module"

Ensure-GraphAuthenticationModule

$RequiredScopes = @(
    "Group.Read.All",
    "Channel.ReadBasic.All"
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

$TeamsUri = "https://graph.microsoft.com/v1.0/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName,mail,mailNickname,visibility,createdDateTime&`$top=999"

try {
    $Teams = @(Invoke-GraphGetAllPages -Uri $TeamsUri -Headers $Headers | Sort-Object displayName)
}
catch {
    throw "Failed to get Microsoft Teams. Error: $($_.Exception.Message)"
}

Write-Host "Found $($Teams.Count) Teams."

# ------------------------------------------------------------
# Export channels
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
        -Activity "Exporting Teams channels" `
        -Status "$CurrentTeamNumber of $TotalTeams - $TeamName" `
        -PercentComplete $ProgressPercent

    Write-Host "Processing Team: $TeamName"

    $Channels = @()
    $ChannelError = ""

    try {
        # Do not add $top here. The Teams channels endpoint supports $select and $filter, but $top can return BadRequest.
        $ChannelsUri = "https://graph.microsoft.com/v1.0/teams/$TeamId/channels?`$select=id,displayName,description,membershipType,createdDateTime,webUrl,isArchived"
        $Channels = @(Invoke-GraphGetAllPages -Uri $ChannelsUri)
    }
    catch {
        $ChannelError = $_.Exception.Message
        Write-Warning "Could not read channels for Team '$TeamName'. Error: $ChannelError"

        [void]$ErrorExport.Add([PSCustomObject]@{
            TeamName     = $TeamName
            TeamId       = $TeamId
            ChannelError = $ChannelError
        })
    }

    $FilteredChannels = @(
        foreach ($Channel in $Channels) {
            $MembershipType = Get-GraphProperty -InputObject $Channel -Name "membershipType"

            if ($IncludeSharedChannels) {
                $Channel
            }
            else {
                if ($MembershipType -in @("standard", "private")) {
                    $Channel
                }
            }
        }
    ) | Sort-Object membershipType, displayName

    foreach ($Channel in $FilteredChannels) {
        $ChannelId = Get-GraphProperty -InputObject $Channel -Name "id"
        $ChannelName = Get-GraphProperty -InputObject $Channel -Name "displayName"
        $ChannelDescription = Get-GraphProperty -InputObject $Channel -Name "description"
        $ChannelMembershipType = Get-GraphProperty -InputObject $Channel -Name "membershipType"
        $ChannelCreatedDate = Get-GraphProperty -InputObject $Channel -Name "createdDateTime"
        $ChannelWebUrl = Get-GraphProperty -InputObject $Channel -Name "webUrl"
        $ChannelIsArchived = Get-GraphProperty -InputObject $Channel -Name "isArchived"

        [void]$DetailedExport.Add([PSCustomObject]@{
            TeamName              = $TeamName
            TeamId                = $TeamId
            TeamMail              = $TeamMail
            TeamMailNickname      = $TeamMailNickname
            TeamVisibility        = $TeamVisibility
            TeamCreatedDate       = $TeamCreatedDate
            ChannelName           = $ChannelName
            ChannelId             = $ChannelId
            ChannelType           = Convert-ChannelMembershipType -MembershipType $ChannelMembershipType
            ChannelMembershipType = $ChannelMembershipType
            ChannelDescription    = $ChannelDescription
            ChannelCreatedDate    = $ChannelCreatedDate
            ChannelIsArchived     = $ChannelIsArchived
            ChannelWebUrl         = $ChannelWebUrl
        })
    }

    $StandardChannels = @(
        $FilteredChannels |
        Where-Object { (Get-GraphProperty -InputObject $_ -Name "membershipType") -eq "standard" }
    )

    $PrivateChannels = @(
        $FilteredChannels |
        Where-Object { (Get-GraphProperty -InputObject $_ -Name "membershipType") -eq "private" }
    )

    $SharedChannels = @(
        $FilteredChannels |
        Where-Object { (Get-GraphProperty -InputObject $_ -Name "membershipType") -eq "shared" }
    )

    $StandardChannelNames = @(
        $StandardChannels |
        ForEach-Object { Get-GraphProperty -InputObject $_ -Name "displayName" } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $PrivateChannelNames = @(
        $PrivateChannels |
        ForEach-Object { Get-GraphProperty -InputObject $_ -Name "displayName" } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $SharedChannelNames = @(
        $SharedChannels |
        ForEach-Object { Get-GraphProperty -InputObject $_ -Name "displayName" } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
    ) -join "; "

    $Status = if ([string]::IsNullOrWhiteSpace($ChannelError)) {
        "Success"
    }
    else {
        "Failed"
    }

    [void]$SummaryExport.Add([PSCustomObject]@{
        TeamName             = $TeamName
        TeamId               = $TeamId
        TeamMail             = $TeamMail
        TeamMailNickname     = $TeamMailNickname
        TeamVisibility       = $TeamVisibility
        TeamCreatedDate      = $TeamCreatedDate
        TotalChannelCount    = $FilteredChannels.Count
        PublicChannelCount   = $StandardChannels.Count
        PrivateChannelCount  = $PrivateChannels.Count
        SharedChannelCount   = $SharedChannels.Count
        PublicChannelNames   = $StandardChannelNames
        PrivateChannelNames  = $PrivateChannelNames
        SharedChannelNames   = $SharedChannelNames
        ExportStatus         = $Status
        ChannelError         = $ChannelError
    })
}

Write-Progress -Activity "Exporting Teams channels" -Completed

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
    "ChannelName",
    "ChannelId",
    "ChannelType",
    "ChannelMembershipType",
    "ChannelDescription",
    "ChannelCreatedDate",
    "ChannelIsArchived",
    "ChannelWebUrl"
)

$SummaryHeaders = @(
    "TeamName",
    "TeamId",
    "TeamMail",
    "TeamMailNickname",
    "TeamVisibility",
    "TeamCreatedDate",
    "TotalChannelCount",
    "PublicChannelCount",
    "PrivateChannelCount",
    "SharedChannelCount",
    "PublicChannelNames",
    "PrivateChannelNames",
    "SharedChannelNames",
    "ExportStatus",
    "ChannelError"
)

$ErrorHeaders = @(
    "TeamName",
    "TeamId",
    "ChannelError"
)

Export-CsvSafe -Data $DetailedExport -Path $DetailCsvPath -Headers $DetailHeaders
Export-CsvSafe -Data $SummaryExport -Path $SummaryCsvPath -Headers $SummaryHeaders
Export-CsvSafe -Data $ErrorExport -Path $ErrorCsvPath -Headers $ErrorHeaders

Write-Host ""
Write-Host "Export completed successfully." -ForegroundColor Green
Write-Host "Detailed CSV: $DetailCsvPath" -ForegroundColor Green
Write-Host "Summary CSV:  $SummaryCsvPath" -ForegroundColor Green
Write-Host "Errors CSV:   $ErrorCsvPath" -ForegroundColor Green

if (-not $IncludeSharedChannels) {
    Write-Host ""
    Write-Host "Note: Shared channels were excluded. To include them, run the script with -IncludeSharedChannels." -ForegroundColor Yellow
}