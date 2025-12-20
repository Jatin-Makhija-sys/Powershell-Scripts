<#
.SYNOPSIS
Exports all Microsoft Intune Platform (Device Management) PowerShell scripts from an Intune tenant to local .ps1 files.

.DESCRIPTION
This script retrieves Intune Platform scripts (Devices > Scripts and remediations > Platform scripts) using Microsoft Graph
and writes each script to disk.

High-level flow:
  1) Create an output folder (defaults to C:\Temp\IntunePlatformScripts)
  2) List all scripts from:
       GET https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts
  3) For each script:
       - Get full details (includes scriptContent and fileName)
       - Decode scriptContent (Base64) into readable PowerShell text
       - Save it as "<DisplayName> - <FileName>" in the output folder

PREREQUISITES
- Microsoft Graph PowerShell SDK installed.
- You must connect to Microsoft Graph before running this script, for example:
    Connect-MgGraph -Scopes "DeviceManagementScripts.Read.All"
- Your account (or app) must have permissions to read Intune device management scripts.
  In many tenants, this requires admin consent.

OUTPUTS
- One .ps1 file per Platform script in:
    C:\Temp\IntunePlatformScripts
- Console message confirming export path.

LIMITATIONS / NOTES
- This script uses the Microsoft Graph /beta endpoint for deviceManagementScripts. Beta APIs may change.
- This script does not currently implement paging (@odata.nextLink). If you have a large number of scripts,
  you may need to add paging logic to ensure all scripts are exported.
- File naming sanitises invalid Windows filename characters in the Intune script displayName.

SECURITY
Exported scripts may contain sensitive logic (URLs, tokens, credentials, local paths). Store outputs securely and restrict access.

.EXAMPLE
# 1) Connect first (interactive delegated)
Connect-MgGraph -Scopes "DeviceManagementScripts.Read.All"

# 2) Run the export script
.\Export-IntunePlatformScripts.ps1

.EXAMPLE
# Run from an elevated PowerShell session and export to a custom folder
$OutDir = "D:\Exports\IntuneScripts"
# (Then run the script after setting $OutDir, or modify it into a parameter)

.NOTES
Author: Jatin Makhija (CloudInfra.net)
Purpose: Tenant audit / recovery of Intune Platform script content
#>

# Output folder where scripts will be exported.
$OutDir = "C:\Temp\IntunePlatformScripts"

# Create the folder if it doesn't exist. -Force avoids errors if already present.
New-Item -Path $OutDir -ItemType Directory -Force | Out-Null

# List scripts (basic listing, returns an array in the 'value' property)
# Endpoint: /deviceManagement/deviceManagementScripts
$resp = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts"
$scripts = $resp.value

# Loop through each script returned by the list call
foreach ($s in $scripts) {

    # Retrieve full script details by ID, including:
    # - displayName
    # - fileName
    # - scriptContent (Base64-encoded)
    $detail = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$($s.id)"

    # Sanitise display name for a Windows filename
    $name = ($detail.displayName -replace '[\\/:*?"<>|]', '_')

    # Build output file path: "<DisplayName> - <OriginalFileName>"
    $file = Join-Path $OutDir ("{0} - {1}" -f $name, $detail.fileName)

    # Decode Base64 scriptContent to readable UTF-8 script text
    $content = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($detail.scriptContent))

    # Write script content to file
    $content | Out-File -FilePath $file -Encoding utf8
}

Write-Host "Export complete: $OutDir"