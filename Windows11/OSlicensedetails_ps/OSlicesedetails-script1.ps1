<#
.DESCRIPTION
    This script will get Windows OS details like license name,
     Product key information etc. 
    Author: Jatin Makhija
    Website: Copyright - Cloudinfra.net
    Version: 1.0.0
#>
# Define color codes for better formatting
$foregroundColor = "Yellow"
$backgroundColor = "Black"

# Retrieve OS License Information

# Get the license object with a valid partial product key
$license = Get-WmiObject -Class SoftwareLicensingProduct | Where-Object { $_.PartialProductKey -ne $null }

# Get the original product key from SoftwareLicensingService
$productKey = (Get-WmiObject -Query 'select * from SoftwareLicensingService').OA3xOriginalProductKey

# Display License Details with colors
Write-Host "Operating System License Details:" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
Write-Host "---------------------------------" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
Write-Host "License Name: $($license.Name)" -ForegroundColor $foregroundColor
Write-Host "Description: $($license.Description)" -ForegroundColor $foregroundColor
Write-Host "Application ID: $($license.ApplicationId)" -ForegroundColor $foregroundColor
Write-Host "Product Key Channel: $($license.ProductKeyChannel)" -ForegroundColor $foregroundColor
Write-Host "Use License URL: $($license.UseLicenseURL)" -ForegroundColor $foregroundColor
Write-Host "Validation URL: $($license.ValidationURL)" -ForegroundColor $foregroundColor
Write-Host "Partial Product Key: $($license.PartialProductKey)" -ForegroundColor $foregroundColor
Write-Host "Product Key ID: $($license.ProductKeyID)" -ForegroundColor $foregroundColor
Write-Host "License Status: $($license.LicenseStatus)" -ForegroundColor $foregroundColor
Write-Host "Product Key: $productKey" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor