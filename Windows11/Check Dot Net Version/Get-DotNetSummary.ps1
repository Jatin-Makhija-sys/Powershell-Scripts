<# 
.SYNOPSIS
    Collects .NET Framework, .NET runtime, and SDK information
.DESCRIPTION
    Self-contained script that defines helper functions and prints summary.
.NOTES
    Author: Jatin Makhija
    Version: 1.0
#>

# --- Helper functions ---

function Get-DotNetFramework {
    $reg = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    if (-not (Test-Path $reg)) { return $null }

    $p = Get-ItemProperty $reg
    $rel = [int]$p.Release

    $map = @(
        @{ MinRelease = 533325; Version = '4.8.1' }
        @{ MinRelease = 528040; Version = '4.8'   }
        @{ MinRelease = 461808; Version = '4.7.2' }
        @{ MinRelease = 461308; Version = '4.7.1' }
        @{ MinRelease = 460798; Version = '4.7'   }
        @{ MinRelease = 394802; Version = '4.6.2' }
        @{ MinRelease = 394254; Version = '4.6.1' }
        @{ MinRelease = 393295; Version = '4.6'   }
        @{ MinRelease = 379893; Version = '4.5.2' }
        @{ MinRelease = 378675; Version = '4.5.1' }
        @{ MinRelease = 378389; Version = '4.5'   }
    )

    $ver = ($map | Where-Object { $rel -ge $_.MinRelease } | Select-Object -First 1).Version
    [pscustomobject]@{
        Product     = '.NET Framework'
        Version     = $ver
        Release     = $rel
        Install     = $p.Install
        InstallPath = $p.InstallPath
    }
}

function Get-DotNetRuntimes {
    $exe = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    if (-not (Test-Path $exe)) { return @() }
    & $exe --list-runtimes | ForEach-Object {
        if ($_ -match '^(?<Name>\S+)\s+(?<Version>\S+)\s+\[(?<Path>[^\]]+)\]') {
            [pscustomobject]@{ Type='Runtime'; Name=$matches.Name; Version=$matches.Version; Path=$matches.Path }
        }
    }
}

function Get-DotNetSDKs {
    $exe = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    if (-not (Test-Path $exe)) { return @() }
    & $exe --list-sdks | ForEach-Object {
        if ($_ -match '^(?<Version>\S+)\s+\[(?<Path>[^\]]+)\]') {
            [pscustomobject]@{ Type='SDK'; Name='SDK'; Version=$matches.Version; Path=$matches.Path }
        }
    }
}

# --- Main function ---

function Get-DotNetSummary {
    $fw = Get-DotNetFramework
    $exe = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    $hasDotNetHost = Test-Path $exe

    $runtimes = if ($hasDotNetHost) { Get-DotNetRuntimes } else { @() }
    $sdks     = if ($hasDotNetHost) { Get-DotNetSDKs     } else { @() }

    $hostVersion = $null
    try { 
        $hostVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost' -Name Version -ErrorAction Stop 
    } catch {}

    [pscustomobject]@{
        Framework  = $fw
        DotNetHost = [pscustomobject]@{
            Present     = $hasDotNetHost
            Path        = if ($hasDotNetHost) { $exe } else { $null }
            HostVersion = $hostVersion
        }
        Runtimes = $runtimes
        SDKs     = $sdks
    }
}

# --- Run ---
Get-DotNetSummary | Format-List