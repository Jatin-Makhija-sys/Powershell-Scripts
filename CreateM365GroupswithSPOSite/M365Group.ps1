Function Create-M365GroupwithSPOSite {
<#
.SYNOPSIS
Create Microsoft 365 Groups in bulk along with Sharepoint Sites.If Teams Column value is Y
Teams Site will also be linked to the group else Teams Site will not be linked/created. 

.DESCRIPTION
This is Create-M365GroupwithSPOSite Function which can be used to create Microsoft 365 Groups
with Sharepoint Sites (with or without Teams). 

.PARAMETER CSVFilePath
Path to the CSV file containing group information.

.NOTES
    Author     : Jatin Makhija
    Version    : 1.0.2
    DateCreated: 13-08-2021
    DateUpdated: 24-08-2021
    Blog       : https://www.techpress.net

.EXAMPLE
PS> Create-M365GroupwithSPOSite -CSVFilePath "C:\Path\To\Groups.csv" -Verbose
#>

    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, Position = 0, HelpMessage = "Please Enter the Path to CSV File")]
        [string]$CSVFilePath
    )

    # Check PowerShell version
    if ($PSVersionTable.PSVersion -lt [Version]"7.2") {
        Write-Warning "This script requires PowerShell version 7.2 or later. Please upgrade PowerShell and try again."
        return
    }

    # Log setup
    $LogFolder = "C:\Apps\Logs"
    $LogFile = Join-Path -Path $LogFolder -ChildPath "M365GroupLog-$(Get-Date -Format 'MM-dd-yyyy_hh-mm-ss').csv"
    if (!(Test-Path -Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder | Out-Null
    } else {
        Write-Verbose "Log folder exists at $LogFolder"
    }

    Function LogWrite {
        param ([string]$LogString)
        Add-Content -Path $LogFile -Value $LogString
    }

    # Check for PnP PowerShell module
    Try {
        if (!(Get-Module -Name "PnP.PowerShell" -ListAvailable)) {
            Write-Host "PnP.PowerShell module is not available" -ForegroundColor Yellow
            if ((Read-Host "Install module? [Y/N]") -match "[yY]") {
                Install-Module -Name "PnP.PowerShell" -Force -Confirm:$False
                Import-Module -Name "PnP.PowerShell" -ErrorAction Stop
            } else {
                Write-Warning "PnP PowerShell module is required."
                Exit
            }
        }
    } Catch {
        Write-Warning "Failed to load PnP PowerShell module: $_"
        return
    }

    # Connection details
    $arrayOfOwners = "jmakhija@techpress.net", "jack@techpress.net"
    $arrayOfMembers = "joniS@cloudinfra.net"
    $Params = @{
        ClientId            = "00bc65aa-c125-9999-aba6-fde345245aa3"
        CertificatePath     = "C:\TechPress.pfx"
        CertificatePassword = (Read-Host -Prompt "Enter PFX Password" -AsSecureString)
        Url                 = "https://8756dvgy.sharepoint.com/"
        Tenant              = "8756dvgy.onmicrosoft.com"
    }

    Write-Host "Connecting to PnP Online" -ForegroundColor Blue -BackgroundColor White
    Connect-PnPOnline @Params

    # Processing CSV
    Import-Csv -Path $CSVFilePath | ForEach-Object {
        $displayName = $_.displayname
        $nickname = $_.nickname
        $description = $_.description
        $teams = $_.Teams

        if (Get-PnPMicrosoft365Group -Identity $displayName) {
            Write-Verbose "M365 Group '$displayName' already exists"
            LogWrite "$displayName * Already Exists"
        } else {
            $groupParams = @{
                DisplayName   = $displayName
                Description   = $description
                MailNickname  = $nickname
                Owners        = $arrayOfOwners
                Members       = $arrayOfMembers
                IsPrivate     = $true
            }

            if ($teams -eq 'Y') {
                Write-Verbose "Creating M365 Group + SPO Site with connected Teams for '$displayName'"
                $groupParams.Add("CreateTeam", $true)
                Try {
                    New-PnPMicrosoft365Group @groupParams | Out-Null
                    LogWrite "$displayName * Created with Teams Site"
                } Catch {
                    LogWrite "$displayName * Creation failed with Teams"
                }
            } else {
                Write-Verbose "Creating M365 Group + SPO Site without Teams for '$displayName'"
                Try {
                    New-PnPMicrosoft365Group @groupParams | Out-Null
                    LogWrite "$displayName * Created without Teams Site"
                } Catch {
                    LogWrite "$displayName * Creation failed without Teams"
                }
            }
        }
    }
}
