      *****************************************************************
      * LEDGWRIT - journal (ledger) writer
      *
      * The only program that writes the journal file.  For each
      * posted transaction it writes the debit entry and then the
      * credit entry described by POSTING-RESULT, numbering entries
      * consecutively from 1, and adds them to the run's control
      * totals in BATCH-TOTALS.
      *
      * CALL "LEDGWRIT" USING function, path, BATCH-CONTROL,
      *                       TXN-WORK-AREA, POSTING-RESULT,
      *                       BATCH-TOTALS, status-code,
      *                       status-detail
      *
      *   function     "O" open, "W" write the entries of one
      *                posted transaction, "C" close
      *   status-code  "0000", F014 (cannot open), F015 (write or
      *                close failed) or F016 (control total too
      *                large)
      *
      * Any status other than "0000" is fatal to the batch: a journal
      * that may be missing an entry cannot be trusted.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LEDGWRIT.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT JOURNAL-FILE ASSIGN TO DYNAMIC WS-JOURNAL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  JOURNAL-FILE.
       01  JOURNAL-FILE-RECORD             PIC X(98).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".
       COPY "ledger-record.cpy".

       01  WS-JOURNAL-PATH                 PIC X(256).
       01  WS-FILE-STATUS                  PIC X(2).
       01  WS-FILE-OPEN-FLAG               PIC X(1) VALUE "N".
           88  WS-FILE-IS-OPEN             VALUE "Y".
       01  WS-NEXT-SEQUENCE                PIC 9(8) BINARY VALUE 1.
       01  WS-ENTRY-NUMBER                 PIC 9(1).

       LINKAGE SECTION.
       01  LK-FUNCTION                     PIC X(1).
           88  LK-FUNCTION-OPEN            VALUE "O".
           88  LK-FUNCTION-WRITE           VALUE "W".
           88  LK-FUNCTION-CLOSE           VALUE "C".
       01  LK-JOURNAL-PATH                 PIC X(256).
       COPY "batch-control.cpy".
       COPY "txn-work.cpy".
       COPY "posting-result.cpy".
       COPY "batch-totals.cpy".
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-STATUS-DETAIL                PIC X(60).

       PROCEDURE DIVISION USING LK-FUNCTION
                                LK-JOURNAL-PATH
                                BATCH-CONTROL
                                TXN-WORK-AREA
                                POSTING-RESULT
                                BATCH-TOTALS
                                LK-STATUS-CODE
                                LK-STATUS-DETAIL.
       0000-DISPATCH.
           MOVE EC-NONE TO LK-STATUS-CODE
           MOVE SPACES TO LK-STATUS-DETAIL
           EVALUATE TRUE
               WHEN LK-FUNCTION-OPEN
                   PERFORM 1000-OPEN-JOURNAL
               WHEN LK-FUNCTION-WRITE
                   PERFORM 2000-WRITE-ENTRY
                       VARYING WS-ENTRY-NUMBER FROM 1 BY 1
                       UNTIL WS-ENTRY-NUMBER > PR-ENTRY-COUNT
                          OR LK-STATUS-CODE NOT = EC-NONE
               WHEN LK-FUNCTION-CLOSE
                   PERFORM 3000-CLOSE-JOURNAL
           END-EVALUATE
           GOBACK.

       1000-OPEN-JOURNAL.
           MOVE LK-JOURNAL-PATH TO WS-JOURNAL-PATH
           MOVE 1 TO WS-NEXT-SEQUENCE
           OPEN OUTPUT JOURNAL-FILE
           IF WS-FILE-STATUS = "00"
               SET WS-FILE-IS-OPEN TO TRUE
           ELSE
               MOVE EC-OUTPUT-OPEN TO LK-STATUS-CODE
               STRING "JOURNAL OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.

       2000-WRITE-ENTRY.
           MOVE SPACES TO JOURNAL-AREA
           MOVE WS-NEXT-SEQUENCE   TO JR-SEQUENCE
           MOVE TW-TXN-ID          TO JR-TXN-ID
           MOVE TW-TXN-DATE        TO JR-TXN-DATE
           MOVE TW-TXN-TYPE        TO JR-TXN-TYPE
           MOVE PR-ACCOUNT (WS-ENTRY-NUMBER)       TO JR-ACCOUNT
           MOVE PR-SIDE (WS-ENTRY-NUMBER)          TO JR-SIDE
           MOVE PR-AMOUNT (WS-ENTRY-NUMBER)        TO JR-AMOUNT
           MOVE PR-BALANCE-AFTER (WS-ENTRY-NUMBER)
             TO JR-BALANCE-AFTER
           MOVE PR-CONTRA (WS-ENTRY-NUMBER)        TO JR-CONTRA
           MOVE BC-BATCH-DATE      TO JR-BATCH-DATE
           MOVE TW-RECORD-NUMBER   TO JR-SOURCE-RECORD

           MOVE JOURNAL-RECORD TO JOURNAL-FILE-RECORD
           WRITE JOURNAL-FILE-RECORD
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
               STRING "JOURNAL WRITE FILE STATUS " WS-FILE-STATUS
                      " TXN " TW-TXN-ID
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           ADD 1 TO WS-NEXT-SEQUENCE
           ADD 1 TO BT-JOURNAL-ENTRIES
           IF JR-IS-DEBIT
               ADD PR-AMOUNT (WS-ENTRY-NUMBER) TO BT-TOTAL-DEBITS
                   ON SIZE ERROR
                       PERFORM 2900-REPORT-TOTAL-OVERFLOW
               END-ADD
           ELSE
               ADD PR-AMOUNT (WS-ENTRY-NUMBER) TO BT-TOTAL-CREDITS
                   ON SIZE ERROR
                       PERFORM 2900-REPORT-TOTAL-OVERFLOW
               END-ADD
           END-IF.

       2900-REPORT-TOTAL-OVERFLOW.
           MOVE EC-TOTAL-OVERFLOW TO LK-STATUS-CODE
           STRING "JOURNAL CONTROL TOTAL OVERFLOW AT TXN " TW-TXN-ID
               DELIMITED BY SIZE INTO LK-STATUS-DETAIL.

       3000-CLOSE-JOURNAL.
           IF WS-FILE-IS-OPEN
               CLOSE JOURNAL-FILE
               MOVE "N" TO WS-FILE-OPEN-FLAG
               IF WS-FILE-STATUS NOT = "00"
                   MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
                   STRING "JOURNAL CLOSE FILE STATUS " WS-FILE-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               END-IF
           END-IF.
