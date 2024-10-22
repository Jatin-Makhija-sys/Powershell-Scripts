# Connect to Azure AD
Connect-AzureAD

# Get all users
$users = Get-AzureADUser -All $true

$result = @()

foreach ($user in $users) {
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
}

$result | Export-Csv -Path "C:\M365_Users_Licenses_All.csv" -NoTypeInformation
Write-Host "Export completed. File saved as C:\M365_Users_Licenses_All.csv"