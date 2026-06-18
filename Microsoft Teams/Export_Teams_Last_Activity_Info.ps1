<#
.SYNOPSIS
Exports Microsoft Teams last activity date to CSV.

.DESCRIPTION
This script exports all Microsoft Teams with their last activity date.

It creates:
1. Teams_Last_Activity.csv
   Contains only TeamName and LastActivityDate.

2. Teams_Last_Activity_Raw_Report.csv
   Raw Microsoft Graph Teams activity report downloaded from Graph.

.NOTES
Required Microsoft Graph permissions:
- Reports.Read.All
- Group.Read.All

Why Group.Read.All?
The Teams activity report may only return Teams included in the selected report period.
The script also reads the full Team list and matches it with the activity report so Teams with no activity in the selected period are still included in the final CSV.

Default report period:
- D180

Supported periods:
- D7
- D30
- D90
- D180
#>

param(
    [ValidateSet("D7", "D30", "D90", "D180")]
    [string]$Period = "D180",

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

function Download-TeamsActivityReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Period,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $ReportUri = "https://graph.microsoft.com/v1.0/reports/getTeamsTeamActivityDetail(period='$Period')"

    $Command = Get-Command Invoke-MgGraphRequest -ErrorAction Stop

    if ($Command.Parameters.ContainsKey("OutputFilePath")) {
        Invoke-MgGraphRequest -Method GET -Uri $ReportUri -OutputFilePath $OutputPath -ErrorAction Stop | Out-Null
    }
    elseif ($Command.Parameters.ContainsKey("OutFile")) {
        Invoke-MgGraphRequest -Method GET -Uri $ReportUri -OutFile $OutputPath -ErrorAction Stop | Out-Null
    }
    else {
        throw "Your installed Microsoft.Graph.Authentication module does not support OutputFilePath or OutFile with Invoke-MgGraphRequest. Update the module and run the script again."
    }

    if (-not (Test-Path -Path $OutputPath)) {
        throw "The Teams activity report was not downloaded."
    }

    $FileInfo = Get-Item -Path $OutputPath

    if ($FileInfo.Length -eq 0) {
        throw "The Teams activity report was downloaded but the file is empty."
    }
}

function Get-CsvValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Row,

        [Parameter(Mandatory = $true)]
        [string[]]$PossibleColumnNames
    )

    foreach ($ColumnName in $PossibleColumnNames) {
        $Property = $Row.PSObject.Properties[$ColumnName]

        if ($null -ne $Property) {
            return $Property.Value
        }
    }

    return $null
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

    $OutputFolder = Join-Path -Path $BasePath -ChildPath ("Teams_Last_Activity_Export_{0}" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
}

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
}

$RawReportCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Last_Activity_Raw_Report.csv"
$FinalCsvPath = Join-Path -Path $OutputFolder -ChildPath "Teams_Last_Activity.csv"

# ------------------------------------------------------------
# Prepare Microsoft Graph
# ------------------------------------------------------------

Write-Section "Preparing Microsoft Graph PowerShell module"

Ensure-GraphAuthenticationModule

$RequiredScopes = @(
    "Reports.Read.All",
    "Group.Read.All"
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
# Download Teams activity report
# ------------------------------------------------------------

Write-Section "Downloading Teams activity report"

Write-Host "Report period: $Period"
Download-TeamsActivityReport -Period $Period -OutputPath $RawReportCsvPath

$ActivityReportRows = @(Import-Csv -Path $RawReportCsvPath)

Write-Host "Rows found in Teams activity report: $($ActivityReportRows.Count)"

# ------------------------------------------------------------
# Get all Microsoft Teams
# ------------------------------------------------------------

Write-Section "Getting all Microsoft Teams"

$Headers = @{
    "ConsistencyLevel" = "eventual"
}

$TeamsUri = "https://graph.microsoft.com/v1.0/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName&`$top=999"

try {
    $Teams = @(Invoke-GraphGetAllPages -Uri $TeamsUri -Headers $Headers | Sort-Object displayName)
}
catch {
    throw "Failed to get Microsoft Teams. Error: $($_.Exception.Message)"
}

Write-Host "Teams found in tenant: $($Teams.Count)"

# ------------------------------------------------------------
# Build lookup from activity report
# ------------------------------------------------------------

$ActivityByTeamId = @{}
$ActivityByTeamName = @{}

foreach ($Row in $ActivityReportRows) {
    $ReportTeamId = Get-CsvValue -Row $Row -PossibleColumnNames @(
        "Team Id",
        "Team ID",
        "TeamId"
    )

    $ReportTeamName = Get-CsvValue -Row $Row -PossibleColumnNames @(
        "Team Name",
        "Team Display Name",
        "TeamName"
    )

    $LastActivityDate = Get-CsvValue -Row $Row -PossibleColumnNames @(
        "Last Activity Date",
        "LastActivityDate"
    )

    if (-not [string]::IsNullOrWhiteSpace($ReportTeamId)) {
        $ActivityByTeamId[$ReportTeamId] = $LastActivityDate
    }

    if (-not [string]::IsNullOrWhiteSpace($ReportTeamName)) {
        $ActivityByTeamName[$ReportTeamName.ToLowerInvariant()] = $LastActivityDate
    }
}

# ------------------------------------------------------------
# Create final output
# ------------------------------------------------------------

Write-Section "Creating final export"

$FinalExport = New-Object System.Collections.Generic.List[object]

foreach ($Team in $Teams) {
    $TeamId = Get-GraphProperty -InputObject $Team -Name "id"
    $TeamName = Get-GraphProperty -InputObject $Team -Name "displayName"

    $LastActivityDate = $null

    if (-not [string]::IsNullOrWhiteSpace($TeamId) -and $ActivityByTeamId.ContainsKey($TeamId)) {
        $LastActivityDate = $ActivityByTeamId[$TeamId]
    }
    elseif (-not [string]::IsNullOrWhiteSpace($TeamName) -and $ActivityByTeamName.ContainsKey($TeamName.ToLowerInvariant())) {
        $LastActivityDate = $ActivityByTeamName[$TeamName.ToLowerInvariant()]
    }

    [void]$FinalExport.Add([PSCustomObject]@{
        TeamName         = $TeamName
        LastActivityDate = $LastActivityDate
    })
}

$FinalExport |
    Sort-Object TeamName |
    Export-Csv -Path $FinalCsvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Export completed successfully." -ForegroundColor Green
Write-Host "CSV file: $FinalCsvPath" -ForegroundColor Green
Write-Host "Raw report: $RawReportCsvPath" -ForegroundColor Green

Write-Host ""
Write-Host "Note:" -ForegroundColor Yellow
Write-Host "If LastActivityDate is blank, the Team was not found in the $Period Teams activity report." -ForegroundColor Yellow