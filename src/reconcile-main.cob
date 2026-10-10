      *****************************************************************
      * LEDGRECN - standalone reconciliation (audit) driver
      *
      * Re-runs the reconciliation of a finished batch from its files
      * alone: the opening master, the journal and the closing master.
      * Use it to confirm that a set of outputs is still internally
      * consistent before promoting it, or after it has been copied,
      * restored or otherwise handled.
      *
      * File names come from the same environment variables the batch
      * uses:
      *     LEDGER_ACCOUNTS_IN    opening account master
      *     LEDGER_JOURNAL_OUT    journal written by the batch
      *     LEDGER_ACCOUNTS_OUT   closing account master
      *
      * The result is written to standard output.
      *
      * Return codes
      *    0  reconciled
      *    8  discrepancies found
      *   12  a file name is missing or a file could not be read
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEDGRECN.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".
       COPY "recon-result.cpy".

       01  WS-ENV-NAME                     PIC X(24).
       01  WS-ENV-VALUE                    PIC X(256).
       01  WS-NAMES-MISSING-FLAG           PIC X(1) VALUE "N".
           88  WS-NAMES-ARE-MISSING        VALUE "Y".

       01  WS-MESSAGE-TEXT                 PIC X(48).
       01  WS-COUNT-EDITED                 PIC ZZ,ZZZ,ZZ9.
       01  WS-AMOUNT-EDITED                PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99-.
       01  WS-EXPECTED-EDITED              PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99-.
       01  WS-ACTUAL-EDITED                PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99-.
       01  WS-DETAIL-NUMBER                PIC 9(4) BINARY.
       01  WS-RETURN-CODE                  PIC 9(4).

       PROCEDURE DIVISION.
       0000-RUN-RECONCILIATION.
           DISPLAY "LEDGRECN: RECONCILIATION STARTED"
           PERFORM 1000-GET-FILE-NAMES

           IF WS-NAMES-ARE-MISSING
               MOVE 12 TO WS-RETURN-CODE
           ELSE
               CALL "RECONCIL" USING RECON-REQUEST
                                     RECON-RESULT
               PERFORM 2000-REPORT-RESULT
           END-IF

           DISPLAY "LEDGRECN: RUN ENDED  RETURN CODE " WS-RETURN-CODE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.

       1000-GET-FILE-NAMES.
           MOVE "LEDGER_ACCOUNTS_IN" TO WS-ENV-NAME
           PERFORM 1100-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO RQ-OPENING-PATH
           MOVE "LEDGER_JOURNAL_OUT" TO WS-ENV-NAME
           PERFORM 1100-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO RQ-JOURNAL-PATH
           MOVE "LEDGER_ACCOUNTS_OUT" TO WS-ENV-NAME
           PERFORM 1100-GET-ONE-FILE-NAME
           MOVE WS-ENV-VALUE TO RQ-CLOSING-PATH.

       1100-GET-ONE-FILE-NAME.
           MOVE SPACES TO WS-ENV-VALUE
           ACCEPT WS-ENV-VALUE FROM ENVIRONMENT WS-ENV-NAME
               ON EXCEPTION
                   MOVE SPACES TO WS-ENV-VALUE
           END-ACCEPT
           IF WS-ENV-VALUE = SPACES
               SET WS-NAMES-ARE-MISSING TO TRUE
               CALL "ERRTEXT" USING EC-FILE-NAME-MISSING
                                    WS-MESSAGE-TEXT
               DISPLAY "LEDGRECN: FATAL " EC-FILE-NAME-MISSING " "
                       FUNCTION TRIM (WS-MESSAGE-TEXT TRAILING)
               DISPLAY "LEDGRECN:       VARIABLE "
                       FUNCTION TRIM (WS-ENV-NAME TRAILING)
           END-IF.

       2000-REPORT-RESULT.
           EVALUATE TRUE
               WHEN RR-PASSED
                   MOVE ZERO TO WS-RETURN-CODE
                   PERFORM 2100-DISPLAY-TOTALS
                   DISPLAY "LEDGRECN: RECONCILIATION PASSED"
               WHEN RR-FAILED
                   MOVE 8 TO WS-RETURN-CODE
                   PERFORM 2100-DISPLAY-TOTALS
                   PERFORM 2200-DISPLAY-DISCREPANCIES
                   DISPLAY "LEDGRECN: RECONCILIATION FAILED"
               WHEN OTHER
                   MOVE 12 TO WS-RETURN-CODE
                   CALL "ERRTEXT" USING RR-FATAL-CODE
                                        WS-MESSAGE-TEXT
                   DISPLAY "LEDGRECN: FATAL " RR-FATAL-CODE " "
                           FUNCTION TRIM (WS-MESSAGE-TEXT TRAILING)
                   DISPLAY "LEDGRECN:       "
                           FUNCTION TRIM (RR-FATAL-DETAIL TRAILING)
           END-EVALUATE.

       2100-DISPLAY-TOTALS.
           MOVE RR-JOURNAL-ENTRIES TO WS-COUNT-EDITED
           DISPLAY "LEDGRECN: JOURNAL ENTRIES REPLAYED   "
                   WS-COUNT-EDITED
           MOVE RR-ACCOUNTS-COMPARED TO WS-COUNT-EDITED
           DISPLAY "LEDGRECN: ACCOUNTS COMPARED          "
                   WS-COUNT-EDITED
           MOVE RR-TOTAL-DEBITS TO WS-AMOUNT-EDITED
           DISPLAY "LEDGRECN: TOTAL DEBITS      " WS-AMOUNT-EDITED
           MOVE RR-TOTAL-CREDITS TO WS-AMOUNT-EDITED
           DISPLAY "LEDGRECN: TOTAL CREDITS     " WS-AMOUNT-EDITED
           MOVE RR-OPENING-TOTAL TO WS-AMOUNT-EDITED
           DISPLAY "LEDGRECN: OPENING TOTAL     " WS-AMOUNT-EDITED
           MOVE RR-CLEARING-POSITION TO WS-AMOUNT-EDITED
           DISPLAY "LEDGRECN: NET CASH          " WS-AMOUNT-EDITED
           MOVE RR-CLOSING-TOTAL TO WS-AMOUNT-EDITED
           DISPLAY "LEDGRECN: CLOSING TOTAL     " WS-AMOUNT-EDITED
           MOVE RR-DISCREPANCY-COUNT TO WS-COUNT-EDITED
           DISPLAY "LEDGRECN: DISCREPANCIES FOUND        "
                   WS-COUNT-EDITED.

       2200-DISPLAY-DISCREPANCIES.
           PERFORM VARYING WS-DETAIL-NUMBER FROM 1 BY 1
                   UNTIL WS-DETAIL-NUMBER > RR-DETAIL-COUNT
               CALL "ERRTEXT" USING RR-D-CODE (WS-DETAIL-NUMBER)
                                    WS-MESSAGE-TEXT
               MOVE RR-D-EXPECTED (WS-DETAIL-NUMBER)
                 TO WS-EXPECTED-EDITED
               MOVE RR-D-ACTUAL (WS-DETAIL-NUMBER)
                 TO WS-ACTUAL-EDITED
               DISPLAY "LEDGRECN: " RR-D-CODE (WS-DETAIL-NUMBER) " "
                       RR-D-KEY (WS-DETAIL-NUMBER) " "
                       FUNCTION TRIM (WS-MESSAGE-TEXT TRAILING)
               DISPLAY "LEDGRECN:      EXPECTED " WS-EXPECTED-EDITED
                       "  ACTUAL " WS-ACTUAL-EDITED
           END-PERFORM.
