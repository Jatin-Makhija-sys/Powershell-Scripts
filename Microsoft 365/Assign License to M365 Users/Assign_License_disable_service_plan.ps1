# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Define the SKU ID, User UPN, and Service Plan IDs to disable
$skuId = "c42b9cae-ea4f-4ab7-9717-81576235ccac"
$userUPN = "jack@techpress.net"
$disabledPlans = @("199a5c09-e0ca-4e37-8f7c-b05d533e1ea2")

# Get the user and assign the license with disabled services
$user = Get-MgUser -Filter "userPrincipalName eq '$userUPN'"
if ($user) {
    Set-MgUserLicense -UserId $user.Id -AddLicenses @(@{SkuId = $skuId; DisabledPlans = $disabledPlans}) -RemoveLicenses @()
    Write-Host "License assigned with disabled services to $userUPN"
} else {
    Write-Host "User $userUPN not found"
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph | out-null