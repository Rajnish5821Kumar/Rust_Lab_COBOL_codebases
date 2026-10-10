#!/usr/bin/env bash
#
# lint-cobol.sh - source-format checks the compiler does not make.
#
# Usage: scripts/lint-cobol.sh
#
# In fixed-format COBOL the compiler silently ignores everything
# after column 72.  A statement that runs one character too long
# therefore loses its tail without any diagnostic, which can change
# what the program does.  This script fails the build when any
# source or copybook line:
#
#   - is longer than 72 columns;
#   - contains a tab (a tab's width is ambiguous in a format that is
#     defined by column position);
#   - contains a carriage return (the repository stores LF endings);
#   - ends in trailing spaces.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FILES=(src/*.cob copybooks/*.cpy tests/unit/*.cob tests/unit/*.cpy)

if awk '
    function report(problem) {
        printf "%s:%d: %s\n", FILENAME, FNR, problem
        problems++
    }
    /\r/           { report("carriage return"); sub(/\r$/, "") }
    /\t/           { report("tab character") }
    length($0) > 72 { report("line is " length($0) " columns (limit 72)") }
    / $/           { report("trailing spaces") }
    END { exit (problems > 0) ? 1 : 0 }
' "${FILES[@]}"; then
    echo "lint-cobol.sh: ${#FILES[@]} files checked, no problems"
else
    echo "lint-cobol.sh: source-format problems found" >&2
    exit 1
fi
