#!/usr/bin/env bash
# Points git at the versioned hooks in .githooks/ so the Entro pre-commit hook runs locally.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
echo "✅ Git hooks installed (core.hooksPath=.githooks)."
