@echo off
setlocal EnableExtensions

:: Windows image and system file repair (DISM + SFC)
:: Requires: Run as Administrator

:: Check for Administrator rights
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo This script must be run as Administrator.
  pause
  exit /b 1
)

echo.
echo [1/2] Running DISM /Online /Cleanup-Image /RestoreHealth ...
DISM /Online /Cleanup-Image /RestoreHealth
set DISM_RC=%errorlevel%

echo.
echo [2/2] Running SFC /SCANNOW ...
sfc /scannow
set SFC_RC=%errorlevel%

echo.
echo Completed. (DISM exit code: %DISM_RC%, SFC exit code: %SFC_RC%)
echo If repairs were made, please reboot this device.
pause