#!/bin/zsh
# Intune Custom Attribute: Company Portal version
# Data type: String (semantic version, e.g., 5.2409.0)
plist="/Applications/Company Portal.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || echo ""
