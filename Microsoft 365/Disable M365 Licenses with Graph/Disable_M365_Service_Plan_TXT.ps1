<#
.DESCRIPTION
    This script will disable specified service plans for multiple M365 Users
    while keeping the existing licenses disabled.
    Author: Jatin Makhija
    Website: Copyright - techpress.net
    Version: 1.1.0
#>

# Connect to Microsoft Graph
Connect-MgGraph -Scopes User.ReadWrite.All -NoWelcome

# Path to the text file containing user UPNs (one per line)
$usersFile = "C:\temp\users.txt"

# Specify the license SKU part number (e.g., "DeveloperPack_E5")
$license = "DeveloperPack_E5"

# Specify the service plans to disable (e.g., "SWAY", "YAMMER_ENTERPRISE")
$servicePlansToDisable = @("SWAY", "YAMMER_ENTERPRISE")

$sku = Get-MgSubscribedSku -All | Where-Object { $_.SkuPartNumber -eq $license }

# Get service plan IDs for the plans to disable
$newDisabledPlans = $sku.ServicePlans | Where-Object { $_.ServicePlanName -in $servicePlansToDisable } | Select-Object -ExpandProperty ServicePlanId

# Read users from the text file and process each one
Get-Content -Path $usersFile | ForEach-Object {
    $userUPN = $_.Trim()

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

        Set-MgUserLicense -UserId $userUPN -AddLicenses $addLicenses -RemoveLicenses @()

        Write-Host "Updated licenses for $userUPN"
    } else {
        Write-Host "Skipping empty line in the file."
    }
}

Write-Host "License update process completed."