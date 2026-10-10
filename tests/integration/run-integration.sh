#!/usr/bin/env bash
#
# run-integration.sh - run every batch listed in cases.txt and check
# its results.
#
# Usage: tests/integration/run-integration.sh [--update] [CASE...]
#
# For each case the batch is run through scripts/run-batch.sh into
# build/test-output/integration/<case>/ and four things are checked:
#
#   1. the return code is the one in cases.txt;
#   2. the run produced exactly the files in testdata/expected/<case>/
#      - no more and no fewer (so a failed run that leaves a closing
#      master behind is caught);
#   3. every file matches its expected copy byte for byte, apart from
#      line endings;
#   4. when the run completed (return code 0 or 4), the independent
#      checker tests/lib/check-ledger.awk confirms the accounting
#      invariants from the opening master, journal and closing master.
#
# --update rewrites testdata/expected from the current outputs
# instead of comparing.  It exists for deliberate changes to a report
# layout.  It makes every case "pass" by definition, so review the
# resulting git diff line by line before committing it; check 4 still
# runs and still fails on an accounting error.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=tests/lib/assert.sh
. tests/lib/assert.sh

UPDATE=0
if [ "${1:-}" = "--update" ]; then
    UPDATE=1
    shift
fi
ONLY=("$@")

OUT_ROOT="build/test-output/integration"
EXPECTED_ROOT="testdata/expected"
mkdir -p "$OUT_ROOT"

wanted() {
    [ "${#ONLY[@]}" -eq 0 ] && return 0
    local name
    for name in "${ONLY[@]}"; do
        [ "$name" = "$1" ] && return 0
    done
    return 1
}

trim() {
    local text="$1"
    text="${text#"${text%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    printf '%s' "$text"
}

run_case() {
    local name="$1" control="$2" accounts="$3" transactions="$4"
    local history="$5" expected_rc="$6"
    local out="$OUT_ROOT/$name" expected="$EXPECTED_ROOT/$name"
    local args actual_rc file

    begin_test "$name"
    rm -rf "$out"
    args=("testdata/control/$control" "testdata/accounts/$accounts"
          "testdata/transactions/$transactions" "$out")
    if [ "$history" != "-" ]; then
        args+=("testdata/history/$history")
    fi

    bash scripts/run-batch.sh "${args[@]}" >/dev/null 2>&1
    actual_rc=$?
    assert_equal "$expected_rc" "$actual_rc" "return code"

    if [ "$UPDATE" -eq 1 ]; then
        rm -rf "$expected"
        mkdir -p "$expected"
        for file in "$out"/*; do
            [ -f "$file" ] || continue
            tr -d '\r' < "$file" > "$expected/$(basename "$file")"
        done
    else
        assert_equal "$(cd "$expected" 2>/dev/null && ls | sort | tr '\n' ' ')" \
                     "$(cd "$out" && ls | sort | tr '\n' ' ')" \
                     "set of output files"
        for file in "$expected"/*; do
            [ -f "$file" ] || continue
            if [ -f "$out/$(basename "$file")" ]; then
                assert_same_content "$file" "$out/$(basename "$file")"
            fi
        done
    fi

    if [ "$actual_rc" -le 4 ]; then
        assert_succeeds "independent ledger check" \
            awk -f tests/lib/check-ledger.awk \
                "testdata/accounts/$accounts" \
                "$out/journal.out" "$out/accounts.out"
    fi
}

cases_run=0
while IFS='|' read -r name control accounts transactions history rc; do
    name="$(trim "$name")"
    case "$name" in ''|'#'*) continue ;; esac
    wanted "$name" || continue
    run_case "$name" "$(trim "$control")" "$(trim "$accounts")" \
             "$(trim "$transactions")" "$(trim "$history")" "$(trim "$rc")"
    cases_run=$((cases_run + 1))
done < tests/integration/cases.txt

if [ "$cases_run" -eq 0 ]; then
    echo "run-integration.sh: no cases were run" >&2
    exit 1
fi
finish_suite "INTEGRATION ($cases_run cases)"
