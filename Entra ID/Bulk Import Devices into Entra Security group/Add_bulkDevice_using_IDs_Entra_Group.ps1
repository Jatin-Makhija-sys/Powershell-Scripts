# Requires: Microsoft.Graph PowerShell SDK
# Install-Module Microsoft.Graph -Scope CurrentUser

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups

$GroupId = "<EntraSecurityGroupObjectId>"
$CsvPath = "C:\Temp\DevicesToAdd.csv"

# Delegated permissions (interactive). For app-only, use certificate/secret auth and ensure proper app permissions.
Connect-MgGraph -Scopes "GroupMember.ReadWrite.All" | Out-Null

$devices = Import-Csv $CsvPath

foreach ($d in $devices) {
    $deviceId = $d.DeviceObjectId.Trim()
    if ([string]::IsNullOrWhiteSpace($deviceId)) { continue }

    try {
        # Add directory object reference (device) to the group
        New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"
        } | Out-Null

        Write-Host "Added device to group: $deviceId"
    }
    catch {
        Write-Warning "Failed for $deviceId. $($_.Exception.Message)"
    }
}

Disconnect-MgGraph | Out-Null