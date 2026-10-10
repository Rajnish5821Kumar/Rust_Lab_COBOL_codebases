#!/usr/bin/env bash
#
# run-batch.sh - run one ledger batch.
#
# Usage:
#   scripts/run-batch.sh CONTROL ACCOUNTS TRANSACTIONS OUTDIR [HISTORY]
#
#   CONTROL       control file (business parameters, batch date)
#   ACCOUNTS      opening account master
#   TRANSACTIONS  transaction file
#   OUTDIR        directory for this run's outputs (created if
#                 missing; outputs of an earlier run in it are removed
#                 first so a failed run cannot leave stale files that
#                 look like results)
#   HISTORY       optional posted-transaction history from earlier
#                 batches.  Without it, a transaction already posted
#                 by an earlier batch is NOT detected.
#
# Outputs written to OUTDIR:
#   accounts.out  closing account master (opening master for the
#                 next batch)
#   journal.out   journal entries
#   history.out   HISTORY plus the ids this batch posted (HISTORY for
#                 the next batch)
#   posted.rpt    posted transactions report
#   rejects.rpt   rejected transactions report
#   summary.rpt   batch summary and reconciliation result
#   job.log       the program's job log (also shown on the terminal)
#
# This script plays the part of the JCL: it only maps file names to
# the program's environment variables.  It exits with the program's
# return code:
#   0 clean, 4 rejects, 8 reconciliation failed, 12 abandoned before
#   processing, 16 abandoned during processing.
# For 8 or more the files in OUTDIR must not be used.
#
# Environment:
#   LEDGER_BIN_DIR  directory holding ledger-batch (default: bin/
#                   in this repository)
#
set -uo pipefail

if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    sed -n '3,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRAM="${LEDGER_BIN_DIR:-$ROOT/bin}/ledger-batch"

if [ ! -x "$PROGRAM" ] && [ ! -x "$PROGRAM.exe" ]; then
    echo "run-batch.sh: $PROGRAM not found; run scripts/build.sh" >&2
    exit 2
fi

OUTDIR="$4"
mkdir -p "$OUTDIR" || exit 2
rm -f "$OUTDIR/accounts.out" "$OUTDIR/journal.out" \
      "$OUTDIR/history.out" "$OUTDIR/posted.rpt" \
      "$OUTDIR/rejects.rpt" "$OUTDIR/summary.rpt" "$OUTDIR/job.log"

export LEDGER_CONTROL="$1"
export LEDGER_ACCOUNTS_IN="$2"
export LEDGER_TXN_IN="$3"
export LEDGER_ACCOUNTS_OUT="$OUTDIR/accounts.out"
export LEDGER_JOURNAL_OUT="$OUTDIR/journal.out"
export LEDGER_HISTORY_OUT="$OUTDIR/history.out"
export LEDGER_POSTED_RPT="$OUTDIR/posted.rpt"
export LEDGER_REJECT_RPT="$OUTDIR/rejects.rpt"
export LEDGER_SUMMARY_RPT="$OUTDIR/summary.rpt"
if [ "$#" -eq 5 ]; then
    export LEDGER_HISTORY_IN="$5"
else
    unset LEDGER_HISTORY_IN
fi

"$PROGRAM" | tee "$OUTDIR/job.log"
exit "${PIPESTATUS[0]}"
