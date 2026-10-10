#!/usr/bin/env bash
#
# count-source-lines.sh - report the size of the repository by
# language, counted from the files git tracks (or, outside a git
# repository, from the files on disk under the known directories).
#
# Usage: scripts/count-source-lines.sh
#
# For each language three figures are given:
#   files   number of files
#   lines   physical lines
#   code    lines that are neither blank nor a whole-line comment
#
# For COBOL a comment line is one with "*" or "/" in column 7.
# For shell, awk, make and YAML it is a line whose first non-blank
# character is "#".  Markdown and data files have no comment syntax,
# so "code" there simply means non-blank lines.
#
# The figures are plain counts.  They say nothing about quality and
# are reported so that claims about the size of the code base can be
# checked against the repository itself.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        && [ -n "$(git ls-files | head -n 1)" ]; then
    list_files() { git ls-files; }
else
    list_files() {
        find src copybooks tests testdata scripts docs .github \
             Makefile README.md .gitignore .gitattributes \
             -type f 2>/dev/null | sed 's|^\./||'
    }
fi

classify() {
    case "$1" in
        src/*.cob)                 echo "COBOL programs (src)" ;;
        copybooks/*.cpy)           echo "COBOL copybooks" ;;
        tests/unit/*.cob|tests/unit/*.cpy)
                                   echo "COBOL unit tests" ;;
        *.sh)                      echo "Shell" ;;
        *.awk)                     echo "AWK" ;;
        Makefile)                  echo "Make" ;;
        *.yml|*.yaml)              echo "YAML" ;;
        *.md)                      echo "Markdown" ;;
        testdata/*|tests/integration/cases.txt)
                                   echo "Test data" ;;
        *)                         echo "Other" ;;
    esac
}

TALLY="$(mktemp)"
trap 'rm -f "$TALLY"' EXIT

while IFS= read -r file; do
    [ -f "$file" ] || continue
    language="$(classify "$file")"
    case "$language" in
        COBOL*) style=cobol ;;
        Shell|AWK|Make|YAML) style=hash ;;
        *) style=none ;;
    esac
    awk -v language="$language" -v style="$style" '
        { sub(/\r$/, ""); lines++ }
        /^[ \t]*$/ { next }
        style == "cobol" && substr($0, 7, 1) ~ /[*\/]/ { next }
        style == "hash" && /^[ \t]*#/ { next }
        { code++ }
        END { printf "%s|%d|%d\n", language, lines, code }
    ' "$file" >> "$TALLY"
done < <(list_files)

awk -F'|' '
    {
        files[$1]++; lines[$1] += $2; code[$1] += $3
        if ($1 ~ /^COBOL/) {
            cobol_files++; cobol_lines += $2; cobol_code += $3
        }
        total_files++; total_lines += $2; total_code += $3
    }
    END {
        order = "COBOL programs (src)|COBOL copybooks|COBOL unit tests|" \
                "Shell|AWK|Make|YAML|Markdown|Test data|Other"
        count = split(order, name, "|")
        printf "%-24s %6s %8s %8s\n", "Language", "files", "lines", "code"
        printf "%-24s %6s %8s %8s\n", "--------", "-----", "-----", "----"
        for (i = 1; i <= count; i++)
            if (name[i] in files)
                printf "%-24s %6d %8d %8d\n", name[i], files[name[i]], \
                       lines[name[i]], code[name[i]]
        printf "%-24s %6s %8s %8s\n", "--------", "-----", "-----", "----"
        printf "%-24s %6d %8d %8d\n", "All COBOL", cobol_files, \
               cobol_lines, cobol_code
        printf "%-24s %6d %8d %8d\n", "Everything", total_files, \
               total_lines, total_code
    }
' "$TALLY"
