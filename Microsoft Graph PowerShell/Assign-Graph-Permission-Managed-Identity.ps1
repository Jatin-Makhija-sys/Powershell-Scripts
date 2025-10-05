# Provide Information in Below Vars
$TenantId        = "9bde39d-f87c-44dd-a9ee-224hhsjs559e"
$MiObjectId      = "c9661b98-cca1-44e8-978d-897a093c2d8f" 
$GraphAppId      = "00000003-0000-0000-c000-000000000000"            # Microsoft Graph
$TargetAppRole   = "Directory.Read.All"                               # change as needed

# Connect To MS Graph using Device Code
Write-Host "Signing in to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -TenantId $TenantId `
  -Scopes "Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All" `
  -UseDeviceCode

# Resolve SPs by IDs
Write-Host "Resolving service principals..." -ForegroundColor Cyan

# Managed Identity SP (principal to receive the app role)
$miSp = Get-MgServicePrincipal -ServicePrincipalId $MiObjectId -ErrorAction Stop

# Microsoft Graph SP (resource exposing app roles)
$graphSp = Get-MgServicePrincipal -Filter "appId eq '$GraphAppId'" -ErrorAction Stop

# Pick the APPLICATION permission (app role) you want
$role = $graphSp.AppRoles |
  Where-Object { $_.Value -eq $TargetAppRole -and $_.IsEnabled -and $_.AllowedMemberTypes -contains "Application" } |
  Select-Object -First 1

if (-not $role) {
  throw "App role '$TargetAppRole' not found on Microsoft Graph for Application member type."
}

Write-Host "Assigning app role '$($role.Value)' to '$($miSp.DisplayName)'..." -ForegroundColor Cyan

# Assign the app role
$assignment = New-MgServicePrincipalAppRoleAssignment `
  -ServicePrincipalId $miSp.Id `
  -PrincipalId        $miSp.Id `
  -ResourceId         $graphSp.Id `
  -AppRoleId          $role.Id

Write-Host "Done. AppRoleAssignment Id: $($assignment.Id)" -ForegroundColor Green

# Verify
Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $miSp.Id |
  Where-Object { $_.ResourceId -eq $graphSp.Id } |
  Select-Object PrincipalDisplayName, ResourceDisplayName, AppRoleId