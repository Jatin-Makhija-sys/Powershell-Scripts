# Install Microsoft Graph module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser

# Import Microsoft Graph module
Import-Module Microsoft.Graph

# Connect to Microsoft Graph with required permissions (Delegated or Application)
Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"

# Specify the UserPrincipalName of the user you want to check
$UserPrincipalName = "jatin.makhija@techpress.net"

# Get user information using Microsoft Graph
$user = Get-MgUser -UserId $UserPrincipalName

# Get assigned licenses for the specific user
$licenses = Get-MgUserLicenseDetail -UserId $user.Id

$result = @()

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

# Export result to CSV
$result | Export-Csv -Path "C:\M365_User_Licenses.csv" -NoTypeInformation
Write-Host "Export completed. File saved as C:\M365_User_Licenses.csv"
