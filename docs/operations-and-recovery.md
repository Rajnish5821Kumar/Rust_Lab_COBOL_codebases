# Operations and recovery

## Running a batch

```sh
bash scripts/run-batch.sh CONTROL ACCOUNTS TRANSACTIONS OUTDIR [HISTORY]
```

`run-batch.sh` is the equivalent of the JCL for the job step. It clears
any earlier outputs from `OUTDIR`, maps the file names to environment
variables, runs `bin/ledger-batch`, copies the job log to
`OUTDIR/job.log` and exits with the program's return code.

To run the program without the wrapper, set the variables yourself:

| Variable | Direction | Required | File |
|----------|-----------|----------|------|
| `LEDGER_CONTROL` | in | yes | control file |
| `LEDGER_ACCOUNTS_IN` | in | yes | opening account master |
| `LEDGER_TXN_IN` | in | yes | transaction file |
| `LEDGER_HISTORY_IN` | in | no | posted-id history from earlier batches |
| `LEDGER_ACCOUNTS_OUT` | out | yes | closing account master |
| `LEDGER_JOURNAL_OUT` | out | yes | journal |
| `LEDGER_HISTORY_OUT` | out | no | updated history |
| `LEDGER_POSTED_RPT` | out | yes | posted report |
| `LEDGER_REJECT_RPT` | out | yes | reject report |
| `LEDGER_SUMMARY_RPT` | out | yes | summary report |

A required variable that is unset or blank is fatal (F017). The program
refuses to run if the closing master has the same name as the opening
master, or the updated history the same name as the history (F019),
because either would overwrite the only copy of an input.

## The daily cycle

```
day N opening master ─┐
day N transactions ───┼─► batch ─┬─► day N closing master ──► day N+1 opening master
history up to N-1 ────┘          ├─► history up to N ───────► day N+1 history
control file (date N) ───────────┤
                                 ├─► journal for day N       (keep)
                                 └─► reports                 (review)
```

1. Write the control file for the day (at least `BATCH-DATE`).
2. Run the batch into a new, empty output directory.
3. Look at the return code and `summary.rpt`.
4. Return code 0 or 4: the outputs are good. Keep the journal, give the
   reject report to whoever corrects rejects, and use `accounts.out` and
   `history.out` as tomorrow's inputs.
5. Return code 8 or higher: do **not** use anything in the output
   directory. See the next section.

Never write a batch's outputs over its inputs, and keep each day's
opening master, transaction file, journal and closing master together.
They are what make a rerun or an audit possible.

## Return codes and what to do

| Code | What happened | Operator action |
|------|---------------|-----------------|
| 0 | All transactions posted and the outputs reconciled. | Promote the outputs. |
| 4 | Completed; some transactions were rejected. The outputs reconciled. | Promote the outputs. Work the reject report; corrected transactions go in a later batch under the same ids. |
| 8 | The batch finished writing, but reconciliation found a discrepancy or could not read a file. | Discard the outputs. Keep the job log and summary (they list the discrepancies) and investigate before rerunning: this indicates a defect or a file changed while the batch ran, not a data problem. |
| 12 | Abandoned before any transaction was processed: an input is missing, unreadable or fails its checks, a file name is missing, or an output could not be opened. | Nothing was posted. Fix the cause named in the job log and run again. |
| 16 | Abandoned after processing began: a read or write failed. | Discard the outputs (the reports say `RUN ABANDONED`). No closing master is written in this case. Fix the cause (space, permissions, device) and run again from the start. |

The job log always ends with `RUN ENDED  RETURN CODE nnnn`. A fatal
condition is logged as `FATAL Fnnn message` followed by a detail line
(file status, record number, keyword or variable name).

Diagnosing a code-12 input failure, by code:

| Code | Look at |
|------|---------|
| F001–F003 | the control file: path, keywords (columns 1–24), value shapes, `BATCH-DATE` |
| F004 | the account master path and permissions |
| F005 | the record number in the detail line; a field is malformed |
| F006 | the master is not in ascending account order, or an account appears twice |
| F007, F008 | the master is incomplete or was edited without updating its trailer |
| F009 | more than 5,000 accounts |
| F010 | the transaction file path and permissions |
| F012, F013, F018 | the history file: path, a malformed or repeated record, more than 50,000 ids |
| F014 | an output directory does not exist or is not writable |
| F017, F019 | the environment variables naming the files |

## Restart and recovery

**There is no checkpoint or mid-file restart.** Recovery is by rerun:

- The batch modifies no input. Whatever happens, the opening master,
  the transaction file and the history file are exactly as they were.
- So recovery from any failure is the same: discard the output
  directory, fix the cause, and run the batch again from the beginning
  with the same inputs. Because the batch is deterministic, the rerun
  produces exactly what the failed run would have produced.
- Outputs are not written atomically. A run that fails part-way leaves
  partial files in its output directory. The return code is the only
  signal that tells good outputs from partial ones, which is why
  `run-batch.sh` writes into a directory of its own and why promotion
  must be a separate, deliberate step after checking the code.

What this design does not handle:

- A machine or process crash gives no return code at all. Treat a run
  with no `RUN ENDED` line in its job log as failed.
- If the closing master was promoted and *then* the journal for that
  day was lost, the journal cannot be regenerated without the original
  opening master and transaction file. Keep them until the day is
  archived.
- There is no automatic promotion, generation management or archive.
  Those are the operator's or the scheduler's job.

## Reruns and duplicate processing

A rerun of a failed batch against the **same opening master** is safe:
nothing from the failed run was kept.

The dangerous case is submitting a transaction file a second time
against a master that **already includes it** — for example rerunning
yesterday's file after yesterday's closing master was promoted. What
happens depends on the history file:

| History file supplied? | Result of resubmitting an already-posted file |
|------------------------|-----------------------------------------------|
| Yes, and it includes the earlier run | Every transaction is rejected with B007. Balances are unchanged. |
| No | **Every transaction is posted a second time.** The job log prints `NO HISTORY FILE - DUPLICATES OF EARLIER RUNS WILL NOT BE DETECTED`, but nothing stops the run. |
| Yes, but an older copy that predates the earlier run | The transactions are posted a second time. The history file is only as good as its currency. |

Both outcomes are pinned by tests (`rerun:` scenarios in
`tests/regression/run-regression.sh`), so this behaviour is a
documented property, not an accident.

Further limits of duplicate detection:

- It is by transaction id only. The same payment sent under two
  different ids is two transactions.
- A rejected transaction's id is not remembered (so it can be corrected
  and resubmitted). If two records in one file share an id and the first
  is rejected, the second is processed normally.
- The history file grows by one record per posted transaction and is
  never pruned. At 50,000 ids the batch stops loading it (F018), and a
  batch that fills the store mid-run rejects the remaining transactions
  (B015). Pruning old ids safely would require guaranteeing that no
  transaction older than the pruning horizon can be accepted; the
  `MAX-BACKDATE-DAYS` rule is the hook for that, but pruning itself is
  not implemented.
- The history file has no trailer control record, so a truncated
  history file is not detected.

## Auditing a finished batch

```sh
LEDGER_ACCOUNTS_IN=opening-master \
LEDGER_JOURNAL_OUT=journal \
LEDGER_ACCOUNTS_OUT=closing-master \
    bin/ledger-reconcile
```

Returns 0 (reconciled), 8 (discrepancies, listed on standard output) or
12 (a file is missing, unreadable or fails its own checks). Use it
before promoting outputs that have been copied or restored.

What reconciliation can and cannot tell you:

- It detects outputs that are *inconsistent* with each other or with
  the opening master: a changed balance, a removed or altered journal
  entry, a truncated file.
- It cannot detect a set of files that has been altered *consistently*
  (opening master, journal and closing master all changed to agree), and
  it says nothing about whether the transactions themselves were
  legitimate. It is an integrity check, not a security control.

## Capacity and resource limits

| Limit | Value | What happens at the limit |
|-------|-------|---------------------------|
| Accounts on the master | 5,000 | 5,001 or more: batch abandoned, F009 |
| Transaction ids remembered (history + this batch) | 50,000 | history larger: F018. Store fills mid-batch: remaining transactions rejected, B015 |
| Transactions per batch | 99,999,999 by counter size; in practice bounded by the id limit above | — |
| Transaction record area | 200 bytes | longer lines are split by the runtime into several records, each rejected; the number of reject lines for one such line depends on the GnuCOBOL version |
| Single amount | 99,999,999,999.99 | larger cannot be expressed in the record |
| Account balance | ±9,999,999,999,999.99 | posting that would exceed it is rejected, B014 |
| Control totals | ±999,999,999,999,999.99 | batch abandoned, F016 |
| File name length | 256 characters | longer names are truncated by the program |

Memory use is fixed at a few megabytes regardless of batch size.
A 20,000-transaction batch over 100 accounts runs in about one second
on a current laptop (measured as part of the regression suite; this is
an observation, not a benchmark).

Raising the account or id limit means changing the `OCCURS` sizes and
the matching `VALUE`s in `copybooks/account-table.cpy` or
`src/history-store.cob` and recompiling. The hash table slot count in
`history-store.cob` should stay a prime comfortably larger than the id
capacity.

## Platform notes

- **Line endings.** Input files should have the line endings native to
  the platform the batch runs on. On Linux, a file with Windows (CRLF)
  endings has a carriage return at the end of each record. The reader
  treats that as a non-printable character, so every transaction would
  be rejected (V014) and a master or control file would be refused.
  Convert such files first (`dos2unix` or `tr -d '\r'`). This follows
  from how the code handles non-printable bytes; it is not covered by
  an automated test.
- **Character set.** Records must be ASCII. Any byte outside space to
  tilde, including UTF-8 multi-byte characters in a description, causes
  the record to be rejected (V014).
- **Windows.** Outputs are written with CRLF endings by the MinGW
  runtime. They are valid inputs to the next batch on Windows.

## Data retention

The system deletes nothing and archives nothing. Every output directory
holds account names, account numbers and balances in plain text and
stays on disk until someone removes it. Decide how long each kind of
file must be kept and who may read it; see
[security.md](security.md).
