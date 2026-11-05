#Requires -Version 7.0
<#
.SYNOPSIS
Exports a read-only user sign-in review using client-secret app-only authentication.
.DESCRIPTION
Requires Microsoft.Graph.Authentication and Microsoft.Graph.Users.
Grant Microsoft Graph APPLICATION permissions User.Read.All and AuditLog.Read.All
with admin consent. Sign-in activity requires Microsoft Entra ID P1 or P2.
Enter ClientId, ClientSecret (secret VALUE), and TenantId in the variables below.
Exports all users, including guests and disabled accounts. Missing successful
sign-in dates are not treated as proof of inactivity. Existing CSV is replaced.
Run in a dedicated PowerShell process: this script connects and disconnects Graph.
.EXAMPLE
./Export-InactiveUserReview.ps1 -InactiveDays 90 -OutputPath 'C:\Reports\UserSignInReview.csv'
#>
[CmdletBinding()]
param(
    [ValidateRange(1,3650)][int]$InactiveDays = 90,
    [ValidateNotNullOrEmpty()][string]$OutputPath = './UserSignInReview.csv'
)
$ErrorActionPreference = 'Stop'

# Replace these values before running the script.
$ClientId = '2bc59a27-26dd-4e84-8410-6d5cb28e6010'
$ClientSecret = '<your-new-client-secret-value>'
$TenantId = '<your-directory-tenant-id>'

Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Users -ErrorAction Stop

try {
    $TenantId = ([guid]$TenantId).ToString()
    $ClientId = ([guid]$ClientId).ToString()
}
catch { throw 'Replace TenantId and ClientId with valid GUIDs from the app Overview page.' }
if ($TenantId -eq [guid]::Empty.ToString() -or $ClientId -eq [guid]::Empty.ToString()) {
    throw 'TenantId and ClientId must be non-empty GUIDs.'
}
if ([string]::IsNullOrWhiteSpace($ClientSecret) -or $ClientSecret -eq '<your-new-client-secret-value>') {
    throw 'Replace ClientSecret with the secret Value from the app registration.'
}
$SecureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force

function Format-UtcDate {
    param($Value)
    if ($null -ne $Value) {
        ([DateTimeOffset]$Value).ToUniversalTime().ToString('o')
    }
}

$Connected = $false
try {
    $Credential = [pscredential]::new($ClientId, $SecureClientSecret)
    Connect-MgGraph -TenantId $TenantId.ToString() -ClientSecretCredential $Credential -ContextScope Process -NoWelcome -ErrorAction Stop | Out-Null
    $Connected = $true
    $Context = Get-MgContext
    if ($Context.AuthType -ne 'AppOnly' -or
        $Context.TenantId -ne $TenantId.ToString() -or
        $Context.ClientId -ne $ClientId.ToString()) {
        throw 'The Graph connection does not match the requested app-only context.'
    }

    $Now = [DateTimeOffset]::UtcNow
    $Cutoff = $Now.AddDays(-$InactiveDays)
    $Properties = @(
        'id','displayName','userPrincipalName','userType',
        'accountEnabled','createdDateTime','assignedLicenses','signInActivity'
    )
    # -All retrieves every page; signInActivity supports pages of up to 500 users.
    $Users = @(Get-MgUser -All -PageSize 500 -Property $Properties -ErrorAction Stop)
    if ($Users.Count -eq 0) { throw 'No users returned. No report was written.' }

    $Report = @(foreach ($User in $Users) {
        $Created = $null
        $LastSuccess = $null
        $DaysSinceSuccess = $null
        if ($null -ne $User.CreatedDateTime) {
            $Created = ([DateTimeOffset]$User.CreatedDateTime).ToUniversalTime()
        }
        if ($null -ne $User.SignInActivity.LastSuccessfulSignInDateTime) {
            $LastSuccess = ([DateTimeOffset]$User.SignInActivity.LastSuccessfulSignInDateTime).ToUniversalTime()
            $DaysSinceSuccess = [math]::Floor(($Now - $LastSuccess).TotalDays)
        }
        if ($null -ne $LastSuccess) {
            if ($LastSuccess -le $Cutoff) { $Assessment = 'Inactive candidate' }
            else { $Assessment = 'Recent successful sign-in' }
        }
        elseif ($null -ne $Created -and $Created -gt $Cutoff) {
            $Assessment = 'New account - no successful date returned'
        }
        else { $Assessment = 'Unknown - no successful date returned' }

        [pscustomobject]@{
            UserId = $User.Id
            DisplayName = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            UserType = $User.UserType
            AccountEnabled = $User.AccountEnabled
            HasAssignedLicense = (@($User.AssignedLicenses | Where-Object { $null -ne $_ }).Count -gt 0)
            CreatedDateTimeUtc = Format-UtcDate $Created
            LastSuccessfulSignInUtc = Format-UtcDate $LastSuccess
            LastInteractiveAttemptUtc = Format-UtcDate $User.SignInActivity.LastSignInDateTime
            LastNonInteractiveAttemptUtc = Format-UtcDate $User.SignInActivity.LastNonInteractiveSignInDateTime
            DaysSinceSuccessfulSignIn = $DaysSinceSuccess
            ActivityAssessment = $Assessment
            InactiveThresholdDays = $InactiveDays
            CutoffUtc = Format-UtcDate $Cutoff
            ReportGeneratedUtc = Format-UtcDate $Now
        }
    })
    if (@($Report | Where-Object { $_.LastSuccessfulSignInUtc }).Count -eq 0) {
        Write-Warning 'No successful sign-in dates were returned. Check licensing and permissions before interpreting the report.'
    }
    $ResolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    New-Item -ItemType Directory -Path (Split-Path $ResolvedPath -Parent) -Force | Out-Null
    $Report | Sort-Object ActivityAssessment,UserPrincipalName |
        Export-Csv -LiteralPath $ResolvedPath -NoTypeInformation -Encoding utf8BOM
    $Report | Group-Object ActivityAssessment |
        Select-Object Name,Count | Format-Table -AutoSize
    Write-Host "Exported $($Report.Count) users to $ResolvedPath"
}
finally {
    if ($Connected) {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
}

