#!/bin/zsh
# Intune Custom Attribute: Battery cycle count
# Data type: Integer (non-negative integer; blank if not available)
/usr/sbin/system_profiler SPPowerDataType -detailLevel mini 2>/dev/null | /usr/bin/awk -F': ' '/Cycle Count/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; found=1; exit} END{if(!found) print ""}'
