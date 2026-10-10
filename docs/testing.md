# Testing

## Running the tests

```sh
make test                 # lint, build, then every suite
bash scripts/test.sh      # the same, without make

make unit                 # one suite at a time
make integration
make regression

bash tests/integration/run-integration.sh deposit-valid   # one case
```

`make test` exits non-zero if the lint, the build or any assertion
fails. Every suite runs even when an earlier one has failed, so one run
shows everything that is wrong. Nothing is skipped silently: the one
scenario that cannot run on every platform prints a `NOTE` saying so.

Test outputs are written under `build/test-output/` and left there so a
failure can be inspected.

## The three suites

### Unit tests — `tests/unit/`

COBOL programs that `CALL` a module directly with constructed inputs
and check what comes back. They cover the modules that make decisions
and do no file I/O. A small harness (`test-harness-ws.cpy`,
`test-harness-pd.cpy`) counts checks and sets the exit status.

| Test program | Module under test | What it checks |
|--------------|-------------------|----------------|
| `test-date-validator.cob` | `DATEVAL` | 39 dates: month lengths, leap years including century rules, range, non-numeric; day-number differences |
| `test-transaction-validator.cob` | `TXNVALID` | every V and stateless B code, each limit at and one cent past its boundary, and the documented order of checks when a record has two faults |
| `test-account-processor.cob` | `ACCTPROC` | each transaction type's balances and journal entries; every posting rule; that a refused transaction changes nothing (the whole table is summed before and after); overdraft floor; daily limit; overflow |
| `test-history-store.cob` | `HISTSTOR` | check/add/duplicate/reset; fills the store to its 50,000 capacity and verifies every id is still found |
| `test-error-messages.cob` | `ERRTEXT` | every code in `error-codes.cpy` has a message and no two codes share a value |

### Integration tests — `tests/integration/`

Each line of `cases.txt` is one complete batch run: a control file, an
account master, a transaction file, optionally a history file, and the
expected return code. For each case `run-integration.sh` checks:

1. the return code;
2. that the run produced **exactly** the set of files in
   `testdata/expected/<case>/` — a failed run that leaves a closing
   master behind fails here;
3. that every output file equals its expected copy (line endings
   aside): closing master, journal, history, all three reports and the
   job log;
4. for runs that completed, that `tests/lib/check-ledger.awk` agrees
   the accounting invariants hold.

Check 4 matters because checks 1–3 compare against files that were
themselves produced by the program. `check-ledger.awk` is a separate
implementation of the invariants, in a different language, that reads
only the opening master, journal and closing master. An accounting
error that was faithfully captured in an expected file would still fail
it.

### Regression tests — `tests/regression/`

Scenarios that need several runs, a damaged file or an unusual
environment, written as explicit assertions in
`run-regression.sh`:

- **repeatable** — two runs on the same inputs give identical files;
- **rerun** — resubmitting a posted file with and without history;
- **chained** — day 2 run on day 1's closing master and history;
- **audit** — `ledger-reconcile` passes good outputs and detects a
  changed balance (with and without a matching trailer), a removed
  journal entry, a changed amount, a redirected entry, a damaged record,
  a wrong opening master and a missing journal;
- **environment** — missing file-name variables, an output named the
  same as its input, outputs that cannot be opened, stale outputs;
- **scale and limits** — a 20,000-transaction batch whose deposit total
  is recomputed independently from the input file; 5,000 and 5,001
  accounts; the id store filling mid-batch, exactly full, and over
  capacity; a 700-byte record;
- **write failure** (Linux only) — the journal directed at `/dev/full`
  so that writes fail mid-run.

## Required scenarios and where they are tested

| # | Scenario | Tests |
|---|----------|-------|
| 1 | Valid deposit | integration `deposit-valid`; unit `2000-DEPOSIT-CASES` |
| 2 | Valid withdrawal | integration `withdrawal-valid`; unit `3000-WITHDRAWAL-CASES` |
| 3 | Insufficient-funds withdrawal | integration `withdrawal-insufficient` (one cent over, exact balance, already negative); unit |
| 4 | Valid transfer with balanced entries | integration `transfer-valid` (+ `check-ledger.awk` pair check); unit `4000-TRANSFER-CASES` |
| 5 | Invalid account reference | integration `invalid-account` (13 records: unknown, frozen, closed, malformed, reserved, same-account); unit |
| 6 | Invalid transaction type | integration `invalid-type`; unit |
| 7 | Malformed record | integration `malformed-records` (16 records: short, blank, long, bad amount, bad date, bad id, tab character, boundary lengths 53/54) |
| 8 | Duplicate transaction id | integration `duplicate-ids`, `mixed-batch-with-history`; unit history store |
| 9 | Missing or unreadable input | integration `missing-transactions`, `missing-accounts`, `missing-control`, `missing-history`; regression environment scenarios |
| 10 | Empty transaction file | integration `empty-transactions` |
| 11 | Monetary boundaries and overflow | integration `boundary-amounts` (0.01, zero, largest amount, largest balance ± 0.01); unit `6000-OVERFLOW-CASES` |
| 12 | Incorrect opening balances / reconciliation failure | integration `master-*` (9 cases); regression audit scenarios |
| 13 | Batch reruns and duplicate-processing risk | regression `repeatable`, `rerun:` (3 scenarios), `chained:` |
| 14 | Multiple transactions on one account | integration `multiple-same-account`, `business-limits` |
| 15 | Large batches and resource limits | regression `scale:` and `limits:` scenarios |

## Expected outputs

`testdata/expected/` was first written by running the program, and then
**checked by hand**: for each case the posted and rejected lines, the
balances and the summary totals were worked out from the inputs and
compared. They are assertions about correct behaviour, not a recording
of whatever the program happened to do.

To change them deliberately (for instance after altering a report
layout):

```sh
bash tests/integration/run-integration.sh --update
git diff testdata/expected        # read every changed line
```

`--update` makes the file comparison pass by definition, so the diff
review is the test. The independent ledger check still runs in update
mode and still fails on an accounting error.

## Do the tests detect defects?

A test suite that cannot fail proves nothing, so six defects were
introduced one at a time into a scratch copy of the source and the
suites were run against each:

| Injected defect | Result |
|-----------------|--------|
| Funds check off by one cent (`<` became `<=`) | detected: unit, integration |
| Transfer never credits the destination | detected: unit, integration, regression (in-batch reconciliation returned 8) |
| Century leap-year rule removed | detected: unit |
| Deposit limit made exclusive | detected: unit, integration |
| In-batch duplicates not detected | detected: unit, integration, regression |
| Journal credit entry written one cent high | detected: integration, regression |

This was a manual spot check, not systematic mutation testing, and the
mutation script is not part of the repository.

## Results

Recorded on 2026-10-10 for the initial implementation, from clean
builds with `make test`.

Local run:

| Environment | GnuCOBOL 3.2.0 (MinGW, GCC 9.2.0), Windows 11, Git Bash 5 |
|---|---|
| Lint | 32 files, no problems |
| Unit | 5 programs, 382 checks, 0 failed |
| Integration | 36 cases, 220 assertions, 0 failed |
| Regression | 117 assertions, 0 failed; the `/dev/full` write-failure scenario was **not run** (Linux only) |

First CI run (GitHub Actions run 38041424246, on the pull request that
introduced the system), both jobs:

| Environment | GnuCOBOL 3.1.2 on Ubuntu 24.04; GnuCOBOL 3.2.0 on Debian 13 |
|---|---|
| Lint | 32 files, no problems |
| Unit | 5 programs, 382 checks, 0 failed |
| Integration | 36 cases, 220 assertions, 0 failed |
| Regression | 121 assertions, 0 failed, including the `/dev/full` write-failure scenario (its 4 assertions are the difference from the local count) |

These are the results of the runs named above. For the state of any
later commit, look at the Actions tab of the repository; this file
cannot know the outcome of a run that happens after it is committed.

To reproduce: install GnuCOBOL (see the README), then `make clean test`.

## Coverage

```sh
make coverage             # needs GnuCOBOL 3.2+ and gcov
```

**Method.** `scripts/coverage.sh` rebuilds every executable with gcc
coverage instrumentation (`cobc -g --coverage`), runs all three suites
against the instrumented executables, and uses `gcov` to map the
counters back to COBOL source lines. Results from all executables are
merged: a line counts as covered if any test executed it.

**What is measured.** Lines of `src/*.cob` from the `PROCEDURE DIVISION`
header onward that gcov treats as executable. Data definitions,
copybooks and the test programs are excluded. This is **line coverage**
— not branch, condition or path coverage.

**Measured result**, local Windows run (all suites passing):

| Program | Lines | Covered | Percent |
|---------|------:|--------:|--------:|
| account-processor.cob | 115 | 111 | 96.5% |
| account-store.cob | 166 | 136 | 81.9% |
| control-loader.cob | 122 | 115 | 94.3% |
| date-validator.cob | 26 | 26 | 100.0% |
| error-messages.cob | 144 | 144 | 100.0% |
| history-store.cob | 130 | 119 | 91.5% |
| ledger-writer.cob | 57 | 47 | 82.5% |
| main.cob | 293 | 253 | 86.3% |
| reconcile-main.cob | 69 | 69 | 100.0% |
| reconciliation.cob | 231 | 194 | 84.0% |
| reporting.cob | 392 | 322 | 82.1% |
| transaction-reader.cob | 56 | 52 | 92.9% |
| transaction-validator.cob | 89 | 89 | 100.0% |
| **Total** | **1,890** | **1,677** | **88.7%** |

The same measurement in the first CI run (GnuCOBOL 3.2.0, gcov 14.2.0,
Debian 13) gave **91.0%** (1,719 of 1,890 lines). The difference is
entirely the write-failure scenario, which runs only on Linux and
reaches the abandoned-run paths: `ledger-writer.cob` 87.7%, `main.cob`
88.4% and `reporting.cob` 90.6%; every other program is unchanged.

Caveats on these numbers:

- gcov counts source lines, and a multi-line COBOL statement counts as
  several lines. It is a fair proportion, not an exact statement count.
- High line coverage does not show that the assertions are good; the
  defect-injection check above is the evidence for that.

**What is not covered.** Almost all of the uncovered lines are the
handling of I/O failures that cannot be provoked portably: a write or
close that fails on the master, history or report files, a read error
part-way through a file, and control-total overflow (which would need
totals above 999 trillion). The paths exist and were reviewed, but they
have not been executed by a test, and should be regarded as unproven.

## What the tests do not show

- Behaviour on any compiler other than GnuCOBOL 3.1/3.2.
- Behaviour on EBCDIC platforms.
- Behaviour under concurrent runs, write failure on any file other
  than the journal, or process crashes.
- Performance beyond the single 20,000-transaction observation.
- Anything about security; see [security.md](security.md).
