      *****************************************************************
      * RECONCIL - balance and ledger reconciliation
      *
      * Proves, from the files on disk alone, that a batch's outputs
      * are consistent with its inputs.  It shares no memory with the
      * posting run: it loads the opening master, replays every
      * journal entry against it, and compares the result with the
      * closing master.  It can therefore be run inside the batch
      * (LEDGMAIN does so) or later as an audit (LEDGRECN).
      *
      * Checks                                                  Code
      *   journal record is well formed                         R008
      *   journal sequence numbers run 1..n with no gap         R007
      *   entries come as a debit then a credit for the same
      *     transaction id and amount                           R009
      *   every customer entry is for an account on the
      *     opening master                                      R003
      *   each entry's balance-after equals the balance
      *     obtained by replaying the journal                   R005
      *   total debits equal total credits                      R001
      *   opening and closing masters hold the same accounts,
      *     names and statuses                                  R004
      *   each closing balance = opening balance + credits
      *     - debits for that account                           R002
      *   closing total = opening total + clearing position     R006
      *
      * CALL "RECONCIL" USING RECON-REQUEST, RECON-RESULT
      *
      * RR-STATUS is "P" passed, "F" failed (discrepancies found) or
      * "A" aborted (an input could not be read: RR-FATAL-CODE says
      * why).  A master that fails its own load checks (for example a
      * trailer that does not match) aborts the reconciliation.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. RECONCIL.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT JOURNAL-FILE ASSIGN TO DYNAMIC WS-JOURNAL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  JOURNAL-FILE.
       01  JOURNAL-FILE-RECORD             PIC X(120).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".
       COPY "ledger-record.cpy".

      *    OP- starts as the opening master and, as the journal is
      *    replayed into it, becomes the expected closing position.
      *    CL- is the closing master as written by the batch.
       COPY "account-table.cpy" REPLACING ==:AT:== BY ==OP==.
       COPY "account-table.cpy" REPLACING ==:AT:== BY ==CL==.

       01  WS-JOURNAL-PATH                 PIC X(256).
       01  WS-FILE-STATUS                  PIC X(2).
       01  WS-END-OF-FILE-FLAG             PIC X(1).
           88  WS-END-OF-FILE              VALUE "Y".

       01  WS-STORE-FUNCTION               PIC X(1).
       01  WS-STORE-STATUS                 PIC X(4).
       01  WS-STORE-DETAIL                 PIC X(60).

       01  WS-CLEARING-ACCOUNT             PIC X(10)
                                           VALUE "0000000000".
       01  WS-PREVIOUS-SEQUENCE            PIC 9(8) BINARY.
       01  WS-EXPECTED-SEQUENCE            PIC 9(8) BINARY.
       01  WS-ENTRY-VALID-FLAG             PIC X(1).
           88  WS-ENTRY-IS-VALID           VALUE "Y".

      *    Pairing state: the debit most recently read that is still
      *    waiting for its credit.
       01  WS-AWAITING-CREDIT-FLAG         PIC X(1).
           88  WS-AWAITING-CREDIT          VALUE "Y".
           88  WS-AWAITING-DEBIT           VALUE "N".
       01  WS-HELD-TXN-ID                  PIC X(12).
       01  WS-HELD-AMOUNT                  PIC S9(11)V99
                                           PACKED-DECIMAL.

       01  WS-FOUND-ENTRY                  PIC 9(8) BINARY.
       01  WS-ENTRY-NUMBER                 PIC 9(8) BINARY.
       01  WS-COMPARE-COUNT                PIC 9(8) BINARY.
       01  WS-REPLAYED-BALANCE             PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  WS-EXPECTED-TOTAL               PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  WS-SEQUENCE-DISPLAY             PIC 9(8).

      *    One discrepancy, staged here before it is recorded.
       01  WS-DISCREPANCY.
           05  WS-D-CODE                   PIC X(4).
           05  WS-D-KEY                    PIC X(12).
           05  WS-D-EXPECTED               PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  WS-D-ACTUAL                 PIC S9(15)V99
                                           PACKED-DECIMAL.

       LINKAGE SECTION.
       COPY "recon-result.cpy".

       PROCEDURE DIVISION USING RECON-REQUEST
                                RECON-RESULT.
       0000-RECONCILE.
           PERFORM 1000-INITIALISE-RESULT
           PERFORM 2000-LOAD-OPENING-MASTER
           IF NOT RR-ABORTED
               PERFORM 3000-REPLAY-JOURNAL
           END-IF
           IF NOT RR-ABORTED
               PERFORM 5000-LOAD-CLOSING-MASTER
           END-IF
           IF NOT RR-ABORTED
               PERFORM 6000-COMPARE-MASTERS
               PERFORM 7000-CHECK-CONTROL-TOTALS
               IF RR-DISCREPANCY-COUNT = ZERO
                   SET RR-PASSED TO TRUE
               ELSE
                   SET RR-FAILED TO TRUE
               END-IF
           END-IF
           GOBACK.

       1000-INITIALISE-RESULT.
           INITIALIZE RECON-RESULT
           SET RR-NOT-RUN TO TRUE
           MOVE EC-NONE TO RR-FATAL-CODE.

       2000-LOAD-OPENING-MASTER.
           MOVE "L" TO WS-STORE-FUNCTION
           CALL "ACCTSTOR" USING WS-STORE-FUNCTION
                                 RQ-OPENING-PATH
                                 OP-ACCOUNT-TABLE
                                 WS-STORE-STATUS
                                 WS-STORE-DETAIL
           IF WS-STORE-STATUS = EC-NONE
               MOVE OP-TOTAL-BALANCE TO RR-OPENING-TOTAL
           ELSE
               SET RR-ABORTED TO TRUE
               MOVE WS-STORE-STATUS TO RR-FATAL-CODE
               STRING "OPENING MASTER: " WS-STORE-DETAIL
                   DELIMITED BY SIZE INTO RR-FATAL-DETAIL
           END-IF.

      *---------------------------------------------------------------
      * Journal replay
      *---------------------------------------------------------------
       3000-REPLAY-JOURNAL.
           MOVE RQ-JOURNAL-PATH TO WS-JOURNAL-PATH
           MOVE "N" TO WS-END-OF-FILE-FLAG
           MOVE ZERO TO WS-PREVIOUS-SEQUENCE
           SET WS-AWAITING-DEBIT TO TRUE

           OPEN INPUT JOURNAL-FILE
           IF WS-FILE-STATUS NOT = "00"
               SET RR-ABORTED TO TRUE
               MOVE EC-JOURNAL-OPEN TO RR-FATAL-CODE
               STRING "JOURNAL OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO RR-FATAL-DETAIL
               EXIT PARAGRAPH
           END-IF

           PERFORM 3100-READ-JOURNAL-RECORD
           PERFORM UNTIL WS-END-OF-FILE
               PERFORM 3200-CHECK-JOURNAL-ENTRY
               PERFORM 3100-READ-JOURNAL-RECORD
           END-PERFORM
           CLOSE JOURNAL-FILE

           IF NOT RR-ABORTED AND WS-AWAITING-CREDIT
               MOVE EC-RECON-PAIR TO WS-D-CODE
               MOVE WS-HELD-TXN-ID TO WS-D-KEY
               MOVE WS-HELD-AMOUNT TO WS-D-EXPECTED
               MOVE ZERO TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
           END-IF.

       3100-READ-JOURNAL-RECORD.
           MOVE SPACES TO JOURNAL-FILE-RECORD
           READ JOURNAL-FILE
           EVALUATE TRUE
               WHEN WS-FILE-STATUS = "10"
                   SET WS-END-OF-FILE TO TRUE
               WHEN WS-FILE-STATUS (1:1) = "0"
                   ADD 1 TO RR-JOURNAL-ENTRIES
                   MOVE JOURNAL-FILE-RECORD TO JOURNAL-AREA
               WHEN OTHER
                   SET RR-ABORTED TO TRUE
                   MOVE EC-JOURNAL-OPEN TO RR-FATAL-CODE
                   STRING "JOURNAL READ FILE STATUS " WS-FILE-STATUS
                       DELIMITED BY SIZE INTO RR-FATAL-DETAIL
                   SET WS-END-OF-FILE TO TRUE
           END-EVALUATE.

       3200-CHECK-JOURNAL-ENTRY.
           PERFORM 3300-CHECK-ENTRY-FORMAT
           IF WS-ENTRY-IS-VALID
               PERFORM 3400-CHECK-SEQUENCE
               PERFORM 3500-CHECK-PAIRING
               PERFORM 3600-ACCUMULATE-TOTALS
               IF JR-ACCOUNT = WS-CLEARING-ACCOUNT
                   PERFORM 4000-REPLAY-CLEARING-ENTRY
               ELSE
                   PERFORM 4100-REPLAY-CUSTOMER-ENTRY
               END-IF
           END-IF.

      *    A record that is not well formed cannot be replayed.  It
      *    is reported by its position in the file, because its own
      *    sequence number may be part of what is wrong.
       3300-CHECK-ENTRY-FORMAT.
           MOVE "Y" TO WS-ENTRY-VALID-FLAG
           IF JR-OVERFLOW-AREA NOT = SPACES
                   OR JR-SEQUENCE IS NOT NUMERIC
                   OR JR-ACCOUNT IS NOT NUMERIC
                   OR JR-AMOUNT IS NOT NUMERIC
                   OR JR-BALANCE-AFTER IS NOT NUMERIC
                   OR (NOT JR-IS-DEBIT AND NOT JR-IS-CREDIT)
               MOVE "N" TO WS-ENTRY-VALID-FLAG
           END-IF
           IF WS-ENTRY-IS-VALID
               IF JR-AMOUNT = ZERO
                   MOVE "N" TO WS-ENTRY-VALID-FLAG
               END-IF
           END-IF
           IF NOT WS-ENTRY-IS-VALID
               MOVE EC-RECON-RECORD TO WS-D-CODE
               MOVE RR-JOURNAL-ENTRIES TO WS-SEQUENCE-DISPLAY
               MOVE SPACES TO WS-D-KEY
               STRING "REC " WS-SEQUENCE-DISPLAY
                   DELIMITED BY SIZE INTO WS-D-KEY
               MOVE ZERO TO WS-D-EXPECTED
               MOVE ZERO TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
           END-IF.

      *    Each sequence number must be one more than the one before.
      *    After a gap the check carries on from the number actually
      *    found, so one missing entry is reported once.
       3400-CHECK-SEQUENCE.
           COMPUTE WS-EXPECTED-SEQUENCE = WS-PREVIOUS-SEQUENCE + 1
           IF JR-SEQUENCE NOT = WS-EXPECTED-SEQUENCE
               MOVE EC-RECON-SEQUENCE TO WS-D-CODE
               PERFORM 8100-KEY-FROM-SEQUENCE
               MOVE WS-EXPECTED-SEQUENCE TO WS-D-EXPECTED
               MOVE JR-SEQUENCE TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
           END-IF
           MOVE JR-SEQUENCE TO WS-PREVIOUS-SEQUENCE.

       3500-CHECK-PAIRING.
           IF JR-IS-DEBIT
               IF WS-AWAITING-CREDIT
      *            Two debits in a row: the held one has no credit.
                   MOVE EC-RECON-PAIR TO WS-D-CODE
                   MOVE WS-HELD-TXN-ID TO WS-D-KEY
                   MOVE WS-HELD-AMOUNT TO WS-D-EXPECTED
                   MOVE ZERO TO WS-D-ACTUAL
                   PERFORM 8000-RECORD-DISCREPANCY
               END-IF
               MOVE JR-TXN-ID TO WS-HELD-TXN-ID
               MOVE JR-AMOUNT TO WS-HELD-AMOUNT
               SET WS-AWAITING-CREDIT TO TRUE
           ELSE
               IF WS-AWAITING-CREDIT
                       AND JR-TXN-ID = WS-HELD-TXN-ID
                       AND JR-AMOUNT = WS-HELD-AMOUNT
                   CONTINUE
               ELSE
                   MOVE EC-RECON-PAIR TO WS-D-CODE
                   MOVE JR-TXN-ID TO WS-D-KEY
                   IF WS-AWAITING-CREDIT
                       MOVE WS-HELD-AMOUNT TO WS-D-EXPECTED
                   ELSE
                       MOVE ZERO TO WS-D-EXPECTED
                   END-IF
                   MOVE JR-AMOUNT TO WS-D-ACTUAL
                   PERFORM 8000-RECORD-DISCREPANCY
               END-IF
               SET WS-AWAITING-DEBIT TO TRUE
           END-IF.

       3600-ACCUMULATE-TOTALS.
           IF JR-IS-DEBIT
               ADD JR-AMOUNT TO RR-TOTAL-DEBITS
                   ON SIZE ERROR
                       PERFORM 3900-REPORT-ARITHMETIC-OVERFLOW
               END-ADD
           ELSE
               ADD JR-AMOUNT TO RR-TOTAL-CREDITS
                   ON SIZE ERROR
                       PERFORM 3900-REPORT-ARITHMETIC-OVERFLOW
               END-ADD
           END-IF.

       3900-REPORT-ARITHMETIC-OVERFLOW.
           MOVE EC-RECON-RECORD TO WS-D-CODE
           PERFORM 8100-KEY-FROM-SEQUENCE
           MOVE ZERO TO WS-D-EXPECTED
           MOVE JR-AMOUNT TO WS-D-ACTUAL
           PERFORM 8000-RECORD-DISCREPANCY.

      *    The clearing account is an asset: debits increase it.
       4000-REPLAY-CLEARING-ENTRY.
           IF JR-IS-DEBIT
               ADD JR-AMOUNT TO RR-CLEARING-POSITION
                   ON SIZE ERROR
                       PERFORM 3900-REPORT-ARITHMETIC-OVERFLOW
               END-ADD
           ELSE
               SUBTRACT JR-AMOUNT FROM RR-CLEARING-POSITION
                   ON SIZE ERROR
                       PERFORM 3900-REPORT-ARITHMETIC-OVERFLOW
               END-SUBTRACT
           END-IF
           MOVE RR-CLEARING-POSITION TO WS-REPLAYED-BALANCE
           PERFORM 4200-CHECK-RUNNING-BALANCE.

      *    Customer accounts are liabilities: credits increase them.
       4100-REPLAY-CUSTOMER-ENTRY.
           MOVE ZERO TO WS-FOUND-ENTRY
           IF OP-ACCOUNT-COUNT > ZERO
               SEARCH ALL OP-ENTRY
                   AT END
                       CONTINUE
                   WHEN OP-ACCT-ID (OP-IDX) = JR-ACCOUNT
                       SET WS-FOUND-ENTRY TO OP-IDX
               END-SEARCH
           END-IF

           IF WS-FOUND-ENTRY = ZERO
               MOVE EC-RECON-UNKNOWN-ACCT TO WS-D-CODE
               MOVE JR-ACCOUNT TO WS-D-KEY
               MOVE ZERO TO WS-D-EXPECTED
               MOVE JR-AMOUNT TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
               EXIT PARAGRAPH
           END-IF

           IF JR-IS-DEBIT
               SUBTRACT JR-AMOUNT FROM OP-BALANCE (WS-FOUND-ENTRY)
                   ON SIZE ERROR
                       PERFORM 3900-REPORT-ARITHMETIC-OVERFLOW
               END-SUBTRACT
           ELSE
               ADD JR-AMOUNT TO OP-BALANCE (WS-FOUND-ENTRY)
                   ON SIZE ERROR
                       PERFORM 3900-REPORT-ARITHMETIC-OVERFLOW
               END-ADD
           END-IF
           MOVE OP-BALANCE (WS-FOUND-ENTRY) TO WS-REPLAYED-BALANCE
           PERFORM 4200-CHECK-RUNNING-BALANCE.

       4200-CHECK-RUNNING-BALANCE.
           IF JR-BALANCE-AFTER NOT = WS-REPLAYED-BALANCE
               MOVE EC-RECON-RUNNING-BAL TO WS-D-CODE
               PERFORM 8100-KEY-FROM-SEQUENCE
               MOVE WS-REPLAYED-BALANCE TO WS-D-EXPECTED
               MOVE JR-BALANCE-AFTER TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
           END-IF.

      *---------------------------------------------------------------
      * Closing master comparison
      *---------------------------------------------------------------
       5000-LOAD-CLOSING-MASTER.
           MOVE "L" TO WS-STORE-FUNCTION
           CALL "ACCTSTOR" USING WS-STORE-FUNCTION
                                 RQ-CLOSING-PATH
                                 CL-ACCOUNT-TABLE
                                 WS-STORE-STATUS
                                 WS-STORE-DETAIL
           IF WS-STORE-STATUS = EC-NONE
               MOVE CL-TOTAL-BALANCE TO RR-CLOSING-TOTAL
           ELSE
               SET RR-ABORTED TO TRUE
               MOVE WS-STORE-STATUS TO RR-FATAL-CODE
               STRING "CLOSING MASTER: " WS-STORE-DETAIL
                   DELIMITED BY SIZE INTO RR-FATAL-DETAIL
           END-IF.

       6000-COMPARE-MASTERS.
           MOVE OP-ACCOUNT-COUNT TO WS-COMPARE-COUNT
           IF OP-ACCOUNT-COUNT NOT = CL-ACCOUNT-COUNT
               MOVE EC-RECON-ACCOUNT-SET TO WS-D-CODE
               MOVE "ACCT COUNT" TO WS-D-KEY
               MOVE OP-ACCOUNT-COUNT TO WS-D-EXPECTED
               MOVE CL-ACCOUNT-COUNT TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
               IF CL-ACCOUNT-COUNT < WS-COMPARE-COUNT
                   MOVE CL-ACCOUNT-COUNT TO WS-COMPARE-COUNT
               END-IF
           END-IF
           MOVE WS-COMPARE-COUNT TO RR-ACCOUNTS-COMPARED

           PERFORM 6100-COMPARE-ONE-ACCOUNT
               VARYING WS-ENTRY-NUMBER FROM 1 BY 1
               UNTIL WS-ENTRY-NUMBER > WS-COMPARE-COUNT

           MOVE ZERO TO RR-EXPECTED-CLOSING
           PERFORM VARYING WS-ENTRY-NUMBER FROM 1 BY 1
                   UNTIL WS-ENTRY-NUMBER > OP-ACCOUNT-COUNT
               ADD OP-BALANCE (WS-ENTRY-NUMBER)
                   TO RR-EXPECTED-CLOSING
           END-PERFORM.

       6100-COMPARE-ONE-ACCOUNT.
           EVALUATE TRUE
               WHEN OP-ACCT-ID (WS-ENTRY-NUMBER)
                       NOT = CL-ACCT-ID (WS-ENTRY-NUMBER)
                 OR OP-ACCT-NAME (WS-ENTRY-NUMBER)
                       NOT = CL-ACCT-NAME (WS-ENTRY-NUMBER)
                 OR OP-ACCT-STATUS (WS-ENTRY-NUMBER)
                       NOT = CL-ACCT-STATUS (WS-ENTRY-NUMBER)
                   MOVE EC-RECON-ACCOUNT-SET TO WS-D-CODE
                   MOVE OP-ACCT-ID (WS-ENTRY-NUMBER) TO WS-D-KEY
                   MOVE ZERO TO WS-D-EXPECTED
                   MOVE ZERO TO WS-D-ACTUAL
                   PERFORM 8000-RECORD-DISCREPANCY
               WHEN OP-BALANCE (WS-ENTRY-NUMBER)
                       NOT = CL-BALANCE (WS-ENTRY-NUMBER)
                   MOVE EC-RECON-BALANCE TO WS-D-CODE
                   MOVE OP-ACCT-ID (WS-ENTRY-NUMBER) TO WS-D-KEY
                   MOVE OP-BALANCE (WS-ENTRY-NUMBER)
                     TO WS-D-EXPECTED
                   MOVE CL-BALANCE (WS-ENTRY-NUMBER) TO WS-D-ACTUAL
                   PERFORM 8000-RECORD-DISCREPANCY
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       7000-CHECK-CONTROL-TOTALS.
           IF RR-TOTAL-DEBITS NOT = RR-TOTAL-CREDITS
               MOVE EC-RECON-DR-CR TO WS-D-CODE
               MOVE "JOURNAL" TO WS-D-KEY
               MOVE RR-TOTAL-DEBITS TO WS-D-EXPECTED
               MOVE RR-TOTAL-CREDITS TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
           END-IF

      *    Money enters and leaves the customer accounts only through
      *    the clearing account, so the growth in total customer
      *    balances must equal the clearing position.
           COMPUTE WS-EXPECTED-TOTAL =
               RR-OPENING-TOTAL + RR-CLEARING-POSITION
           IF RR-CLOSING-TOTAL NOT = WS-EXPECTED-TOTAL
               MOVE EC-RECON-CONTROL-TOTAL TO WS-D-CODE
               MOVE "TOTALS" TO WS-D-KEY
               MOVE WS-EXPECTED-TOTAL TO WS-D-EXPECTED
               MOVE RR-CLOSING-TOTAL TO WS-D-ACTUAL
               PERFORM 8000-RECORD-DISCREPANCY
           END-IF.

      *---------------------------------------------------------------
      * Discrepancy recording
      *---------------------------------------------------------------
       8000-RECORD-DISCREPANCY.
           ADD 1 TO RR-DISCREPANCY-COUNT
           IF RR-DETAIL-COUNT < 20
               ADD 1 TO RR-DETAIL-COUNT
               MOVE WS-D-CODE     TO RR-D-CODE (RR-DETAIL-COUNT)
               MOVE WS-D-KEY      TO RR-D-KEY (RR-DETAIL-COUNT)
               MOVE WS-D-EXPECTED TO RR-D-EXPECTED (RR-DETAIL-COUNT)
               MOVE WS-D-ACTUAL   TO RR-D-ACTUAL (RR-DETAIL-COUNT)
           END-IF.

       8100-KEY-FROM-SEQUENCE.
           MOVE JR-SEQUENCE TO WS-SEQUENCE-DISPLAY
           MOVE SPACES TO WS-D-KEY
           STRING "SEQ " WS-SEQUENCE-DISPLAY
               DELIMITED BY SIZE INTO WS-D-KEY.
