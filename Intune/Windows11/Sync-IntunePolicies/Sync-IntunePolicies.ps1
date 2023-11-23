try {
    # Install required modules
    Install-Module -Name Microsoft.Graph.DeviceManagement -Force -ErrorAction Stop
    Install-Module -Name Microsoft.Graph.DeviceManagement.Actions -Force -ErrorAction Stop

    # Import required modules
    Import-Module -Name Microsoft.Graph.DeviceManagement -ErrorAction Stop
    Import-Module -Name Microsoft.Graph.DeviceManagement.Actions -ErrorAction Stop

    # Connect to Microsoft Graph
    Connect-MgGraph -scope DeviceManagementManagedDevices.PrivilegedOperations.All, DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementManagedDevices.Read.All -ErrorAction Stop

    # Get all managed devices
    $managedDevices = Get-MgDeviceManagementManagedDevice -All -ErrorAction Stop

    # Synchronize each managed device
    foreach ($device in $managedDevices) {
        try {
            Sync-MgDeviceManagementManagedDevice -ManagedDeviceId $device.Id -ErrorAction Stop
            Write-Host "Invoking Intune Sync for $($device.DeviceName)" -ForegroundColor Yellow
        }
        catch {
            Write-Error "Failed to sync device $($device.DeviceName). Error: $_"
        }
    }
}
catch {
    Write-Error "An error occurred. Error: $_"
}
finally {
    # Cleanup
    Remove-Module -Name Microsoft.Graph.DeviceManagement -ErrorAction SilentlyContinue
    Remove-Module -Name Microsoft.Graph.DeviceManagement.Actions -ErrorAction SilentlyContinue
}
