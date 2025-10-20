# Detection: Microsoft 365 Companion (user context, exact package)
# Exit 0 if installed for current user; else exit 1.

$ErrorActionPreference = 'SilentlyContinue'

$pkg = Get-AppxPackage -Name 'Microsoft.M365Companions'

if ($pkg) {
    Write-Output "Detected: $($pkg.Name) v$($pkg.Version) (PFN: $($pkg.PackageFamilyName))"
    exit 0
    Pause
} else {
    Write-Output "Not detected: Microsoft.M365Companions (current user)"
    exit 1
    Pause
}