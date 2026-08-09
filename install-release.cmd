@echo off
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "ADB=%ROOT%platform-tools\adb.exe"
set "APK=%ROOT%build\app\outputs\flutter-apk\app-release.apk"

if not exist "%ADB%" (
  echo [NP Market] Missing adb.exe:
  echo %ADB%
  pause
  exit /b 1
)

if not exist "%APK%" (
  echo [NP Market] Missing APK:
  echo %APK%
  echo Run build-release.cmd first.
  pause
  exit /b 1
)

set "PATH=%ROOT%platform-tools;%PATH%"
"%ADB%" start-server >nul

for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices') do (
  if "%%B"=="device" (
    set "DEVICE_ID=%%A"
    goto :found
  )
)

echo [NP Market] No Android device found.
"%ADB%" devices -l
pause
exit /b 1

:found
echo [NP Market] Installing to !DEVICE_ID!
"%ADB%" -s !DEVICE_ID! install -r "%APK%"
pause
