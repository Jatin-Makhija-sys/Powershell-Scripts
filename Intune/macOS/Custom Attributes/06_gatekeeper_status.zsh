#!/bin/zsh
# Intune Custom Attribute: Gatekeeper (App assessment)
# Data type: String (expected outputs: Enabled or Disabled)
/usr/sbin/spctl --status 2>/dev/null | /usr/bin/grep -qi "enabled" && echo "Enabled" || echo "Disabled"
