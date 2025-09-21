Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' -MaxEvents 3000 |
  Where-Object Id -eq 3076 |
  ForEach-Object {
    if ($_.Message -match '(?s)attempted to load\s+(?<path>.+?)\s+that did not meet.*Policy ID:\{(?<policyid>[0-9a-fA-F\-]+)\}\)\.\s+(?<action>.+)$') {
      [pscustomobject]@{
        TimeCreated                      = $_.TimeCreated
        AttemptedPath                    = $matches['path']
        'Violated Code Integrity Policy' = $matches['policyid']
        ActionTaken                      = $matches['action']
      }
    }
  } | Format-Table -AutoSize