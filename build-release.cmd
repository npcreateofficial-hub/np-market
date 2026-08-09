@echo off
setlocal
set "ROOT=%~dp0"
set "API_BASE=https://go.np-class.com/np-market"
set "PATH=%ROOT%platform-tools;%PATH%"

echo [NP Market] API: %API_BASE%
flutter build apk --release --dart-define=NP_MARKET_API_BASE_URL=%API_BASE%
pause
