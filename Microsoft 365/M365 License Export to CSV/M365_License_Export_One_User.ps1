# Connect to Azure AD
Connect-AzureAD

# Provide UPN of the user
$UserPrincipalName = "jatin.makhija@techpress.net"

# Get the user object for the specific user
$user = Get-AzureADUser -Filter "UserPrincipalName eq '$UserPrincipalName'"

$result = @()

$licenses = Get-AzureADUserLicenseDetail -ObjectId $user.ObjectId

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
$result | Export-Csv -Path "C:\M365_User_License.csv" -NoTypeInformation

Write-Host "Export completed. File saved as C:\M365_User_License.csv"