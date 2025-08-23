#!/bin/zsh
# Intune Custom Attribute: Secure Enclave present
# Data type: String (expected outputs: Yes or No)
if [[ "$(/usr/sbin/sysctl -n hw.optional.arm64 2>/dev/null)" == "1" ]]; then
  echo "Yes"
else
  /usr/sbin/system_profiler SPiBridgeDataType 2>/dev/null | /usr/bin/awk -F': ' '/Model Name/ {print ($2=="Apple T2 Security Chip")?"Yes":"No"; found=1; exit} END{if(!found) print "No"}'
fi
