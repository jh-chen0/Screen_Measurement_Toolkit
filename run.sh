#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
./build.sh --fast
pkill -x ScreenMeasurementToolkit 2>/dev/null || true
open "build/Screen Measurement Toolkit.app"
