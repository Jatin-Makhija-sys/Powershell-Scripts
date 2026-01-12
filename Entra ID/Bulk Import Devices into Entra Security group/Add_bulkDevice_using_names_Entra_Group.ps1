Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.DirectoryManagement

$GroupId = "<EntraSecurityGroupObjectId>"
$DeviceNames = @("PC-001","PC-002")

Connect-MgGraph -Scopes "Device.Read.All","GroupMember.ReadWrite.All" | Out-Null

foreach ($name in $DeviceNames) {
    $deviceResults = Get-MgDevice -Filter "displayName eq '$name'" -Property Id,DisplayName

    if (-not $deviceResults) {
        Write-Warning "Not found: $name"
        continue
    }

    if ($deviceResults.Count -gt 1) {
        Write-Warning "Multiple matches for $name. Skipping."
        continue
    }

    $deviceId = $deviceResults.Id
    try {
        New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"
        } | Out-Null
        Write-Host "Added $name ($deviceId)"
    }
    catch {
        Write-Warning "Failed for $name. $($_.Exception.Message)"
    }
}

Disconnect-MgGraph | Out-Null