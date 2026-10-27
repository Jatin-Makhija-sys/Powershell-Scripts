# These values identify the Microsoft Entra tenant and the app registration used for certificate-based authentication.
$TenantId = '9dcda47d-f87c-44dd-a9ee-2243d525559e'
$ClientId = 'ac8a9c49-0d6b-447c-8ed0-c34339add967'
$Thumbprint = 'C65C3975F312897103544953630F1E7E37A6FD52'

# Load the certificate from the CurrentUser personal store by thumbprint.
# This certificate must be trusted and usable by the script account.
$Certificate = Get-Item -Path "Cert:\CurrentUser\My\$Thumbprint"

# Ensure the certificate includes a private key before attempting Graph authentication.
if (-not $Certificate.HasPrivateKey) {
    throw 'The certificate must have an accessible private key.'
}

# Connect to Microsoft Graph using the certificate instead of a user interactive sign-in.
# -ContextScope Process keeps the connection scoped to the current PowerShell process.
# -NoWelcome suppresses the welcome banner.
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $Certificate -ContextScope Process -NoWelcome

# Run the inactive user review export script in a try/finally block so the session is cleaned up even if the export fails.
try {
    # This script generates the CSV report for inactive users over the specified threshold.
    & 'C:\temp\Scripts\Export-InactiveUserReview.ps1' -InactiveDays 90 -OutputPath 'C:\Reports\UserSignInReview_v5.csv'
}
finally {
    # Always disconnect from Graph to avoid leaving an open session behind.
    Disconnect-MgGraph | Out-Null
}