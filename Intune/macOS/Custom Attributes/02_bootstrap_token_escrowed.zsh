#!/bin/zsh
# Intune Custom Attribute: Bootstrap Token escrowed to MDM
# Data type: String (expected outputs: YES or NO)
out=$(/usr/bin/profiles status -type bootstraptoken 2>/dev/null)
# Example line: "Escrowed to server: YES"
echo "$out" | /usr/bin/awk -F': *' 'BEGIN{IGNORECASE=1}/Escrowed to server/{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print toupper($2); found=1} END{if(!found) print ""}'
