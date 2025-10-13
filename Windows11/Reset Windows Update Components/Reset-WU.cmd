@echo off
setlocal EnableExtensions

:: Reset Windows Update components (safe/guarded)
:: Requires: Run as Administrator

:: Check for Administrator rights
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo This script must be run as Administrator.
  pause
  exit /b 1
)

echo.
echo [1/6] Stopping services...
for %%S in (wuauserv bits cryptsvc msiserver usosvc dosvc) do (
  net stop %%S >nul 2>&1
)

echo.
echo [2/6] Clearing BITS transfer queue...
del /q /f "%ALLUSERSPROFILE%\Microsoft\Network\Downloader\qmgr*.dat" 2>nul

echo.
echo [2a/6] Clearing Delivery Optimization cache...
if exist "C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache" (
  rd /s /q "C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache" 2>nul
)
md "C:\ProgramData\Microsoft\Windows\DeliveryOptimization\Cache" 2>nul

echo.
echo [3/6] Renaming Windows Update caches...
if exist "%systemroot%\SoftwareDistribution\" ren "%systemroot%\SoftwareDistribution" SoftwareDistribution.old
if exist "%systemroot%\System32\catroot2\"" ren "%systemroot%\System32\catroot2" catroot2.old

echo.
echo [4/6] Resetting WinHTTP proxy and Winsock...
netsh winhttp reset proxy
netsh winsock reset

echo.
echo [5/6] Starting services...
for %%S in (cryptsvc wuauserv bits msiserver usosvc dosvc) do (
  net start %%S >nul 2>&1
)

echo.
echo [6/6] Done. A reboot is recommended (required for the Winsock reset).
pause