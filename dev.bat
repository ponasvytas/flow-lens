@echo off
setlocal
REM Start Flow Lens without terminating unrelated browser processes or
REM weakening browser security.
flutter run -d chrome --web-hostname=localhost --web-port=43888
endlocal
