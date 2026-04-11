#!/usr/bin/env bash
set -euo pipefail

# Run Swift tests using native swift if available, otherwise via Docker Swift image.
if command -v swift >/dev/null 2>&1; then
  echo "Running native swift test"
  swift test
else
  echo "Native Swift not found; running tests in Docker (swift:5.9)"
  docker run --rm -v "$(pwd):/workspace" -w /workspace swift:5.9 /bin/bash -lc "swift test"
fi
