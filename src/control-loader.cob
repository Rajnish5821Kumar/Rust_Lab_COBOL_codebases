      *****************************************************************
      * CTLLOAD - batch control file loader
      *
      * Reads the control file and fills BATCH-CONTROL with the
      * business parameters for the run.  The file is LINE SEQUENTIAL;
      * each line is a keyword in columns 1-24 and a value starting
      * in column 25.  Blank lines and lines starting with "*" are
      * ignored.
      *
      *   Keyword                Value                       Default
      *   BATCH-DATE             YYYYMMDD                    required
      *   BATCH-ID               1-8 printable characters    BATCH
      *   MAX-DEPOSIT-AMOUNT     13 digits, 2 implied dec.   no limit
      *   MAX-WITHDRAWAL-AMOUNT  13 digits, 2 implied dec.   no limit
      *   MAX-TRANSFER-AMOUNT    13 digits, 2 implied dec.   no limit
      *   DAILY-DEBIT-LIMIT      13 digits, 2 implied dec.   no limit
      *   OVERDRAFT-LIMIT        13 digits, 2 implied dec.   zero
      *   MAX-BACKDATE-DAYS      4 digits                    0030
      *
      * "No limit" means the largest value the amount field holds.
      * The loader is strict on purpose: an unknown keyword, a
      * repeated keyword or a badly formed value is fatal, because a
      * mistyped limit that was silently ignored would let a batch
      * post with rules nobody intended.
      *
      * CALL "CTLLOAD" USING control-path, BATCH-CONTROL,
      *                      status-code, status-detail
      *
      *   status-code    PIC X(4)   out  "0000" or an F code
      *   status-detail  PIC X(60)  out  line number and keyword
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CTLLOAD.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT CONTROL-FILE ASSIGN TO DYNAMIC WS-CONTROL-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  CONTROL-FILE.
       01  CONTROL-LINE.
           05  CL-KEYWORD                  PIC X(24).
           05  CL-VALUE                    PIC X(56).
           05  CL-OVERFLOW                 PIC X(20).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".

       01  WS-CONTROL-PATH                 PIC X(256).
       01  WS-FILE-STATUS                  PIC X(2).
       01  WS-END-OF-FILE-FLAG             PIC X(1).
           88  WS-END-OF-FILE              VALUE "Y".
       01  WS-LINE-NUMBER                  PIC 9(4).

       01  WS-AMOUNT-TEXT                  PIC X(13).
       01  WS-AMOUNT-NUMERIC REDEFINES WS-AMOUNT-TEXT
                                           PIC 9(11)V99.
       01  WS-PARSED-AMOUNT                PIC S9(11)V99
                                           PACKED-DECIMAL.
       01  WS-DAYS-TEXT                    PIC X(4).
       01  WS-DAYS-NUMERIC REDEFINES WS-DAYS-TEXT
                                           PIC 9(4).
       01  WS-VALUE-VALID-FLAG             PIC X(1).
           88  WS-VALUE-IS-VALID           VALUE "Y".
           88  WS-VALUE-IS-INVALID         VALUE "N".

      *    One "seen" flag per keyword, in the order of the table in
      *    the program header, so a repeated keyword is detected.
       01  WS-KEYWORD-SEEN-FLAGS.
           05  WS-KEYWORD-SEEN             PIC X(1) OCCURS 8 TIMES.
       01  WS-KEYWORD-NUMBER               PIC 9(2).

       01  WS-DATE-TEXT                    PIC X(8).
       01  WS-DATE-VALID-FLAG              PIC X(1).
           88  WS-DATE-IS-VALID            VALUE "Y".
       01  WS-DAY-NUMBER                   PIC 9(8) BINARY.

       LINKAGE SECTION.
       01  LK-CONTROL-PATH                 PIC X(256).
       COPY "batch-control.cpy".
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-STATUS-DETAIL                PIC X(60).

       PROCEDURE DIVISION USING LK-CONTROL-PATH
                                BATCH-CONTROL
                                LK-STATUS-CODE
                                LK-STATUS-DETAIL.
       0000-LOAD-CONTROL-FILE.
           PERFORM 1000-SET-DEFAULTS

           MOVE LK-CONTROL-PATH TO WS-CONTROL-PATH
           OPEN INPUT CONTROL-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-CONTROL-OPEN TO LK-STATUS-CODE
               STRING "OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               GOBACK
           END-IF

           PERFORM 2000-READ-CONTROL-LINE
           PERFORM UNTIL WS-END-OF-FILE
                      OR LK-STATUS-CODE NOT = EC-NONE
               PERFORM 3000-APPLY-CONTROL-LINE
               IF LK-STATUS-CODE = EC-NONE
                   PERFORM 2000-READ-CONTROL-LINE
               END-IF
           END-PERFORM

           CLOSE CONTROL-FILE

           IF LK-STATUS-CODE = EC-NONE
               PERFORM 5000-CHECK-BATCH-DATE
           END-IF
           GOBACK.

       1000-SET-DEFAULTS.
           MOVE EC-NONE TO LK-STATUS-CODE
           MOVE SPACES TO LK-STATUS-DETAIL
           MOVE "N" TO WS-END-OF-FILE-FLAG
           MOVE ZERO TO WS-LINE-NUMBER
           MOVE ALL "N" TO WS-KEYWORD-SEEN-FLAGS

           MOVE "BATCH" TO BC-BATCH-ID
           MOVE ZERO TO BC-BATCH-DATE
           MOVE ZERO TO BC-BATCH-DAY-NUMBER
           MOVE 99999999999.99 TO BC-MAX-DEPOSIT
           MOVE 99999999999.99 TO BC-MAX-WITHDRAWAL
           MOVE 99999999999.99 TO BC-MAX-TRANSFER
           MOVE 99999999999.99 TO BC-DAILY-DEBIT-LIMIT
           MOVE ZERO TO BC-OVERDRAFT-LIMIT
           MOVE 30 TO BC-MAX-BACKDATE-DAYS
           MOVE "0000000000" TO BC-CLEARING-ACCOUNT.

      *    Any file status in the "successful" class (first character
      *    zero) is accepted: the line content is validated below, so
      *    a truncation or data warning from the runtime cannot let a
      *    bad value through.
       2000-READ-CONTROL-LINE.
           MOVE SPACES TO CONTROL-LINE
           READ CONTROL-FILE
           EVALUATE TRUE
               WHEN WS-FILE-STATUS = "10"
                   SET WS-END-OF-FILE TO TRUE
               WHEN WS-FILE-STATUS (1:1) = "0"
                   ADD 1 TO WS-LINE-NUMBER
               WHEN OTHER
                   MOVE EC-CONTROL-OPEN TO LK-STATUS-CODE
                   STRING "READ FILE STATUS " WS-FILE-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
                   SET WS-END-OF-FILE TO TRUE
           END-EVALUATE.

       3000-APPLY-CONTROL-LINE.
           IF CONTROL-LINE = SPACES OR CL-KEYWORD (1:1) = "*"
               EXIT PARAGRAPH
           END-IF

           SET WS-VALUE-IS-VALID TO TRUE
           IF CL-OVERFLOW NOT = SPACES
               SET WS-VALUE-IS-INVALID TO TRUE
           END-IF

           EVALUATE CL-KEYWORD
               WHEN "BATCH-DATE"
                   MOVE 1 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4100-PARSE-BATCH-DATE
               WHEN "BATCH-ID"
                   MOVE 2 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4200-PARSE-BATCH-ID
               WHEN "MAX-DEPOSIT-AMOUNT"
                   MOVE 3 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4300-PARSE-AMOUNT
                   MOVE WS-PARSED-AMOUNT TO BC-MAX-DEPOSIT
               WHEN "MAX-WITHDRAWAL-AMOUNT"
                   MOVE 4 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4300-PARSE-AMOUNT
                   MOVE WS-PARSED-AMOUNT TO BC-MAX-WITHDRAWAL
               WHEN "MAX-TRANSFER-AMOUNT"
                   MOVE 5 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4300-PARSE-AMOUNT
                   MOVE WS-PARSED-AMOUNT TO BC-MAX-TRANSFER
               WHEN "DAILY-DEBIT-LIMIT"
                   MOVE 6 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4300-PARSE-AMOUNT
                   MOVE WS-PARSED-AMOUNT TO BC-DAILY-DEBIT-LIMIT
               WHEN "OVERDRAFT-LIMIT"
                   MOVE 7 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4300-PARSE-AMOUNT
                   MOVE WS-PARSED-AMOUNT TO BC-OVERDRAFT-LIMIT
               WHEN "MAX-BACKDATE-DAYS"
                   MOVE 8 TO WS-KEYWORD-NUMBER
                   PERFORM 4000-NOTE-KEYWORD
                   PERFORM 4400-PARSE-BACKDATE-DAYS
               WHEN OTHER
                   SET WS-VALUE-IS-INVALID TO TRUE
           END-EVALUATE

           IF WS-VALUE-IS-INVALID
               MOVE EC-CONTROL-INVALID TO LK-STATUS-CODE
               STRING "LINE " WS-LINE-NUMBER " KEYWORD " CL-KEYWORD
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.

       4000-NOTE-KEYWORD.
           IF WS-KEYWORD-SEEN (WS-KEYWORD-NUMBER) = "Y"
               SET WS-VALUE-IS-INVALID TO TRUE
           END-IF
           MOVE "Y" TO WS-KEYWORD-SEEN (WS-KEYWORD-NUMBER).

      *    Only the shape is checked here.  Whether the digits form a
      *    real calendar date is checked once the file has been read,
      *    so that a bad date is reported with its own code (F003).
       4100-PARSE-BATCH-DATE.
           IF CL-VALUE (1:8) IS NUMERIC AND CL-VALUE (9:48) = SPACES
               MOVE CL-VALUE (1:8) TO BC-BATCH-DATE
           ELSE
               SET WS-VALUE-IS-INVALID TO TRUE
           END-IF.

       4200-PARSE-BATCH-ID.
           IF CL-VALUE (1:8) NOT = SPACES
                   AND CL-VALUE (9:48) = SPACES
               MOVE CL-VALUE (1:8) TO BC-BATCH-ID
           ELSE
               SET WS-VALUE-IS-INVALID TO TRUE
           END-IF.

       4300-PARSE-AMOUNT.
           MOVE ZERO TO WS-PARSED-AMOUNT
           IF CL-VALUE (1:13) IS NUMERIC AND CL-VALUE (14:43) = SPACES
               MOVE CL-VALUE (1:13) TO WS-AMOUNT-TEXT
               MOVE WS-AMOUNT-NUMERIC TO WS-PARSED-AMOUNT
           ELSE
               SET WS-VALUE-IS-INVALID TO TRUE
           END-IF.

       4400-PARSE-BACKDATE-DAYS.
           IF CL-VALUE (1:4) IS NUMERIC AND CL-VALUE (5:52) = SPACES
               MOVE CL-VALUE (1:4) TO WS-DAYS-TEXT
               MOVE WS-DAYS-NUMERIC TO BC-MAX-BACKDATE-DAYS
           ELSE
               SET WS-VALUE-IS-INVALID TO TRUE
           END-IF.

       5000-CHECK-BATCH-DATE.
           MOVE BC-BATCH-DATE TO WS-DATE-TEXT
           CALL "DATEVAL" USING WS-DATE-TEXT
                                WS-DATE-VALID-FLAG
                                WS-DAY-NUMBER
           IF WS-DATE-IS-VALID
               MOVE WS-DAY-NUMBER TO BC-BATCH-DAY-NUMBER
           ELSE
               MOVE EC-BATCH-DATE TO LK-STATUS-CODE
               STRING "BATCH-DATE VALUE " WS-DATE-TEXT
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.
