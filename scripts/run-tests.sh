#!/usr/bin/env bash
set -euo pipefail

# Run tests with local Swift when available; otherwise use the Swift Docker image.
if command -v swift >/dev/null 2>&1; then
  echo "Running native swift test"
  swift test
else
  echo "Native Swift not found; running tests in Docker (swift:6.2)"
  docker run --rm -v "$(pwd):/workspace" -w /workspace swift:6.2 /bin/bash -lc "swift test"
fi
