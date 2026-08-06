#Requires -Version 5.1

<#
.SYNOPSIS
Exports Microsoft Teams channels and their moderation settings.

.DESCRIPTION
The script uses an existing Microsoft Graph connection.

Connect before running with:
    Group.Read.All
    Channel.ReadBasic.All
    ChannelSettings.Read.All

The script uses:
    /v1.0/groups
    /beta/teams/{team-id}/allChannels

.EXAMPLE
.\Teams_Channels_with_Moderation_Setting.ps1

.EXAMPLE
.\Teams_Channels_with_Moderation_Setting.ps1 `
    -ExportPath "C:\Temp\Teams-Channel-Moderation-Report.csv"
#>

param (
    [string]$ExportPath = ".\Teams-Channel-Moderation-Report.csv"
)

$ErrorActionPreference = "Stop"

#-----------------------------------------------------------
# Validate Microsoft Graph module and existing connection
#-----------------------------------------------------------

if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {

    throw (
        "Microsoft.Graph.Authentication is not installed or imported. " +
        "Install it using: Install-Module Microsoft.Graph.Authentication"
    )
}

if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {

    throw (
        "Invoke-MgGraphRequest is unavailable. Import the Graph module " +
        "using: Import-Module Microsoft.Graph.Authentication"
    )
}

$GraphContext = Get-MgContext

if (
    $null -eq $GraphContext -or
    [string]::IsNullOrWhiteSpace($GraphContext.Account)
) {
    throw (
        "No active Microsoft Graph connection was found. " +
        "Connect to Microsoft Graph before running this script."
    )
}

Write-Host ""
Write-Host "Using existing Microsoft Graph connection." `
    -ForegroundColor Cyan

Write-Host "Account:   $($GraphContext.Account)" `
    -ForegroundColor Green

Write-Host "Tenant ID: $($GraphContext.TenantId)" `
    -ForegroundColor Green

Write-Host "Auth type: $($GraphContext.AuthType)" `
    -ForegroundColor Green

#-----------------------------------------------------------
# Validate Graph permissions
#-----------------------------------------------------------

$GrantedScopes = @($GraphContext.Scopes)

$MissingPermissions = [System.Collections.Generic.List[string]]::new()

if ("Group.Read.All" -notin $GrantedScopes) {
    [void]$MissingPermissions.Add("Group.Read.All")
}

$HasChannelSettingsPermission = (
    "ChannelSettings.Read.All" -in $GrantedScopes -or
    "ChannelSettings.ReadWrite.All" -in $GrantedScopes
)

if (-not $HasChannelSettingsPermission) {
    [void]$MissingPermissions.Add("ChannelSettings.Read.All")
}

if ($MissingPermissions.Count -gt 0) {

    throw (
        "The existing Graph connection is missing these permissions: " +
        "$($MissingPermissions -join ', ')`n`n" +
        "Reconnect Microsoft Graph with the required scopes."
    )
}

Write-Host "Required Graph permissions are present." `
    -ForegroundColor Green

Write-Host ""

#-----------------------------------------------------------
# Graph error handling
#-----------------------------------------------------------

function Get-GraphErrorDetails {

    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $StatusCode = $null
    $Message = $ErrorRecord.Exception.Message

    if (
        $ErrorRecord.Exception.PSObject.Properties.Name `
            -contains "ResponseStatusCode"
    ) {
        $StatusCode = [int]$ErrorRecord.Exception.ResponseStatusCode
    }
    elseif (
        $null -ne $ErrorRecord.Exception.Response -and
        $null -ne $ErrorRecord.Exception.Response.StatusCode
    ) {
        $StatusCode = [int]$ErrorRecord.Exception.Response.StatusCode
    }
    elseif ($Message -match "HTTP/\d(?:\.\d)?\s+([45]\d\d)") {
        $StatusCode = [int]$Matches[1]
    }
    elseif ($Message -match "\b([45]\d\d)\b") {
        $StatusCode = [int]$Matches[1]
    }

    if (
        $null -ne $ErrorRecord.ErrorDetails -and
        -not [string]::IsNullOrWhiteSpace(
            $ErrorRecord.ErrorDetails.Message
        )
    ) {
        $Message = $ErrorRecord.ErrorDetails.Message
    }

    [PSCustomObject]@{
        StatusCode = $StatusCode
        Message    = $Message
    }
}

function Invoke-GraphRequestWithRetry {

    param (
        [Parameter(Mandatory)]
        [string]$Uri,

        [ValidateRange(1, 10)]
        [int]$MaximumRetries = 5
    )

    for ($Attempt = 1; $Attempt -le $MaximumRetries; $Attempt++) {

        try {

            return Invoke-MgGraphRequest `
                -Method GET `
                -Uri $Uri `
                -OutputType PSObject `
                -ErrorAction Stop
        }
        catch {

            $GraphError = Get-GraphErrorDetails `
                -ErrorRecord $_

            # Retry only throttling and temporary service errors
            $ShouldRetry = (
                $GraphError.StatusCode -eq 429 -or
                (
                    $GraphError.StatusCode -ge 500 -and
                    $GraphError.StatusCode -le 599
                )
            )

            if (
                -not $ShouldRetry -or
                $Attempt -eq $MaximumRetries
            ) {
                throw (
                    "Microsoft Graph request failed.`n" +
                    "URI: $Uri`n" +
                    "HTTP status: $($GraphError.StatusCode)`n" +
                    "Error: $($GraphError.Message)"
                )
            }

            $Delay = [Math]::Pow(2, $Attempt)

            Write-Warning (
                "Graph returned HTTP $($GraphError.StatusCode). " +
                "Retrying in $Delay seconds..."
            )

            Start-Sleep -Seconds $Delay
        }
    }
}

function Invoke-GraphCollectionRequest {

    param (
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $Results = [System.Collections.Generic.List[object]]::new()
    $NextLink = $Uri

    while (-not [string]::IsNullOrWhiteSpace($NextLink)) {

        $Response = Invoke-GraphRequestWithRetry `
            -Uri $NextLink

        foreach ($Item in @($Response.value)) {

            if ($null -ne $Item) {
                [void]$Results.Add($Item)
            }
        }

        $NextLink = $Response.'@odata.nextLink'
    }

    return $Results
}

#-----------------------------------------------------------
# Retrieve all Teams
#-----------------------------------------------------------

$Report = [System.Collections.Generic.List[object]]::new()

Write-Host "Retrieving Microsoft Teams..." `
    -ForegroundColor Cyan

$TeamsUri = (
    "https://graph.microsoft.com/v1.0/groups?" +
    "`$filter=resourceProvisioningOptions/Any(x:x%20eq%20'Team')" +
    "&`$select=id,displayName,description,visibility" +
    "&`$top=999"
)

try {

    $Teams = @(
        Invoke-GraphCollectionRequest -Uri $TeamsUri
    )
}
catch {

    throw (
        "Unable to retrieve Microsoft Teams.`n`n" +
        "$($_.Exception.Message)"
    )
}

Write-Host "Teams found: $($Teams.Count)" `
    -ForegroundColor Green

Write-Host ""

if ($Teams.Count -eq 0) {

    Write-Warning "No Microsoft Teams were returned."
    return
}

#-----------------------------------------------------------
# Process each Team and channel
#-----------------------------------------------------------

$TeamNumber = 0
$ProcessedChannels = 0
$FailedTeams = 0

foreach ($Team in ($Teams | Sort-Object displayName)) {

    $TeamNumber++

    $TeamPercentage = [Math]::Round(
        ($TeamNumber / $Teams.Count) * 100
    )

    Write-Progress `
        -Id 1 `
        -Activity "Checking Microsoft Teams channel moderation" `
        -Status "$TeamNumber of $($Teams.Count): $($Team.displayName)" `
        -PercentComplete $TeamPercentage

    Write-Host (
        "[$TeamNumber/$($Teams.Count)] Team: " +
        "$($Team.displayName)"
    ) -ForegroundColor Cyan

    try {

        # Beta is required because moderationSettings is not
        # currently selectable through the v1.0 channel resource.
        $ChannelsUri = (
            "https://graph.microsoft.com/beta/teams/" +
            "$($Team.id)/allChannels?" +
            "`$select=id,displayName,description," +
            "membershipType,isArchived,moderationSettings"
        )

        $Channels = @(
            Invoke-GraphCollectionRequest `
                -Uri $ChannelsUri
        )

        if ($Channels.Count -eq 0) {

            Write-Host "    No channels returned." `
                -ForegroundColor DarkYellow

            [void]$Report.Add(
                [PSCustomObject]@{
                    TeamName                     = $Team.displayName
                    TeamId                       = $Team.id
                    TeamVisibility               = $Team.visibility
                    TeamDescription              = $Team.description
                    ChannelName                  = ""
                    ChannelId                    = ""
                    ChannelType                  = ""
                    ChannelArchived              = ""
                    ChannelDescription           = ""
                    ChannelModeration             = "Unknown"
                    UserNewMessageRestriction     = ""
                    ReplyRestriction              = ""
                    AllowNewMessageFromBots       = ""
                    AllowNewMessageFromConnectors = ""
                    CollectionStatus              = "No channels returned"
                    ErrorMessage                  = ""
                }
            )

            continue
        }

        $ChannelNumber = 0

        foreach ($Channel in $Channels) {

            $ChannelNumber++
            $ProcessedChannels++

            $ChannelPercentage = [Math]::Round(
                ($ChannelNumber / $Channels.Count) * 100
            )

            Write-Progress `
                -Id 2 `
                -ParentId 1 `
                -Activity "Processing channels" `
                -Status (
                    "$ChannelNumber of $($Channels.Count): " +
                    "$($Channel.displayName)"
                ) `
                -PercentComplete $ChannelPercentage

            $ModerationSettings = $Channel.moderationSettings

            if ($null -ne $ModerationSettings) {

                $UserNewMessageRestriction = (
                    $ModerationSettings.userNewMessageRestriction
                )

                $ReplyRestriction = (
                    $ModerationSettings.replyRestriction
                )

                $AllowNewMessageFromBots = (
                    $ModerationSettings.allowNewMessageFromBots
                )

                $AllowNewMessageFromConnectors = (
                    $ModerationSettings.
                        allowNewMessageFromConnectors
                )
            }
            else {

                $UserNewMessageRestriction = "Default"
                $ReplyRestriction = "Default"
                $AllowNewMessageFromBots = ""
                $AllowNewMessageFromConnectors = ""
            }

            $ChannelModeration = if (
                $UserNewMessageRestriction -eq "moderators"
            ) {
                "On"
            }
            else {
                "Off"
            }

            Write-Host (
                "    [$ChannelNumber/$($Channels.Count)] " +
                "Channel: $($Channel.displayName) | " +
                "Type: $($Channel.membershipType) | " +
                "Moderation: $ChannelModeration"
            ) -ForegroundColor Gray

            [void]$Report.Add(
                [PSCustomObject]@{
                    TeamName                     = $Team.displayName
                    TeamId                       = $Team.id
                    TeamVisibility               = $Team.visibility
                    TeamDescription              = $Team.description
                    ChannelName                  = $Channel.displayName
                    ChannelId                    = $Channel.id
                    ChannelType                  = $Channel.membershipType
                    ChannelArchived              = $Channel.isArchived
                    ChannelDescription           = $Channel.description
                    ChannelModeration             = $ChannelModeration
                    UserNewMessageRestriction     = $UserNewMessageRestriction
                    ReplyRestriction              = $ReplyRestriction
                    AllowNewMessageFromBots       = $AllowNewMessageFromBots
                    AllowNewMessageFromConnectors = $AllowNewMessageFromConnectors
                    CollectionStatus              = "Success"
                    ErrorMessage                  = ""
                }
            )
        }

        Write-Progress `
            -Id 2 `
            -ParentId 1 `
            -Activity "Processing channels" `
            -Completed
    }
    catch {

        $FailedTeams++
        $ErrorText = $_.Exception.Message

        Write-Warning (
            "Unable to retrieve channels for team " +
            "'$($Team.displayName)'. $ErrorText"
        )

        [void]$Report.Add(
            [PSCustomObject]@{
                TeamName                     = $Team.displayName
                TeamId                       = $Team.id
                TeamVisibility               = $Team.visibility
                TeamDescription              = $Team.description
                ChannelName                  = ""
                ChannelId                    = ""
                ChannelType                  = ""
                ChannelArchived              = ""
                ChannelDescription           = ""
                ChannelModeration             = "Unknown"
                UserNewMessageRestriction     = ""
                ReplyRestriction              = ""
                AllowNewMessageFromBots       = ""
                AllowNewMessageFromConnectors = ""
                CollectionStatus              = "Failed"
                ErrorMessage                  = $ErrorText
            }
        )
    }

    Write-Host ""
}

Write-Progress `
    -Id 1 `
    -Activity "Checking Microsoft Teams channel moderation" `
    -Completed

#-----------------------------------------------------------
# Export CSV
#-----------------------------------------------------------

$ExportPath = [System.IO.Path]::GetFullPath(
    $ExportPath
)

$ExportFolder = Split-Path `
    -Path $ExportPath `
    -Parent

if (-not (Test-Path -Path $ExportFolder)) {

    New-Item `
        -Path $ExportFolder `
        -ItemType Directory `
        -Force | Out-Null
}

$Report |
    Sort-Object TeamName, ChannelName |
    Export-Csv `
        -Path $ExportPath `
        -NoTypeInformation `
        -Encoding UTF8

#-----------------------------------------------------------
# Display summary
#-----------------------------------------------------------

$SuccessfulChannelRows = @(
    $Report | Where-Object {
        $_.CollectionStatus -eq "Success"
    }
).Count

$ModerationOnChannels = @(
    $Report | Where-Object {
        $_.CollectionStatus -eq "Success" -and
        $_.ChannelModeration -eq "On"
    }
).Count

$ModerationOffChannels = @(
    $Report | Where-Object {
        $_.CollectionStatus -eq "Success" -and
        $_.ChannelModeration -eq "Off"
    }
).Count

Write-Host "Report completed successfully." `
    -ForegroundColor Green

Write-Host "CSV file: $ExportPath" `
    -ForegroundColor Green

Write-Host "Teams processed: $($Teams.Count)" `
    -ForegroundColor Green

Write-Host "Channels exported: $SuccessfulChannelRows" `
    -ForegroundColor Green

Write-Host "Moderation On: $ModerationOnChannels" `
    -ForegroundColor Green

Write-Host "Moderation Off: $ModerationOffChannels" `
    -ForegroundColor Green

if ($FailedTeams -gt 0) {

    Write-Host "Teams with errors: $FailedTeams" `
        -ForegroundColor Yellow
}
else {

    Write-Host "Teams with errors: 0" `
        -ForegroundColor Green
}