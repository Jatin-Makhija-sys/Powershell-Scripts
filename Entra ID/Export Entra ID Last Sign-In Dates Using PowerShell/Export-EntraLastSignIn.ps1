<#
.SYNOPSIS
    Export Entra ID user sign-in summaries using Microsoft Graph.
.DESCRIPTION
    Reads all users, or exact UPNs from a text file. Exports successful
    sign-in and attempt timestamps in UTC. Does not change accounts.
    Connect-MgGraph must be run before executing this script.
.PARAMETER UPNFile
    Optional text file containing one user principal name per line.
.PARAMETER OutputPath
    Destination CSV. The parent folder is created if needed.
.NOTES
    Site: cloudinfra.net
    Requires Microsoft.Graph.Users and Microsoft.Graph.Authentication.
    Delegated scopes: User.Read.All, AuditLog.Read.All.
#>
[CmdletBinding()]
param(
    [string]$UPNFile,
    [string]$OutputPath = 'C:\Temp\Entra-LastSignIn.csv'
)

$ErrorActionPreference = 'Stop'
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users

if (-not (Get-MgContext)) {
    throw 'Connect to Microsoft Graph before running this script.'
}

$Properties = @(
    'Id', 'DisplayName', 'UserPrincipalName', 'UserType',
    'CreatedDateTime', 'SignInActivity'
)
$ReportTime = [DateTimeOffset]::UtcNow

function Format-UtcDate {
    param($Value)
    if ($null -ne $Value) {
        ([DateTimeOffset]$Value).ToUniversalTime().ToString(
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        )
    }
}

function New-ReportRow {
    param($User, [string]$InputUPN, [string]$LookupError)

    $LastSuccess = $null
    $Days = $null
    $State = 'Lookup failed'
    if ($null -ne $User) {
        $LastSuccess = $User.SignInActivity.LastSuccessfulSignInDateTime
        if ($null -ne $LastSuccess) {
            $Days = [math]::Floor(
                ($ReportTime - [DateTimeOffset]$LastSuccess).TotalDays
            )
            $State = 'Successful sign-in recorded'
        }
        else {
            $State = 'No successful sign-in recorded'
        }
    }

    [PSCustomObject]@{
        UserId                         = $User.Id
        DisplayName                    = $User.DisplayName
        UserPrincipalName              = $(if ($User) {
            $User.UserPrincipalName
        } else { $InputUPN })
        UserType                       = $User.UserType
        CreatedDateTimeUtc             = Format-UtcDate $User.CreatedDateTime
        LastSuccessfulSignInUtc        = Format-UtcDate $LastSuccess
        LastInteractiveAttemptUtc      = Format-UtcDate $User.SignInActivity.LastSignInDateTime
        LastNonInteractiveAttemptUtc   = Format-UtcDate $User.SignInActivity.LastNonInteractiveSignInDateTime
        DaysSinceLastSuccessfulSignIn  = $Days
        SignInDataStatus               = $State
        LookupError                    = $LookupError
        ReportGeneratedUtc             = Format-UtcDate $ReportTime
    }
}

if ($UPNFile) {
    $UPNs = @(Get-Content -LiteralPath $UPNFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ } |
        Sort-Object -Unique)

    if ($UPNs.Count -eq 0) {
        throw 'The UPN file contains no users.'
    }

    $Report = @(foreach ($UPN in $UPNs) {
        try {
            $Identity = Get-MgUser -UserId $UPN -Property Id `
                -ErrorAction Stop
            $User = Get-MgUser -UserId $Identity.Id -Property $Properties `
                -ErrorAction Stop
            New-ReportRow -User $User
        }
        catch {
            New-ReportRow -InputUPN $UPN -LookupError $_.Exception.Message
        }
    })
}
else {
    # Retrieve all pages before exporting. A failed request stops the export.
    $Users = @(Get-MgUser -All -PageSize 500 `
        -Property $Properties -ErrorAction Stop)
    $Report = @(foreach ($User in $Users) {
        New-ReportRow -User $User
    })
}

if ($Report.Count -eq 0) {
    throw 'No users returned. No CSV was written.'
}

$FullPath = [System.IO.Path]::GetFullPath($OutputPath)
$Folder = [System.IO.Path]::GetDirectoryName($FullPath)
[System.IO.Directory]::CreateDirectory($Folder) | Out-Null
$Report | Export-Csv -LiteralPath $FullPath -NoTypeInformation -Encoding utf8
Write-Host "Exported $($Report.Count) rows to $FullPath"

$Failed = @($Report | Where-Object SignInDataStatus -eq 'Lookup failed')
if ($Failed.Count -gt 0) {
    Write-Warning "$($Failed.Count) user lookups failed. Review LookupError in the CSV."
}