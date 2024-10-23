# Specify the userPrincipalName of the user you want to check
$userPrincipalName = "jatin.makhija@techpress.net"

# Get user information using Microsoft Graph
$user = Get-MgUser -UserId $userPrincipalName

# Get assigned licenses for the specific user
$licenses = Get-MgUserLicenseDetail -UserId $user.Id

$result = @()

foreach ($license in $licenses) {
    foreach ($plan in $license.ServicePlans) {
        $result += [pscustomobject]@{
            userPrincipalName = $user.UserPrincipalName
            displayName       = $user.DisplayName
            skuPartNumber     = $license.SkuPartNumber
            servicePlanName   = $plan.ServicePlanName
            servicePlanStatus = $plan.ProvisioningStatus
        }
    }
}

# Export result to CSV
$result | Export-Csv -Path "C:\M365_User_Licenses.csv" -NoTypeInformation
Write-Host "Export completed. File saved as C:\M365_User_Licenses.csv"
