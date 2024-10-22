# Install Microsoft Graph module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser

# Import Microsoft Graph module
Import-Module Microsoft.Graph

# Connect to Microsoft Graph with required permissions (Delegated or Application)
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"

# Get all users in the tenant (supports pagination)
$allUsers = Get-MgUser -All

$result = @()

foreach ($user in $allUsers) {
    # Get assigned licenses for the current user
    $licenses = Get-MgUserLicenseDetail -UserId $user.Id

    foreach ($license in $licenses) {
        foreach ($plan in $license.ServicePlans) {
            $result += [pscustomobject]@{
                UserPrincipalName = $user.UserPrincipalName
                DisplayName       = $user.DisplayName
                SKUPartNumber     = $license.SkuPartNumber
                ServicePlanName   = $plan.ServicePlanName
                ServicePlanStatus = $plan.ProvisioningStatus
            }
        }
    }
}

# Export result to CSV
$result | Export-Csv -Path "C:\M365_AllUsers_Licenses.csv" -NoTypeInformation
Write-Host "Export completed. File saved as C:\M365_AllUsers_Licenses.csv"
