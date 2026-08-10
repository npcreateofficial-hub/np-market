@echo off
setlocal
set "ROOT=%~dp0"
set "API_BASE=https://go.np-class.com/np-market"
set "DART_SUPPRESS_ANALYTICS=true"
set "FLUTTER_SUPPRESS_ANALYTICS=true"
if not defined SUPABASE_URL set "SUPABASE_URL=https://zptyyrunbshsxdhiuuhq.supabase.co"
if not defined SUPABASE_ANON_KEY set "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpwdHl5cnVuYnNoc3hkaGl1dWhxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYyNTM2NjMsImV4cCI6MjEwMTgyOTY2M30.UwG1szTXf-c6OMOkMW0wkDZpZo4atufQHrHHMSzPD54"
set "PATH=%ROOT%platform-tools;%PATH%"

for /d %%J in ("%ProgramFiles%\Microsoft\jdk-17*") do if exist "%%~fJ\bin\java.exe" if not defined NP_MARKET_JDK17 set "NP_MARKET_JDK17=%%~fJ"
if not defined NP_MARKET_JDK17 if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" set "NP_MARKET_JDK17=%ProgramFiles%\Android\Android Studio\jbr"
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

echo [NP Market] API: %API_BASE%
flutter build apk --release --dart-define=NP_MARKET_API_BASE_URL=%API_BASE% --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
pause
