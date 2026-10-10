      *****************************************************************
      * ACCTSTOR - account master load and save
      *
      * The only program that reads or writes an account master file.
      *
      * Function "L" loads a master file into an account table and
      * proves it is trustworthy before anything is posted against
      * it.  The load fails (nothing may be posted) when:
      *   - the file cannot be opened or read               F004
      *   - a record is not a well-formed detail/trailer     F005
      *   - account ids are not strictly ascending           F006
      *   - there is no trailer record                       F007
      *   - the detail count or balance total differs from
      *     the trailer control totals                       F008
      *   - there are more accounts than the table holds     F009
      *
      * Function "S" writes an account table as a master file in the
      * same layout, with a freshly computed trailer, and stores the
      * new total in the table's TOTAL-BALANCE field.
      *
      * CALL "ACCTSTOR" USING function, path, account-table,
      *                       status-code, status-detail
      *
      *   function       PIC X(1)    in   "L" load, "S" save
      *   path           PIC X(256)  in   master file name
      *   status-code    PIC X(4)    out  "0000" or an F code
      *   status-detail  PIC X(60)   out  record number and cause
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCTSTOR.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           CLASS PRINTABLE-CHARACTER IS " " THRU "~".
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT MASTER-FILE ASSIGN TO DYNAMIC WS-MASTER-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  MASTER-FILE.
       01  MASTER-FILE-RECORD              PIC X(100).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".
       COPY "account-record.cpy".

       01  WS-MASTER-PATH                  PIC X(256).
       01  WS-FILE-STATUS                  PIC X(2).
       01  WS-END-OF-FILE-FLAG             PIC X(1).
           88  WS-END-OF-FILE              VALUE "Y".
       01  WS-TRAILER-SEEN-FLAG            PIC X(1).
           88  WS-TRAILER-SEEN             VALUE "Y".
       01  WS-RECORD-NUMBER                PIC 9(7).
       01  WS-PREVIOUS-ACCT-ID             PIC X(10).
       01  WS-RUNNING-TOTAL                PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  WS-ENTRY-NUMBER                 PIC 9(8) BINARY.
       01  WS-CAUSE                        PIC X(36).

       LINKAGE SECTION.
       01  LK-FUNCTION                     PIC X(1).
           88  LK-FUNCTION-LOAD            VALUE "L".
           88  LK-FUNCTION-SAVE            VALUE "S".
       01  LK-MASTER-PATH                  PIC X(256).
       COPY "account-table.cpy" REPLACING ==:AT:== BY ==AT==.
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-STATUS-DETAIL                PIC X(60).

       PROCEDURE DIVISION USING LK-FUNCTION
                                LK-MASTER-PATH
                                AT-ACCOUNT-TABLE
                                LK-STATUS-CODE
                                LK-STATUS-DETAIL.
       0000-DISPATCH.
           MOVE EC-NONE TO LK-STATUS-CODE
           MOVE SPACES TO LK-STATUS-DETAIL
           MOVE LK-MASTER-PATH TO WS-MASTER-PATH
           EVALUATE TRUE
               WHEN LK-FUNCTION-LOAD
                   PERFORM 1000-LOAD-MASTER
               WHEN LK-FUNCTION-SAVE
                   PERFORM 5000-SAVE-MASTER
           END-EVALUATE
           GOBACK.

      *---------------------------------------------------------------
      * LOAD
      *---------------------------------------------------------------
       1000-LOAD-MASTER.
           MOVE ZERO TO AT-ACCOUNT-COUNT
           MOVE ZERO TO AT-TOTAL-BALANCE
           MOVE ZERO TO AT-CLEARING-POSITION
           MOVE ZERO TO WS-RUNNING-TOTAL
           MOVE ZERO TO WS-RECORD-NUMBER
           MOVE LOW-VALUES TO WS-PREVIOUS-ACCT-ID
           MOVE "N" TO WS-END-OF-FILE-FLAG
           MOVE "N" TO WS-TRAILER-SEEN-FLAG

           OPEN INPUT MASTER-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-MASTER-OPEN TO LK-STATUS-CODE
               STRING "OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           PERFORM 1100-READ-MASTER-RECORD
           PERFORM UNTIL WS-END-OF-FILE
                      OR LK-STATUS-CODE NOT = EC-NONE
               PERFORM 2000-CHECK-MASTER-RECORD
               IF LK-STATUS-CODE = EC-NONE
                   PERFORM 1100-READ-MASTER-RECORD
               END-IF
           END-PERFORM

           CLOSE MASTER-FILE

           IF LK-STATUS-CODE = EC-NONE AND NOT WS-TRAILER-SEEN
               MOVE EC-MASTER-NO-TRAILER TO LK-STATUS-CODE
               STRING "RECORDS READ " WS-RECORD-NUMBER
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF
           IF LK-STATUS-CODE = EC-NONE
               MOVE WS-RUNNING-TOTAL TO AT-TOTAL-BALANCE
           END-IF.

       1100-READ-MASTER-RECORD.
           MOVE SPACES TO MASTER-FILE-RECORD
           READ MASTER-FILE
           EVALUATE TRUE
               WHEN WS-FILE-STATUS = "10"
                   SET WS-END-OF-FILE TO TRUE
               WHEN WS-FILE-STATUS (1:1) = "0"
                   ADD 1 TO WS-RECORD-NUMBER
                   MOVE MASTER-FILE-RECORD TO ACCT-MASTER-AREA
               WHEN OTHER
                   MOVE EC-MASTER-OPEN TO LK-STATUS-CODE
                   STRING "READ FILE STATUS " WS-FILE-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
                   SET WS-END-OF-FILE TO TRUE
           END-EVALUATE.

       2000-CHECK-MASTER-RECORD.
           EVALUATE TRUE
               WHEN WS-TRAILER-SEEN
                   MOVE "RECORD FOUND AFTER THE TRAILER" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-OVERFLOW-AREA NOT = SPACES
                   MOVE "RECORD LONGER THAN 80 BYTES" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-IS-DETAIL
                   PERFORM 2100-CHECK-DETAIL-RECORD
               WHEN AM-IS-TRAILER
                   PERFORM 2200-CHECK-TRAILER-RECORD
               WHEN OTHER
                   MOVE "RECORD TYPE NOT A OR T" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
           END-EVALUATE.

       2100-CHECK-DETAIL-RECORD.
           EVALUATE TRUE
               WHEN AM-ACCT-ID IS NOT NUMERIC
                   MOVE "ACCOUNT ID NOT 10 DIGITS" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-ACCT-ID = "0000000000"
                   MOVE "ACCOUNT ID IS RESERVED" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-ACCT-NAME IS NOT PRINTABLE-CHARACTER
                   MOVE "ACCOUNT NAME NOT PRINTABLE" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-ACCT-STATUS NOT = "A" AND NOT = "F"
                                             AND NOT = "C"
                   MOVE "ACCOUNT STATUS NOT A, F OR C" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-BALANCE IS NOT NUMERIC
                   MOVE "BALANCE NOT SIGN PLUS 15 DIGITS" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-DETAIL-FILLER NOT = SPACES
                   MOVE "DATA AFTER THE BALANCE FIELD" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-ACCT-ID NOT > WS-PREVIOUS-ACCT-ID
                   MOVE EC-MASTER-SEQUENCE TO LK-STATUS-CODE
                   STRING "RECORD " WS-RECORD-NUMBER
                          " ACCOUNT " AM-ACCT-ID
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               WHEN AT-ACCOUNT-COUNT NOT < AT-MAX-ACCOUNTS
                   MOVE EC-MASTER-CAPACITY TO LK-STATUS-CODE
                   STRING "RECORD " WS-RECORD-NUMBER
                          " EXCEEDS TABLE CAPACITY"
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               WHEN OTHER
                   PERFORM 2110-ADD-ACCOUNT-TO-TABLE
           END-EVALUATE.

       2110-ADD-ACCOUNT-TO-TABLE.
           ADD 1 TO AT-ACCOUNT-COUNT
           MOVE AT-ACCOUNT-COUNT TO WS-ENTRY-NUMBER
           MOVE AM-ACCT-ID     TO AT-ACCT-ID (WS-ENTRY-NUMBER)
           MOVE AM-ACCT-NAME   TO AT-ACCT-NAME (WS-ENTRY-NUMBER)
           MOVE AM-ACCT-STATUS TO AT-ACCT-STATUS (WS-ENTRY-NUMBER)
           MOVE AM-BALANCE     TO AT-BALANCE (WS-ENTRY-NUMBER)
           MOVE ZERO           TO AT-DEBIT-TODAY (WS-ENTRY-NUMBER)
           MOVE AM-ACCT-ID     TO WS-PREVIOUS-ACCT-ID
           ADD AM-BALANCE TO WS-RUNNING-TOTAL
               ON SIZE ERROR
                   MOVE EC-TOTAL-OVERFLOW TO LK-STATUS-CODE
                   STRING "RECORD " WS-RECORD-NUMBER
                          " BALANCE TOTAL OVERFLOW"
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-ADD.

       2200-CHECK-TRAILER-RECORD.
           SET WS-TRAILER-SEEN TO TRUE
           EVALUATE TRUE
               WHEN AM-TRAILER-COUNT IS NOT NUMERIC
                   MOVE "TRAILER COUNT NOT 7 DIGITS" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-TRAILER-TOTAL IS NOT NUMERIC
                   MOVE "TRAILER TOTAL NOT SIGN + 17 DIGITS"
                     TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-TRAILER-FILLER NOT = SPACES
                   MOVE "DATA AFTER THE TRAILER TOTAL" TO WS-CAUSE
                   PERFORM 2900-REPORT-BAD-RECORD
               WHEN AM-TRAILER-COUNT NOT = AT-ACCOUNT-COUNT
                   MOVE EC-MASTER-CONTROL-TOTAL TO LK-STATUS-CODE
                   MOVE "TRAILER COUNT DIFFERS FROM RECORDS READ"
                     TO LK-STATUS-DETAIL
               WHEN AM-TRAILER-TOTAL NOT = WS-RUNNING-TOTAL
                   MOVE EC-MASTER-CONTROL-TOTAL TO LK-STATUS-CODE
                   MOVE "TRAILER TOTAL DIFFERS FROM SUM OF BALANCES"
                     TO LK-STATUS-DETAIL
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       2900-REPORT-BAD-RECORD.
           MOVE EC-MASTER-RECORD TO LK-STATUS-CODE
           STRING "RECORD " WS-RECORD-NUMBER " " WS-CAUSE
               DELIMITED BY SIZE INTO LK-STATUS-DETAIL.

      *---------------------------------------------------------------
      * SAVE
      *---------------------------------------------------------------
       5000-SAVE-MASTER.
           MOVE ZERO TO WS-RUNNING-TOTAL
           MOVE ZERO TO WS-RECORD-NUMBER

           OPEN OUTPUT MASTER-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-OUTPUT-OPEN TO LK-STATUS-CODE
               STRING "ACCOUNT MASTER OPEN FILE STATUS "
                      WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           PERFORM 5100-WRITE-DETAIL-RECORD
               VARYING WS-ENTRY-NUMBER FROM 1 BY 1
               UNTIL WS-ENTRY-NUMBER > AT-ACCOUNT-COUNT
                  OR LK-STATUS-CODE NOT = EC-NONE

           IF LK-STATUS-CODE = EC-NONE
               PERFORM 5200-WRITE-TRAILER-RECORD
           END-IF

           CLOSE MASTER-FILE
           IF LK-STATUS-CODE = EC-NONE
               IF WS-FILE-STATUS = "00"
                   MOVE WS-RUNNING-TOTAL TO AT-TOTAL-BALANCE
               ELSE
                   MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
                   STRING "ACCOUNT MASTER CLOSE FILE STATUS "
                          WS-FILE-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               END-IF
           END-IF.

       5100-WRITE-DETAIL-RECORD.
           MOVE SPACES TO ACCT-MASTER-AREA
           SET AM-IS-DETAIL TO TRUE
           MOVE AT-ACCT-ID (WS-ENTRY-NUMBER)     TO AM-ACCT-ID
           MOVE AT-ACCT-NAME (WS-ENTRY-NUMBER)   TO AM-ACCT-NAME
           MOVE AT-ACCT-STATUS (WS-ENTRY-NUMBER) TO AM-ACCT-STATUS
           MOVE AT-BALANCE (WS-ENTRY-NUMBER)     TO AM-BALANCE
           ADD AT-BALANCE (WS-ENTRY-NUMBER) TO WS-RUNNING-TOTAL
               ON SIZE ERROR
                   MOVE EC-TOTAL-OVERFLOW TO LK-STATUS-CODE
                   MOVE "CLOSING BALANCE TOTAL OVERFLOW"
                     TO LK-STATUS-DETAIL
           END-ADD
           IF LK-STATUS-CODE = EC-NONE
               PERFORM 5900-WRITE-MASTER-RECORD
           END-IF.

       5200-WRITE-TRAILER-RECORD.
           MOVE SPACES TO ACCT-MASTER-AREA
           SET AM-IS-TRAILER TO TRUE
           MOVE AT-ACCOUNT-COUNT TO AM-TRAILER-COUNT
           MOVE WS-RUNNING-TOTAL TO AM-TRAILER-TOTAL
           PERFORM 5900-WRITE-MASTER-RECORD.

       5900-WRITE-MASTER-RECORD.
           ADD 1 TO WS-RECORD-NUMBER
           MOVE ACCT-MASTER-AREA TO MASTER-FILE-RECORD
           WRITE MASTER-FILE-RECORD
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
               STRING "ACCOUNT MASTER RECORD " WS-RECORD-NUMBER
                      " WRITE FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.
