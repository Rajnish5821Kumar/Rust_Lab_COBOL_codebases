      *****************************************************************
      * TERRTEXT - unit tests for ERRTEXT (src/error-messages.cob)
      *
      * Walks every status code defined in ERROR-CODES.CPY and checks
      * that ERRTEXT has a real message for it, and that no two codes
      * share a value.  This is the test that fails when someone adds
      * a code to the copybook and forgets the message.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TERRTEXT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "test-harness-ws.cpy".
       COPY "error-codes.cpy".

       01  WS-CODE-NUMBER                  PIC 9(4) BINARY.
       01  WS-OTHER-NUMBER                 PIC 9(4) BINARY.
       01  WS-STATUS-CODE                  PIC X(4).
       01  WS-MESSAGE-TEXT                 PIC X(48).
       01  WS-DUPLICATE-FLAG               PIC X(1).

       PROCEDURE DIVISION.
       0000-RUN-TESTS.
           MOVE "ERROR MESSAGES" TO TH-SUITE-NAME
           PERFORM 1000-CHECK-ONE-CODE
               VARYING WS-CODE-NUMBER FROM 1 BY 1
               UNTIL WS-CODE-NUMBER > EC-TABLE-SIZE
           PERFORM 2000-CHECK-FIXED-ANSWERS
           PERFORM TH-FINISH
           STOP RUN.

       1000-CHECK-ONE-CODE.
           MOVE EC-TABLE-ENTRY (WS-CODE-NUMBER) TO WS-STATUS-CODE
           MOVE SPACES TO WS-MESSAGE-TEXT
           CALL "ERRTEXT" USING WS-STATUS-CODE WS-MESSAGE-TEXT

           MOVE SPACES TO TH-CASE-NAME
           STRING "CODE " WS-STATUS-CODE " HAS A MESSAGE"
               DELIMITED BY SIZE INTO TH-CASE-NAME
           MOVE "Y" TO TH-EXPECTED-TEXT
           IF WS-MESSAGE-TEXT = SPACES
                   OR WS-MESSAGE-TEXT = "UNKNOWN STATUS CODE"
               MOVE "N" TO TH-ACTUAL-TEXT
           ELSE
               MOVE "Y" TO TH-ACTUAL-TEXT
           END-IF
           PERFORM TH-CHECK-TEXT

           MOVE "N" TO WS-DUPLICATE-FLAG
           PERFORM VARYING WS-OTHER-NUMBER FROM 1 BY 1
                   UNTIL WS-OTHER-NUMBER > EC-TABLE-SIZE
               IF WS-OTHER-NUMBER NOT = WS-CODE-NUMBER
                       AND EC-TABLE-ENTRY (WS-OTHER-NUMBER)
                               = WS-STATUS-CODE
                   MOVE "Y" TO WS-DUPLICATE-FLAG
               END-IF
           END-PERFORM
           MOVE SPACES TO TH-CASE-NAME
           STRING "CODE " WS-STATUS-CODE " IS DEFINED ONLY ONCE"
               DELIMITED BY SIZE INTO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           MOVE WS-DUPLICATE-FLAG TO TH-ACTUAL-TEXT
           PERFORM TH-CHECK-TEXT.

       2000-CHECK-FIXED-ANSWERS.
           MOVE "0000" TO WS-STATUS-CODE
           CALL "ERRTEXT" USING WS-STATUS-CODE WS-MESSAGE-TEXT
           MOVE "CODE 0000 MEANS ACCEPTED" TO TH-CASE-NAME
           MOVE "ACCEPTED" TO TH-EXPECTED-TEXT
           MOVE WS-MESSAGE-TEXT TO TH-ACTUAL-TEXT
           PERFORM TH-CHECK-TEXT

           MOVE "B012" TO WS-STATUS-CODE
           CALL "ERRTEXT" USING WS-STATUS-CODE WS-MESSAGE-TEXT
           MOVE "CODE B012 TEXT" TO TH-CASE-NAME
           MOVE "INSUFFICIENT AVAILABLE FUNDS" TO TH-EXPECTED-TEXT
           MOVE WS-MESSAGE-TEXT TO TH-ACTUAL-TEXT
           PERFORM TH-CHECK-TEXT

           MOVE "V999" TO WS-STATUS-CODE
           PERFORM 2100-CHECK-UNKNOWN
           MOVE "B999" TO WS-STATUS-CODE
           PERFORM 2100-CHECK-UNKNOWN
           MOVE "F999" TO WS-STATUS-CODE
           PERFORM 2100-CHECK-UNKNOWN
           MOVE "R999" TO WS-STATUS-CODE
           PERFORM 2100-CHECK-UNKNOWN
           MOVE "ZZZZ" TO WS-STATUS-CODE
           PERFORM 2100-CHECK-UNKNOWN
           MOVE SPACES TO WS-STATUS-CODE
           PERFORM 2100-CHECK-UNKNOWN.

       2100-CHECK-UNKNOWN.
           CALL "ERRTEXT" USING WS-STATUS-CODE WS-MESSAGE-TEXT
           MOVE SPACES TO TH-CASE-NAME
           STRING "CODE [" WS-STATUS-CODE "] IS REPORTED AS UNKNOWN"
               DELIMITED BY SIZE INTO TH-CASE-NAME
           MOVE "UNKNOWN STATUS CODE" TO TH-EXPECTED-TEXT
           MOVE WS-MESSAGE-TEXT TO TH-ACTUAL-TEXT
           PERFORM TH-CHECK-TEXT.

       COPY "test-harness-pd.cpy".
