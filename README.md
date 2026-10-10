# Enterprise COBOL Transaction Processing and Ledger System

A batch transaction-processing and double-entry ledger system written in
COBOL (GnuCOBOL 3.x). It reads a file of deposits, withdrawals and
transfers, validates each one, posts the good ones against an account
master, journals every posting as a balanced debit/credit pair, reports
what was posted and what was rejected and why, and then proves from the
files on disk that the books balance.

> **This is a portfolio and reference application. It is not a certified
> banking system.** It has never been deployed in production and has
> processed only the synthetic data in this repository. It must not be
> used to process real funds or real customer data without independent
> engineering, security, compliance and operational validation. See
> [Known limitations](#known-limitations) and
> [docs/security.md](docs/security.md).

## What it does

- Reads fixed-width transactions from a sequential file and validates
  every field: transaction id, date (real calendar dates, leap years),
  type, account numbers and amount.
- Posts deposits, withdrawals and transfers, refusing any debit that
  would exceed available funds, a per-transaction limit, or a
  per-account daily debit limit. Limits and the batch date come from a
  control file, not from the code or the system clock.
- Detects duplicate transaction ids, both within a batch and (when a
  history file is supplied) across earlier batches.
- Writes a journal in which every posting is a debit and a credit of the
  same amount, so total debits always equal total credits.
- Produces a posted-transactions report, a rejected-transactions report
  with a status code and message per reject, and a batch summary with
  control totals and rejects by reason.
- Reconciles its own outputs: it reloads the opening master, replays the
  journal, and compares the result with the closing master it wrote.
  The same check is available as a standalone audit program.
- Treats bad inputs as fatal before anything is posted: an account
  master that does not match its own trailer totals, a control file with
  an unknown keyword, a missing file.
- Uses packed-decimal fixed-point arithmetic for all money, with
  `ON SIZE ERROR` on every balance and total. There is no floating
  point anywhere.

## Quick start

### Requirements

| Tool | Version | Used for |
|------|---------|----------|
| GnuCOBOL (`cobc`) | 3.1 or 3.2 | compiling |
| bash | 4.4 or later | build and test scripts |
| awk, diff, sed, coreutils | any POSIX | test scripts |
| make | any (optional) | convenience targets |
| gcov | matching the C compiler (optional) | `make coverage` only |

Install GnuCOBOL:

```sh
# Debian / Ubuntu
sudo apt-get install gnucobol3

# Fedora
sudo dnf install gnucobol

# macOS (Homebrew)
brew install gnucobol

# Windows: use WSL with the Debian/Ubuntu command above, or a MinGW
# build of GnuCOBOL 3.2 run from Git Bash or MSYS2 with cobc on PATH.
```

### Build, test, run

```sh
make build      # or: bash scripts/build.sh
make test       # lint + build + all tests   (or: bash scripts/test.sh)
make example    # run the example batch into build/example/
```

Without `make`, run the scripts directly; every `make` target is a
one-line wrapper round a script.

### Run a batch yourself

```sh
bash scripts/run-batch.sh \
    testdata/control/standard.ctl \
    testdata/accounts/standard.dat \
    testdata/transactions/mixed-batch.dat \
    build/example \
    testdata/history/empty.dat
```

```
LEDGMAIN: BATCH RUN STARTED
LEDGMAIN: BATCH DATE 20260115  BATCH ID B2026015
LEDGMAIN: RECORDS READ       10  POSTED        5  REJECTED        5
LEDGMAIN: RECONCILIATION PASSED
LEDGMAIN: RUN ENDED  RETURN CODE 0004
```

The run leaves these files in `build/example/`:

| File | Contents |
|------|----------|
| `accounts.out` | closing account master (the next batch's opening master) |
| `journal.out` | journal: two entries per posted transaction |
| `history.out` | ids posted so far (the next batch's history file) |
| `posted.rpt` | posted transactions report |
| `rejects.rpt` | rejected transactions report |
| `summary.rpt` | control totals and reconciliation result |
| `job.log` | the job log shown above |

An extract of `rejects.rpt` from that run:

```
  REC NO  TXN ID        DATE      T  ACCOUNT     CONTRA      AMOUNT         CODE  REASON
       4  MIX000000004  20260115  W  1000000002              0000000900000  B004  WITHDRAWAL EXCEEDS THE PER-TRANSACTION LIMIT
       6  MIX000000006  20260115  D  1000000004              0000000004000  B010  ACCOUNT IS NOT ACTIVE
       7  MIX000000002  20260115  W  1000000001              0000000006000  B006  DUPLICATE TRANSACTION ID IN THIS BATCH
       8  MIX000000007  20260115  W  1000000006              0000000020000  B012  INSUFFICIENT AVAILABLE FUNDS
      10  MIX000000009  20260115  X  1000000001              0000000001000  V006  TRANSACTION TYPE NOT D, W OR T
```

### Return codes

| Code | Meaning | Outputs usable? |
|------|---------|-----------------|
| 0 | every transaction posted; outputs reconciled | yes |
| 4 | completed; one or more transactions rejected | yes |
| 8 | completed, but reconciliation failed or could not finish | **no** |
| 12 | abandoned before processing (bad or missing input) | none written |
| 16 | abandoned during processing (I/O failure) | **no** |

## Repository layout

```
src/            COBOL programs (one responsibility each)
  main.cob                  LEDGMAIN  batch driver
  reconcile-main.cob        LEDGRECN  standalone reconciliation driver
  control-loader.cob        CTLLOAD   control file
  account-store.cob         ACCTSTOR  account master load/save
  history-store.cob         HISTSTOR  posted-id store, duplicate detection
  transaction-reader.cob    TXNREAD   transaction file
  transaction-validator.cob TXNVALID  record validation
  date-validator.cob        DATEVAL   calendar dates
  account-processor.cob     ACCTPROC  posting rules
  ledger-writer.cob         LEDGWRIT  journal file
  reconciliation.cob        RECONCIL  balance and ledger reconciliation
  reporting.cob             REPORTS   the three reports
  error-messages.cob        ERRTEXT   status code messages
copybooks/      record layouts and shared data areas
tests/
  unit/         COBOL test programs for the modules without file I/O
  integration/  one batch run per case, compared with expected output
  regression/   multi-run scenarios: reruns, tampering, limits, scale
  lib/          assertion helpers, independent ledger checker
testdata/       synthetic inputs and expected outputs
scripts/        build, run, test, lint, coverage, line count
docs/           design and operating documentation
.github/workflows/cobol-ci.yml   CI: build and test on two compilers
```

## Documentation

| Document | Covers |
|----------|--------|
| [docs/architecture.md](docs/architecture.md) | modules, data flow, design decisions, COBOL dialect |
| [docs/record-formats.md](docs/record-formats.md) | every input and output layout, column by column |
| [docs/business-rules.md](docs/business-rules.md) | accounting model, rules, status codes, invariants |
| [docs/testing.md](docs/testing.md) | test suites, how to run and reproduce, coverage |
| [docs/operations-and-recovery.md](docs/operations-and-recovery.md) | running a batch, return codes, reruns, recovery |
| [docs/security.md](docs/security.md) | security review and what is deliberately out of scope |

## Known limitations

These are stated in full in the documents above; the main ones are:

- **No checkpoint/restart.** A batch that fails is rerun from the
  beginning against the same opening master. Outputs are complete files
  or must be discarded; there is no partial commit.
- **Duplicate protection across batches depends on the history file.**
  A batch run without it will post a transaction that an earlier batch
  already posted. The job log says so when it happens, but nothing
  prevents it.
- **Everything is held in memory**: at most 5,000 accounts and 50,000
  remembered transaction ids. The history file is never pruned.
- **Single process, sequential files.** No locking, no concurrency, no
  database, no online access.
- **No authentication, authorisation, encryption or operator audit
  trail.** Protection of the files is left entirely to the operating
  system.
- **One currency, no interest, fees, holds or value dating.**
- **Verified only on GnuCOBOL** (3.2 on Windows/MinGW locally; 3.1 and
  3.2 on Linux in CI). It has not been compiled with an IBM, Micro Focus
  or other compiler.

## Provenance and licence

- All data in this repository is synthetic. Names, account numbers and
  amounts are invented.
- The code was written for this repository; no third-party source is
  included. The build needs GnuCOBOL (GPL/LGPL) installed separately;
  none of it is redistributed here.
- This code base was produced with substantial AI assistance (Claude
  Code) at the direction of the repository owner. It should not be
  described as a mainly human-written code base.
- No licence file has been added yet. Until the owner adds one, the
  default applies: all rights reserved.
