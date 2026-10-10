      *****************************************************************
      * DATEVAL - calendar date validation
      *
      * Checks that an 8-character field holds a real Gregorian
      * calendar date in the form YYYYMMDD and, if it does, returns
      * its day number (days since 31 December 1600, the base used
      * by FUNCTION INTEGER-OF-DATE) so callers can compare dates and
      * measure the distance between them.
      *
      * CALL "DATEVAL" USING date-text, valid-flag, day-number
      *
      *   date-text    PIC X(8)         in   candidate date
      *   valid-flag   PIC X(1)         out  "Y" valid, "N" not
      *   day-number   PIC 9(8) BINARY  out  zero when not valid
      *
      * Years before 1601 are refused because INTEGER-OF-DATE is not
      * defined for them.  The program keeps no state between calls.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. DATEVAL.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-DATE-PARTS.
           05  WS-YEAR                     PIC 9(4).
           05  WS-MONTH                    PIC 9(2).
           05  WS-DAY                      PIC 9(2).
       01  WS-DATE-NUMERIC REDEFINES WS-DATE-PARTS
                                           PIC 9(8).

       01  WS-MONTH-LENGTH-VALUES          PIC X(24)
               VALUE "312831303130313130313031".
       01  WS-MONTH-LENGTH-TABLE REDEFINES WS-MONTH-LENGTH-VALUES.
           05  WS-MONTH-LENGTH             PIC 9(2) OCCURS 12 TIMES.

       01  WS-LAST-DAY-OF-MONTH            PIC 9(2).
       01  WS-LEAP-YEAR-FLAG               PIC X(1).
           88  WS-IS-LEAP-YEAR             VALUE "Y".

       LINKAGE SECTION.
       01  LK-DATE-TEXT                    PIC X(8).
       01  LK-VALID-FLAG                   PIC X(1).
           88  LK-DATE-IS-VALID            VALUE "Y".
           88  LK-DATE-IS-INVALID          VALUE "N".
       01  LK-DAY-NUMBER                   PIC 9(8) BINARY.

       PROCEDURE DIVISION USING LK-DATE-TEXT
                                LK-VALID-FLAG
                                LK-DAY-NUMBER.
       0000-VALIDATE-DATE.
           SET LK-DATE-IS-INVALID TO TRUE
           MOVE ZERO TO LK-DAY-NUMBER

           IF LK-DATE-TEXT IS NOT NUMERIC
               GOBACK
           END-IF

           MOVE LK-DATE-TEXT TO WS-DATE-PARTS

           IF WS-YEAR < 1601
               GOBACK
           END-IF
           IF WS-MONTH < 1 OR WS-MONTH > 12
               GOBACK
           END-IF

           PERFORM 1000-FIND-LAST-DAY-OF-MONTH

           IF WS-DAY < 1 OR WS-DAY > WS-LAST-DAY-OF-MONTH
               GOBACK
           END-IF

           SET LK-DATE-IS-VALID TO TRUE
           COMPUTE LK-DAY-NUMBER =
               FUNCTION INTEGER-OF-DATE (WS-DATE-NUMERIC)
           GOBACK.

      *    A year is a leap year when it divides by 4, unless it is
      *    a century year that does not divide by 400.
       1000-FIND-LAST-DAY-OF-MONTH.
           MOVE "N" TO WS-LEAP-YEAR-FLAG
           IF FUNCTION MOD (WS-YEAR, 4) = 0
               IF FUNCTION MOD (WS-YEAR, 100) NOT = 0
                   SET WS-IS-LEAP-YEAR TO TRUE
               ELSE
                   IF FUNCTION MOD (WS-YEAR, 400) = 0
                       SET WS-IS-LEAP-YEAR TO TRUE
                   END-IF
               END-IF
           END-IF

           MOVE WS-MONTH-LENGTH (WS-MONTH) TO WS-LAST-DAY-OF-MONTH
           IF WS-MONTH = 2 AND WS-IS-LEAP-YEAR
               MOVE 29 TO WS-LAST-DAY-OF-MONTH
           END-IF.
