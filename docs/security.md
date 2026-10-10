# Security considerations

> This is a portfolio and reference application, not a certified
> banking system. It has had no independent security review, no
> penetration test and no compliance assessment, and it has never been
> deployed. It must not be used to process real funds or real customer
> data without independent engineering, security, compliance and
> operational validation.

This document records what was reviewed while building it, what the
code does about each point, and — more importantly — what it does not
do.

## What the system trusts

The batch has no notion of users. It trusts completely:

- whoever can start it and set its environment variables;
- the control file (the batch date and every limit);
- the opening account master, provided it is internally consistent;
- the operating system's file permissions.

The transaction file is the only input treated as untrusted data, and
even there "untrusted" means *possibly malformed*, not *possibly
malicious*: the system checks that a transaction is well formed and
within the rules, not that the person who submitted it was entitled to.

## Review findings

### Input validation

- Every transaction field is read as text and class-tested before it is
  used as a number. `TXN-AMOUNT-NUMERIC` is referenced only after
  `TXN-AMOUNT IS NUMERIC` has passed, so a non-numeric amount cannot
  reach arithmetic.
- Transaction ids are restricted to `A`–`Z` and `0`–`9`; account numbers
  and dates to digits; the type to three literal values.
- The account master, history file and control file are validated
  field by field on load and the batch refuses to start on any defect.
- Non-printable bytes in a transaction record are replaced with `?`
  before the record is handled further, and the record is rejected.
  This keeps control characters out of the reject report and the job
  log (where they could otherwise corrupt a terminal or a downstream
  parser) and keeps report writes from failing on input-derived data.
- **Not done:** no check that an account name is free of characters
  that are meaningful to some *other* consumer (spreadsheet formulas,
  HTML). Names are restricted to printable ASCII only. Anything that
  imports the reports elsewhere must treat them as untrusted text.

### Numeric precision and overflow

- All money is `PACKED-DECIMAL` fixed-point with two decimals. There is
  no floating point, no division and no rounding.
- Every arithmetic statement that produces a balance or total has
  `ON SIZE ERROR`; overflow rejects the transaction (B014) or abandons
  the batch (F016). Boundary values are tested at the cent
  (`boundary-amounts` integration case, `6000-OVERFLOW-CASES` unit
  tests).
- Amounts in transactions are unsigned by layout, so a negative amount
  cannot be expressed; a leading `-` fails the numeric test (V010).
  A deposit therefore cannot be used as a disguised withdrawal.
- A transfer from an account to itself is refused (V012).

### Record boundaries

- Record areas are longer than the layouts they hold, and the excess
  must be blank. An over-long transaction is rejected (V002); an
  over-long master, history or journal record is a fatal or
  reconciliation error. Nothing is silently truncated into a valid
  record.
- Table subscripts are bounded by explicit capacity checks before each
  insert (accounts, ids, reject reasons, discrepancy details).
- Reference modification uses constant offsets and lengths, except in
  three character-by-character loops (two in `TXNREAD`, one in
  `HISTSTOR`), each bounded by the length of the field it walks.

### Duplicate detection

- Works as documented in
  [operations-and-recovery.md](operations-and-recovery.md), with a
  significant caveat: **it depends on a history file that the operator
  supplies and the system cannot authenticate.** An omitted or stale
  history file re-enables double posting. The history file has no
  control totals, so truncation is not detected.

### Integrity of outputs

- The account master carries trailer control totals, and reconciliation
  ties the closing master to the opening master through the journal.
  This detects accidental damage and naive tampering with one file.
- **Not done:** no cryptographic integrity. Control totals are not a
  MAC; anyone who can write the files can recompute them, and a
  consistent alteration of all three files passes reconciliation. There
  are no hashes, signatures or append-only storage.

### File permissions and data at rest

- **Not done.** The program creates files with whatever permissions the
  process umask gives and sets none itself. Account names, numbers and
  balances are written in plain text to the master, journal, reports
  and job log. There is no encryption and no masking of account numbers
  in reports.
- Running it for real would need, at minimum: a dedicated service
  account, a restrictive umask, output directories readable only by
  that account and the people who must read the reports, and encrypted
  storage.

### Data retention

- **Not done.** The system never deletes or archives anything. Output
  directories accumulate until removed, and `run-batch.sh` deletes the
  previous outputs in a directory it is pointed at again. Retention
  periods and secure disposal are left to the operator.

### Error handling and information disclosure

- Every file operation's status is checked; no declarative or default
  runtime abort is relied on. Fatal conditions end the run with a
  defined return code after closing the files that were open.
- Diagnostics name the file role, status code, record number and, for
  rejects, the offending record's fields. That is appropriate for an
  operator's job log, but it means **the job log and reject report
  contain account numbers and amounts** and must be protected like the
  data itself.
- File *paths* are not echoed into reports or the job log.

### Authentication, authorisation, audit

- **Not done.** No operator identity is captured. There is no record of
  who ran a batch, who prepared the transaction file or who changed the
  control file, no maker/checker separation, and no per-transaction
  authorisation. The journal records *what* was posted, not *on whose
  authority*.

### Concurrency

- **Not done.** There is no file locking. Two batches run at once
  against the same master would both read the same opening position and
  each write a closing master that ignores the other. Serialising runs
  is the scheduler's job.

### Secrets

- The repository contains no passwords, tokens, API keys, private keys
  or connection strings, and the programs use none. The system makes no
  network connections.
- All data under `testdata/` is synthetic: invented names, sequential
  made-up account numbers, arbitrary amounts. None of it was derived
  from real records.
- `.gitignore` excludes build products, run outputs outside
  `testdata/expected/`, and common secret-bearing file names (`.env`,
  `*.pem`, `*.key`).

### Build and supply chain

- The only build dependency is GnuCOBOL and its C compiler, installed
  from the operating system's package repository. No third-party COBOL
  source, library or copybook is included or downloaded.
- The CI workflow uses two GitHub-maintained actions
  (`actions/checkout`, `actions/upload-artifact`) pinned by major
  version tag, not by commit hash, and a `debian:13` container image
  pinned by tag, not by digest. Pinning by hash/digest would be the
  stricter choice. The workflow requests read-only repository
  permission and uses no secrets.
- The test scripts are bash and awk and run only programs built from
  this repository.

## Summary

Within its scope — a deterministic batch that validates, posts and
reconciles — the code is careful about arithmetic, validation, bounds
and error handling. Everything that makes a financial system *secure*
in the operational sense (identity, authorisation, encryption,
tamper-evidence, retention, segregation of duties, concurrency control,
monitoring) is absent by design and would have to be supplied and
independently assessed before any real use.
