#!/bin/zsh
# Intune Custom Attribute: Local admin count
# Data type: Integer (0 or greater)
members=$(/usr/bin/dscl . -read /Groups/admin GroupMembership 2>/dev/null | /usr/bin/cut -d ' ' -f2-)
count=$(echo "$members" | /usr/bin/awk '{print NF}')
echo ${count:-0}
