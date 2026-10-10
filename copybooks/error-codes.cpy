      *****************************************************************
      * ERROR-CODES.CPY
      *
      * Every status code the system can report.  The first character
      * gives the class of the condition:
      *
      *   V  the record is structurally invalid   (transaction rejected)
      *   B  a business rule refused the posting  (transaction rejected)
      *   F  fatal condition                      (batch abandoned)
      *   R  reconciliation discrepancy           (batch flagged)
      *
      * Message texts live in ERRTEXT (src/error-messages.cob); the
      * unit test for ERRTEXT fails if a code here has no message.
      *****************************************************************
       01  LEDGER-ERROR-CODES.
           05  EC-NONE                     PIC X(4) VALUE "0000".
      *    ---- V: record validation ---------------------------------
           05  EC-REC-TOO-SHORT            PIC X(4) VALUE "V001".
           05  EC-REC-TOO-LONG             PIC X(4) VALUE "V002".
           05  EC-TXN-ID-INVALID           PIC X(4) VALUE "V003".
           05  EC-DATE-NOT-NUMERIC         PIC X(4) VALUE "V004".
           05  EC-DATE-INVALID             PIC X(4) VALUE "V005".
           05  EC-TYPE-INVALID             PIC X(4) VALUE "V006".
           05  EC-ACCT-FORMAT              PIC X(4) VALUE "V007".
           05  EC-CONTRA-FORMAT            PIC X(4) VALUE "V008".
           05  EC-CONTRA-NOT-BLANK         PIC X(4) VALUE "V009".
           05  EC-AMOUNT-NOT-NUMERIC       PIC X(4) VALUE "V010".
           05  EC-AMOUNT-ZERO              PIC X(4) VALUE "V011".
           05  EC-SAME-ACCOUNT             PIC X(4) VALUE "V012".
           05  EC-RESERVED-ACCOUNT         PIC X(4) VALUE "V013".
           05  EC-UNPRINTABLE              PIC X(4) VALUE "V014".
      *    ---- B: business rules ------------------------------------
           05  EC-DATE-FUTURE              PIC X(4) VALUE "B001".
           05  EC-DATE-STALE               PIC X(4) VALUE "B002".
           05  EC-LIMIT-DEPOSIT            PIC X(4) VALUE "B003".
           05  EC-LIMIT-WITHDRAWAL         PIC X(4) VALUE "B004".
           05  EC-LIMIT-TRANSFER           PIC X(4) VALUE "B005".
           05  EC-DUP-IN-BATCH             PIC X(4) VALUE "B006".
           05  EC-DUP-PRIOR-BATCH          PIC X(4) VALUE "B007".
           05  EC-ACCT-NOT-FOUND           PIC X(4) VALUE "B008".
           05  EC-CONTRA-NOT-FOUND         PIC X(4) VALUE "B009".
           05  EC-ACCT-NOT-ACTIVE          PIC X(4) VALUE "B010".
           05  EC-CONTRA-NOT-ACTIVE        PIC X(4) VALUE "B011".
           05  EC-INSUFFICIENT-FUNDS       PIC X(4) VALUE "B012".
           05  EC-DAILY-LIMIT              PIC X(4) VALUE "B013".
           05  EC-BALANCE-OVERFLOW         PIC X(4) VALUE "B014".
           05  EC-ID-CAPACITY              PIC X(4) VALUE "B015".
      *    ---- F: fatal conditions ----------------------------------
           05  EC-CONTROL-OPEN             PIC X(4) VALUE "F001".
           05  EC-CONTROL-INVALID          PIC X(4) VALUE "F002".
           05  EC-BATCH-DATE               PIC X(4) VALUE "F003".
           05  EC-MASTER-OPEN              PIC X(4) VALUE "F004".
           05  EC-MASTER-RECORD            PIC X(4) VALUE "F005".
           05  EC-MASTER-SEQUENCE          PIC X(4) VALUE "F006".
           05  EC-MASTER-NO-TRAILER        PIC X(4) VALUE "F007".
           05  EC-MASTER-CONTROL-TOTAL     PIC X(4) VALUE "F008".
           05  EC-MASTER-CAPACITY          PIC X(4) VALUE "F009".
           05  EC-TXN-OPEN                 PIC X(4) VALUE "F010".
           05  EC-TXN-READ                 PIC X(4) VALUE "F011".
           05  EC-HISTORY-OPEN             PIC X(4) VALUE "F012".
           05  EC-HISTORY-RECORD           PIC X(4) VALUE "F013".
           05  EC-OUTPUT-OPEN              PIC X(4) VALUE "F014".
           05  EC-OUTPUT-WRITE             PIC X(4) VALUE "F015".
           05  EC-TOTAL-OVERFLOW           PIC X(4) VALUE "F016".
           05  EC-FILE-NAME-MISSING        PIC X(4) VALUE "F017".
           05  EC-HISTORY-CAPACITY         PIC X(4) VALUE "F018".
           05  EC-SAME-IN-OUT-PATH         PIC X(4) VALUE "F019".
           05  EC-JOURNAL-OPEN             PIC X(4) VALUE "F020".
      *    ---- R: reconciliation discrepancies ----------------------
           05  EC-RECON-DR-CR              PIC X(4) VALUE "R001".
           05  EC-RECON-BALANCE            PIC X(4) VALUE "R002".
           05  EC-RECON-UNKNOWN-ACCT       PIC X(4) VALUE "R003".
           05  EC-RECON-ACCOUNT-SET        PIC X(4) VALUE "R004".
           05  EC-RECON-RUNNING-BAL        PIC X(4) VALUE "R005".
           05  EC-RECON-CONTROL-TOTAL      PIC X(4) VALUE "R006".
           05  EC-RECON-SEQUENCE           PIC X(4) VALUE "R007".
           05  EC-RECON-RECORD             PIC X(4) VALUE "R008".
           05  EC-RECON-PAIR               PIC X(4) VALUE "R009".
           05  EC-RECON-MEMORY-TOTALS      PIC X(4) VALUE "R010".
       01  LEDGER-ERROR-TABLE REDEFINES LEDGER-ERROR-CODES.
           05  EC-TABLE-ENTRY              PIC X(4) OCCURS 60 TIMES.
       01  EC-TABLE-SIZE                   PIC 9(4) BINARY VALUE 60.
