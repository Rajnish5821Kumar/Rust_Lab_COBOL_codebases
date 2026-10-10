#!/usr/bin/env bash
#
# test.sh - lint, build and test in one step.
#
# Usage: scripts/test.sh [unit] [integration] [regression]
#
# This is what `make test` and the CI workflow run.  It stops at the
# first step that fails and exits non-zero.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash scripts/lint-cobol.sh
bash scripts/build.sh
bash tests/run-tests.sh "$@"
