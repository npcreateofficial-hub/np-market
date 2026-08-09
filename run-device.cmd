@echo off
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "ADB=%ROOT%platform-tools\adb.exe"
set "API_BASE=https://go.np-class.com/np-market"

if not exist "%ADB%" (
  echo [NP Market] Missing adb.exe:
  echo %ADB%
  pause
  exit /b 1
)

set "PATH=%ROOT%platform-tools;%PATH%"

echo [NP Market] Using ADB:
echo %ADB%
echo.

"%ADB%" start-server >nul

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
  if "%%B"=="device" (
    set "DEVICE_ID=%%A"
    goto :found
  )
)

echo [NP Market] No Android device found.
echo.
"%ADB%" devices -l
echo.
echo Unlock the phone, approve USB debugging, reconnect USB, then run this again.
pause
exit /b 1

:found
echo [NP Market] Found device: !DEVICE_ID!
echo [NP Market] API: %API_BASE%
echo.
flutter run -d !DEVICE_ID! --dart-define=NP_MARKET_API_BASE_URL=%API_BASE%
