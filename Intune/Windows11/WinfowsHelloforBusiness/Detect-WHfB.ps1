<# 
.SYNOPSIS 
Detect if WHfB is configured for a User
 
.DESCRIPTION 
Below script will check and confirm If WHfB is enabled
for a particular current logged-on user 
.NOTES     
        Name       : Detect-WHfB.ps1
        Author     : Jatin Makhija  
        Version    : 1.0.0  
        DateCreated: 10-Nov-2023
        Blog       : https://cloudinfra.net
         
.LINK 
https://cloudinfra.net 
#>
# Retrieve the current user's Windows principal and SID (Security Identifier)
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUserSid = $currentUser.Identity.User.Value

# Define the registry path for the PIN credential provider
$PINguid = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\{D6886603-9D2F-4EB2-B667-1971041FA96B}"

# Check if the registry path for the PIN credential provider exists
if (Test-Path -Path $PINguid) {
    # Retrieve information from the registry about each SID folder under the PIN credential provider
    $SIDFolders = Get-ChildItem -Path $PINguid | ForEach-Object { Get-ItemProperty $_.PSPath }

    # Check if the SID of the logged-on user is available
    if ($currentUserSid -ne $null -and $currentUserSid -ne '') {
        # Check if the PIN credential provider is in use for the logged-on user and logon credentials are available
        if ($SIDFolders.PSChildName -eq $currentUserSid -and $SIDFolders.LogonCredsAvailable -eq 1) {
            Write-Output "User is enrolled in WHfB."
            Exit 1
        }
        else {
            Write-Output "User is not enrolled in WHfB."
            exit 0
        }
    }
    else {
        Write-Output "Unable to retrieve the SID for the logged-on user."
        exit 0
    }
}
else {
    Write-Output "Registry path for the PIN credential provider was not found."
    exit 0
}
