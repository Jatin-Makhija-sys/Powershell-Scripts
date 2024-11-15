(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*Teams*" }) | 
    ForEach-Object { 
        Write-Output "Removing provisioned package: $($_.PackageName)" 
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue 
    }

$installedTeams = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*Teams*" }
if ($installedTeams) {
    $installedTeams | ForEach-Object { 
        Write-Output "Removing installed package: $($_.PackageFullName)" 
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue 
    }
} else {
    Write-Output "No installed package for Microsoft Teams found."
}

Write-Output "Microsoft Teams removal process completed."