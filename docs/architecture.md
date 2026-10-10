# Architecture

## Shape of the system

The system is a classic sequential batch: load reference data, make one
pass over a transaction file, write new master data and reports. It is
built as two executables that share eleven subprograms.

| Executable | Driver | Purpose |
|------------|--------|---------|
| `bin/ledger-batch` | `LEDGMAIN` (`src/main.cob`) | run one batch |
| `bin/ledger-reconcile` | `LEDGRECN` (`src/reconcile-main.cob`) | audit a finished batch from its files |

All programs are compiled and statically linked into each executable
(`scripts/build.sh`); there are no dynamically loaded modules.

## Modules

Two rules decide what goes where:

1. **Each file is owned by exactly one program.** Only that program has
   the `SELECT`/`FD`, and it is the only place that file's status codes
   are interpreted.
2. **Each decision is made in exactly one program**, and the programs
   that make decisions do no file I/O, so they can be unit-tested by
   calling them.

| Program | Source | Owns | Does |
|---------|--------|------|------|
| `LEDGMAIN` | `main.cob` | — | Order of work, fatal-error handling, return code. No rules, no I/O. |
| `CTLLOAD` | `control-loader.cob` | control file | Parses business parameters; strict about unknown or repeated keywords. |
| `ACCTSTOR` | `account-store.cob` | account master (in and out) | Loads and proves the master (sequence, trailer totals); writes the closing master. |
| `HISTSTOR` | `history-store.cob` | history file | Holds posted ids in a hash table; answers "has this id been posted?" |
| `TXNREAD` | `transaction-reader.cob` | transaction file | Returns each record as text with its number and length; neutralises non-printable characters. |
| `TXNVALID` | `transaction-validator.cob` | — | Field validation and stateless business rules. Pure function of record + control. |
| `DATEVAL` | `date-validator.cob` | — | Calendar-date validation; day numbers for date arithmetic. |
| `ACCTPROC` | `account-processor.cob` | — | Posting rules against the account table; all-or-nothing update. |
| `LEDGWRIT` | `ledger-writer.cob` | journal (write) | Writes the debit/credit pair; keeps journal control totals. |
| `RECONCIL` | `reconciliation.cob` | journal (read) | Replays the journal against the opening master and compares with the closing master. |
| `REPORTS` | `reporting.cob` | three report files | Posted, rejected and summary reports. |
| `ERRTEXT` | `error-messages.cob` | — | Status code to message text. |
| `LEDGRECN` | `reconcile-main.cob` | — | Standalone driver for `RECONCIL`. |

Shared data definitions live in `copybooks/`:

| Copybook | Defines |
|----------|---------|
| `transaction-record.cpy` | transaction input record |
| `account-record.cpy` | account master detail and trailer records |
| `ledger-record.cpy` | journal record |
| `history-record.cpy` | history record |
| `error-codes.cpy` | every status code |
| `batch-control.cpy` | parsed control parameters |
| `batch-files.cpy` | file names for the run |
| `txn-work.cpy` | the transaction being processed, as passed between modules |
| `posting-result.cpy` | the two journal entries a posting produced |
| `batch-totals.cpy` | in-memory control totals |
| `account-table.cpy` | in-memory account table (parameterised by a `:AT:` tag) |
| `recon-result.cpy` | reconciliation request and result |

## Flow of one batch

```
LEDGMAIN
 1000 start        read file names from the environment; refuse an output
                   named the same as its input
 2000 load         CTLLOAD   control file      -> BATCH-CONTROL
                   ACCTSTOR  opening master    -> account table (proved)
                   HISTSTOR  history file      -> id store
 3000 open         TXNREAD open, LEDGWRIT open, REPORTS open
 4000 process      for each record:
                       TXNREAD   read
                       TXNVALID  validate                 ─┐ first stage
                       HISTSTOR  duplicate check           ├ to object sets
                       ACCTPROC  posting rules + update   ─┘ the status code
                       accepted: LEDGWRIT write pair, HISTSTOR add,
                                 REPORTS posted line
                       rejected: REPORTS reject line
 5000 close        TXNREAD close, LEDGWRIT close
 6000 save         ACCTSTOR  closing master
                   HISTSTOR  updated history
 7000 reconcile    RECONCIL  opening master + journal vs closing master,
                   then compare its totals with the in-memory totals
 8000 finish       return code, REPORTS summary, close, job log
```

A fatal condition at any step sets a run-level flag; later steps that
would post or save are skipped, files are still closed, and the return
code is 12 (nothing had been processed) or 16 (processing had begun).

## Design decisions

### Posting is planned, then applied

`ACCTPROC` computes every new balance into work fields, checks every
rule against those work fields, and only then moves them into the
account table. A refused transaction therefore changes nothing. This
matters most for transfers, where the source can be fine and the
destination can overflow: the source must not be debited. The unit test
`TRANSFER INTO A FULL ACCOUNT` pins this.

### Reconciliation shares no memory with posting

`RECONCIL` takes three file names and nothing else. It reloads the
opening master, replays the journal and loads the closing master
through the same `ACCTSTOR` load checks any batch would apply. Because
it does not see the posting run's account table or totals, a defect in
posting cannot make reconciliation agree with it by construction.
`LEDGMAIN` then adds one more check (R010): the totals reconciliation
derived from disk must equal the totals it kept in memory.

The honest limit of this design: `RECONCIL` and `ACCTPROC` are written
in the same language by the same author and share `ACCTSTOR`. The test
suite therefore also uses `tests/lib/check-ledger.awk`, an independent
implementation of the same invariants in another language.

### Tables in memory, sized by documented limits

Accounts are held in a table of 5,000 entries searched with
`SEARCH ALL`, which is why the master must be in ascending account
order. Posted ids are held in a 50,000-entry store indexed by a
65,537-slot open-addressing hash table (polynomial hash over the 12 id
characters, `h = h * 31 + character code` modulo 65,537, with linear
probing). Both limits are enforced with
explicit status codes (F009, F018, B015) rather than left to overflow.

An indexed (ISAM) file would remove both limits. It was not used
because it would make the build depend on how each GnuCOBOL package was
configured, and because sequential master files with trailer control
totals are themselves a pattern worth showing.

### No clock, no randomness

The batch date comes from the control file. Reports carry no timestamps.
The same inputs give byte-identical outputs, which is what makes
expected-output testing possible and reruns predictable.

### File names from the environment

Each file name is read from an environment variable (`LEDGER_TXN_IN`
and so on; the list is in `copybooks/batch-files.cpy`). This stands in
for JCL DD statements: the program never contains a path, and
`scripts/run-batch.sh` plays the part of the JCL.

### Errors are values, not exceptions

Every subprogram returns a four-character status code and a detail
string. No program uses declaratives or lets a file status go
unchecked. `LEDGMAIN` decides what a status means for the run.

## COBOL dialect

The source is fixed format (columns 7–72), checked by
`scripts/lint-cobol.sh`, and compiled with `cobc -fixed -Wall -Werror`.
It keeps to COBOL 85 structure with a small number of later or
vendor features, each used for a stated reason:

| Feature | Standard status | Why it is used |
|---------|-----------------|----------------|
| `ORGANIZATION IS LINE SEQUENTIAL` | extension (GnuCOBOL, Micro Focus, IBM) | text files that can be read, diffed and versioned |
| `ASSIGN TO DYNAMIC data-name` | extension | file names supplied at run time |
| `ACCEPT ... FROM ENVIRONMENT` | extension (X/Open) | DD-name style file assignment |
| `RETURN-CODE` special register | extension (IBM, Micro Focus, GnuCOBOL) | return code to the job step |
| `GOBACK` | COBOL 2002 | return from a subprogram |
| `EXIT PARAGRAPH`, `EXIT PERFORM` | COBOL 2002 | early exit without `GO TO` |
| `FUNCTION TRIM` | COBOL 2014 | tidy job-log lines |
| `COPY ... REPLACING ==:AT:==` partial-word tag | common extension | two account tables in `RECONCIL` |
| `SIGN IS LEADING SEPARATE`, `PACKED-DECIMAL`, `BINARY`, `SEARCH ALL`, `INITIALIZE`, intrinsic functions `MOD`, `ORD`, `INTEGER-OF-DATE` | COBOL 85 (and its 1989 intrinsic-function amendment) | — |

Porting to another compiler would mean revisiting the first four rows;
the business logic does not depend on them.

Character handling assumes an ASCII-compatible native character set:
"printable" is defined as space through tilde. On an EBCDIC platform
the `CLASS` definitions in `TXNREAD` and `ACCTSTOR` would need
restating.

## Runtime differences that the code neutralises

GnuCOBOL 3.1 and 3.2 treat `LINE SEQUENTIAL` files differently:

- 3.2 validates record content and returns status 09 on reading, or 71
  on writing, a record with control characters; 3.1 does not.
- Both split a line longer than the record area into several records,
  but only 3.2 signals it (status 06).

So the code does not rely on either. `TXNREAD` accepts any status in
the "successful" class, replaces non-printable characters itself and
measures the record itself; `TXNVALID` then rejects the record on those
facts. The result is the same on both versions, and report writes can
never fail on input-derived characters. The one remaining difference —
how many reject lines a record longer than 200 bytes produces — is
documented in [operations-and-recovery.md](operations-and-recovery.md).
