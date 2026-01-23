<#
.SYNOPSIS
Exports Intune Detected Apps inventory to CSV with Excel-friendly UTF-8 encoding.

.REQUIREMENTS
- Microsoft.Graph PowerShell module
- Graph permission: DeviceManagementManagedDevices.Read.All

.NOTES
Name        : Export-IntuneSoftwareInventory.ps1
Author      : Jatin Makhija
Version     : 1.0.0
DateCreated : 21-Jan-2026
Blog        : https://cloudinfra.net

.EXAMPLE
.\Export-IntuneSoftwareInventory.ps1 -OutputPath "C:\Temp\Intune-SoftwareInventory.csv"

.EXAMPLE
.\Export-IntuneSoftwareInventory.ps1 -OutputPath "C:\Temp\Intune-SoftwareInventory.csv" -IncludeTimestamp

#>

# Output path
$OutputPath = "C:\Temp\Intune-DetectedApps.csv"
$null = New-Item -Path (Split-Path $OutputPath) -ItemType Directory -Force -ErrorAction SilentlyContinue

# Pick delimiter based on current Windows locale (Excel-friendly)
$Delimiter = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ListSeparator

# Pick encoding that keeps special characters readable in Excel
# - Windows PowerShell 5.1: UTF8 includes BOM
# - PowerShell 7+: UTF8 is BOM-less, so use utf8BOM explicitly
$CsvEncoding =
if ($PSVersionTable.PSVersion.Major -ge 7) { "utf8BOM" } else { "utf8" }

# Ensure Graph module is present
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph)) {
    throw "Microsoft.Graph module not found. Install it: Install-Module Microsoft.Graph -Scope CurrentUser"
}

# Connect (delegated)
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All" | Out-Null

# Query all detected apps (handles paging)
$uri = "https://graph.microsoft.com/v1.0/deviceManagement/detectedApps?$top=999"
$all = New-Object System.Collections.Generic.List[object]

try {
    do {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
        foreach ($item in $resp.value) { $all.Add($item) }
        $uri = $resp.'@odata.nextLink'
    } while ($uri)
}
catch {
    $msg = $_.Exception.Message
    throw "Graph query failed. Common causes: missing permission, admin consent not granted, or Intune license. Details: $msg"
}

# Build rows
$rows = $all | ForEach-Object {
    [pscustomobject]@{
        AppName      = $_.displayName
        Version      = $_.version
        Publisher    = $_.publisher
        Platform     = $_.platform
        DeviceCount  = $_.deviceCount
        SizeInBytes  = $_.sizeInByte
        AppId        = $_.id
    }
} | Sort-Object AppName, Version

# Export to CSV
$rows | Export-Csv -Path $OutputPath -NoTypeInformation -Delimiter $Delimiter -Encoding $CsvEncoding

Write-Host "Export complete: $OutputPath"
Write-Host "Rows exported: $($rows.Count)"
Write-Host "Delimiter used: '$Delimiter' | Encoding: $CsvEncoding"