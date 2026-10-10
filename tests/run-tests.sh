#!/usr/bin/env bash
#
# run-tests.sh - run the automated test suites.
#
# Usage: tests/run-tests.sh [unit] [integration] [regression]
#        (no argument runs all three)
#
# The executables must already be built (scripts/build.sh);
# scripts/test.sh does both steps.  Every requested suite is run even
# if an earlier one fails, and the exit status is non-zero if any
# suite failed, so a failure can never be hidden by a later success.
#
# Environment:
#   LEDGER_BIN_DIR   directory holding ledger-batch and
#                    ledger-reconcile          (default: bin)
#   LEDGER_UNIT_DIR  directory holding the unit-test executables
#                                              (default: build/unit)
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BIN_DIR="${LEDGER_BIN_DIR:-bin}"
UNIT_DIR="${LEDGER_UNIT_DIR:-build/unit}"

if [ "$#" -eq 0 ]; then
    set -- unit integration regression
fi

found_program() {
    [ -x "$1" ] || [ -x "$1.exe" ]
}

if ! found_program "$BIN_DIR/ledger-batch" \
        || ! found_program "$BIN_DIR/ledger-reconcile"; then
    echo "run-tests.sh: executables not found in $BIN_DIR;" \
         "run scripts/build.sh first" >&2
    exit 2
fi

FAILED_SUITES=""

run_unit_suite() {
    local sources=(tests/unit/test-*.cob) source name program status
    local failed=0
    for source in "${sources[@]}"; do
        name="$(basename "$source" .cob)"
        program="$UNIT_DIR/$name"
        if ! found_program "$program"; then
            echo "FAIL  unit test executable missing: $program"
            failed=1
            continue
        fi
        "$program"
        status=$?
        if [ "$status" -ne 0 ]; then
            echo "FAIL  $name exited with status $status"
            failed=1
        fi
    done
    echo "UNIT: ${#sources[@]} programs"
    return "$failed"
}

for suite in "$@"; do
    echo "==== $suite ===="
    case "$suite" in
        unit)        run_unit_suite ;;
        integration) bash tests/integration/run-integration.sh ;;
        regression)  bash tests/regression/run-regression.sh ;;
        *)
            echo "run-tests.sh: unknown suite '$suite'" >&2
            exit 2
            ;;
    esac
    if [ "$?" -ne 0 ]; then
        FAILED_SUITES="$FAILED_SUITES $suite"
    fi
done

echo "================"
if [ -n "$FAILED_SUITES" ]; then
    echo "TESTS FAILED:$FAILED_SUITES"
    exit 1
fi
echo "ALL TESTS PASSED: $*"
