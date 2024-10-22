# Install Microsoft Graph module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser

# Import the Microsoft Graph module
Import-Module Microsoft.Graph

# Connect to Microsoft Graph with required permissions (Delegated or Application)
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"

# Specify the UserPrincipalName of the user you want to check
$UserPrincipalName = "user@domain.com"

# Get user information using Microsoft Graph
$user = Get-MgUser -UserId $UserPrincipalName

# Get assigned licenses for the specific user
$licenses = Get-MgUserLicenseDetail -UserId $user.Id

# Create an array to store the result
$result = @()

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

# Export result to CSV
$result | Export-Csv -Path "C:\Graph_User_License.csv" -NoTypeInformation

Write-Host "Export completed. File saved as C:\Graph_User_License.csv"
