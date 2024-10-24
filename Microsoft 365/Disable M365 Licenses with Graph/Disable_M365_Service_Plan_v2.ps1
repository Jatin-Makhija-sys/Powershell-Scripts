<#
.DESCRIPTION
    This script will disable give licenses for a M365 Users while
    still keeping the existing licenses disabled
    Author: Jatin Makhija
    Website: Copyright - techpress.net
    Version: 1.0.0
#>

# Connect to Microsoft Graph
Connect-MgGraph -Scopes User.ReadWrite.All

#Provide user's UPN
$userUPN = "jack@techpress.net"
$license = "DeveloperPack_E5"

# Get user's license details
$userLicense = Get-MgUserLicenseDetail -UserId $userUPN
$disabledPlans = $userLicense.ServicePlans | Where-Object { $_.ProvisioningStatus -eq "Disabled" } | Select-Object -ExpandProperty ServicePlanId

# Get the SKU for the specified license
$sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $license }
$newDisabledPlans = $sku.ServicePlans | Where-Object { $_.ServicePlanName -in ("SWAY", "YAMMER_ENTERPRISE") } | Select-Object -ExpandProperty ServicePlanId

$allDisabledPlans = @()
$allDisabledPlans += $disabledPlans
$allDisabledPlans += $newDisabledPlans

# Create the addLicenses array
$addLicenses = @(@{
    SkuId         = $sku.SkuId
    DisabledPlans = $allDisabledPlans # This will be an array of IDs
})

# Update user's license
Set-MgUserLicense -UserId $userUPN -AddLicenses $addLicenses -RemoveLicenses @()