      *****************************************************************
      * TEST-HARNESS-WS.CPY
      *
      * WORKING-STORAGE half of the unit-test harness.  A test
      * program copies this into WORKING-STORAGE and copies
      * TEST-HARNESS-PD.CPY at the end of its PROCEDURE DIVISION.
      *
      * To make a check, a test sets TH-CASE-NAME and either
      *   TH-EXPECTED-TEXT / TH-ACTUAL-TEXT, then
      *       PERFORM TH-CHECK-TEXT
      * or
      *   TH-EXPECTED-NUMBER / TH-ACTUAL-NUMBER, then
      *       PERFORM TH-CHECK-NUMBER
      * and finishes with PERFORM TH-FINISH, which prints the tally
      * and sets RETURN-CODE to 1 if any check failed.
      *****************************************************************
       01  TH-SUITE-NAME                   PIC X(30).
       01  TH-CASE-NAME                    PIC X(50).
       01  TH-EXPECTED-TEXT                PIC X(48).
       01  TH-ACTUAL-TEXT                  PIC X(48).
       01  TH-EXPECTED-NUMBER              PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  TH-ACTUAL-NUMBER                PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  TH-CHECKS-RUN                   PIC 9(6) VALUE ZERO.
       01  TH-CHECKS-FAILED                PIC 9(6) VALUE ZERO.
       01  TH-NUMBER-EDITED                PIC -(15)9.99.
