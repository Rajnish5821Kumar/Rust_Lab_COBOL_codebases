#!/usr/bin/env bash
#
# build.sh - compile the ledger batch system with GnuCOBOL.
#
# Usage: scripts/build.sh
#
# Produces, under bin/:
#   ledger-batch      the batch run            (driver: src/main.cob)
#   ledger-reconcile  standalone reconciliation
#                                    (driver: src/reconcile-main.cob)
# and, under build/unit/, one executable per tests/unit/test-*.cob.
#
# Compiler warnings are treated as errors.  The script stops at the
# first failure and exits non-zero.
#
# Environment:
#   COBC        compiler command            (default: cobc)
#   COBCFLAGS   extra flags for every compile
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COBC="${COBC:-cobc}"
EXTRA_FLAGS=()
if [ -n "${COBCFLAGS:-}" ]; then
    # shellcheck disable=SC2206
    EXTRA_FLAGS=(${COBCFLAGS})
fi

if ! command -v "$COBC" >/dev/null 2>&1; then
    echo "build.sh: '$COBC' not found. Install GnuCOBOL 3.x" \
         "(see README.md) or set COBC." >&2
    exit 127
fi

# -fixed            fixed-format source (columns 7-72)
# -Wall -Werror     report all warnings and fail on any of them
# -I copybooks      where COPY finds the copybooks
FLAGS=(-x -fixed -Wall -Werror -I copybooks "${EXTRA_FLAGS[@]}")

# Modules shared by every executable.  Order does not matter to the
# linker; it is alphabetical for readability.
MODULES=(
    src/account-processor.cob
    src/account-store.cob
    src/control-loader.cob
    src/date-validator.cob
    src/error-messages.cob
    src/history-store.cob
    src/ledger-writer.cob
    src/reconciliation.cob
    src/reporting.cob
    src/transaction-reader.cob
    src/transaction-validator.cob
)

mkdir -p bin build/unit

echo "build.sh: $("$COBC" --version | head -n 1)"

echo "build.sh: compiling bin/ledger-batch"
"$COBC" "${FLAGS[@]}" -o bin/ledger-batch src/main.cob "${MODULES[@]}"

echo "build.sh: compiling bin/ledger-reconcile"
"$COBC" "${FLAGS[@]}" -o bin/ledger-reconcile \
    src/reconcile-main.cob "${MODULES[@]}"

for test_source in tests/unit/test-*.cob; do
    [ -e "$test_source" ] || continue
    name="$(basename "$test_source" .cob)"
    echo "build.sh: compiling build/unit/$name"
    "$COBC" "${FLAGS[@]}" -I tests/unit -o "build/unit/$name" \
        "$test_source" "${MODULES[@]}"
done

echo "build.sh: build complete"
