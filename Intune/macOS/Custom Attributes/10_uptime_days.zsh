#!/bin/zsh
# Intune Custom Attribute: Uptime (days)
# Data type: Integer (non-negative integer)
now=$(/bin/date +%s)
bt_epoch=$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null | /usr/bin/sed -E 's/.*sec = ([0-9]+).*/\1/')
if [[ "$bt_epoch" == <-> ]]; then
  echo $(( (now - bt_epoch) / 86400 ))
else
  echo "0"
fi
