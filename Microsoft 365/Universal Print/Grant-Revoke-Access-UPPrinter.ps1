<#
.SYNOPSIS
    Interactively grants or removes access for a user or group to a Universal Print printer share.

.DESCRIPTION
    This script connects to Microsoft Universal Print and Microsoft Graph, then:
    - Checks if required modules are installed (UniversalPrintManagement, Microsoft.Graph.Users, Microsoft.Graph.Groups) and installs them if missing.
    - Prompts the administrator to choose between granting or removing access.
    - Prompts for whether the principal is a user or a group.
    - Resolves the user or group via Microsoft Graph (supports UPN/ObjectId for users and displayName/ObjectId for groups).
    - Lists and allows selection of a Universal Print printer share (supports search and Out-GridView selection if available).
    - Grants or removes access accordingly.

.PARAMETER None
    This script is fully interactive and does not require parameters. You will be prompted for:
        - Action (Grant or Remove)
        - Principal type (User or Group)
        - Principal identifier (UPN/ObjectId or displayName/ObjectId)
        - Printer share (search term or selection from a list)

.REQUIREMENTS
    - PowerShell 5.1 or later
    - Internet connectivity to Microsoft Graph and Universal Print endpoints
    - UniversalPrintManagement module
    - Microsoft.Graph.Users and Microsoft.Graph.Groups modules
    - Microsoft 365 account with appropriate admin rights to manage Universal Print

.OUTPUTS
    Console messages confirming the action taken (grant or remove) and the target principal and printer share.

.EXAMPLE
    PS C:\> .\Manage-UPPrinterShareAccess.ps1
    [Interactive prompts follow]
    This example connects to Universal Print, prompts for the required details, and grants or removes access accordingly.

.NOTES
    Author   : Jatin Makhija
    Website  : https://techpress.net
    Created  : 10-Aug-2025
    Version  : 1.0
#>


$ErrorActionPreference = 'Stop'

# === Check & Install Required Modules ===
$modules = @(
    @{ Name = "UniversalPrintManagement"; Graph = $false },
    @{ Name = "Microsoft.Graph.Users";    Graph = $true  },
    @{ Name = "Microsoft.Graph.Groups";   Graph = $true  }
)

foreach ($mod in $modules) {
    if (Get-Module -ListAvailable -Name $mod.Name) {
        Write-Host "Module '$($mod.Name)' is already installed. Skipping install." -ForegroundColor Yellow
    } else {
        Write-Host "Module '$($mod.Name)' not found. Installing..." -ForegroundColor Cyan
        Install-Module $mod.Name -Scope CurrentUser -Force -ErrorAction Stop
    }
}

# Import Universal Print module
Import-Module UniversalPrintManagement

# Connect services
Connect-UPService | Out-null
Connect-MgGraph -Scopes "User.Read.All","Group.Read.All" -NoWelcome


# Helpers
function Test-OutGridViewAvailable { [bool](Get-Command Out-GridView -ErrorAction SilentlyContinue) }
function Test-IsGuid([string]$s){ [guid]::TryParse($s, [ref]([guid]::Empty)) }

# 0) Action
do {
  $action = (Read-Host "Choose action: 'Grant' or 'Remove'").Trim()
} until ($action -match '^(?i:grant|remove)$')
$action = ($action.Substring(0,1).ToUpper() + $action.Substring(1).ToLower())

# 1) Principal type
do {
  $principalType = (Read-Host "Target a 'User' or a 'Group'?").Trim()
} until ($principalType -match '^(?i:user|group)$')
$principalType = ($principalType.Substring(0,1).ToUpper() + $principalType.Substring(1).ToLower())

# 2) Principal value
$principalPrompt = if ($principalType -eq 'User') {
  "Enter User identifier (UPN or ObjectId)"
} else {
  "Enter Group identifier (displayName or ObjectId)"
}
do {
  $principalValue = (Read-Host $principalPrompt).Trim()
} until ($principalValue)

# 3) Resolve principal via Graph
if ($principalType -eq 'User') {
  if (Test-IsGuid $principalValue) { $principal = Get-MgUser -UserId $principalValue }
  else {
    try { $principal = Get-MgUser -UserId $principalValue } catch { $principal = $null }
    if (-not $principal) { $principal = Get-MgUser -Filter "userPrincipalName eq '$principalValue'" }
  }
  if (-not $principal) { throw "User '$principalValue' not found." }
  $principalId    = $principal.Id
  $principalLabel = $principal.UserPrincipalName
} else {
  if (Test-IsGuid $principalValue) { $principal = Get-MgGroup -GroupId $principalValue }
  else {
    $principal = Get-MgGroup -Filter "displayName eq '$principalValue'"
    if ($principal -and $principal.Count -gt 1) {
      if (Test-OutGridViewAvailable) {
        $principal = $principal | Out-GridView -Title "Multiple groups found — select one" -PassThru
      } else {
        Write-Host "Multiple groups found:"
        for ($i=0; $i -lt $principal.Count; $i++) {
          Write-Host ("{0}. {1}  ({2})" -f $i, $principal[$i].DisplayName, $principal[$i].Id)
        }
        do {
          $idxText = Read-Host "Enter the number for the correct group"
          $ok = [int]::TryParse($idxText, [ref]([int]$idx))
        } until ($ok -and $idx -ge 0 -and $idx -lt $principal.Count)
        $principal = $principal[$idx]
      }
    }
  }
  if (-not $principal) { throw "Group '$principalValue' not found." }
  $principalId    = $principal.Id
  $principalLabel = $principal.DisplayName
}

# 4) Choose printer share
$search = Read-Host "Enter part (or all) of the Printer Share display name to search"
# Fetch all shares (handle paging)
$sharesResp = Get-UPPrinterShare
$shares = @()
if ($sharesResp) {
  if ($sharesResp.PSObject.Properties.Name -contains 'Results') {
    $shares += $sharesResp.Results
    while ($sharesResp.'@odata.nextLink') {
      $sharesResp = Get-UPPrinterShare -Uri $sharesResp.'@odata.nextLink'
      $shares += $sharesResp.Results
    }
  } else { $shares += $sharesResp }
}
if (-not $shares) { throw "No printer shares found in Universal Print." }

$matches = if ($search) { $shares | Where-Object { $_.DisplayName -like "*$search*" } } else { $shares }
if (-not $matches) { throw "No printer shares matched '$search'." }

if (Test-OutGridViewAvailable) {
  $share = $matches | Select-Object DisplayName, Id, @{n='PrinterId';e={$_.Printer.Id}}, CreatedDateTime |
           Out-GridView -Title "Select the Printer Share" -PassThru
} else {
  Write-Host "Matched printer shares:"
  for ($i=0; $i -lt $matches.Count; $i++) {
    Write-Host ("{0}. {1}  ({2})" -f $i, $matches[$i].DisplayName, $matches[$i].Id)
  }
  do {
    $sIdxText = Read-Host "Enter the number for the correct share"
    $sOk = [int]::TryParse($sIdxText, [ref]([int]$sIdx))
  } until ($sOk -and $sIdx -ge 0 -and $sIdx -lt $matches.Count)
  $share = $matches[$sIdx]
}
if (-not $share) { throw "No printer share selected." }

# 5) Confirm
Write-Host ""
Write-Host "About to $action access:" -ForegroundColor Cyan
Write-Host ("  Principal Type : {0}" -f $principalType)
Write-Host ("  Principal      : {0}" -f $principalLabel)
Write-Host ("  Principal Id   : {0}" -f $principalId)
Write-Host ("  Printer Share  : {0}" -f $share.DisplayName)
Write-Host ("  Share Id       : {0}" -f $share.Id)
$go = Read-Host "Proceed? (YES to continue)"
if ($go -ne 'YES') { Write-Host "Cancelled."; return }

# 6) Execute
if ($action -eq 'Grant') {
  if ($principalType -eq 'User') {
    Grant-UPAccess -ShareId $share.Id -UserId $principalId
  } else {
    Grant-UPAccess -ShareId $share.Id -GroupId $principalId
  }
  Write-Host "Success: Granted access to $principalType '$principalLabel' for share '$($share.DisplayName)'. ✅" -ForegroundColor Green
} else {
  if ($principalType -eq 'User') {
    Revoke-UPAccess -ShareId $share.Id -UserId $principalId
  } else {
    Revoke-UPAccess -ShareId $share.Id -GroupId $principalId
  }
  Write-Host "Success: Removed access for $principalType '$principalLabel' from share '$($share.DisplayName)'. ✅" -ForegroundColor Green
}