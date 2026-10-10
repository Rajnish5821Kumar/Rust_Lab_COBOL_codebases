# Record formats

All files are `LINE SEQUENTIAL` text: one record per line, fields at
fixed column positions, no delimiters. Trailing spaces on a line carry
no information and are not written. Column numbers below start at 1.

Conventions used in every file:

- **Amounts** are digits only with two implied decimal places, so
  `0000000012345` is 123.45. There is never a decimal point or a
  thousands separator in a data file.
- **Signed amounts** (balances) have the sign as a separate leading
  character, `+` or `-`, followed by the digits.
- **Dates** are `YYYYMMDD`.
- **Account numbers** are 10 digits. `0000000000` is reserved for the
  internal clearing account and may not appear in input files.

The authoritative definitions are the copybooks named in each section.

## Inputs

### Control file

Copybook: none (parsed in `src/control-loader.cob`). One parameter per
line: keyword in columns 1–24, value starting in column 25. Blank lines
and lines starting with `*` are ignored.

| Keyword | Value | Default | Meaning |
|---------|-------|---------|---------|
| `BATCH-DATE` | `YYYYMMDD` | required | the business date of the batch |
| `BATCH-ID` | 1–8 characters | `BATCH` | label printed on reports |
| `MAX-DEPOSIT-AMOUNT` | 13 digits | 99,999,999,999.99 | largest single deposit |
| `MAX-WITHDRAWAL-AMOUNT` | 13 digits | 99,999,999,999.99 | largest single withdrawal |
| `MAX-TRANSFER-AMOUNT` | 13 digits | 99,999,999,999.99 | largest single transfer |
| `DAILY-DEBIT-LIMIT` | 13 digits | 99,999,999,999.99 | most one account may be debited in one batch |
| `OVERDRAFT-LIMIT` | 13 digits | 0.00 | how far below zero a balance may go |
| `MAX-BACKDATE-DAYS` | 4 digits | 0030 | oldest transaction date accepted, in days before the batch date |

Example (`testdata/control/standard.ctl`):

```
BATCH-ID                B2026015
BATCH-DATE              20260115
MAX-DEPOSIT-AMOUNT      0000100000000
MAX-WITHDRAWAL-AMOUNT   0000000500000
MAX-TRANSFER-AMOUNT     0000002000000
DAILY-DEBIT-LIMIT       0000002500000
OVERDRAFT-LIMIT         0000000000000
MAX-BACKDATE-DAYS       0005
```

An unknown keyword, a keyword given twice, a value of the wrong shape
or anything after the value is fatal (F002). A missing or impossible
`BATCH-DATE` is fatal (F003).

### Account master

Copybook: `copybooks/account-record.cpy`. 80 bytes. Detail records in
strictly ascending account-number order, followed by exactly one
trailer record, which must be the last record.

Detail record:

| Columns | Length | Field | Content |
|---------|--------|-------|---------|
| 1 | 1 | record type | `A` |
| 2–11 | 10 | account number | 10 digits, not `0000000000` |
| 12–41 | 30 | account name | printable characters |
| 42 | 1 | status | `A` active, `F` frozen, `C` closed |
| 43 | 1 | balance sign | `+` or `-` |
| 44–58 | 15 | balance | 13 digits + 2 implied decimals |
| 59–80 | 22 | unused | spaces |

Trailer record:

| Columns | Length | Field | Content |
|---------|--------|-------|---------|
| 1 | 1 | record type | `T` |
| 2–8 | 7 | record count | number of detail records |
| 9 | 1 | total sign | `+` or `-` |
| 10–26 | 17 | total balance | 15 digits + 2 implied decimals: the sum of all balances |
| 27–80 | 54 | unused | spaces |

Example:

```
A1000000001ALICE ANDERSON                A+000000000100000
A1000000002BRIAN BAKER                   A+000000000250050
A1000000007GEORGE GREY                   A-000000000002500
T0000003+00000000000347550
```

The master is how opening balances are established: the balance on each
detail record is that account's opening balance for the batch. The
trailer is the control that the file is complete and unaltered since it
was written; a master that does not match its trailer is refused (F008)
and nothing is posted.

The closing master a batch writes has the same layout, so it is used
unchanged as the next batch's opening master.

### Transaction file

Copybook: `copybooks/transaction-record.cpy`. 80 bytes.

| Columns | Length | Field | Content |
|---------|--------|-------|---------|
| 1–12 | 12 | transaction id | exactly 12 characters, `A`–`Z` and `0`–`9` |
| 13–20 | 8 | transaction date | `YYYYMMDD` |
| 21 | 1 | type | `D` deposit, `W` withdrawal, `T` transfer |
| 22–31 | 10 | account | credited by `D`; debited by `W` and `T` |
| 32–41 | 10 | destination account | account credited by `T`; spaces for `D` and `W` |
| 42–54 | 13 | amount | 11 digits + 2 implied decimals, greater than zero |
| 55–80 | 26 | description | free text, optional, not interpreted |

Example (a 1,250.00 deposit, then a 4,200.00 transfer from account
1000000003 to account 1000000002):

```
MIX00000000120260115D1000000001          0000000125000SALARY
MIX00000000320260115T100000000310000000020000000420000INVOICE 1041
```

A record may be as short as 54 bytes (no description). An empty file is
a valid batch of zero transactions. A blank line is a malformed record
and is rejected (V001).

### History file (optional)

Copybook: `copybooks/history-record.cpy`. 20 bytes. One record for each
transaction id already posted.

| Columns | Length | Field | Content |
|---------|--------|-------|---------|
| 1–12 | 12 | transaction id | as on the transaction that was posted |
| 13–20 | 8 | posted date | batch date of the batch that posted it |

Before the first batch, use an empty file. After each batch, the
`history.out` it wrote is the history file for the next one.

## Outputs

### Journal

Copybook: `copybooks/ledger-record.cpy`. 98 bytes. Two records per
posted transaction: the debit, then the credit.

| Columns | Length | Field | Content |
|---------|--------|-------|---------|
| 1–8 | 8 | sequence | 1, 2, 3 … with no gaps |
| 9–20 | 12 | transaction id | |
| 21–28 | 8 | transaction date | from the transaction |
| 29 | 1 | type | `D`, `W` or `T` |
| 30–39 | 10 | account | account this entry is posted to |
| 40–41 | 2 | side | `DR` or `CR` |
| 42–54 | 13 | amount | 11 digits + 2 implied decimals |
| 55 | 1 | balance sign | `+` or `-` |
| 56–72 | 17 | balance after | 15 digits + 2 implied decimals: balance of the account after this entry |
| 73–82 | 10 | contra account | the other account of the pair |
| 83–90 | 8 | batch date | batch that posted it |
| 91–98 | 8 | source record | record number in the transaction file |

Example (a 1,250.00 deposit to account 1000000001, which had 1,000.00):

```
00000001MIX00000000120260115D0000000000DR0000000125000+0000000000012500010000000012026011500000001
00000002MIX00000000120260115D1000000001CR0000000125000+0000000000022500000000000002026011500000001
```

### Closing account master

Same layout as the account master input. Account names and statuses are
copied unchanged; only balances and the trailer total differ.

### Updated history

Same layout as the history input: the input records in their original
order, followed by one record for each transaction this batch posted,
dated with the batch date.

### Reports

The three reports are for people, not programs; their layouts may
change. Each is at most 132 columns.

- `posted.rpt` — record number, id, date, type, account, destination,
  amount, the account's balance after posting and, for a transfer, the
  destination's balance after posting.
- `rejects.rpt` — record number, then the id, date, type, accounts and
  amount **exactly as they appeared in the input** (so a malformed
  amount is shown as received), then the status code and its message.
- `summary.rpt` — batch id and date, rules in force, input counts,
  posted counts and amounts by type, rejects by reason, journal totals,
  opening/closing balance totals, reconciliation result, return code.
