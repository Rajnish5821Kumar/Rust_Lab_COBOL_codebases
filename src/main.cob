      *****************************************************************
      * LEDGMAIN - batch transaction processing driver
      *
      * Runs one batch: loads the control file, the opening account
      * master and (optionally) the posted-transaction history, then
      * reads the transaction file once, posting or rejecting each
      * record, and finally writes the closing master, saves the
      * history, reconciles the outputs and prints the summary.
      *
      * This program holds the order of work and nothing else.  Each
      * file is owned by one subprogram, and each business decision
      * is made by one subprogram:
      *
      *   CTLLOAD   control file            ACCTSTOR  account master
      *   TXNREAD   transaction file        HISTSTOR  history file
      *   TXNVALID  record validation       ACCTPROC  posting rules
      *   LEDGWRIT  journal file            REPORTS   report files
      *   RECONCIL  reconciliation          ERRTEXT   message texts
      *
      * File names come from environment variables (see
      * BATCH-FILES.CPY).  The job log is written to standard output.
      *
      * Return codes
      *    0  every transaction posted; outputs reconciled
      *    4  completed; one or more transactions rejected
      *    8  completed, but reconciliation failed or could not be
      *       completed: outputs must not be used
      *   12  abandoned before processing began (bad or missing
      *       input, or an output could not be opened): nothing was
      *       posted
      *   16  abandoned during or after processing: outputs are
      *       incomplete and must not be used
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEDGMAIN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".
       COPY "batch-files.cpy".
       COPY "batch-control.cpy".
       COPY "transaction-record.cpy".
       COPY "txn-work.cpy".
       COPY "posting-result.cpy".
       COPY "batch-totals.cpy".
       COPY "recon-result.cpy".
       COPY "account-table.cpy" REPLACING ==:AT:== BY ==AT==.

      *    ---- run state --------------------------------------------
       01  WS-RUN-STATE                    PIC X(1) VALUE "0".
           88  WS-RUN-IS-OK                VALUE "0".
           88  WS-RUN-IS-FATAL             VALUE "F".
       01  WS-FATAL-CODE                   PIC X(4) VALUE "0000".
       01  WS-FATAL-DETAIL                 PIC X(60) VALUE SPACES.
       01  WS-PROCESSING-STARTED-FLAG      PIC X(1) VALUE "N".
           88  WS-PROCESSING-STARTED       VALUE "Y".
       01  WS-REPORTS-OPEN-FLAG            PIC X(1) VALUE "N".
           88  WS-REPORTS-ARE-OPEN         VALUE "Y".
       01  WS-JOURNAL-OPEN-FLAG            PIC X(1) VALUE "N".
           88  WS-JOURNAL-IS-OPEN          VALUE "Y".
       01  WS-END-OF-TRANSACTIONS-FLAG     PIC X(1) VALUE "N".
           88  WS-END-OF-TRANSACTIONS      VALUE "Y".

      *    ---- subprogram interface work fields ---------------------
       01  WS-FUNCTION                     PIC X(1).
       01  WS-STATUS-CODE                  PIC X(4).
       01  WS-STATUS-DETAIL                PIC X(60).
       01  WS-READ-RESULT                  PIC X(1).
           88  WS-RECORD-RETURNED          VALUE "0".
           88  WS-READ-AT-END              VALUE "E".
           88  WS-READ-FAILED              VALUE "F".
       01  WS-HISTORY-RESULT               PIC X(1).
           88  WS-ID-NOT-POSTED            VALUE "N".
           88  WS-ID-POSTED-IN-BATCH       VALUE "B".
           88  WS-ID-POSTED-BEFORE         VALUE "P".
           88  WS-ID-STORE-FULL            VALUE "F".
       01  WS-HISTORY-COUNT                PIC 9(8) BINARY.
       01  WS-HISTORY-DATE                 PIC X(8).
       01  WS-NO-PATH                      PIC X(256) VALUE SPACES.
       01  WS-NO-TXN-ID                    PIC X(12) VALUE SPACES.

      *    ---- environment (DD name) lookup -------------------------
       01  WS-ENV-NAME                     PIC X(24).
       01  WS-ENV-VALUE                    PIC X(256).
       01  WS-ENV-REQUIRED-FLAG            PIC X(1).
           88  WS-ENV-IS-REQUIRED          VALUE "Y".

      *    ---- job log ----------------------------------------------
       01  WS-MESSAGE-TEXT                 PIC X(48).
       01  WS-LOG-COUNT-1                  PIC Z(7)9.
       01  WS-LOG-COUNT-2                  PIC Z(7)9.
       01  WS-LOG-COUNT-3                  PIC Z(7)9.
       01  WS-LOG-RETURN-CODE              PIC 9(4).

       PROCEDURE DIVISION.
       0000-RUN-BATCH.
           PERFORM 1000-START-RUN
           IF WS-RUN-IS-OK
               PERFORM 2000-LOAD-INPUTS
           END-IF
           IF WS-RUN-IS-OK
               PERFORM 3000-OPEN-PROCESSING-FILES
           END-IF
           IF WS-RUN-IS-OK
               PERFORM 4000-PROCESS-TRANSACTIONS
           END-IF
           PERFORM 5000-CLOSE-PROCESSING-FILES
           IF WS-RUN-IS-OK
               PERFORM 6000-SAVE-RESULTS
           END-IF
           IF WS-RUN-IS-OK
               PERFORM 7000-RECONCILE-OUTPUTS
           END-IF
           PERFORM 8000-FINISH-RUN
           MOVE BT-RETURN-CODE TO RETURN-CODE
           STOP RUN.

      *---------------------------------------------------------------
      * 1000  Start: clear the totals and collect the file names
      *---------------------------------------------------------------
       1000-START-RUN.
           DISPLAY "LEDGMAIN: BATCH RUN STARTED"
           INITIALIZE BATCH-TOTALS
           INITIALIZE TXN-WORK-AREA
           INITIALIZE POSTING-RESULT
           INITIALIZE RECON-RESULT
           SET RR-NOT-RUN TO TRUE
           MOVE EC-NONE TO RR-FATAL-CODE
           MOVE ZERO TO AT-ACCOUNT-COUNT
           PERFORM 1100-GET-FILE-NAMES
           IF WS-RUN-IS-OK
               PERFORM 1200-CHECK-FILE-NAMES
           END-IF.

       1100-GET-FILE-NAMES.
           MOVE "Y" TO WS-ENV-REQUIRED-FLAG
           MOVE "LEDGER_CONTROL" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-CONTROL-PATH
           MOVE "LEDGER_ACCOUNTS_IN" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-ACCOUNTS-IN-PATH
           MOVE "LEDGER_TXN_IN" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-TXN-IN-PATH
           MOVE "LEDGER_ACCOUNTS_OUT" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-ACCOUNTS-OUT-PATH
           MOVE "LEDGER_JOURNAL_OUT" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-JOURNAL-PATH
           MOVE "LEDGER_POSTED_RPT" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-POSTED-PATH
           MOVE "LEDGER_REJECT_RPT" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-REJECT-PATH
           MOVE "LEDGER_SUMMARY_RPT" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-SUMMARY-PATH

           MOVE "N" TO WS-ENV-REQUIRED-FLAG
           MOVE "LEDGER_HISTORY_IN" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-HISTORY-IN-PATH
           MOVE "LEDGER_HISTORY_OUT" TO WS-ENV-NAME
           PERFORM 1110-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO BF-HISTORY-OUT-PATH.

      *    An unset variable and a variable set to spaces are treated
      *    alike.  Only the first missing required name is reported.
       1110-GET-ONE-FILE-NAME.
           MOVE SPACES TO WS-ENV-VALUE
           ACCEPT WS-ENV-VALUE FROM ENVIRONMENT WS-ENV-NAME
               ON EXCEPTION
                   MOVE SPACES TO WS-ENV-VALUE
           END-ACCEPT
           IF WS-ENV-VALUE = SPACES
                   AND WS-ENV-IS-REQUIRED
                   AND WS-RUN-IS-OK
               MOVE EC-FILE-NAME-MISSING TO WS-STATUS-CODE
               MOVE SPACES TO WS-STATUS-DETAIL
               STRING "VARIABLE " WS-ENV-NAME
                   DELIMITED BY SIZE INTO WS-STATUS-DETAIL
               PERFORM 9000-RAISE-FATAL
           END-IF.

      *    Writing an output over the input it was derived from would
      *    destroy the only copy of the opening position, so it is
      *    refused before anything is opened.
       1200-CHECK-FILE-NAMES.
           IF BF-ACCOUNTS-IN-PATH = BF-ACCOUNTS-OUT-PATH
               MOVE EC-SAME-IN-OUT-PATH TO WS-STATUS-CODE
               MOVE "LEDGER_ACCOUNTS_IN AND LEDGER_ACCOUNTS_OUT"
                 TO WS-STATUS-DETAIL
               PERFORM 9000-RAISE-FATAL
           END-IF
           IF WS-RUN-IS-OK
                   AND BF-HISTORY-IN-PATH NOT = SPACES
                   AND BF-HISTORY-IN-PATH = BF-HISTORY-OUT-PATH
               MOVE EC-SAME-IN-OUT-PATH TO WS-STATUS-CODE
               MOVE "LEDGER_HISTORY_IN AND LEDGER_HISTORY_OUT"
                 TO WS-STATUS-DETAIL
               PERFORM 9000-RAISE-FATAL
           END-IF.

      *---------------------------------------------------------------
      * 2000  Load and prove the inputs before anything is posted
      *---------------------------------------------------------------
       2000-LOAD-INPUTS.
           CALL "CTLLOAD" USING BF-CONTROL-PATH
                                BATCH-CONTROL
                                WS-STATUS-CODE
                                WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
               EXIT PARAGRAPH
           END-IF
           DISPLAY "LEDGMAIN: BATCH DATE " BC-BATCH-DATE
                   "  BATCH ID " FUNCTION TRIM (BC-BATCH-ID TRAILING)

           MOVE "L" TO WS-FUNCTION
           CALL "ACCTSTOR" USING WS-FUNCTION
                                 BF-ACCOUNTS-IN-PATH
                                 AT-ACCOUNT-TABLE
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE AT-ACCOUNT-COUNT TO BT-OPENING-ACCOUNTS
           MOVE AT-TOTAL-BALANCE TO BT-OPENING-TOTAL

           PERFORM 2100-LOAD-HISTORY.

      *    Without a history file the run can only detect duplicates
      *    inside its own transaction file.  That is allowed, but it
      *    is said in the job log so it is never a silent choice.
       2100-LOAD-HISTORY.
           IF BF-HISTORY-IN-PATH = SPACES
               MOVE "R" TO WS-FUNCTION
               DISPLAY "LEDGMAIN: NO HISTORY FILE - DUPLICATES OF "
                       "EARLIER RUNS WILL NOT BE DETECTED"
           ELSE
               MOVE "L" TO WS-FUNCTION
           END-IF
           CALL "HISTSTOR" USING WS-FUNCTION
                                 BF-HISTORY-IN-PATH
                                 WS-NO-TXN-ID
                                 WS-HISTORY-DATE
                                 WS-HISTORY-RESULT
                                 WS-HISTORY-COUNT
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
           ELSE
               MOVE WS-HISTORY-COUNT TO BT-HISTORY-LOADED
           END-IF.

      *---------------------------------------------------------------
      * 3000  Open the transaction file, then the outputs.  The input
      *       is opened first so that a missing transaction file
      *       leaves no half-made outputs behind.
      *---------------------------------------------------------------
       3000-OPEN-PROCESSING-FILES.
           MOVE "O" TO WS-FUNCTION
           CALL "TXNREAD" USING WS-FUNCTION
                                BF-TXN-IN-PATH
                                TXN-INPUT-AREA
                                TXN-WORK-AREA
                                WS-READ-RESULT
                                WS-STATUS-CODE
                                WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
               EXIT PARAGRAPH
           END-IF

           MOVE "O" TO WS-FUNCTION
           CALL "LEDGWRIT" USING WS-FUNCTION
                                 BF-JOURNAL-PATH
                                 BATCH-CONTROL
                                 TXN-WORK-AREA
                                 POSTING-RESULT
                                 BATCH-TOTALS
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
               EXIT PARAGRAPH
           END-IF
           SET WS-JOURNAL-IS-OPEN TO TRUE

           MOVE "O" TO WS-FUNCTION
           PERFORM 9100-CALL-REPORTS
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
           ELSE
               SET WS-REPORTS-ARE-OPEN TO TRUE
           END-IF.

      *---------------------------------------------------------------
      * 4000  The processing loop: one pass over the transaction file
      *---------------------------------------------------------------
       4000-PROCESS-TRANSACTIONS.
           SET WS-PROCESSING-STARTED TO TRUE
           PERFORM 4100-READ-TRANSACTION
           PERFORM UNTIL WS-END-OF-TRANSACTIONS OR WS-RUN-IS-FATAL
               PERFORM 4200-PROCESS-ONE-TRANSACTION
               IF WS-RUN-IS-OK
                   PERFORM 4100-READ-TRANSACTION
               END-IF
           END-PERFORM.

       4100-READ-TRANSACTION.
           MOVE "R" TO WS-FUNCTION
           CALL "TXNREAD" USING WS-FUNCTION
                                BF-TXN-IN-PATH
                                TXN-INPUT-AREA
                                TXN-WORK-AREA
                                WS-READ-RESULT
                                WS-STATUS-CODE
                                WS-STATUS-DETAIL
           EVALUATE TRUE
               WHEN WS-RECORD-RETURNED
                   ADD 1 TO BT-RECORDS-READ
               WHEN WS-READ-AT-END
                   SET WS-END-OF-TRANSACTIONS TO TRUE
               WHEN OTHER
                   PERFORM 9000-RAISE-FATAL
           END-EVALUATE.

      *    Validate, then check for a duplicate, then apply the
      *    posting rules.  The first stage to object decides the
      *    status code; a transaction that passes all three is posted.
       4200-PROCESS-ONE-TRANSACTION.
           CALL "TXNVALID" USING TXN-INPUT-AREA
                                 BATCH-CONTROL
                                 TXN-WORK-AREA
           IF TW-IS-ACCEPTED
               PERFORM 4300-CHECK-FOR-DUPLICATE
           END-IF
           IF TW-IS-ACCEPTED
               CALL "ACCTPROC" USING BATCH-CONTROL
                                     TXN-WORK-AREA
                                     AT-ACCOUNT-TABLE
                                     POSTING-RESULT
           END-IF
           IF TW-IS-ACCEPTED
               PERFORM 4400-RECORD-POSTING
           ELSE
               PERFORM 4500-RECORD-REJECTION
           END-IF.

       4300-CHECK-FOR-DUPLICATE.
           MOVE "C" TO WS-FUNCTION
           PERFORM 9200-CALL-HISTORY-STORE
           EVALUATE TRUE
               WHEN WS-ID-POSTED-IN-BATCH
                   MOVE EC-DUP-IN-BATCH TO TW-STATUS-CODE
               WHEN WS-ID-POSTED-BEFORE
                   MOVE EC-DUP-PRIOR-BATCH TO TW-STATUS-CODE
               WHEN WS-ID-STORE-FULL
                   MOVE EC-ID-CAPACITY TO TW-STATUS-CODE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

      *    The balances have been updated in memory; now make the
      *    posting durable and visible: journal, id store, totals,
      *    posted report.  A failure in any of these is fatal.
       4400-RECORD-POSTING.
           MOVE "W" TO WS-FUNCTION
           CALL "LEDGWRIT" USING WS-FUNCTION
                                 BF-JOURNAL-PATH
                                 BATCH-CONTROL
                                 TXN-WORK-AREA
                                 POSTING-RESULT
                                 BATCH-TOTALS
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
               EXIT PARAGRAPH
           END-IF

           MOVE "A" TO WS-FUNCTION
           PERFORM 9200-CALL-HISTORY-STORE

           ADD 1 TO BT-POSTED-COUNT
           EVALUATE TRUE
               WHEN TW-IS-DEPOSIT
                   ADD 1 TO BT-DEPOSIT-COUNT
                   ADD TW-AMOUNT TO BT-DEPOSIT-AMOUNT
                       ON SIZE ERROR
                           PERFORM 4410-RAISE-TOTAL-OVERFLOW
                   END-ADD
               WHEN TW-IS-WITHDRAWAL
                   ADD 1 TO BT-WITHDRAWAL-COUNT
                   ADD TW-AMOUNT TO BT-WITHDRAWAL-AMOUNT
                       ON SIZE ERROR
                           PERFORM 4410-RAISE-TOTAL-OVERFLOW
                   END-ADD
               WHEN TW-IS-TRANSFER
                   ADD 1 TO BT-TRANSFER-COUNT
                   ADD TW-AMOUNT TO BT-TRANSFER-AMOUNT
                       ON SIZE ERROR
                           PERFORM 4410-RAISE-TOTAL-OVERFLOW
                   END-ADD
           END-EVALUATE

           IF WS-RUN-IS-OK
               MOVE "P" TO WS-FUNCTION
               PERFORM 9100-CALL-REPORTS
               IF WS-STATUS-CODE NOT = EC-NONE
                   PERFORM 9000-RAISE-FATAL
               END-IF
           END-IF.

       4410-RAISE-TOTAL-OVERFLOW.
           MOVE EC-TOTAL-OVERFLOW TO WS-STATUS-CODE
           MOVE SPACES TO WS-STATUS-DETAIL
           STRING "POSTED AMOUNT TOTAL OVERFLOW AT TXN " TW-TXN-ID
               DELIMITED BY SIZE INTO WS-STATUS-DETAIL
           PERFORM 9000-RAISE-FATAL.

       4500-RECORD-REJECTION.
           ADD 1 TO BT-REJECTED-COUNT
           MOVE "J" TO WS-FUNCTION
           PERFORM 9100-CALL-REPORTS
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
           END-IF.

      *---------------------------------------------------------------
      * 5000  Close the transaction file and the journal.  This runs
      *       even after a fatal error so no file is left open.
      *---------------------------------------------------------------
       5000-CLOSE-PROCESSING-FILES.
           MOVE "C" TO WS-FUNCTION
           CALL "TXNREAD" USING WS-FUNCTION
                                BF-TXN-IN-PATH
                                TXN-INPUT-AREA
                                TXN-WORK-AREA
                                WS-READ-RESULT
                                WS-STATUS-CODE
                                WS-STATUS-DETAIL

           IF WS-JOURNAL-IS-OPEN
               MOVE "C" TO WS-FUNCTION
               CALL "LEDGWRIT" USING WS-FUNCTION
                                     BF-JOURNAL-PATH
                                     BATCH-CONTROL
                                     TXN-WORK-AREA
                                     POSTING-RESULT
                                     BATCH-TOTALS
                                     WS-STATUS-CODE
                                     WS-STATUS-DETAIL
               MOVE "N" TO WS-JOURNAL-OPEN-FLAG
               IF WS-STATUS-CODE NOT = EC-NONE AND WS-RUN-IS-OK
                   PERFORM 9000-RAISE-FATAL
               END-IF
           END-IF.

      *---------------------------------------------------------------
      * 6000  Write the closing master and the updated history
      *---------------------------------------------------------------
       6000-SAVE-RESULTS.
           MOVE AT-CLEARING-POSITION TO BT-CLEARING-POSITION

           MOVE "S" TO WS-FUNCTION
           CALL "ACCTSTOR" USING WS-FUNCTION
                                 BF-ACCOUNTS-OUT-PATH
                                 AT-ACCOUNT-TABLE
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL
           IF WS-STATUS-CODE NOT = EC-NONE
               PERFORM 9000-RAISE-FATAL
               EXIT PARAGRAPH
           END-IF
           MOVE AT-TOTAL-BALANCE TO BT-CLOSING-TOTAL

           IF BF-HISTORY-OUT-PATH NOT = SPACES
               MOVE "S" TO WS-FUNCTION
               CALL "HISTSTOR" USING WS-FUNCTION
                                     BF-HISTORY-OUT-PATH
                                     WS-NO-TXN-ID
                                     WS-HISTORY-DATE
                                     WS-HISTORY-RESULT
                                     WS-HISTORY-COUNT
                                     WS-STATUS-CODE
                                     WS-STATUS-DETAIL
               IF WS-STATUS-CODE NOT = EC-NONE
                   PERFORM 9000-RAISE-FATAL
               ELSE
                   MOVE WS-HISTORY-COUNT TO BT-HISTORY-SAVED
               END-IF
           END-IF.

      *---------------------------------------------------------------
      * 7000  Reconcile the files just written, then make sure what
      *       is on disk agrees with the totals kept during the run
      *---------------------------------------------------------------
       7000-RECONCILE-OUTPUTS.
           MOVE BF-ACCOUNTS-IN-PATH  TO RQ-OPENING-PATH
           MOVE BF-JOURNAL-PATH      TO RQ-JOURNAL-PATH
           MOVE BF-ACCOUNTS-OUT-PATH TO RQ-CLOSING-PATH
           CALL "RECONCIL" USING RECON-REQUEST
                                 RECON-RESULT

           IF RR-PASSED OR RR-FAILED
               IF RR-JOURNAL-ENTRIES NOT = BT-JOURNAL-ENTRIES
                       OR RR-TOTAL-DEBITS NOT = BT-TOTAL-DEBITS
                       OR RR-TOTAL-CREDITS NOT = BT-TOTAL-CREDITS
                       OR RR-OPENING-TOTAL NOT = BT-OPENING-TOTAL
                       OR RR-CLOSING-TOTAL NOT = BT-CLOSING-TOTAL
                       OR RR-CLEARING-POSITION
                              NOT = BT-CLEARING-POSITION
                   PERFORM 7100-RECORD-MEMORY-MISMATCH
               END-IF
           END-IF.

       7100-RECORD-MEMORY-MISMATCH.
           SET RR-FAILED TO TRUE
           ADD 1 TO RR-DISCREPANCY-COUNT
           IF RR-DETAIL-COUNT < 20
               ADD 1 TO RR-DETAIL-COUNT
               MOVE EC-RECON-MEMORY-TOTALS
                 TO RR-D-CODE (RR-DETAIL-COUNT)
               MOVE "RUN TOTALS" TO RR-D-KEY (RR-DETAIL-COUNT)
               MOVE BT-TOTAL-DEBITS
                 TO RR-D-EXPECTED (RR-DETAIL-COUNT)
               MOVE RR-TOTAL-DEBITS
                 TO RR-D-ACTUAL (RR-DETAIL-COUNT)
           END-IF.

      *---------------------------------------------------------------
      * 8000  Finish: decide the return code, print the summary,
      *       close the reports and complete the job log
      *---------------------------------------------------------------
       8000-FINISH-RUN.
           PERFORM 8100-SET-RETURN-CODE

           IF WS-REPORTS-ARE-OPEN
               IF WS-RUN-IS-FATAL
                   MOVE "X" TO WS-FUNCTION
                   MOVE WS-FATAL-CODE TO WS-STATUS-CODE
                   MOVE WS-FATAL-DETAIL TO WS-STATUS-DETAIL
               ELSE
                   MOVE "S" TO WS-FUNCTION
               END-IF
               PERFORM 9100-CALL-REPORTS
               IF WS-STATUS-CODE NOT = EC-NONE AND WS-RUN-IS-OK
                   PERFORM 9000-RAISE-FATAL
               END-IF

               MOVE "C" TO WS-FUNCTION
               PERFORM 9100-CALL-REPORTS
               IF WS-STATUS-CODE NOT = EC-NONE AND WS-RUN-IS-OK
                   PERFORM 9000-RAISE-FATAL
               END-IF
               MOVE "N" TO WS-REPORTS-OPEN-FLAG
      *        A report failure this late changes the outcome.
               PERFORM 8100-SET-RETURN-CODE
           END-IF

           PERFORM 8200-WRITE-JOB-LOG-TOTALS.

       8100-SET-RETURN-CODE.
           EVALUATE TRUE
               WHEN WS-RUN-IS-FATAL AND WS-PROCESSING-STARTED
                   MOVE 16 TO BT-RETURN-CODE
               WHEN WS-RUN-IS-FATAL
                   MOVE 12 TO BT-RETURN-CODE
               WHEN NOT RR-PASSED
                   MOVE 8 TO BT-RETURN-CODE
               WHEN BT-REJECTED-COUNT > ZERO
                   MOVE 4 TO BT-RETURN-CODE
               WHEN OTHER
                   MOVE ZERO TO BT-RETURN-CODE
           END-EVALUATE.

       8200-WRITE-JOB-LOG-TOTALS.
           IF WS-PROCESSING-STARTED
               MOVE BT-RECORDS-READ   TO WS-LOG-COUNT-1
               MOVE BT-POSTED-COUNT   TO WS-LOG-COUNT-2
               MOVE BT-REJECTED-COUNT TO WS-LOG-COUNT-3
               DISPLAY "LEDGMAIN: RECORDS READ " WS-LOG-COUNT-1
                       "  POSTED " WS-LOG-COUNT-2
                       "  REJECTED " WS-LOG-COUNT-3
           END-IF

           IF WS-RUN-IS-OK
               EVALUATE TRUE
                   WHEN RR-PASSED
                       DISPLAY "LEDGMAIN: RECONCILIATION PASSED"
                   WHEN RR-FAILED
                       MOVE RR-DISCREPANCY-COUNT TO WS-LOG-COUNT-1
                       DISPLAY "LEDGMAIN: RECONCILIATION FAILED "
                               WS-LOG-COUNT-1 " DISCREPANCIES"
                   WHEN OTHER
                       CALL "ERRTEXT" USING RR-FATAL-CODE
                                            WS-MESSAGE-TEXT
                       DISPLAY "LEDGMAIN: RECONCILIATION NOT "
                               "COMPLETED " RR-FATAL-CODE " "
                               FUNCTION TRIM (WS-MESSAGE-TEXT TRAILING)
                       DISPLAY "LEDGMAIN:       "
                               FUNCTION TRIM (RR-FATAL-DETAIL TRAILING)
               END-EVALUATE
           END-IF

           MOVE BT-RETURN-CODE TO WS-LOG-RETURN-CODE
           DISPLAY "LEDGMAIN: RUN ENDED  RETURN CODE "
                   WS-LOG-RETURN-CODE.

      *---------------------------------------------------------------
      * 9000  Shared helpers
      *---------------------------------------------------------------
      *    Records the first fatal condition and logs it.  Later ones
      *    are logged too but do not replace the first, which is the
      *    cause; the rest are usually consequences.
       9000-RAISE-FATAL.
           CALL "ERRTEXT" USING WS-STATUS-CODE WS-MESSAGE-TEXT
           DISPLAY "LEDGMAIN: FATAL " WS-STATUS-CODE " "
                   FUNCTION TRIM (WS-MESSAGE-TEXT TRAILING)
           DISPLAY "LEDGMAIN:       "
                   FUNCTION TRIM (WS-STATUS-DETAIL TRAILING)
           IF WS-RUN-IS-OK
               SET WS-RUN-IS-FATAL TO TRUE
               MOVE WS-STATUS-CODE TO WS-FATAL-CODE
               MOVE WS-STATUS-DETAIL TO WS-FATAL-DETAIL
           END-IF.

       9100-CALL-REPORTS.
           CALL "REPORTS" USING WS-FUNCTION
                                BATCH-FILE-NAMES
                                BATCH-CONTROL
                                TXN-WORK-AREA
                                POSTING-RESULT
                                BATCH-TOTALS
                                RECON-RESULT
                                WS-STATUS-CODE
                                WS-STATUS-DETAIL.

       9200-CALL-HISTORY-STORE.
           MOVE BC-BATCH-DATE TO WS-HISTORY-DATE
           CALL "HISTSTOR" USING WS-FUNCTION
                                 WS-NO-PATH
                                 TW-TXN-ID
                                 WS-HISTORY-DATE
                                 WS-HISTORY-RESULT
                                 WS-HISTORY-COUNT
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL.
