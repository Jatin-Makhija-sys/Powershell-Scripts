function Get-DotNetSummary {
    $fw = Get-DotNetFramework

    $exe = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'
    $hasDotNetHost = Test-Path $exe

    $runtimes = if ($hasDotNetHost) { Get-DotNetRuntimes } else { @() }
    $sdks     = if ($hasDotNetHost) { Get-DotNetSDKs     } else { @() }

    $hostVersion = $null
    try { $hostVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost' -Name Version -ErrorAction Stop } catch {}

    [pscustomobject]@{
        Framework = $fw
        DotNetHost = [pscustomobject]@{
            Present      = $hasDotNetHost
            Path         = if ($hasDotNetHost) { $exe } else { $null }
            HostVersion  = $hostVersion
        }
        Runtimes = $runtimes
        SDKs     = $sdks
    }
}

Get-DotNetSummary | Format-List