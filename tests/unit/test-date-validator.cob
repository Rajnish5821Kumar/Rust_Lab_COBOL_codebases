      *****************************************************************
      * TDATEVAL - unit tests for DATEVAL (src/date-validator.cob)
      *
      * Part 1 runs a table of candidate dates through DATEVAL and
      * checks the valid/invalid answer.  Part 2 checks the day
      * numbers DATEVAL returns, because the stale-date business
      * rule depends on subtracting them.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TDATEVAL.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "test-harness-ws.cpy".

      *    Each case is a date (8) followed by the expected flag (1).
       01  WS-CASE-VALUES.
      *        ordinary dates
           05  FILLER PIC X(9) VALUE "20260115Y".
           05  FILLER PIC X(9) VALUE "20260101Y".
           05  FILLER PIC X(9) VALUE "20261231Y".
      *        month lengths
           05  FILLER PIC X(9) VALUE "20260131Y".
           05  FILLER PIC X(9) VALUE "20260132N".
           05  FILLER PIC X(9) VALUE "20260430Y".
           05  FILLER PIC X(9) VALUE "20260431N".
           05  FILLER PIC X(9) VALUE "20260630Y".
           05  FILLER PIC X(9) VALUE "20260631N".
           05  FILLER PIC X(9) VALUE "20260930Y".
           05  FILLER PIC X(9) VALUE "20260931N".
           05  FILLER PIC X(9) VALUE "20261130Y".
           05  FILLER PIC X(9) VALUE "20261131N".
           05  FILLER PIC X(9) VALUE "20261232N".
      *        February and the leap-year rule
           05  FILLER PIC X(9) VALUE "20260228Y".
           05  FILLER PIC X(9) VALUE "20260229N".
           05  FILLER PIC X(9) VALUE "20260230N".
           05  FILLER PIC X(9) VALUE "20240229Y".
           05  FILLER PIC X(9) VALUE "20240230N".
           05  FILLER PIC X(9) VALUE "20250229N".
           05  FILLER PIC X(9) VALUE "20280229Y".
           05  FILLER PIC X(9) VALUE "20000229Y".
           05  FILLER PIC X(9) VALUE "19000229N".
           05  FILLER PIC X(9) VALUE "21000229N".
           05  FILLER PIC X(9) VALUE "24000229Y".
      *        out-of-range parts
           05  FILLER PIC X(9) VALUE "20260001N".
           05  FILLER PIC X(9) VALUE "20261301N".
           05  FILLER PIC X(9) VALUE "20260100N".
           05  FILLER PIC X(9) VALUE "00000000N".
           05  FILLER PIC X(9) VALUE "99999999N".
      *        supported year range
           05  FILLER PIC X(9) VALUE "16010101Y".
           05  FILLER PIC X(9) VALUE "16001231N".
           05  FILLER PIC X(9) VALUE "99991231Y".
      *        not numeric
           05  FILLER PIC X(9) VALUE "        N".
           05  FILLER PIC X(9) VALUE "2026011 N".
           05  FILLER PIC X(9) VALUE " 0260115N".
           05  FILLER PIC X(9) VALUE "2026-115N".
           05  FILLER PIC X(9) VALUE "ABCDEFGHN".
           05  FILLER PIC X(9) VALUE "2026011XN".
       01  WS-CASE-TABLE REDEFINES WS-CASE-VALUES.
           05  WS-CASE OCCURS 39 TIMES.
               10  WS-CASE-DATE            PIC X(8).
               10  WS-CASE-EXPECTED        PIC X(1).
       01  WS-CASE-COUNT                   PIC 9(4) BINARY VALUE 39.
       01  WS-CASE-NUMBER                  PIC 9(4) BINARY.

       01  WS-DATE-TEXT                    PIC X(8).
       01  WS-VALID-FLAG                   PIC X(1).
       01  WS-DAY-NUMBER                   PIC 9(8) BINARY.
       01  WS-FIRST-DAY-NUMBER             PIC 9(8) BINARY.
       01  WS-SECOND-DAY-NUMBER            PIC 9(8) BINARY.

       PROCEDURE DIVISION.
       0000-RUN-TESTS.
           MOVE "DATE VALIDATOR" TO TH-SUITE-NAME
           PERFORM 1000-CHECK-ONE-CASE
               VARYING WS-CASE-NUMBER FROM 1 BY 1
               UNTIL WS-CASE-NUMBER > WS-CASE-COUNT
           PERFORM 2000-CHECK-DAY-NUMBERS
           PERFORM TH-FINISH
           STOP RUN.

       1000-CHECK-ONE-CASE.
           MOVE WS-CASE-DATE (WS-CASE-NUMBER) TO WS-DATE-TEXT
           MOVE "?" TO WS-VALID-FLAG
           CALL "DATEVAL" USING WS-DATE-TEXT
                                WS-VALID-FLAG
                                WS-DAY-NUMBER
           MOVE SPACES TO TH-CASE-NAME
           STRING "VALIDITY OF [" WS-DATE-TEXT "]"
               DELIMITED BY SIZE INTO TH-CASE-NAME
           MOVE WS-CASE-EXPECTED (WS-CASE-NUMBER) TO TH-EXPECTED-TEXT
           MOVE WS-VALID-FLAG TO TH-ACTUAL-TEXT
           PERFORM TH-CHECK-TEXT

      *    An invalid date must come back with a zero day number so a
      *    caller cannot use a stale one by accident.
           IF WS-CASE-EXPECTED (WS-CASE-NUMBER) = "N"
               MOVE SPACES TO TH-CASE-NAME
               STRING "ZERO DAY NUMBER FOR [" WS-DATE-TEXT "]"
                   DELIMITED BY SIZE INTO TH-CASE-NAME
               MOVE ZERO TO TH-EXPECTED-NUMBER
               MOVE WS-DAY-NUMBER TO TH-ACTUAL-NUMBER
               PERFORM TH-CHECK-NUMBER
           END-IF.

       2000-CHECK-DAY-NUMBERS.
           MOVE "16010101" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE "DAY NUMBER OF 1601-01-01 IS 1" TO TH-CASE-NAME
           MOVE 1 TO TH-EXPECTED-NUMBER
           MOVE WS-DAY-NUMBER TO TH-ACTUAL-NUMBER
           PERFORM TH-CHECK-NUMBER

           MOVE "20260110" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-FIRST-DAY-NUMBER
           MOVE "20260115" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-SECOND-DAY-NUMBER
           MOVE "2026-01-10 TO 2026-01-15 IS 5 DAYS" TO TH-CASE-NAME
           MOVE 5 TO TH-EXPECTED-NUMBER
           PERFORM 2200-CHECK-DIFFERENCE

           MOVE "20251231" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-FIRST-DAY-NUMBER
           MOVE "20260101" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-SECOND-DAY-NUMBER
           MOVE "YEAR END TO NEW YEAR IS 1 DAY" TO TH-CASE-NAME
           MOVE 1 TO TH-EXPECTED-NUMBER
           PERFORM 2200-CHECK-DIFFERENCE

           MOVE "20240228" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-FIRST-DAY-NUMBER
           MOVE "20240301" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-SECOND-DAY-NUMBER
           MOVE "28 FEB TO 1 MAR IN A LEAP YEAR IS 2 DAYS"
             TO TH-CASE-NAME
           MOVE 2 TO TH-EXPECTED-NUMBER
           PERFORM 2200-CHECK-DIFFERENCE

           MOVE "20250228" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-FIRST-DAY-NUMBER
           MOVE "20250301" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-SECOND-DAY-NUMBER
           MOVE "28 FEB TO 1 MAR IN A COMMON YEAR IS 1 DAY"
             TO TH-CASE-NAME
           MOVE 1 TO TH-EXPECTED-NUMBER
           PERFORM 2200-CHECK-DIFFERENCE

           MOVE "20250115" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-FIRST-DAY-NUMBER
           MOVE "20260115" TO WS-DATE-TEXT
           PERFORM 2100-GET-DAY-NUMBER
           MOVE WS-DAY-NUMBER TO WS-SECOND-DAY-NUMBER
           MOVE "ONE COMMON YEAR IS 365 DAYS" TO TH-CASE-NAME
           MOVE 365 TO TH-EXPECTED-NUMBER
           PERFORM 2200-CHECK-DIFFERENCE.

       2100-GET-DAY-NUMBER.
           CALL "DATEVAL" USING WS-DATE-TEXT
                                WS-VALID-FLAG
                                WS-DAY-NUMBER.

       2200-CHECK-DIFFERENCE.
           COMPUTE TH-ACTUAL-NUMBER =
               WS-SECOND-DAY-NUMBER - WS-FIRST-DAY-NUMBER
           PERFORM TH-CHECK-NUMBER.

       COPY "test-harness-pd.cpy".
