#!/usr/bin/env bash
#
# coverage.sh - measure line coverage of the COBOL programs in src/.
#
# Usage: scripts/coverage.sh
#
# Method
#   1. Every executable (the two programs and each unit test) is
#      rebuilt with gcc coverage instrumentation, each in its own
#      directory under build/coverage/obj/ so their counter files
#      cannot collide.
#   2. All three test suites are run against the instrumented
#      executables.  The suites must pass; coverage of a failing run
#      is not reported.
#   3. gcov maps the counters back to COBOL source lines (cobc emits
#      #line directives into the C it generates).
#   4. The per-executable results are merged: a source line counts as
#      covered if any executable ran it during any test.
#
# What is counted
#   Only lines of src/*.cob from the PROCEDURE DIVISION header
#   onwards that gcov regards as executable.  Data definitions,
#   copybooks and the test programs themselves are left out, so the
#   percentage is "procedure-division lines executed by the tests".
#   It is line coverage, not branch or condition coverage.
#
# Requirements: GnuCOBOL with --coverage support (3.2 or later) and
# the gcov that belongs to the C compiler cobc uses.
#
# Output: a table on standard output, also saved to
# build/coverage/coverage.txt.  Exit status is non-zero if the build
# or the tests fail.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COBC="${COBC:-cobc}"
GCOV="${GCOV:-gcov}"
COV="$ROOT/build/coverage"

for tool in "$COBC" "$GCOV"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "coverage.sh: '$tool' not found" >&2
        exit 127
    fi
done
# The help text is captured before it is searched.  Piping it straight
# into `grep -q` is a race: grep exits at the first match, cobc is
# killed by SIGPIPE while still writing, and under pipefail the check
# then fails even though the option is there.
COBC_HELP="$("$COBC" --help)"
if ! grep -q -- '--coverage' <<< "$COBC_HELP"; then
    echo "coverage.sh: this cobc has no --coverage option" \
         "(GnuCOBOL 3.2 or later is needed)" >&2
    exit 2
fi

rm -rf "$COV"
mkdir -p "$COV/bin" "$COV/unit" "$COV/obj"

MODULES=()
for module in src/*.cob; do
    case "$module" in
        src/main.cob|src/reconcile-main.cob) ;;
        *) MODULES+=("$ROOT/$module") ;;
    esac
done

# build_instrumented NAME OUTPUT-DIR DRIVER-SOURCE
build_instrumented() {
    local name="$1" output_dir="$2" driver="$3"
    mkdir -p "$COV/obj/$name"
    (
        cd "$COV/obj/$name"
        "$COBC" -x -fixed -g --coverage \
            -I "$ROOT/copybooks" -I "$ROOT/tests/unit" \
            -o "$output_dir/$name" "$ROOT/$driver" "${MODULES[@]}"
    )
}

echo "coverage.sh: building instrumented executables"
build_instrumented ledger-batch "$COV/bin" src/main.cob
build_instrumented ledger-reconcile "$COV/bin" src/reconcile-main.cob
for test_source in tests/unit/test-*.cob; do
    build_instrumented "$(basename "$test_source" .cob)" "$COV/unit" \
        "$test_source"
done

echo "coverage.sh: running the test suites"
LEDGER_BIN_DIR="$COV/bin" LEDGER_UNIT_DIR="$COV/unit" \
    bash tests/run-tests.sh

echo "coverage.sh: collecting counters"
GCOV_FILES=()
for object_dir in "$COV"/obj/*/; do
    (
        cd "$object_dir"
        # A module no test reached has no .gcda file; gcov then
        # reports its lines as unexecuted, which is what is wanted.
        "$GCOV" -o . ./*.gcno >/dev/null 2>&1 || true
    )
    for source in src/*.cob; do
        gcov_file="$object_dir$(basename "$source").gcov"
        if [ -f "$gcov_file" ]; then
            GCOV_FILES+=("$gcov_file")
        fi
    done
done
if [ "${#GCOV_FILES[@]}" -eq 0 ]; then
    echo "coverage.sh: gcov produced no reports for src/*.cob" >&2
    exit 1
fi

# Merge every <program>.cob.gcov file.  A gcov line looks like
#     count:  line-number:source text
# where count is "-" (not executable), "#####" or "=====" (never
# executed) or a number, possibly followed by "*".
awk -F: '
    FNR == 1 {
        split(FILENAME, parts, "/")
        program = parts[length(parts)]
        sub(/\.gcov$/, "", program)
        in_procedure = 0
    }
    {
        count = $1
        gsub(/[ \t*]/, "", count)
        line = $2 + 0
        if (line == 0) next
        text = $0
        sub(/^[^:]*:[^:]*:/, "", text)
        if (substr(text, 7, 1) == " " && text ~ /PROCEDURE +DIVISION/)
            in_procedure = 1
        if (!in_procedure || count == "-") next
        key = program SUBSEP line
        executable[key] = 1
        if (count != "#####" && count != "=====" && count + 0 > 0)
            covered[key] = 1
    }
    END {
        for (key in executable) {
            split(key, parts, SUBSEP)
            lines[parts[1]]++
            total_lines++
            if (key in covered) { hit[parts[1]]++; total_hit++ }
        }
        printf "%-30s %10s %10s %9s\n", "Program", "lines", "covered", "percent"
        printf "%-30s %10s %10s %9s\n", "-------", "-----", "-------", "-------"
        count = 0
        for (program in lines) names[++count] = program
        for (i = 1; i <= count; i++)
            for (j = i + 1; j <= count; j++)
                if (names[j] < names[i]) {
                    swap = names[i]; names[i] = names[j]; names[j] = swap
                }
        for (i = 1; i <= count; i++) {
            program = names[i]
            printf "%-30s %10d %10d %8.1f%%\n", program, lines[program], \
                   hit[program], 100 * hit[program] / lines[program]
        }
        printf "%-30s %10s %10s %9s\n", "-------", "-----", "-------", "-------"
        if (total_lines > 0)
            printf "%-30s %10d %10d %8.1f%%\n", "TOTAL", total_lines, \
                   total_hit, 100 * total_hit / total_lines
        else
            print "no coverage data found"
    }
' "${GCOV_FILES[@]}" | tee "$COV/coverage.txt"

if grep -q "no coverage data found" "$COV/coverage.txt"; then
    exit 1
fi
