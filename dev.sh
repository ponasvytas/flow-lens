#!/bin/bash
# Quick development restart script
pkill -f "flutter_tools.snapshot run"
sleep 1
flutter run -d web-server --web-hostname=localhost --web-port=43888
