#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

cd "$SRCROOT"

if ! command -v mise >/dev/null 2>&1; then
    echo "error: mise not found. Run 'make init' to install project tools."
    exit 1
fi

mise install --quiet
mise run format-lint
