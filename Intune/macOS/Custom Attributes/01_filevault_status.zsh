#!/bin/zsh
# Intune Custom Attribute: FileVault status
# Data type: String (expected outputs: On or Off)
status=$(/usr/bin/fdesetup status 2>/dev/null)
if [[ "$status" == *"On."* ]]; then
  echo "On"
else
  echo "Off"
fi
