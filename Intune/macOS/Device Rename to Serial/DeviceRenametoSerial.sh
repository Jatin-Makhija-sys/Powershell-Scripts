#!/bin/bash
#
# TechPress.net | Rename macOS device to Serial (Intune)
# Original Author: paoloma@microsoft.com
# Original Ref: (Microsoft Github) macOS/Config/DeviceRename/DeviceRename2.sh
# Modified by: Jatin Makhija (techpress.net)
# Version: 1.0
# Summary: Renames a Mac to its serial number only. Toggle scope to ABM, BYOD, or ALL.
# Usage: Set TARGET_SCOPE, deploy as an Intune shell script.
# Requirements: Run as root. macOS 12+.
# Logging: /Library/Logs/Microsoft/IntuneScripts/DeviceRename/DeviceRename.log

# ===== Toggle scope =====
# Set to one of: ABM | BYOD | ALL
TARGET_SCOPE="ALL"

appname="DeviceRename"
logdir="/Library/Logs/Microsoft/IntuneScripts/$appname"
log="$logdir/$appname.log"

mkdir -p "$logdir"
exec &> >(tee -a "$log")

echo ""
echo "##############################################################"
echo "# $(date) | Starting $appname"
echo "##############################################################"

# Detect ABM (DEP) enrollment: returns "Yes" or "No"
dep_status="$(profiles status -type enrollment 2>/dev/null | awk -F': ' '/Enrolled via DEP/ {print $2}')"
dep_status="${dep_status:-No}"  # default to No if not found
echo "$(date) | ABM (DEP) enrollment: $dep_status"

# Scope filter
case "$TARGET_SCOPE" in
  "ABM")
    if [ "$dep_status" != "Yes" ]; then
      echo "$(date) | Skipping: BYOD device and scope is ABM."
      exit 0
    fi
    ;;
  "BYOD")
    if [ "$dep_status" = "Yes" ]; then
      echo "$(date) | Skipping: ABM device and scope is BYOD."
      exit 0
    fi
    ;;
  "ALL") : ;;  # proceed
  *)
    echo "$(date) | Invalid TARGET_SCOPE '$TARGET_SCOPE'. Use ABM, BYOD, or ALL."
    exit 1
    ;;
esac

# Get serial (fast, reliable)
SerialNum="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformSerialNumber/ {print $4}')"
if [ -z "$SerialNum" ]; then
  echo "$(date) | Unable to determine serial number."
  exit 1
fi
echo "$(date) | Serial: $SerialNum"

NewName="$SerialNum"

# Current names
CurrentCN="$(scutil --get ComputerName 2>/dev/null || true)"
CurrentHN="$(scutil --get HostName 2>/dev/null || true)"
CurrentLHN="$(scutil --get LocalHostName 2>/dev/null || true)"
echo "$(date) | Current ComputerName: ${CurrentCN:-<unset>}"
echo "$(date) | Current HostName: ${CurrentHN:-<unset>}"
echo "$(date) | Current LocalHostName: ${CurrentLHN:-<unset>}"
echo "$(date) | Target name: $NewName"

# Short-circuit if already set
if [ "$CurrentCN" = "$NewName" ] && [ "$CurrentHN" = "$NewName" ] && [ "$CurrentLHN" = "$NewName" ]; then
  echo "$(date) | Rename not required. Already set."
  exit 0
fi

# Apply names
if scutil --set ComputerName "$NewName"; then
  echo "$(date) | ComputerName set to $NewName"
else
  echo "$(date) | Failed to set ComputerName"
  exit 1
fi

if scutil --set HostName "$NewName"; then
  echo "$(date) | HostName set to $NewName"
else
  echo "$(date) | Failed to set HostName"
  exit 1
fi

if scutil --set LocalHostName "$NewName"; then
  echo "$(date) | LocalHostName set to $NewName"
else
  echo "$(date) | Failed to set LocalHostName"
  exit 1
fi

echo "$(date) | Rename complete."
exit 0