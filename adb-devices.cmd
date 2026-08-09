@echo off
setlocal
set "ROOT=%~dp0"
set "ADB=%ROOT%platform-tools\adb.exe"

if not exist "%ADB%" (
  echo [NP Market] Missing adb.exe:
  echo %ADB%
  echo.
  echo Put Android platform-tools in:
  echo %ROOT%platform-tools
  pause
  exit /b 1
)

set "PATH=%ROOT%platform-tools;%PATH%"

echo [NP Market] Using ADB:
echo %ADB%
echo.

"%ADB%" kill-server >nul 2>nul
"%ADB%" start-server
echo.
"%ADB%" devices -l
echo.
echo If the list is empty, unlock the phone, approve USB debugging, then run this again.
pause
