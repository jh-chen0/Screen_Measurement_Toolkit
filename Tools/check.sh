#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Checks/verify-upstream.py
mkdir -p build .module-cache
SOURCES=()
while IFS= read -r file; do
  [[ "$file" == */main.swift ]] || SOURCES+=("$file")
done < <(find Sources/ScreenMeasurementToolkit -name '*.swift' -type f | sort)
swiftc -module-name ToolkitChecks -module-cache-path .module-cache \
  "${SOURCES[@]}" Checks/ScreenAngleChecks.swift -o build/ToolkitChecks
./build/ToolkitChecks "$@"
