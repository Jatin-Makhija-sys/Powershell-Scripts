#!/bin/zsh
# Intune Custom Attribute: Rosetta installed (Apple Silicon)
# Data type: String (expected outputs: Yes or No)
/usr/sbin/pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1 && echo "Yes" || echo "No"
