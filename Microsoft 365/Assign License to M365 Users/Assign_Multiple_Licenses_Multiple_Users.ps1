# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All"

# Path to the text files containing user UPNs and SKU IDs
$userUPNFile = "C:\Path\To\users.txt"  # Renamed variable
$skuFile = "C:\Path\To\skuids.txt"

# Read user UPNs and SKU IDs from the respective files
$upnList = Get-Content -Path $userUPNFile  
$skuIds = Get-Content -Path $skuFile

# Loop through each user and assign the licenses
foreach ($upn in $upnList) {  # Renamed variable
    # Get user by UPN
    $user = Get-MgUser -Filter "userPrincipalName eq '$upn'"  # Renamed variable
    
    if ($user) {
        # Prepare the license assignment object
        $licenseAssignment = @{
            AddLicenses = @()
            RemoveLicenses = @()
        }

        # Add all SKU IDs from the skuids.txt file to the AddLicenses array
        foreach ($skuId in $skuIds) {
            $licenseAssignment.AddLicenses += @{SkuId = $skuId}
        }

        # Assign licenses to the user
        try {
            Set-MgUserLicense -UserId $user.Id -AddLicenses $licenseAssignment.AddLicenses -RemoveLicenses $licenseAssignment.RemoveLicenses
            Write-Host "Successfully assigned licenses to $upn"  # Renamed variable
        } catch {
            Write-Host "Failed to assign licenses to $upn. Error: $_"  # Renamed variable
        }
    } else {
        Write-Host "User $upn not found"  # Renamed variable
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
