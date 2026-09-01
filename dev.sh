#!/bin/bash
set -euo pipefail

# Start Flow Lens without terminating unrelated Flutter processes.
flutter run -d web-server --web-hostname=localhost --web-port=43888
