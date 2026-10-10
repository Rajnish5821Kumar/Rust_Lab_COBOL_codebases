#!/usr/bin/env bash
#
# run-regression.sh - scenario tests that need more than one run, a
# damaged file, or an unusual environment.
#
# Usage: tests/regression/run-regression.sh
#
# Scenarios
#   repeatable       the same inputs give byte-identical outputs
#   rerun            what a rerun does with and without a history file
#   chained          two batches in sequence, day 2 built on day 1
#   audit            ledger-reconcile accepts good outputs and detects
#                    each kind of tampering
#   environment      missing file-name variables, unsafe file names,
#                    unwritable outputs, stale outputs
#   scale            a 20,000-transaction batch and every documented
#                    resource limit
#
# Everything is written under build/test-output/regression/.
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=tests/lib/assert.sh
. tests/lib/assert.sh

BIN="${LEDGER_BIN_DIR:-bin}"
OUT="build/test-output/regression"
rm -rf "$OUT"
mkdir -p "$OUT"

CONTROL="testdata/control/standard.ctl"
ACCOUNTS="testdata/accounts/standard.dat"
TXN="testdata/transactions"
OUTPUT_FILES="accounts.out journal.out history.out posted.rpt
              rejects.rpt summary.rpt job.log"

# run_batch OUTDIR CONTROL ACCOUNTS TRANSACTIONS [HISTORY]
# Runs a batch quietly and leaves its return code in BATCH_RC.
run_batch() {
    local out="$1"
    shift
    bash scripts/run-batch.sh "$1" "$2" "$3" "$out" ${4:+"$4"} \
        >/dev/null 2>&1
    BATCH_RC=$?
}

# run_reconcile OPENING JOURNAL CLOSING LOGFILE
# Runs the standalone reconciliation; return code in RECON_RC.
run_reconcile() {
    LEDGER_ACCOUNTS_IN="$1" LEDGER_JOURNAL_OUT="$2" \
    LEDGER_ACCOUNTS_OUT="$3" "$BIN/ledger-reconcile" > "$4" 2>&1
    RECON_RC=$?
}

# summary_value FILE LABEL
# Prints the value printed against LABEL in a summary report.
summary_value() {
    tr -d '\r' < "$1" | awk -v label="$2" '{
        value = $NF
        line = $0
        sub(/[ \t]+[^ \t]+$/, "", line)
        sub(/^[ \t]+/, "", line)
        if (line == label) { print value; exit }
    }'
}

# ---------------------------------------------------------------------
# repeatable: a batch reads no clock and no random source, so running
# it twice on the same inputs must give identical files.
# ---------------------------------------------------------------------
begin_test "repeatable"
run_batch "$OUT/repeat-1" "$CONTROL" "$ACCOUNTS" "$TXN/mixed-batch.dat" \
          testdata/history/prior-batch.dat
assert_equal 4 "$BATCH_RC" "first run return code"
run_batch "$OUT/repeat-2" "$CONTROL" "$ACCOUNTS" "$TXN/mixed-batch.dat" \
          testdata/history/prior-batch.dat
assert_equal 4 "$BATCH_RC" "second run return code"
for file in $OUTPUT_FILES; do
    assert_same_content "$OUT/repeat-1/$file" "$OUT/repeat-2/$file"
done

# ---------------------------------------------------------------------
# rerun: the documented duplicate-processing risk.
# ---------------------------------------------------------------------
# Day 1: Alice (1000000001) receives a 250.00 deposit: 1,000.00 becomes
# 1,250.00.
begin_test "rerun: first posting"
run_batch "$OUT/rerun-day1" "$CONTROL" "$ACCOUNTS" \
          "$TXN/deposit-valid.dat" testdata/history/empty.dat
assert_equal 0 "$BATCH_RC" "return code"
assert_contains "$OUT/rerun-day1/accounts.out" \
    "A1000000001ALICE ANDERSON                A+000000000125000"
assert_contains "$OUT/rerun-day1/history.out" "DEP00000000120260115"
assert_line_count 1 "$OUT/rerun-day1/history.out"

# The same transaction file is submitted again against the new master
# WITHOUT the history file.  Nothing can tell the batch that the
# deposit was already posted, so it posts again: 1,500.00.  This is
# the risk the history file exists to remove, pinned here so that the
# behaviour is a known fact rather than a surprise.
begin_test "rerun: without history the transaction posts twice"
run_batch "$OUT/rerun-no-history" "$CONTROL" \
          "$OUT/rerun-day1/accounts.out" "$TXN/deposit-valid.dat"
assert_equal 0 "$BATCH_RC" "return code"
assert_contains "$OUT/rerun-no-history/accounts.out" \
    "A1000000001ALICE ANDERSON                A+000000000150000"
assert_contains "$OUT/rerun-no-history/job.log" "NO HISTORY FILE"

# Submitted again WITH the history file from day 1, the deposit is
# rejected as already posted and the master is unchanged.
begin_test "rerun: with history the transaction is rejected"
run_batch "$OUT/rerun-with-history" "$CONTROL" \
          "$OUT/rerun-day1/accounts.out" "$TXN/deposit-valid.dat" \
          "$OUT/rerun-day1/history.out"
assert_equal 4 "$BATCH_RC" "return code"
assert_contains "$OUT/rerun-with-history/rejects.rpt" "B007"
assert_same_content "$OUT/rerun-day1/accounts.out" \
                    "$OUT/rerun-with-history/accounts.out"
assert_file_empty "$OUT/rerun-with-history/journal.out"
assert_same_content "$OUT/rerun-day1/history.out" \
                    "$OUT/rerun-with-history/history.out"
assert_not_contains "$OUT/rerun-day1/job.log" "NO HISTORY FILE"

# ---------------------------------------------------------------------
# chained: day 2 uses day 1's closing master and history as inputs.
# ---------------------------------------------------------------------
begin_test "chained: day 1"
run_batch "$OUT/chain-day1" "$CONTROL" "$ACCOUNTS" \
          "$TXN/mixed-batch.dat" testdata/history/empty.dat
assert_equal 4 "$BATCH_RC" "return code"
assert_line_count 5 "$OUT/chain-day1/history.out"

# Day 2 runs the multiple-same-account file.  Alice opens day 2 with
# 2,190.00 (1,000.00 + 1,250.00 - 60.00) instead of 1,000.00, so the
# two withdrawals that are refused for lack of funds in the single-day
# integration case are posted here: all 12 records post and Alice
# closes at 190.98.
begin_test "chained: day 2 builds on day 1"
assert_contains "$OUT/chain-day1/accounts.out" \
    "A1000000001ALICE ANDERSON                A+000000000219000"
run_batch "$OUT/chain-day2" "$CONTROL" "$OUT/chain-day1/accounts.out" \
          "$TXN/multiple-same-account.dat" "$OUT/chain-day1/history.out"
assert_equal 0 "$BATCH_RC" "return code"
assert_equal 12 "$(summary_value "$OUT/chain-day2/summary.rpt" \
    "TRANSACTIONS POSTED")" "transactions posted"
assert_equal 5 "$(summary_value "$OUT/chain-day2/summary.rpt" \
    "PRIOR TRANSACTION IDS LOADED")" "prior ids loaded"
assert_equal PASSED "$(summary_value "$OUT/chain-day2/summary.rpt" \
    "STATUS")" "reconciliation status"
assert_contains "$OUT/chain-day2/accounts.out" \
    "A1000000001ALICE ANDERSON                A+000000000019098"
assert_succeeds "independent ledger check of day 2" \
    awk -f tests/lib/check-ledger.awk "$OUT/chain-day1/accounts.out" \
        "$OUT/chain-day2/journal.out" "$OUT/chain-day2/accounts.out"
# History grows by exactly the 12 ids day 2 posted.
assert_line_count 17 "$OUT/chain-day2/history.out"

# A day-1 id submitted on day 2 is caught through the chained history.
begin_test "chained: day 1 id resubmitted on day 2"
run_batch "$OUT/chain-resubmit" "$CONTROL" \
          "$OUT/chain-day2/accounts.out" "$TXN/mixed-batch.dat" \
          "$OUT/chain-day2/history.out"
assert_contains "$OUT/chain-resubmit/rejects.rpt" \
    "MIX000000001  20260115  D  1000000001              0000000125000  B007"
assert_same_content "$OUT/chain-day2/accounts.out" \
                    "$OUT/chain-resubmit/accounts.out"

# ---------------------------------------------------------------------
# audit: the standalone reconciliation program.
# ---------------------------------------------------------------------
GOOD="$OUT/chain-day1"
AUDIT="$OUT/audit"
mkdir -p "$AUDIT"

begin_test "audit: untouched outputs reconcile"
run_reconcile "$ACCOUNTS" "$GOOD/journal.out" "$GOOD/accounts.out" \
              "$AUDIT/good.log"
assert_equal 0 "$RECON_RC" "return code"
assert_contains "$AUDIT/good.log" "RECONCILIATION PASSED"

# A closing balance altered by one cent, trailer left alone: the
# master no longer matches its own trailer, so it is refused outright.
begin_test "audit: closing balance altered, trailer not"
sed 's/^\(A1000000001.\{31\}\)+000000000219000/\1+000000000219001/' \
    "$GOOD/accounts.out" > "$AUDIT/balance-only.out"
run_reconcile "$ACCOUNTS" "$GOOD/journal.out" \
              "$AUDIT/balance-only.out" "$AUDIT/balance-only.log"
assert_equal 12 "$RECON_RC" "return code"
assert_contains "$AUDIT/balance-only.log" "F008"

# The same alteration with the trailer adjusted to match: the master
# is now self-consistent, and only the journal replay can expose it.
begin_test "audit: closing balance and trailer altered together"
sed -e 's/^\(A1000000001.\{31\}\)+000000000219000/\1+000000000219001/' \
    -e 's/^T0000008+01000000005543950/T0000008+01000000005543951/' \
    "$GOOD/accounts.out" > "$AUDIT/balance-and-trailer.out"
run_reconcile "$ACCOUNTS" "$GOOD/journal.out" \
              "$AUDIT/balance-and-trailer.out" \
              "$AUDIT/balance-and-trailer.log"
assert_equal 8 "$RECON_RC" "return code"
assert_contains "$AUDIT/balance-and-trailer.log" "R002 1000000001"
assert_contains "$AUDIT/balance-and-trailer.log" "R006"
assert_contains "$AUDIT/balance-and-trailer.log" "RECONCILIATION FAILED"

begin_test "audit: journal entry removed"
sed '4d' "$GOOD/journal.out" > "$AUDIT/entry-removed.out"
run_reconcile "$ACCOUNTS" "$AUDIT/entry-removed.out" \
              "$GOOD/accounts.out" "$AUDIT/entry-removed.log"
assert_equal 8 "$RECON_RC" "return code"
assert_contains "$AUDIT/entry-removed.log" "R007"
assert_contains "$AUDIT/entry-removed.log" "R009"
assert_contains "$AUDIT/entry-removed.log" "R001"

begin_test "audit: journal amount altered"
sed '1s/DR0000000125000/DR0000000125001/' "$GOOD/journal.out" \
    > "$AUDIT/amount-altered.out"
run_reconcile "$ACCOUNTS" "$AUDIT/amount-altered.out" \
              "$GOOD/accounts.out" "$AUDIT/amount-altered.log"
assert_equal 8 "$RECON_RC" "return code"
assert_contains "$AUDIT/amount-altered.log" "R009"
assert_contains "$AUDIT/amount-altered.log" "R005"
assert_contains "$AUDIT/amount-altered.log" "R001"

begin_test "audit: journal entry redirected to an unknown account"
sed '2s/D1000000001CR/D7777777777CR/' "$GOOD/journal.out" \
    > "$AUDIT/account-altered.out"
run_reconcile "$ACCOUNTS" "$AUDIT/account-altered.out" \
              "$GOOD/accounts.out" "$AUDIT/account-altered.log"
assert_equal 8 "$RECON_RC" "return code"
assert_contains "$AUDIT/account-altered.log" "R003 7777777777"
assert_contains "$AUDIT/account-altered.log" "R002 1000000001"

begin_test "audit: journal record damaged"
sed '3s/DR0000000006000/DR00000000060X0/' "$GOOD/journal.out" \
    > "$AUDIT/record-damaged.out"
run_reconcile "$ACCOUNTS" "$AUDIT/record-damaged.out" \
              "$GOOD/accounts.out" "$AUDIT/record-damaged.log"
assert_equal 8 "$RECON_RC" "return code"
assert_contains "$AUDIT/record-damaged.log" "R008 REC 00000003"

begin_test "audit: wrong opening master"
run_reconcile "$GOOD/accounts.out" "$GOOD/journal.out" \
              "$GOOD/accounts.out" "$AUDIT/wrong-opening.log"
assert_equal 8 "$RECON_RC" "return code"

begin_test "audit: journal missing"
run_reconcile "$ACCOUNTS" "$AUDIT/no-such-journal.out" \
              "$GOOD/accounts.out" "$AUDIT/journal-missing.log"
assert_equal 12 "$RECON_RC" "return code"
assert_contains "$AUDIT/journal-missing.log" "F020"

begin_test "audit: file-name variable missing"
LEDGER_ACCOUNTS_IN="$ACCOUNTS" LEDGER_JOURNAL_OUT="$GOOD/journal.out" \
    env -u LEDGER_ACCOUNTS_OUT "$BIN/ledger-reconcile" \
    > "$AUDIT/no-variable.log" 2>&1
assert_equal 12 "$?" "return code"
assert_contains "$AUDIT/no-variable.log" "F017"
assert_contains "$AUDIT/no-variable.log" "LEDGER_ACCOUNTS_OUT"

# ---------------------------------------------------------------------
# environment
# ---------------------------------------------------------------------
ENVDIR="$OUT/environment"
mkdir -p "$ENVDIR"

# run_program_with LOGFILE VAR=VALUE...
# Runs ledger-batch with exactly the given LEDGER_ variables.
run_program_with() {
    local log="$1"
    shift
    env -u LEDGER_CONTROL -u LEDGER_ACCOUNTS_IN -u LEDGER_TXN_IN \
        -u LEDGER_HISTORY_IN -u LEDGER_ACCOUNTS_OUT \
        -u LEDGER_JOURNAL_OUT -u LEDGER_HISTORY_OUT \
        -u LEDGER_POSTED_RPT -u LEDGER_REJECT_RPT \
        -u LEDGER_SUMMARY_RPT "$@" "$BIN/ledger-batch" > "$log" 2>&1
    BATCH_RC=$?
}

begin_test "environment: no file-name variables at all"
run_program_with "$ENVDIR/none.log"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$ENVDIR/none.log" "F017"
assert_contains "$ENVDIR/none.log" "VARIABLE LEDGER_CONTROL"

begin_test "environment: one required variable missing"
run_program_with "$ENVDIR/one-missing.log" \
    LEDGER_CONTROL="$CONTROL" LEDGER_ACCOUNTS_IN="$ACCOUNTS" \
    LEDGER_TXN_IN="$TXN/deposit-valid.dat" \
    LEDGER_ACCOUNTS_OUT="$ENVDIR/a.out" \
    LEDGER_POSTED_RPT="$ENVDIR/p.rpt" LEDGER_REJECT_RPT="$ENVDIR/r.rpt" \
    LEDGER_SUMMARY_RPT="$ENVDIR/s.rpt"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$ENVDIR/one-missing.log" "VARIABLE LEDGER_JOURNAL_OUT"
assert_file_absent "$ENVDIR/a.out"

# Naming the opening master as the closing master would overwrite the
# only copy of the opening position.  It must be refused before any
# file is opened, and the master must be untouched.
begin_test "environment: closing master named the same as opening"
cp "$ACCOUNTS" "$ENVDIR/master.dat"
run_program_with "$ENVDIR/same-path.log" \
    LEDGER_CONTROL="$CONTROL" LEDGER_ACCOUNTS_IN="$ENVDIR/master.dat" \
    LEDGER_TXN_IN="$TXN/deposit-valid.dat" \
    LEDGER_ACCOUNTS_OUT="$ENVDIR/master.dat" \
    LEDGER_JOURNAL_OUT="$ENVDIR/j.out" \
    LEDGER_POSTED_RPT="$ENVDIR/p.rpt" LEDGER_REJECT_RPT="$ENVDIR/r.rpt" \
    LEDGER_SUMMARY_RPT="$ENVDIR/s.rpt"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$ENVDIR/same-path.log" "F019"
assert_same_content "$ACCOUNTS" "$ENVDIR/master.dat"
assert_file_absent "$ENVDIR/j.out"

begin_test "environment: history in and out named the same"
cp testdata/history/prior-batch.dat "$ENVDIR/history.dat"
run_program_with "$ENVDIR/same-history.log" \
    LEDGER_CONTROL="$CONTROL" LEDGER_ACCOUNTS_IN="$ACCOUNTS" \
    LEDGER_TXN_IN="$TXN/deposit-valid.dat" \
    LEDGER_HISTORY_IN="$ENVDIR/history.dat" \
    LEDGER_HISTORY_OUT="$ENVDIR/history.dat" \
    LEDGER_ACCOUNTS_OUT="$ENVDIR/a.out" \
    LEDGER_JOURNAL_OUT="$ENVDIR/j.out" \
    LEDGER_POSTED_RPT="$ENVDIR/p.rpt" LEDGER_REJECT_RPT="$ENVDIR/r.rpt" \
    LEDGER_SUMMARY_RPT="$ENVDIR/s.rpt"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$ENVDIR/same-history.log" "F019"
assert_same_content testdata/history/prior-batch.dat "$ENVDIR/history.dat"

# The journal is directed into a directory that does not exist.  The
# batch must stop before posting anything.
begin_test "environment: journal cannot be opened"
run_program_with "$ENVDIR/no-journal.log" \
    LEDGER_CONTROL="$CONTROL" LEDGER_ACCOUNTS_IN="$ACCOUNTS" \
    LEDGER_TXN_IN="$TXN/deposit-valid.dat" \
    LEDGER_ACCOUNTS_OUT="$ENVDIR/a.out" \
    LEDGER_JOURNAL_OUT="$ENVDIR/no-such-directory/j.out" \
    LEDGER_POSTED_RPT="$ENVDIR/p.rpt" LEDGER_REJECT_RPT="$ENVDIR/r.rpt" \
    LEDGER_SUMMARY_RPT="$ENVDIR/s.rpt"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$ENVDIR/no-journal.log" "F014"
assert_file_absent "$ENVDIR/a.out"

begin_test "environment: a report cannot be opened"
run_program_with "$ENVDIR/no-report.log" \
    LEDGER_CONTROL="$CONTROL" LEDGER_ACCOUNTS_IN="$ACCOUNTS" \
    LEDGER_TXN_IN="$TXN/deposit-valid.dat" \
    LEDGER_ACCOUNTS_OUT="$ENVDIR/a.out" \
    LEDGER_JOURNAL_OUT="$ENVDIR/j2.out" \
    LEDGER_POSTED_RPT="$ENVDIR/p.rpt" \
    LEDGER_REJECT_RPT="$ENVDIR/no-such-directory/r.rpt" \
    LEDGER_SUMMARY_RPT="$ENVDIR/s.rpt"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$ENVDIR/no-report.log" "F014"
assert_file_absent "$ENVDIR/a.out"

# A good run followed by a failed run into the same directory: the
# wrapper must not leave the good run's master where the failed run's
# results are expected.
begin_test "environment: failed run leaves no stale outputs"
run_batch "$ENVDIR/stale" "$CONTROL" "$ACCOUNTS" "$TXN/deposit-valid.dat"
assert_file_exists "$ENVDIR/stale/accounts.out"
run_batch "$ENVDIR/stale" "$CONTROL" "$ACCOUNTS" "$TXN/does-not-exist.dat"
assert_equal 12 "$BATCH_RC" "return code"
assert_file_absent "$ENVDIR/stale/accounts.out"
assert_file_absent "$ENVDIR/stale/journal.out"
assert_file_absent "$ENVDIR/stale/summary.rpt"
assert_contains "$ENVDIR/stale/job.log" "F010"

# ---------------------------------------------------------------------
# scale and resource limits
# ---------------------------------------------------------------------
SCALE="$OUT/scale"
mkdir -p "$SCALE"
GENERATE="tests/lib/generate-scale-data.awk"
DEFAULTS="testdata/control/defaults.ctl"

awk -v mode=accounts -v count=100 -f "$GENERATE" > "$SCALE/accounts-100.dat"
awk -v mode=transactions -v count=20000 -v accounts=100 -f "$GENERATE" \
    > "$SCALE/transactions-20000.dat"

begin_test "scale: 20,000 transactions over 100 accounts"
run_batch "$SCALE/large" "$DEFAULTS" "$SCALE/accounts-100.dat" \
          "$SCALE/transactions-20000.dat" testdata/history/empty.dat
assert_equal 0 "$BATCH_RC" "return code"
LARGE="$SCALE/large/summary.rpt"
assert_equal 20,000 "$(summary_value "$LARGE" \
    "TRANSACTION RECORDS READ")" "records read"
assert_equal 20,000 "$(summary_value "$LARGE" \
    "TRANSACTIONS POSTED")" "transactions posted"
assert_equal 0 "$(summary_value "$LARGE" \
    "TRANSACTIONS REJECTED")" "transactions rejected"
assert_equal 6,667 "$(summary_value "$LARGE" "DEPOSITS POSTED")" "deposits"
assert_equal 6,667 "$(summary_value "$LARGE" \
    "WITHDRAWALS POSTED")" "withdrawals"
assert_equal 6,666 "$(summary_value "$LARGE" "TRANSFERS POSTED")" "transfers"
assert_equal 40,000 "$(summary_value "$LARGE" \
    "JOURNAL ENTRIES REPLAYED")" "journal entries replayed"
assert_equal PASSED "$(summary_value "$LARGE" "STATUS")" \
    "reconciliation status"
assert_line_count 40000 "$SCALE/large/journal.out"
assert_line_count 20000 "$SCALE/large/history.out"
assert_succeeds "independent ledger check of the large batch" \
    awk -f tests/lib/check-ledger.awk "$SCALE/accounts-100.dat" \
        "$SCALE/large/journal.out" "$SCALE/large/accounts.out"
# The deposit total in the summary must equal the sum of the deposit
# amounts in the input file, worked out here independently.
expected_deposits=$(awk 'substr($0, 21, 1) == "D" \
        { total += substr($0, 42, 13) } \
    END { printf "%.2f", total / 100 }' "$SCALE/transactions-20000.dat")
actual_deposits=$(summary_value "$LARGE" "DEPOSITS POSTED AMOUNT" \
    | tr -d ',')
assert_equal "$expected_deposits" "$actual_deposits" "deposit total"

# Account table capacity is 5000.
awk -v mode=accounts -v count=5000 -f "$GENERATE" > "$SCALE/accounts-5000.dat"
awk -v mode=accounts -v count=5001 -f "$GENERATE" > "$SCALE/accounts-5001.dat"
awk -v mode=transactions -v count=30 -v accounts=5000 -f "$GENERATE" \
    > "$SCALE/transactions-30.dat"

begin_test "limits: 5000 accounts are accepted"
run_batch "$SCALE/accounts-at-limit" "$DEFAULTS" "$SCALE/accounts-5000.dat" \
          "$SCALE/transactions-30.dat"
assert_equal 0 "$BATCH_RC" "return code"
assert_line_count 5001 "$SCALE/accounts-at-limit/accounts.out"

begin_test "limits: 5001 accounts are refused"
run_batch "$SCALE/accounts-over-limit" "$DEFAULTS" \
          "$SCALE/accounts-5001.dat" "$SCALE/transactions-30.dat"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$SCALE/accounts-over-limit/job.log" "F009"
assert_file_absent "$SCALE/accounts-over-limit/accounts.out"

# The id store holds 50000 ids, history included.  With 49,990 ids of
# history there is room for 10 more: of 30 transactions the first 10
# post and the other 20 are refused, because a transaction that could
# not be remembered could be posted twice.
awk -v mode=history -v count=49990 -f "$GENERATE" > "$SCALE/history-49990.dat"
awk -v mode=history -v count=50000 -f "$GENERATE" > "$SCALE/history-50000.dat"
awk -v mode=history -v count=50001 -f "$GENERATE" > "$SCALE/history-50001.dat"

begin_test "limits: id store fills during the batch"
run_batch "$SCALE/ids-fill" "$DEFAULTS" "$SCALE/accounts-100.dat" \
          "$SCALE/transactions-30.dat" "$SCALE/history-49990.dat"
assert_equal 4 "$BATCH_RC" "return code"
assert_equal 10 "$(summary_value "$SCALE/ids-fill/summary.rpt" \
    "TRANSACTIONS POSTED")" "transactions posted"
assert_equal 20 "$(summary_value "$SCALE/ids-fill/summary.rpt" \
    "B015  DUPLICATE-CHECK TABLE FULL, CANNOT POST SAFELY")" \
    "transactions refused for lack of room"
assert_line_count 50000 "$SCALE/ids-fill/history.out"
assert_succeeds "independent ledger check with a full id store" \
    awk -f tests/lib/check-ledger.awk "$SCALE/accounts-100.dat" \
        "$SCALE/ids-fill/journal.out" "$SCALE/ids-fill/accounts.out"

begin_test "limits: history exactly at capacity loads"
run_batch "$SCALE/ids-at-limit" "$DEFAULTS" "$SCALE/accounts-100.dat" \
          "$SCALE/transactions-30.dat" "$SCALE/history-50000.dat"
assert_equal 4 "$BATCH_RC" "return code"
assert_equal 30 "$(summary_value "$SCALE/ids-at-limit/summary.rpt" \
    "TRANSACTIONS REJECTED")" "transactions rejected"

begin_test "limits: history over capacity is refused"
run_batch "$SCALE/ids-over-limit" "$DEFAULTS" "$SCALE/accounts-100.dat" \
          "$SCALE/transactions-30.dat" "$SCALE/history-50001.dat"
assert_equal 12 "$BATCH_RC" "return code"
assert_contains "$SCALE/ids-over-limit/job.log" "F018"

# A record far longer than the 200-byte record area.  How the runtime
# splits it differs between GnuCOBOL versions, so only what must hold
# on every version is asserted: nothing from it is posted, and the
# valid record after it still is.
begin_test "limits: record longer than the record area"
{
    awk 'BEGIN { for (i = 1; i <= 700; i++) printf "X"; printf "\n" }'
    cat "$TXN/deposit-valid.dat"
} > "$SCALE/very-long-record.dat"
run_batch "$SCALE/very-long" "$CONTROL" "$ACCOUNTS" \
          "$SCALE/very-long-record.dat"
assert_equal 4 "$BATCH_RC" "return code"
assert_equal 1 "$(summary_value "$SCALE/very-long/summary.rpt" \
    "TRANSACTIONS POSTED")" "transactions posted"
assert_contains "$SCALE/very-long/posted.rpt" "DEP000000001"
assert_contains "$SCALE/very-long/accounts.out" \
    "A1000000001ALICE ANDERSON                A+000000000125000"

# An output device that accepts the open and then fails every write
# is the nearest thing to "disk full" that can be staged.  Linux has
# one (/dev/full).  The run must be abandoned with return code 16 and
# must not write a closing master.
if [ "$(uname -s)" = "Linux" ] && [ -c /dev/full ]; then
    begin_test "environment: journal write fails mid-run"
    mkdir -p "$SCALE/write-failure"
    env LEDGER_CONTROL="$DEFAULTS" \
        LEDGER_ACCOUNTS_IN="$SCALE/accounts-100.dat" \
        LEDGER_TXN_IN="$SCALE/transactions-20000.dat" \
        LEDGER_ACCOUNTS_OUT="$SCALE/write-failure/accounts.out" \
        LEDGER_JOURNAL_OUT=/dev/full \
        LEDGER_POSTED_RPT="$SCALE/write-failure/posted.rpt" \
        LEDGER_REJECT_RPT="$SCALE/write-failure/rejects.rpt" \
        LEDGER_SUMMARY_RPT="$SCALE/write-failure/summary.rpt" \
        timeout 120 "$BIN/ledger-batch" > "$SCALE/write-failure/job.log" 2>&1
    assert_equal 16 "$?" "return code"
    assert_contains "$SCALE/write-failure/job.log" "F015"
    assert_file_absent "$SCALE/write-failure/accounts.out"
    assert_contains "$SCALE/write-failure/summary.rpt" "RUN ABANDONED"
else
    echo "NOTE  journal write-failure scenario needs Linux /dev/full;" \
         "not run on $(uname -s)"
fi

finish_suite "REGRESSION"
