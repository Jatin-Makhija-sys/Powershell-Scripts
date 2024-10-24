<#
.DESCRIPTION
    This script will disable specified service plans for all M365 Users
    while keeping the existing licenses disabled.
    Author: Jatin Makhija
    Website: Copyright - techpress.net
    Version: 1.2.0
#>

# Connect to Microsoft Graph
Connect-MgGraph -Scopes User.ReadWrite.All

# Specify the license SKU part number (e.g., "DeveloperPack_E5")
$license = "DeveloperPack_E5"

# Specify the service plans to disable (e.g., "SWAY", "YAMMER_ENTERPRISE")
$servicePlansToDisable = @("SWAY", "YAMMER_ENTERPRISE")

# Get the SKU for the specified license
$sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $license }

# Get service plan IDs for the plans to disable
$newDisabledPlans = $sku.ServicePlans | Where-Object { $_.ServicePlanName -in $servicePlansToDisable } | Select-Object -ExpandProperty ServicePlanId

# Get all users in the tenant
$users = Get-MgUser -All

foreach ($user in $users) {
    $userUPN = $user.UserPrincipalName

    if ($userUPN -ne "") {
        $userLicense = Get-MgUserLicenseDetail -UserId $userUPN

        # Get currently disabled service plans for the user
        $disabledPlans = $userLicense.ServicePlans | Where-Object { $_.ProvisioningStatus -eq "Disabled" } | Select-Object -ExpandProperty ServicePlanId

        $allDisabledPlans = @()
        $allDisabledPlans += $disabledPlans
        $allDisabledPlans += $newDisabledPlans

        $allDisabledPlans = $allDisabledPlans | Sort-Object -Unique

        $addLicenses = @(@{
            SkuId         = $sku.SkuId
            DisabledPlans = $allDisabledPlans # This will be an array of IDs
        })

        # Update user's license
        Set-MgUserLicense -UserId $userUPN -AddLicenses $addLicenses -RemoveLicenses @()

        Write-Host "Updated licenses for $userUPN"
    } else {
        Write-Host "Skipping user with no UPN."
    }
}

Write-Host "License update process completed."