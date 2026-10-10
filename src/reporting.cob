      *****************************************************************
      * REPORTS - posted, rejected and summary reports
      *
      * The only program that writes the three report files:
      *
      *   posted report   one line per posted transaction
      *   reject report   one line per rejected transaction, with
      *                   the status code and its message
      *   summary report  control totals, rules in force, rejects
      *                   by reason, and the reconciliation outcome
      *
      * Reports contain no clock time or run-specific noise: the
      * same inputs always produce byte-identical reports.
      *
      * CALL "REPORTS" USING function, BATCH-FILE-NAMES,
      *                      BATCH-CONTROL, TXN-WORK-AREA,
      *                      POSTING-RESULT, BATCH-TOTALS,
      *                      RECON-RESULT, status-code,
      *                      status-detail
      *
      *   function  "O"  open the three files and write headings
      *             "P"  write a posted-report line
      *             "J"  write a reject-report line
      *             "S"  write the report footers and the summary
      *             "X"  the run was abandoned: write footers and a
      *                  summary that says so.  status-code and
      *                  status-detail are INPUT for this function
      *                  and carry the fatal condition to print
      *             "C"  close the three files
      *   status-code    "0000", F014 (open) or F015 (write/close)
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. REPORTS.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT POSTED-FILE ASSIGN TO DYNAMIC WS-POSTED-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-POSTED-STATUS.
           SELECT REJECT-FILE ASSIGN TO DYNAMIC WS-REJECT-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-REJECT-STATUS.
           SELECT SUMMARY-FILE ASSIGN TO DYNAMIC WS-SUMMARY-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-SUMMARY-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  POSTED-FILE.
       01  POSTED-FILE-RECORD              PIC X(132).
       FD  REJECT-FILE.
       01  REJECT-FILE-RECORD              PIC X(132).
       FD  SUMMARY-FILE.
       01  SUMMARY-FILE-RECORD             PIC X(132).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".

       01  WS-POSTED-PATH                  PIC X(256).
       01  WS-REJECT-PATH                  PIC X(256).
       01  WS-SUMMARY-PATH                 PIC X(256).
       01  WS-POSTED-STATUS                PIC X(2).
       01  WS-REJECT-STATUS                PIC X(2).
       01  WS-SUMMARY-STATUS               PIC X(2).
       01  WS-FILES-OPEN-FLAG              PIC X(1) VALUE "N".
           88  WS-FILES-ARE-OPEN           VALUE "Y".

       01  WS-PRINT-LINE                   PIC X(132).
       01  WS-DATE-TEXT                    PIC X(8).
       01  WS-DATE-EDITED                  PIC X(10).
       01  WS-MESSAGE-TEXT                 PIC X(48).
       01  WS-FATAL-CODE                   PIC X(4).
       01  WS-FATAL-DETAIL                 PIC X(60).

      *    ---- posted report line -----------------------------------
       01  WS-POSTED-LINE.
           05  PL-RECORD-NUMBER            PIC Z(7)9.
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-TXN-ID                   PIC X(12).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-TXN-DATE                 PIC X(10).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-TXN-TYPE                 PIC X(1).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-ACCOUNT                  PIC X(10).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-CONTRA                   PIC X(10).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-AMOUNT                   PIC ZZ,ZZZ,ZZZ,ZZ9.99.
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-ACCOUNT-BALANCE          PIC Z,ZZZ,ZZZ,ZZZ,ZZ9.99-.
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  PL-CONTRA-BALANCE           PIC Z,ZZZ,ZZZ,ZZZ,ZZ9.99-.
           05  PL-CONTRA-BALANCE-TEXT REDEFINES PL-CONTRA-BALANCE
                                           PIC X(21).

      *    Column headings: one filler per column of the line above.
       01  WS-POSTED-HEADING-1.
           05  FILLER PIC X(8)  VALUE "  REC NO".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(12) VALUE "TXN ID".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE "DATE".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(1)  VALUE "T".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE "ACCOUNT".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE "CONTRA".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(17) VALUE "           AMOUNT".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(21) VALUE "     ACCOUNT BALANCE".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(21) VALUE "      CONTRA BALANCE".

      *    ---- reject report line -----------------------------------
       01  WS-REJECT-LINE.
           05  RL-RECORD-NUMBER            PIC Z(7)9.
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-TXN-ID                   PIC X(12).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-TXN-DATE                 PIC X(8).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-TXN-TYPE                 PIC X(1).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-ACCOUNT                  PIC X(10).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-CONTRA                   PIC X(10).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-AMOUNT                   PIC X(13).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-CODE                     PIC X(4).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  RL-MESSAGE                  PIC X(48).

       01  WS-REJECT-HEADING-1.
           05  FILLER PIC X(8)  VALUE "  REC NO".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(12) VALUE "TXN ID".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(8)  VALUE "DATE".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(1)  VALUE "T".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE "ACCOUNT".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(10) VALUE "CONTRA".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(13) VALUE "AMOUNT".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(4)  VALUE "CODE".
           05  FILLER PIC X(2)  VALUE SPACES.
           05  FILLER PIC X(48) VALUE "REASON".

      *    ---- summary report line ----------------------------------
       01  WS-SUMMARY-LINE.
           05  SL-LABEL                    PIC X(44).
           05  SL-VALUE                    PIC X(40).

       01  WS-LABEL                        PIC X(44).
       01  WS-COUNT-VALUE                  PIC 9(8) BINARY.
       01  WS-COUNT-EDITED                 PIC ZZ,ZZZ,ZZ9.
       01  WS-AMOUNT-VALUE                 PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  WS-AMOUNT-EDITED                PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99-.
       01  WS-RETURN-CODE-EDITED           PIC 9(4).

      *    One reconciliation discrepancy, as printed.
       01  WS-DISCREPANCY-LINE.
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  DL-CODE                     PIC X(4).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  DL-KEY                      PIC X(12).
           05  FILLER                      PIC X(11)
                                           VALUE "  EXPECTED ".
           05  DL-EXPECTED                 PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99-.
           05  FILLER                      PIC X(9) VALUE "  ACTUAL ".
           05  DL-ACTUAL                   PIC ZZZ,ZZZ,ZZZ,ZZZ,ZZ9.99-.

      *    ---- rejects by reason ------------------------------------
      *    Kept in ascending code order so the summary reads the same
      *    whatever order the rejects arrived in.
       01  WS-REASON-COUNT                 PIC 9(4) BINARY VALUE 0.
       01  WS-REASON-TABLE.
           05  WS-REASON OCCURS 60 TIMES.
               10  WS-REASON-CODE          PIC X(4).
               10  WS-REASON-TALLY         PIC 9(8) BINARY.
       01  WS-REASON-NUMBER                PIC 9(4) BINARY.
       01  WS-SHIFT-NUMBER                 PIC 9(4) BINARY.
       01  WS-REASON-LINE.
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  XL-CODE                     PIC X(4).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  XL-MESSAGE                  PIC X(48).
           05  FILLER                      PIC X(2) VALUE SPACES.
           05  XL-TALLY                    PIC ZZ,ZZZ,ZZ9.

       01  WS-DETAIL-NUMBER                PIC 9(4) BINARY.

       LINKAGE SECTION.
       01  LK-FUNCTION                     PIC X(1).
           88  LK-FUNCTION-OPEN            VALUE "O".
           88  LK-FUNCTION-POSTED          VALUE "P".
           88  LK-FUNCTION-REJECT          VALUE "J".
           88  LK-FUNCTION-SUMMARY         VALUE "S".
           88  LK-FUNCTION-ABANDON         VALUE "X".
           88  LK-FUNCTION-CLOSE           VALUE "C".
       COPY "batch-files.cpy".
       COPY "batch-control.cpy".
       COPY "txn-work.cpy".
       COPY "posting-result.cpy".
       COPY "batch-totals.cpy".
       COPY "recon-result.cpy".
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-STATUS-DETAIL                PIC X(60).

       PROCEDURE DIVISION USING LK-FUNCTION
                                BATCH-FILE-NAMES
                                BATCH-CONTROL
                                TXN-WORK-AREA
                                POSTING-RESULT
                                BATCH-TOTALS
                                RECON-RESULT
                                LK-STATUS-CODE
                                LK-STATUS-DETAIL.
       0000-DISPATCH.
           IF LK-FUNCTION-ABANDON
               MOVE LK-STATUS-CODE TO WS-FATAL-CODE
               MOVE LK-STATUS-DETAIL TO WS-FATAL-DETAIL
           END-IF
           MOVE EC-NONE TO LK-STATUS-CODE
           MOVE SPACES TO LK-STATUS-DETAIL

           EVALUATE TRUE
               WHEN LK-FUNCTION-OPEN
                   PERFORM 1000-OPEN-REPORTS
               WHEN LK-FUNCTION-POSTED
                   PERFORM 2000-WRITE-POSTED-LINE
               WHEN LK-FUNCTION-REJECT
                   PERFORM 3000-WRITE-REJECT-LINE
               WHEN LK-FUNCTION-SUMMARY
                   PERFORM 4000-WRITE-FOOTERS
                   PERFORM 5000-WRITE-SUMMARY
               WHEN LK-FUNCTION-ABANDON
                   PERFORM 4500-WRITE-ABANDONED-FOOTERS
                   PERFORM 6000-WRITE-ABANDONED-SUMMARY
               WHEN LK-FUNCTION-CLOSE
                   PERFORM 7000-CLOSE-REPORTS
           END-EVALUATE
           GOBACK.

      *---------------------------------------------------------------
      * OPEN
      *---------------------------------------------------------------
       1000-OPEN-REPORTS.
           MOVE BF-POSTED-PATH  TO WS-POSTED-PATH
           MOVE BF-REJECT-PATH  TO WS-REJECT-PATH
           MOVE BF-SUMMARY-PATH TO WS-SUMMARY-PATH
           MOVE ZERO TO WS-REASON-COUNT

           OPEN OUTPUT POSTED-FILE
           IF WS-POSTED-STATUS NOT = "00"
               MOVE EC-OUTPUT-OPEN TO LK-STATUS-CODE
               STRING "POSTED REPORT OPEN FILE STATUS "
                      WS-POSTED-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF
           OPEN OUTPUT REJECT-FILE
           IF WS-REJECT-STATUS NOT = "00"
               MOVE EC-OUTPUT-OPEN TO LK-STATUS-CODE
               STRING "REJECT REPORT OPEN FILE STATUS "
                      WS-REJECT-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               CLOSE POSTED-FILE
               EXIT PARAGRAPH
           END-IF
           OPEN OUTPUT SUMMARY-FILE
           IF WS-SUMMARY-STATUS NOT = "00"
               MOVE EC-OUTPUT-OPEN TO LK-STATUS-CODE
               STRING "SUMMARY REPORT OPEN FILE STATUS "
                      WS-SUMMARY-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               CLOSE POSTED-FILE
               CLOSE REJECT-FILE
               EXIT PARAGRAPH
           END-IF
           SET WS-FILES-ARE-OPEN TO TRUE

           MOVE BC-BATCH-DATE TO WS-DATE-TEXT
           PERFORM 8000-EDIT-DATE

           MOVE SPACES TO WS-PRINT-LINE
           STRING "POSTED TRANSACTIONS REPORT    BATCH " BC-BATCH-ID
                  "    BATCH DATE " WS-DATE-EDITED
               DELIMITED BY SIZE INTO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE WS-POSTED-HEADING-1 TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE ALL "-" TO WS-PRINT-LINE (1:126)
           PERFORM 9100-PRINT-POSTED

           MOVE SPACES TO WS-PRINT-LINE
           STRING "REJECTED TRANSACTIONS REPORT  BATCH " BC-BATCH-ID
                  "    BATCH DATE " WS-DATE-EDITED
               DELIMITED BY SIZE INTO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           MOVE WS-REJECT-HEADING-1 TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           MOVE ALL "-" TO WS-PRINT-LINE (1:130)
           PERFORM 9200-PRINT-REJECT.

      *---------------------------------------------------------------
      * POSTED LINE
      *---------------------------------------------------------------
      *    The account balance shown is that of the transaction's own
      *    account.  For a deposit that account is the credit entry
      *    (entry 2); for a withdrawal or transfer it is the debit
      *    entry (entry 1).  Only a transfer has a contra balance.
       2000-WRITE-POSTED-LINE.
           MOVE TW-RECORD-NUMBER TO PL-RECORD-NUMBER
           MOVE TW-TXN-ID        TO PL-TXN-ID
           MOVE TW-TXN-DATE      TO WS-DATE-TEXT
           PERFORM 8000-EDIT-DATE
           MOVE WS-DATE-EDITED   TO PL-TXN-DATE
           MOVE TW-TXN-TYPE      TO PL-TXN-TYPE
           MOVE TW-ACCOUNT       TO PL-ACCOUNT
           MOVE TW-CONTRA-ACCOUNT TO PL-CONTRA
           MOVE TW-AMOUNT        TO PL-AMOUNT
           MOVE SPACES           TO PL-CONTRA-BALANCE-TEXT
           EVALUATE TRUE
               WHEN TW-IS-DEPOSIT
                   MOVE PR-BALANCE-AFTER (2) TO PL-ACCOUNT-BALANCE
               WHEN TW-IS-WITHDRAWAL
                   MOVE PR-BALANCE-AFTER (1) TO PL-ACCOUNT-BALANCE
               WHEN OTHER
                   MOVE PR-BALANCE-AFTER (1) TO PL-ACCOUNT-BALANCE
                   MOVE PR-BALANCE-AFTER (2) TO PL-CONTRA-BALANCE
           END-EVALUATE
           MOVE WS-POSTED-LINE TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED.

      *---------------------------------------------------------------
      * REJECT LINE
      *---------------------------------------------------------------
       3000-WRITE-REJECT-LINE.
           MOVE TW-RECORD-NUMBER  TO RL-RECORD-NUMBER
           MOVE TW-TXN-ID         TO RL-TXN-ID
           MOVE TW-TXN-DATE       TO RL-TXN-DATE
           MOVE TW-TXN-TYPE       TO RL-TXN-TYPE
           MOVE TW-ACCOUNT        TO RL-ACCOUNT
           MOVE TW-CONTRA-ACCOUNT TO RL-CONTRA
           MOVE TW-AMOUNT-TEXT    TO RL-AMOUNT
           MOVE TW-STATUS-CODE    TO RL-CODE
           CALL "ERRTEXT" USING TW-STATUS-CODE WS-MESSAGE-TEXT
           MOVE WS-MESSAGE-TEXT   TO RL-MESSAGE
           MOVE WS-REJECT-LINE TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           PERFORM 3100-TALLY-REASON.

      *    Finds the code in the reason table, or inserts it at the
      *    position that keeps the table in ascending code order.
       3100-TALLY-REASON.
           MOVE 1 TO WS-REASON-NUMBER
           PERFORM UNTIL WS-REASON-NUMBER > WS-REASON-COUNT
               IF WS-REASON-CODE (WS-REASON-NUMBER)
                       NOT < TW-STATUS-CODE
                   EXIT PERFORM
               END-IF
               ADD 1 TO WS-REASON-NUMBER
           END-PERFORM

           IF WS-REASON-NUMBER NOT > WS-REASON-COUNT
               IF WS-REASON-CODE (WS-REASON-NUMBER) = TW-STATUS-CODE
                   ADD 1 TO WS-REASON-TALLY (WS-REASON-NUMBER)
                   EXIT PARAGRAPH
               END-IF
           END-IF

           IF WS-REASON-COUNT < 60
               PERFORM VARYING WS-SHIFT-NUMBER
                       FROM WS-REASON-COUNT BY -1
                       UNTIL WS-SHIFT-NUMBER < WS-REASON-NUMBER
                   MOVE WS-REASON (WS-SHIFT-NUMBER)
                     TO WS-REASON (WS-SHIFT-NUMBER + 1)
               END-PERFORM
               ADD 1 TO WS-REASON-COUNT
               MOVE TW-STATUS-CODE
                 TO WS-REASON-CODE (WS-REASON-NUMBER)
               MOVE 1 TO WS-REASON-TALLY (WS-REASON-NUMBER)
           END-IF.

      *---------------------------------------------------------------
      * FOOTERS
      *---------------------------------------------------------------
       4000-WRITE-FOOTERS.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE BT-POSTED-COUNT TO WS-COUNT-EDITED
           MOVE SPACES TO WS-PRINT-LINE
           STRING "TRANSACTIONS POSTED: " WS-COUNT-EDITED
               DELIMITED BY SIZE INTO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE "END OF REPORT" TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED

           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           MOVE BT-REJECTED-COUNT TO WS-COUNT-EDITED
           MOVE SPACES TO WS-PRINT-LINE
           STRING "TRANSACTIONS REJECTED: " WS-COUNT-EDITED
               DELIMITED BY SIZE INTO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           MOVE "END OF REPORT" TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT.

       4500-WRITE-ABANDONED-FOOTERS.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE "RUN ABANDONED - THIS REPORT IS INCOMPLETE"
             TO WS-PRINT-LINE
           PERFORM 9100-PRINT-POSTED
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT
           MOVE "RUN ABANDONED - THIS REPORT IS INCOMPLETE"
             TO WS-PRINT-LINE
           PERFORM 9200-PRINT-REJECT.

      *---------------------------------------------------------------
      * SUMMARY
      *---------------------------------------------------------------
       5000-WRITE-SUMMARY.
           PERFORM 5100-WRITE-SUMMARY-HEADING
           PERFORM 5200-WRITE-RULES
           PERFORM 5300-WRITE-INPUT-COUNTS
           PERFORM 5400-WRITE-RESULT-COUNTS
           PERFORM 5500-WRITE-REJECT-REASONS
           PERFORM 5600-WRITE-JOURNAL-TOTALS
           PERFORM 5700-WRITE-BALANCES
           PERFORM 5800-WRITE-RECONCILIATION
           PERFORM 5900-WRITE-RETURN-CODE.

       5100-WRITE-SUMMARY-HEADING.
           MOVE "BATCH SUMMARY REPORT" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "====================" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "BATCH ID" TO SL-LABEL
           MOVE BC-BATCH-ID TO SL-VALUE
           PERFORM 9400-PRINT-SUMMARY-PAIR
           MOVE BC-BATCH-DATE TO WS-DATE-TEXT
           PERFORM 8000-EDIT-DATE
           MOVE "BATCH DATE" TO SL-LABEL
           MOVE WS-DATE-EDITED TO SL-VALUE
           PERFORM 9400-PRINT-SUMMARY-PAIR.

       5200-WRITE-RULES.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "RULES IN FORCE" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  MAXIMUM DEPOSIT" TO WS-LABEL
           MOVE BC-MAX-DEPOSIT TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  MAXIMUM WITHDRAWAL" TO WS-LABEL
           MOVE BC-MAX-WITHDRAWAL TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  MAXIMUM TRANSFER" TO WS-LABEL
           MOVE BC-MAX-TRANSFER TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  DAILY DEBIT LIMIT PER ACCOUNT" TO WS-LABEL
           MOVE BC-DAILY-DEBIT-LIMIT TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  OVERDRAFT LIMIT" TO WS-LABEL
           MOVE BC-OVERDRAFT-LIMIT TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  MAXIMUM BACKDATE DAYS" TO WS-LABEL
           MOVE BC-MAX-BACKDATE-DAYS TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT.

       5300-WRITE-INPUT-COUNTS.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "INPUT" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  ACCOUNTS ON OPENING MASTER" TO WS-LABEL
           MOVE BT-OPENING-ACCOUNTS TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  PRIOR TRANSACTION IDS LOADED" TO WS-LABEL
           MOVE BT-HISTORY-LOADED TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  TRANSACTION RECORDS READ" TO WS-LABEL
           MOVE BT-RECORDS-READ TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT.

       5400-WRITE-RESULT-COUNTS.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "RESULT" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  TRANSACTIONS POSTED" TO WS-LABEL
           MOVE BT-POSTED-COUNT TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  TRANSACTIONS REJECTED" TO WS-LABEL
           MOVE BT-REJECTED-COUNT TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  DEPOSITS POSTED" TO WS-LABEL
           MOVE BT-DEPOSIT-COUNT TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  DEPOSITS POSTED AMOUNT" TO WS-LABEL
           MOVE BT-DEPOSIT-AMOUNT TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  WITHDRAWALS POSTED" TO WS-LABEL
           MOVE BT-WITHDRAWAL-COUNT TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  WITHDRAWALS POSTED AMOUNT" TO WS-LABEL
           MOVE BT-WITHDRAWAL-AMOUNT TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  TRANSFERS POSTED" TO WS-LABEL
           MOVE BT-TRANSFER-COUNT TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  TRANSFERS POSTED AMOUNT" TO WS-LABEL
           MOVE BT-TRANSFER-AMOUNT TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT.

       5500-WRITE-REJECT-REASONS.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "REJECTIONS BY REASON" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           IF WS-REASON-COUNT = ZERO
               MOVE "  (NONE)" TO WS-PRINT-LINE
               PERFORM 9300-PRINT-SUMMARY
           END-IF
           PERFORM VARYING WS-REASON-NUMBER FROM 1 BY 1
                   UNTIL WS-REASON-NUMBER > WS-REASON-COUNT
               MOVE WS-REASON-CODE (WS-REASON-NUMBER) TO XL-CODE
               CALL "ERRTEXT" USING XL-CODE WS-MESSAGE-TEXT
               MOVE WS-MESSAGE-TEXT TO XL-MESSAGE
               MOVE WS-REASON-TALLY (WS-REASON-NUMBER) TO XL-TALLY
               MOVE WS-REASON-LINE TO WS-PRINT-LINE
               PERFORM 9300-PRINT-SUMMARY
           END-PERFORM.

       5600-WRITE-JOURNAL-TOTALS.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "JOURNAL" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  ENTRIES WRITTEN" TO WS-LABEL
           MOVE BT-JOURNAL-ENTRIES TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  TOTAL DEBITS" TO WS-LABEL
           MOVE BT-TOTAL-DEBITS TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  TOTAL CREDITS" TO WS-LABEL
           MOVE BT-TOTAL-CREDITS TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT.

       5700-WRITE-BALANCES.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "BALANCES" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  OPENING TOTAL OF CUSTOMER BALANCES" TO WS-LABEL
           MOVE BT-OPENING-TOTAL TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  NET CASH THROUGH CLEARING ACCOUNT" TO WS-LABEL
           MOVE BT-CLEARING-POSITION TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT
           MOVE "  CLOSING TOTAL OF CUSTOMER BALANCES" TO WS-LABEL
           MOVE BT-CLOSING-TOTAL TO WS-AMOUNT-VALUE
           PERFORM 9600-PRINT-AMOUNT.

       5800-WRITE-RECONCILIATION.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "RECONCILIATION" TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  STATUS" TO SL-LABEL
           EVALUATE TRUE
               WHEN RR-PASSED
                   MOVE "PASSED" TO SL-VALUE
               WHEN RR-FAILED
                   MOVE "FAILED" TO SL-VALUE
               WHEN RR-ABORTED
                   MOVE "NOT COMPLETED" TO SL-VALUE
               WHEN OTHER
                   MOVE "NOT RUN" TO SL-VALUE
           END-EVALUATE
           PERFORM 9400-PRINT-SUMMARY-PAIR

           IF RR-ABORTED
               MOVE "  CAUSE" TO SL-LABEL
               MOVE RR-FATAL-CODE TO SL-VALUE
               PERFORM 9400-PRINT-SUMMARY-PAIR
               MOVE SPACES TO WS-PRINT-LINE
               STRING "  " RR-FATAL-DETAIL
                   DELIMITED BY SIZE INTO WS-PRINT-LINE
               PERFORM 9300-PRINT-SUMMARY
           END-IF

           MOVE "  JOURNAL ENTRIES REPLAYED" TO WS-LABEL
           MOVE RR-JOURNAL-ENTRIES TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  ACCOUNTS COMPARED" TO WS-LABEL
           MOVE RR-ACCOUNTS-COMPARED TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           MOVE "  DISCREPANCIES FOUND" TO WS-LABEL
           MOVE RR-DISCREPANCY-COUNT TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT

           PERFORM VARYING WS-DETAIL-NUMBER FROM 1 BY 1
                   UNTIL WS-DETAIL-NUMBER > RR-DETAIL-COUNT
               MOVE RR-D-CODE (WS-DETAIL-NUMBER)     TO DL-CODE
               MOVE RR-D-KEY (WS-DETAIL-NUMBER)      TO DL-KEY
               MOVE RR-D-EXPECTED (WS-DETAIL-NUMBER) TO DL-EXPECTED
               MOVE RR-D-ACTUAL (WS-DETAIL-NUMBER)   TO DL-ACTUAL
               MOVE WS-DISCREPANCY-LINE TO WS-PRINT-LINE
               PERFORM 9300-PRINT-SUMMARY
               CALL "ERRTEXT" USING DL-CODE WS-MESSAGE-TEXT
               MOVE SPACES TO WS-PRINT-LINE
               STRING "        " WS-MESSAGE-TEXT
                   DELIMITED BY SIZE INTO WS-PRINT-LINE
               PERFORM 9300-PRINT-SUMMARY
           END-PERFORM.

       5900-WRITE-RETURN-CODE.
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE BT-RETURN-CODE TO WS-RETURN-CODE-EDITED
           MOVE "RETURN CODE" TO SL-LABEL
           MOVE WS-RETURN-CODE-EDITED TO SL-VALUE
           PERFORM 9400-PRINT-SUMMARY-PAIR.

      *    A run that was abandoned gets a short summary that says so
      *    plainly, so nobody mistakes partial counts for a result.
       6000-WRITE-ABANDONED-SUMMARY.
           PERFORM 5100-WRITE-SUMMARY-HEADING
           MOVE SPACES TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "RUN ABANDONED - OUTPUT FILES MUST NOT BE USED"
             TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  STATUS CODE" TO SL-LABEL
           MOVE WS-FATAL-CODE TO SL-VALUE
           PERFORM 9400-PRINT-SUMMARY-PAIR
           CALL "ERRTEXT" USING WS-FATAL-CODE WS-MESSAGE-TEXT
           MOVE SPACES TO WS-PRINT-LINE
           STRING "  " WS-MESSAGE-TEXT
               DELIMITED BY SIZE INTO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE SPACES TO WS-PRINT-LINE
           STRING "  " WS-FATAL-DETAIL
               DELIMITED BY SIZE INTO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE "  TRANSACTION RECORDS READ BEFORE FAILURE"
             TO WS-LABEL
           MOVE BT-RECORDS-READ TO WS-COUNT-VALUE
           PERFORM 9500-PRINT-COUNT
           PERFORM 5900-WRITE-RETURN-CODE.

      *---------------------------------------------------------------
      * CLOSE
      *---------------------------------------------------------------
       7000-CLOSE-REPORTS.
           IF WS-FILES-ARE-OPEN
               CLOSE POSTED-FILE
               CLOSE REJECT-FILE
               CLOSE SUMMARY-FILE
               MOVE "N" TO WS-FILES-OPEN-FLAG
               IF WS-POSTED-STATUS NOT = "00"
                       OR WS-REJECT-STATUS NOT = "00"
                       OR WS-SUMMARY-STATUS NOT = "00"
                   MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
                   MOVE "REPORT CLOSE FAILED" TO LK-STATUS-DETAIL
               END-IF
           END-IF.

      *---------------------------------------------------------------
      * Helpers
      *---------------------------------------------------------------
      *    YYYYMMDD to YYYY-MM-DD.  The field is only ever a date
      *    that has already passed validation.
       8000-EDIT-DATE.
           MOVE SPACES TO WS-DATE-EDITED
           STRING WS-DATE-TEXT (1:4) "-" WS-DATE-TEXT (5:2) "-"
                  WS-DATE-TEXT (7:2)
               DELIMITED BY SIZE INTO WS-DATE-EDITED.

       9100-PRINT-POSTED.
           IF WS-FILES-ARE-OPEN
               WRITE POSTED-FILE-RECORD FROM WS-PRINT-LINE
               IF WS-POSTED-STATUS NOT = "00"
                   MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
                   STRING "POSTED REPORT WRITE FILE STATUS "
                          WS-POSTED-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               END-IF
           END-IF.

       9200-PRINT-REJECT.
           IF WS-FILES-ARE-OPEN
               WRITE REJECT-FILE-RECORD FROM WS-PRINT-LINE
               IF WS-REJECT-STATUS NOT = "00"
                   MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
                   STRING "REJECT REPORT WRITE FILE STATUS "
                          WS-REJECT-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               END-IF
           END-IF.

       9300-PRINT-SUMMARY.
           IF WS-FILES-ARE-OPEN
               WRITE SUMMARY-FILE-RECORD FROM WS-PRINT-LINE
               IF WS-SUMMARY-STATUS NOT = "00"
                   MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
                   STRING "SUMMARY REPORT WRITE FILE STATUS "
                          WS-SUMMARY-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               END-IF
           END-IF.

       9400-PRINT-SUMMARY-PAIR.
           MOVE WS-SUMMARY-LINE TO WS-PRINT-LINE
           PERFORM 9300-PRINT-SUMMARY
           MOVE SPACES TO WS-SUMMARY-LINE.

       9500-PRINT-COUNT.
           MOVE WS-COUNT-VALUE TO WS-COUNT-EDITED
           MOVE WS-LABEL TO SL-LABEL
           MOVE SPACES TO SL-VALUE
           MOVE WS-COUNT-EDITED TO SL-VALUE (13:10)
           PERFORM 9400-PRINT-SUMMARY-PAIR.

       9600-PRINT-AMOUNT.
           MOVE WS-AMOUNT-VALUE TO WS-AMOUNT-EDITED
           MOVE WS-LABEL TO SL-LABEL
           MOVE WS-AMOUNT-EDITED TO SL-VALUE
           PERFORM 9400-PRINT-SUMMARY-PAIR.
