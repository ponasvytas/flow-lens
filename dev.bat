@echo off
REM Quick development restart script for Windows
taskkill /F /IM chrome.exe 2>NUL
timeout /t 1 /nobreak >NUL
flutter run -d chrome --web-hostname=0.0.0.0 --web-port=43888 --web-browser-flag=--disable-web-security
