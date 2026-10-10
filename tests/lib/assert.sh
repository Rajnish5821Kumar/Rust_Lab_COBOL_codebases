#!/usr/bin/env bash
#
# assert.sh - small assertion library for the shell-driven tests.
#
# Source this file, call the assert_* functions, and finish with
# `finish_suite "name"`, which prints the tally and returns non-zero
# if any assertion failed.  An assertion never stops the suite: every
# failure is reported, so one run shows everything that is wrong.
#
# All file comparisons ignore carriage returns, because GnuCOBOL on
# Windows writes CRLF line endings and on Linux writes LF.

ASSERTIONS_RUN=0
ASSERTIONS_FAILED=0
CURRENT_TEST=""

begin_test() {
    CURRENT_TEST="$1"
}

_pass() {
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
}

_fail() {
    ASSERTIONS_RUN=$((ASSERTIONS_RUN + 1))
    ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
    echo "FAIL  [$CURRENT_TEST] $1"
    shift
    for line in "$@"; do
        echo "      $line"
    done
}

# assert_equal EXPECTED ACTUAL WHAT
assert_equal() {
    if [ "$1" = "$2" ]; then
        _pass
    else
        _fail "$3" "expected: $1" "actual:   $2"
    fi
}

# assert_file_exists PATH
assert_file_exists() {
    if [ -f "$1" ]; then _pass; else _fail "file should exist: $1"; fi
}

# assert_file_absent PATH
assert_file_absent() {
    if [ ! -e "$1" ]; then _pass; else _fail "file should not exist: $1"; fi
}

# assert_file_empty PATH
assert_file_empty() {
    if [ -f "$1" ] && [ ! -s "$1" ]; then
        _pass
    else
        _fail "file should exist and be empty: $1"
    fi
}

# assert_contains PATH FIXED-STRING
assert_contains() {
    if tr -d '\r' < "$1" | grep -F -q -- "$2"; then
        _pass
    else
        _fail "$1 should contain: $2"
    fi
}

# assert_not_contains PATH FIXED-STRING
assert_not_contains() {
    if tr -d '\r' < "$1" | grep -F -q -- "$2"; then
        _fail "$1 should not contain: $2"
    else
        _pass
    fi
}

# assert_line_count EXPECTED PATH
assert_line_count() {
    local actual
    actual=$(tr -d '\r' < "$2" | wc -l | tr -d ' ')
    assert_equal "$1" "$actual" "line count of $2"
}

# assert_same_content EXPECTED-PATH ACTUAL-PATH
assert_same_content() {
    local difference
    if difference=$(diff <(tr -d '\r' < "$1") <(tr -d '\r' < "$2")); then
        _pass
    else
        _fail "$2 differs from $1" \
              "$(printf '%s\n' "$difference" | head -n 10)"
    fi
}

# assert_succeeds WHAT COMMAND...
assert_succeeds() {
    local what="$1" output
    shift
    if output=$("$@" 2>&1); then
        _pass
    else
        _fail "$what" "$(printf '%s\n' "$output" | head -n 10)"
    fi
}

# finish_suite NAME
finish_suite() {
    echo "$1: $ASSERTIONS_RUN assertions, $ASSERTIONS_FAILED failed"
    [ "$ASSERTIONS_FAILED" -eq 0 ]
}
