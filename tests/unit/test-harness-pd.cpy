      *****************************************************************
      * TEST-HARNESS-PD.CPY
      *
      * PROCEDURE DIVISION half of the unit-test harness; see
      * TEST-HARNESS-WS.CPY.  A failed check prints the case name
      * with the expected and actual values; a passed check prints
      * nothing, so the output of a healthy suite is one line.
      *****************************************************************
       TH-CHECK-TEXT.
           ADD 1 TO TH-CHECKS-RUN
           IF TH-ACTUAL-TEXT NOT = TH-EXPECTED-TEXT
               ADD 1 TO TH-CHECKS-FAILED
               DISPLAY "FAIL  " TH-CASE-NAME
               DISPLAY "      EXPECTED [" TH-EXPECTED-TEXT "]"
               DISPLAY "      ACTUAL   [" TH-ACTUAL-TEXT "]"
           END-IF.

       TH-CHECK-NUMBER.
           ADD 1 TO TH-CHECKS-RUN
           IF TH-ACTUAL-NUMBER NOT = TH-EXPECTED-NUMBER
               ADD 1 TO TH-CHECKS-FAILED
               DISPLAY "FAIL  " TH-CASE-NAME
               MOVE TH-EXPECTED-NUMBER TO TH-NUMBER-EDITED
               DISPLAY "      EXPECTED " TH-NUMBER-EDITED
               MOVE TH-ACTUAL-NUMBER TO TH-NUMBER-EDITED
               DISPLAY "      ACTUAL   " TH-NUMBER-EDITED
           END-IF.

       TH-FINISH.
           DISPLAY TH-SUITE-NAME ": " TH-CHECKS-RUN " CHECKS, "
                   TH-CHECKS-FAILED " FAILED"
           IF TH-CHECKS-FAILED > ZERO
               MOVE 1 TO RETURN-CODE
           ELSE
               MOVE ZERO TO RETURN-CODE
           END-IF.
