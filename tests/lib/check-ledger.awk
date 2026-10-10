#!/usr/bin/awk -f
#
# check-ledger.awk - independent check of a batch's accounting.
#
# Usage:
#   awk -f tests/lib/check-ledger.awk OPENING JOURNAL CLOSING
#
# This re-derives the ledger invariants from the three files without
# using any of the COBOL code, so a defect shared by the posting
# engine and the COBOL reconciliation program cannot hide from the
# tests.  It is a test oracle, not part of the product.
#
# Invariants checked:
#   1. journal sequence numbers run 1..n with no gap
#   2. entries come in pairs: a DR then a CR with the same
#      transaction id and the same amount
#   3. total debits equal total credits
#   4. each entry's balance-after equals the running balance of its
#      account (opening balance, then every earlier entry applied)
#   5. each closing balance equals opening + credits - debits
#   6. opening and closing masters list the same accounts
#   7. the closing trailer count and total match the closing details
#   8. closing total - opening total = clearing position
#
# All amounts are handled as whole cents.  Awk numbers are doubles,
# which hold integers exactly up to 2^53 (about 9.0e15); the largest
# balance the system holds is 1.0e15 cents, so the arithmetic here is
# exact for single balances and for the totals used in the tests.
#
# Exit status: 0 all invariants hold, 1 otherwise (each failure is
# printed).

function fail(message) {
    printf "check-ledger: %s\n", message
    failures++
}

# Sign character followed by digits, e.g. "+000000000100000".
function signed_cents(text,    value) {
    value = substr(text, 2) + 0
    return (substr(text, 1, 1) == "-") ? -value : value
}

BEGIN {
    CLEARING = "0000000000"
    failures = 0
    if (ARGC != 4) {
        print "usage: check-ledger.awk OPENING JOURNAL CLOSING"
        exit_code = 2
        exit
    }
}

{ sub(/\r$/, "") }

# ---- opening master -------------------------------------------------
FILENAME == ARGV[1] && substr($0, 1, 1) == "A" {
    id = substr($0, 2, 10)
    opening[id] = signed_cents(substr($0, 43, 16))
    running[id] = opening[id]
    opening_total += opening[id]
    opening_count++
    next
}
FILENAME == ARGV[1] { next }

# ---- journal --------------------------------------------------------
FILENAME == ARGV[2] {
    entries++
    seq    = substr($0, 1, 8) + 0
    txn    = substr($0, 9, 12)
    acct   = substr($0, 30, 10)
    side   = substr($0, 40, 2)
    amount = substr($0, 42, 13) + 0
    after  = signed_cents(substr($0, 55, 18))

    if (seq != entries)
        fail("journal sequence " seq " found where " entries " expected")
    if (amount <= 0)
        fail("journal entry " seq " has a non-positive amount")

    if (entries % 2 == 1) {
        if (side != "DR")
            fail("journal entry " seq " should be a DR")
        held_txn = txn
        held_amount = amount
    } else {
        if (side != "CR")
            fail("journal entry " seq " should be a CR")
        if (txn != held_txn || amount != held_amount)
            fail("journal entry " seq " does not match its debit")
    }

    if (side == "DR") total_debits += amount
    else              total_credits += amount

    if (acct == CLEARING) {
        # Asset account: a debit increases it.
        clearing += (side == "DR") ? amount : -amount
        expected_after = clearing
    } else if (acct in running) {
        # Customer (liability) account: a credit increases it.
        running[acct] += (side == "CR") ? amount : -amount
        expected_after = running[acct]
    } else {
        fail("journal entry " seq " is for unknown account " acct)
        next
    }
    if (after != expected_after)
        fail("journal entry " seq " balance-after is wrong for " acct)
    next
}

# ---- closing master -------------------------------------------------
FILENAME == ARGV[3] && substr($0, 1, 1) == "A" {
    id = substr($0, 2, 10)
    balance = signed_cents(substr($0, 43, 16))
    closing_total += balance
    closing_count++
    if (!(id in opening))
        fail("closing master has account " id " that did not open")
    else if (balance != running[id])
        fail("closing balance of " id " is not opening + movements")
    seen[id] = 1
    next
}
FILENAME == ARGV[3] && substr($0, 1, 1) == "T" {
    trailer_seen = 1
    if (substr($0, 2, 7) + 0 != closing_count)
        fail("closing trailer count does not match the detail records")
    if (signed_cents(substr($0, 9, 18)) != closing_total)
        fail("closing trailer total does not match the detail records")
    next
}

END {
    if (exit_code == 2) exit 2
    if (entries % 2 != 0)
        fail("journal has an odd number of entries")
    if (total_debits != total_credits)
        fail("total debits do not equal total credits")
    for (id in opening)
        if (!(id in seen))
            fail("account " id " is missing from the closing master")
    if (!trailer_seen)
        fail("closing master has no trailer")
    if (closing_total - opening_total != clearing)
        fail("closing total is not opening total + clearing position")

    if (failures > 0) exit 1
    printf "check-ledger: ok (%d accounts, %d journal entries)\n", \
           opening_count, entries
}
