# Business rules and accounting model

## Accounting model

### Accounts

- **Customer accounts** are the accounts on the account master. From
  the institution's point of view they are liabilities: money it owes
  its customers. A **credit (CR) increases** a customer balance and a
  **debit (DR) decreases** it.
- **The clearing account**, number `0000000000`, is a single internal
  asset account representing cash that has crossed the counter. A
  **debit increases** it and a **credit decreases** it. It is not on
  the account master, cannot be named in a transaction, and its
  position starts every batch at zero. Its closing position is the net
  cash the batch took in (deposits less withdrawals) and is printed in
  the summary.

### Every posting is a balanced pair

A posted transaction produces exactly two journal entries for the same
amount, the debit first:

| Transaction | Debit entry | Credit entry | Effect |
|-------------|-------------|--------------|--------|
| Deposit of *x* to account A | clearing | A | A + *x*; clearing + *x* |
| Withdrawal of *x* from A | A | clearing | A − *x*; clearing − *x* |
| Transfer of *x* from A to B | A | B | A − *x*; B + *x*; clearing unchanged |

There is no other way for a balance to change.

### Opening balances

An account's opening balance for a batch is the balance on its record
in the opening account master. The batch accepts the master only if its
detail records are in sequence and their count and balance total equal
the trailer record's control totals. Otherwise the batch is abandoned
before any transaction is read (F005–F009).

The system does not create accounts, change names or change statuses.
Those are maintenance of the master, which is outside its scope.

### Rejected transactions

A rejected transaction:

- produces **no** journal entries;
- changes **no** balance, daily-debit total or clearing position;
- is **not** recorded in the history file, so it can be corrected and
  submitted again under the same id;
- appears in the reject report with its status code, and is counted in
  the summary.

### Money

All amounts are fixed-point decimal with two decimal places, held as
`PACKED-DECIMAL`. No floating-point item or function is used.

| Quantity | Picture | Largest value |
|----------|---------|---------------|
| transaction amount, limits | `S9(11)V99` | 99,999,999,999.99 |
| account balance | `S9(13)V99` | 9,999,999,999,999.99 |
| totals, clearing position | `S9(15)V99` | 999,999,999,999,999.99 |

Every addition or subtraction that produces a balance or a total has an
`ON SIZE ERROR` clause. An overflow of a balance rejects the transaction
(B014); an overflow of a control total abandons the batch (F016). No
value is ever truncated or wrapped. Because only addition and
subtraction of two-decimal values occur, there is no rounding anywhere.

## Invariants

These hold after every completed batch, and reconciliation checks each
one from the files on disk (the R code is what is reported if it does
not hold):

| # | Invariant | Code |
|---|-----------|------|
| 1 | Journal sequence numbers are 1, 2, 3 … with no gap or repeat | R007 |
| 2 | Entries come in pairs: a DR then a CR, same transaction id, same amount | R009 |
| 3 | Total debits = total credits | R001 |
| 4 | Every customer entry is for an account on the opening master | R003 |
| 5 | Each entry's balance-after = that account's opening balance with every entry up to and including it applied | R005 |
| 6 | The closing master lists the same accounts, names and statuses as the opening master | R004 |
| 7 | Each closing balance = opening balance + credits − debits to that account | R002 |
| 8 | Closing total of customer balances = opening total + clearing position | R006 |
| 9 | The totals derived from disk = the totals kept in memory during the run | R010 |

## Processing rules

Each record is taken through three stages. The first stage to object
sets the record's single status code; later stages are not consulted.

### Stage 1 — validation (`TXNVALID`)

Depends only on the record and the control file.

| Order | Rule | Code |
|-------|------|------|
| 1 | The record contains only printable characters (space to `~`) | V014 |
| 2 | The record is not longer than 80 bytes | V002 |
| 3 | The record is at least 54 bytes (reaches the end of the amount) | V001 |
| 4 | The transaction id is exactly 12 characters, each `A`–`Z` or `0`–`9` | V003 |
| 5 | The type is `D`, `W` or `T` | V006 |
| 6 | The date is 8 digits | V004 |
| 7 | The date is a real calendar date, year 1601 or later | V005 |
| 8 | The account is 10 digits | V007 |
| 9 | The account is not the clearing account | V013 |
| 10 | Transfer: the destination is 10 digits | V008 |
| 11 | Transfer: the destination is not the clearing account | V013 |
| 12 | Transfer: the destination differs from the source | V012 |
| 13 | Deposit or withdrawal: the destination field is blank | V009 |
| 14 | The amount is 13 digits | V010 |
| 15 | The amount is greater than zero | V011 |
| 16 | The date is not after the batch date | B001 |
| 17 | The date is not more than `MAX-BACKDATE-DAYS` before the batch date | B002 |
| 18 | The amount does not exceed the limit for its type | B003 deposit, B004 withdrawal, B005 transfer |

A limit is inclusive: an amount equal to the limit is accepted.

### Stage 2 — duplicate check (`HISTSTOR`)

| Rule | Code |
|------|------|
| The id has not already been posted by this batch | B006 |
| The id has not been posted by an earlier batch (needs the history file) | B007 |
| There is room to remember the id | B015 |

"Posted" is the operative word. An id that was *rejected* earlier in the
file is not remembered, so a later record with the same id is judged on
its own merits. The integration case `duplicate-ids` shows both
behaviours.

B015 exists because posting a transaction whose id cannot be remembered
would defeat duplicate detection for it; refusing it is the safe side.

### Stage 3 — posting rules (`ACCTPROC`)

| Order | Rule | Code |
|-------|------|------|
| 1 | The account is on the master | B008 |
| 2 | The account is active (status `A`) | B010 |
| 3 | Transfer: the destination is on the master | B009 |
| 4 | Transfer: the destination is active | B011 |
| 5 | Withdrawal or transfer: balance − amount ≥ −`OVERDRAFT-LIMIT` | B012 |
| 6 | Withdrawal or transfer: the account's debits this batch + amount ≤ `DAILY-DEBIT-LIMIT` | B013 |
| 7 | No balance or the clearing position would exceed its field | B014 |

Notes:

- Frozen (`F`) and closed (`C`) accounts take part in nothing: no
  debits and no credits.
- The daily debit limit counts withdrawals and outgoing transfers. It
  is per account and per batch; it does not carry over between batches,
  so the rule is "per day" only if one batch is run per day.
- Deposits and incoming transfers are never limited by the daily limit.
- Transactions are processed strictly in file order. A withdrawal that
  fails for lack of funds is not retried if a later deposit would have
  covered it.

## Status codes

The first character is the class. Message texts are in
`src/error-messages.cob`.

### V — the record is not a valid transaction (rejected)

| Code | Message |
|------|---------|
| V001 | RECORD SHORTER THAN THE REQUIRED FIELDS |
| V002 | RECORD LONGER THAN 80 BYTES |
| V003 | TRANSACTION ID NOT 12 CHARACTERS A-Z 0-9 |
| V004 | TRANSACTION DATE NOT NUMERIC |
| V005 | TRANSACTION DATE NOT A CALENDAR DATE |
| V006 | TRANSACTION TYPE NOT D, W OR T |
| V007 | ACCOUNT NUMBER NOT 10 DIGITS |
| V008 | TRANSFER DESTINATION ACCOUNT NOT 10 DIGITS |
| V009 | DESTINATION ACCOUNT GIVEN ON NON-TRANSFER |
| V010 | AMOUNT NOT 13 DIGITS |
| V011 | AMOUNT IS ZERO |
| V012 | TRANSFER SOURCE AND DESTINATION ARE THE SAME |
| V013 | ACCOUNT NUMBER IS RESERVED FOR INTERNAL USE |
| V014 | RECORD CONTAINS NON-PRINTABLE CHARACTERS |

### B — a business rule refused the posting (rejected)

| Code | Message |
|------|---------|
| B001 | TRANSACTION DATE IS AFTER THE BATCH DATE |
| B002 | TRANSACTION DATE IS OLDER THAN ALLOWED |
| B003 | DEPOSIT EXCEEDS THE PER-TRANSACTION LIMIT |
| B004 | WITHDRAWAL EXCEEDS THE PER-TRANSACTION LIMIT |
| B005 | TRANSFER EXCEEDS THE PER-TRANSACTION LIMIT |
| B006 | DUPLICATE TRANSACTION ID IN THIS BATCH |
| B007 | TRANSACTION ID ALREADY POSTED BY AN EARLIER RUN |
| B008 | ACCOUNT NOT ON THE ACCOUNT MASTER |
| B009 | DESTINATION ACCOUNT NOT ON THE ACCOUNT MASTER |
| B010 | ACCOUNT IS NOT ACTIVE |
| B011 | DESTINATION ACCOUNT IS NOT ACTIVE |
| B012 | INSUFFICIENT AVAILABLE FUNDS |
| B013 | ACCOUNT DAILY DEBIT LIMIT EXCEEDED |
| B014 | POSTING WOULD EXCEED THE LARGEST BALANCE HELD |
| B015 | DUPLICATE-CHECK TABLE FULL, CANNOT POST SAFELY |

### F — fatal: the batch is abandoned

| Code | Message |
|------|---------|
| F001 | CONTROL FILE CANNOT BE OPENED OR READ |
| F002 | CONTROL FILE CONTAINS AN INVALID ENTRY |
| F003 | BATCH-DATE MISSING OR NOT A CALENDAR DATE |
| F004 | ACCOUNT MASTER CANNOT BE OPENED OR READ |
| F005 | ACCOUNT MASTER RECORD IS INVALID |
| F006 | ACCOUNT MASTER OUT OF SEQUENCE OR DUPLICATED |
| F007 | ACCOUNT MASTER HAS NO TRAILER RECORD |
| F008 | ACCOUNT MASTER DOES NOT MATCH ITS TRAILER |
| F009 | ACCOUNT MASTER HAS TOO MANY ACCOUNTS |
| F010 | TRANSACTION FILE CANNOT BE OPENED |
| F011 | TRANSACTION FILE READ ERROR |
| F012 | HISTORY FILE CANNOT BE OPENED OR READ |
| F013 | HISTORY FILE RECORD IS INVALID OR DUPLICATED |
| F014 | OUTPUT FILE CANNOT BE OPENED |
| F015 | OUTPUT FILE WRITE ERROR |
| F016 | CONTROL TOTAL TOO LARGE TO HOLD |
| F017 | REQUIRED FILE NAME VARIABLE IS NOT SET |
| F018 | HISTORY FILE HAS TOO MANY TRANSACTION IDS |
| F019 | INPUT AND OUTPUT FILE NAMES ARE THE SAME |
| F020 | JOURNAL FILE CANNOT BE OPENED OR READ |

### R — reconciliation discrepancy (return code 8)

| Code | Message |
|------|---------|
| R001 | JOURNAL TOTAL DEBITS DO NOT EQUAL CREDITS |
| R002 | CLOSING BALANCE NOT OPENING PLUS MOVEMENTS |
| R003 | JOURNAL ENTRY FOR ACCOUNT NOT ON THE MASTER |
| R004 | OPENING AND CLOSING MASTERS LIST DIFFERENT ACCTS |
| R005 | JOURNAL BALANCE-AFTER DOES NOT FOLLOW ENTRIES |
| R006 | CLOSING TOTAL NOT OPENING TOTAL PLUS NET CASH |
| R007 | JOURNAL SEQUENCE NUMBER GAP OR REPEAT |
| R008 | JOURNAL RECORD IS INVALID |
| R009 | JOURNAL DEBIT/CREDIT PAIR DOES NOT MATCH |
| R010 | JOURNAL ON DISK DIFFERS FROM RUN CONTROL TOTALS |

## Assumptions

- One currency. Amounts have exactly two decimal places.
- The batch date is supplied by the operator and is trusted.
- A transaction id is unique for all time, not per day or per account.
- No interest, fees, holds, value dating, reversals or standing orders.
- Balances may be negative on the master (for example after an
  overdraft was allowed by an earlier control file); a negative balance
  is not itself an error.
