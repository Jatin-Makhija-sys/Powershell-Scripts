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
            # Collect user, SKU, and service plan information
            $result += [pscustomobject]@{
                userPrincipalName = $user.UserPrincipalName
                displayName       = $user.DisplayName
                skuPartNumber     = $license.SkuPartNumber
                servicePlanName   = $plan.ServicePlanName
                servicePlanStatus = $plan.ProvisioningStatus
            }
        }
    }
}

# Export result to CSV
$result | Export-Csv -Path "C:\Graph_AllUsers_Licenses.csv" -NoTypeInformation

Write-Host "Export completed. File saved as C:\Graph_AllUsers_Licenses.csv"
