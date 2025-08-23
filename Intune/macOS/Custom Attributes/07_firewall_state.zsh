#!/bin/zsh
# Intune Custom Attribute: macOS Firewall state
# Data type: Integer (1 = enabled, 0 = disabled)
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | /usr/bin/awk -F'= ' '/State/{print ($2+0); exit}'
