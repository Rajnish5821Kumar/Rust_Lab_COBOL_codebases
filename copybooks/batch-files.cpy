      *****************************************************************
      * BATCH-FILES.CPY
      *
      * File names for one batch run.  Each name is taken from an
      * environment variable, which plays the part a DD statement
      * plays in JCL (see docs/operations-and-recovery.md).
      *
      *   Field                 Environment variable     Required
      *   BF-CONTROL-PATH       LEDGER_CONTROL           yes
      *   BF-ACCOUNTS-IN-PATH   LEDGER_ACCOUNTS_IN       yes
      *   BF-TXN-IN-PATH        LEDGER_TXN_IN            yes
      *   BF-HISTORY-IN-PATH    LEDGER_HISTORY_IN        no
      *   BF-ACCOUNTS-OUT-PATH  LEDGER_ACCOUNTS_OUT      yes
      *   BF-JOURNAL-PATH       LEDGER_JOURNAL_OUT       yes
      *   BF-HISTORY-OUT-PATH   LEDGER_HISTORY_OUT       no
      *   BF-POSTED-PATH        LEDGER_POSTED_RPT        yes
      *   BF-REJECT-PATH        LEDGER_REJECT_RPT        yes
      *   BF-SUMMARY-PATH       LEDGER_SUMMARY_RPT       yes
      *****************************************************************
       01  BATCH-FILE-NAMES.
           05  BF-CONTROL-PATH             PIC X(256).
           05  BF-ACCOUNTS-IN-PATH         PIC X(256).
           05  BF-TXN-IN-PATH              PIC X(256).
           05  BF-HISTORY-IN-PATH          PIC X(256).
           05  BF-ACCOUNTS-OUT-PATH        PIC X(256).
           05  BF-JOURNAL-PATH             PIC X(256).
           05  BF-HISTORY-OUT-PATH         PIC X(256).
           05  BF-POSTED-PATH              PIC X(256).
           05  BF-REJECT-PATH              PIC X(256).
           05  BF-SUMMARY-PATH             PIC X(256).
