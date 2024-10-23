# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All"

# Define license SKU (replace with your own SKU ID)
# To find the SKU ID, run Get-MgSubscribedSku and note the 'SkuId' of the desired license.
$skuId = "c42b9cae-ea4f-4ab7-9717-81576235ccac"

# Path to the text file containing user UPNs
$userUPNFile = "C:\temp\users.txt"

# Read user Upn from the file
$upnList = Get-Content -Path $userUPNFile

# Loop through each user and assign the license
foreach ($upn in $upnList) {
    $user = Get-MgUser -Filter "userPrincipalName eq '$upn'"
    
    if ($user) {
        # Prepare the license assignment object
        $licenseAssignment = @{
            AddLicenses = @(@{SkuId = $skuId})
            RemoveLicenses = @()
        }

        # Assign license to the user
        try {
            Set-MgUserLicense -UserId $user.Id -AddLicenses $licenseAssignment.AddLicenses -RemoveLicenses $licenseAssignment.RemoveLicenses
            Write-Host "Successfully assigned license to $userEmail"
        } catch {
            Write-Host "Failed to assign license to $userEmail. Error: $_"
        }
    } else {
        Write-Host "User $userEmail not found"
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph