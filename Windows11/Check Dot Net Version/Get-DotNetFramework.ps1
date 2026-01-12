function Get-DotNetFramework {
    $reg = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    if (-not (Test-Path $reg)) { return $null }

    $p = Get-ItemProperty $reg
    $rel = [int]$p.Release

    # Mapping uses "greater-or-equal" thresholds to cover cumulative updates
    $map = @(
        @{ MinRelease = 533325; Version = '4.8.1' }  # 4.8.1
        @{ MinRelease = 528040; Version = '4.8'   }  # 4.8 base
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
Get-DotNetFramework