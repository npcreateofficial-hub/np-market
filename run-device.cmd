@echo off
setlocal enabledelayedexpansion
set "ROOT=%~dp0"
set "ADB=%ROOT%platform-tools\adb.exe"
set "API_BASE=https://go.np-class.com/np-market"
if not defined SUPABASE_URL set "SUPABASE_URL=https://zptyyrunbshsxdhiuuhq.supabase.co"
if not defined SUPABASE_ANON_KEY set "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpwdHl5cnVuYnNoc3hkaGl1dWhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNTM2NjMsImV4cCI6MjEwMTgyOTY2M30.UwG1szTXf-c6OMOkMW0wkDZpZo4atufQHrHHMSzPD54"

for /d %%J in ("%ProgramFiles%\Microsoft\jdk-17*") do if not defined NP_MARKET_JDK17 set "NP_MARKET_JDK17=%%~fJ"
if defined NP_MARKET_JDK17 (
  set "JAVA_HOME=%NP_MARKET_JDK17%"
  set "PATH=%JAVA_HOME%\bin;%PATH%"
)

if exist "C:\src\flutter\bin\flutter.bat" (
  set "PATH=C:\src\flutter\bin;%PATH%"
)

if not defined GRADLE_USER_HOME (
  set "GRADLE_USER_HOME=%USERPROFILE%\.gradle"
)

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
flutter run -d !DEVICE_ID! --dart-define=NP_MARKET_API_BASE_URL=%API_BASE% --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
