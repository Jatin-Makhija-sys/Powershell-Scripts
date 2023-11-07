#!/bin/bash

# Script: install_font.sh
# Description: This script downloads a font from a specified URL and installs it silently on a macOS system.
# Author: JatinMakhija
# Website: Cloudinfra.net
# Date: 2023-11-06

# Font download URL
font_url='https://cloudinfrasa01.blob.core.windows.net/fonts/JulieRegular.ttf'

# Check if the font file already exists in /Library/Fonts
if [ -f "/Library/Fonts/JulieRegular.ttf" ]; then
  echo "Font already exists in /Library/Fonts. No need to download."
else
  # Download the font to a temporary location
  tmp_file="/tmp/JulieRegular.TTF"
  curl -o "$tmp_file" "$font_url"

  # Check if the download was successful
  if [ $? -eq 0 ]; then
    # Use sudo to copy the font to /Library/Fonts
    sudo cp "$tmp_file" "/Library/Fonts/"
    sudo chown root:wheel "/Library/Fonts/JulieRegular.TTF"
    echo "Font copied to /Library/Fonts successfully."
  else
    echo "Failed to download the font."
  fi

  # Clean up the temporary file
  rm -f "$tmp_file"
fi