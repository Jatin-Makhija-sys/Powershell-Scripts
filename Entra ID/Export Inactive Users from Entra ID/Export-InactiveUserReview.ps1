param(
    [ValidateRange(1,3650)][int]$InactiveDays = 90,
    [string]$OutputPath = 'C:\Reports\UserSignInReview.csv'
)
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.Graph.Users
if (-not (Get-MgContext)) { throw 'Connect to Graph before running this script.' }

$Now = [DateTimeOffset]::UtcNow
$Cutoff = $Now.AddDays(-$InactiveDays)
function Format-UtcDate {
    param($Value)
    if ($null -eq $Value) { return $null }
    ([DateTimeOffset]$Value).ToUniversalTime().ToString('o')
}
$Properties = @(
    'id','displayName','userPrincipalName','userType',
    'accountEnabled','createdDateTime','assignedLicenses','signInActivity'
)
$Users = @(Get-MgUser -All -PageSize 500 -Property $Properties)
if ($Users.Count -eq 0) { throw 'No users returned. Check the connected tenant.' }

$Report = foreach ($User in $Users) {
    $LastSuccess = $null
    $Created = $null
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

    [PSCustomObject]@{
        UserId = $User.Id
        DisplayName = $User.DisplayName
        UserPrincipalName = $User.UserPrincipalName
        UserType = $User.UserType
        AccountEnabled = $User.AccountEnabled
        HasAssignedLicense = (@($User.AssignedLicenses).Count -gt 0)
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
}
$ResolvedPath = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -Path (Split-Path $ResolvedPath -Parent) -ItemType Directory -Force | Out-Null
$Report | Sort-Object ActivityAssessment,UserPrincipalName |
    Export-Csv -Path $ResolvedPath -NoTypeInformation -Encoding utf8
$Report | Group-Object ActivityAssessment | Select-Object Name,Count | Format-Table -AutoSize
Write-Host "Exported $($Report.Count) users to $ResolvedPath"