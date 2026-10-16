$User = Get-MgUser -UserId 'jatin.makhija@cloudinfra.net' -ErrorAction Stop
$Since = [DateTimeOffset]::UtcNow.AddDays(-30).ToString(
    "yyyy-MM-dd'T'HH:mm:ss'Z'"
)

$Filter = "userId eq '$($User.Id)' and createdDateTime ge $Since and status/errorCode eq 0 and isInteractive eq true"
$Event = Get-MgAuditLogSignIn -Filter $Filter -Top 1 -ErrorAction Stop

if ($Event) {
    $Event | Select-Object CreatedDateTime, UserDisplayName,
        UserPrincipalName, AppDisplayName, IpAddress,
        @{Name='DeviceName'; Expression={$_.DeviceDetail.DisplayName}},
        @{Name='OperatingSystem'; Expression={$_.DeviceDetail.OperatingSystem}}
}
else {
    Write-Host 'No matching successful interactive event in the available logs.'
}