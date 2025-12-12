# Detect-ChromeOutOfDate.ps1
# Exit 0 = compliant, Exit 1 = non-compliant (trigger remediation)

$ErrorActionPreference = 'Stop'

function Get-InstalledChromeVersion {
    $paths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($p in $paths) {
        try {
            $v = (Get-Item $p).VersionInfo.FileVersion
            if ($v) { return [version]$v }
        } catch {}
    }

    # Fallback: system uninstall registry (system-wide installs)
    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path $root)) { continue }
        $apps = Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        }
        $chrome = $apps | Where-Object { $_.DisplayName -eq "Google Chrome" -and $_.DisplayVersion } | Select-Object -First 1
        if ($chrome) { return [version]$chrome.DisplayVersion }
    }

    return $null
}

function Get-LatestStableChromeVersion {
    # VersionHistory API: list stable versions for Windows, pick highest
    # Docs: https://versionhistory.googleapis.com/v1 (Chrome for Developers)
    $uri = "https://versionhistory.googleapis.com/v1/chrome/platforms/win/channels/stable/versions?order_by=version%20desc"

    $resp = Invoke-RestMethod -Method Get -Uri $uri -UseBasicParsing
    if (-not $resp.versions -or $resp.versions.Count -lt 1) {
        throw "VersionHistory API returned no versions."
    }

    # versions[].version is a string like 126.0.6478.127
    return [version]$resp.versions[0].version
}

$installed = Get-InstalledChromeVersion
if (-not $installed) {
    # If Chrome isn't installed system-wide, treat as compliant to avoid endless remediation loops.
    exit 0
}

$latest = Get-LatestStableChromeVersion

if ($installed -lt $latest) {
    Write-Output "Out of date. Installed=$installed LatestStable=$latest"
    exit 1
}

Write-Output "Up to date. Installed=$installed LatestStable=$latest"
exit 0