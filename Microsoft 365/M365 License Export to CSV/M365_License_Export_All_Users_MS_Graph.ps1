# Install Microsoft Graph module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser

# Import the Microsoft Graph module
Import-Module Microsoft.Graph

# Connect to Microsoft Graph with required permissions (Delegated or Application)
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"

# Get all users in the tenant (supports pagination)
$allUsers = Get-MgUser -All

# Create an array to store the result
$result = @()

# Loop through all users
foreach ($user in $allUsers) {
    # Get assigned licenses for the current user
    $licenses = Get-MgUserLicenseDetail -UserId $user.Id

    foreach ($license in $licenses) {
        foreach ($plan in $license.ServicePlans) {
            # Collect user, SKU, and ServicePlan information
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
$result | Export-Csv -Path "C:\Graph_AllUsers_Licenses.csv" -NoTypeInformation

Write-Host "Export completed. File saved as C:\Graph_AllUsers_Licenses.csv"
