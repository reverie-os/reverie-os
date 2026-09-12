#!/usr/bin/env bash
# Install the meta repo git hooks (see FORMAT.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
chmod +x "$ROOT/.hooks/commit-msg" "$ROOT/scripts/commit-lint.sh"
ln -sf "$ROOT/.hooks/commit-msg" "$ROOT/.git/hooks/commit-msg"
echo "installed: $ROOT/.git/hooks/commit-msg"
