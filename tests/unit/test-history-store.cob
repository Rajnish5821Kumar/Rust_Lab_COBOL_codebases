      *****************************************************************
      * THISTSTR - unit tests for HISTSTOR (src/history-store.cob)
      *
      * Exercises the in-memory id store: check, add, duplicate
      * detection, reset, and behaviour at the capacity limit of
      * 50000 ids.  Filling the store also drives the hash table
      * through a great many collisions, so a probing fault would
      * show up as a lost or phantom id.
      *
      * Loading and saving the history file, and the "posted by a
      * prior batch" answer that depends on a load, are covered by
      * the regression tests, which run real batches in sequence.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. THISTSTR.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "test-harness-ws.cpy".

       01  WS-FUNCTION                     PIC X(1).
       01  WS-NO-PATH                      PIC X(256) VALUE SPACES.
       01  WS-TXN-ID                       PIC X(12).
       01  WS-GENERATED-ID.
           05  FILLER                      PIC X(4) VALUE "FILL".
           05  WS-GENERATED-NUMBER         PIC 9(8).
       01  WS-POSTED-DATE                  PIC X(8) VALUE "20260115".
       01  WS-RESULT                       PIC X(1).
       01  WS-ID-COUNT                     PIC 9(8) BINARY.
       01  WS-STATUS-CODE                  PIC X(4).
       01  WS-STATUS-DETAIL                PIC X(60).

       01  WS-FILL-NUMBER                  PIC 9(8) BINARY.
       01  WS-UNEXPECTED-RESULTS           PIC 9(8) BINARY.
       01  WS-CAPACITY                     PIC 9(8) BINARY
                                           VALUE 50000.

       PROCEDURE DIVISION.
       0000-RUN-TESTS.
           MOVE "HISTORY STORE" TO TH-SUITE-NAME
           PERFORM 1000-BASIC-CASES
           PERFORM 2000-CAPACITY-CASES
           PERFORM 3000-RESET-CASES
           PERFORM TH-FINISH
           STOP RUN.

       0900-CALL-STORE.
           CALL "HISTSTOR" USING WS-FUNCTION
                                 WS-NO-PATH
                                 WS-TXN-ID
                                 WS-POSTED-DATE
                                 WS-RESULT
                                 WS-ID-COUNT
                                 WS-STATUS-CODE
                                 WS-STATUS-DETAIL.

       0910-CHECK-RESULT.
           MOVE WS-RESULT TO TH-ACTUAL-TEXT
           PERFORM TH-CHECK-TEXT.

       0920-CHECK-COUNT.
           MOVE WS-ID-COUNT TO TH-ACTUAL-NUMBER
           PERFORM TH-CHECK-NUMBER.

      *---------------------------------------------------------------
       1000-BASIC-CASES.
           MOVE "R" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "RESET LEAVES THE STORE EMPTY" TO TH-CASE-NAME
           MOVE ZERO TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

           MOVE "TXN000000001" TO WS-TXN-ID
           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "UNSEEN ID CHECKS AS NOT POSTED" TO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT
           MOVE "A CHECK DOES NOT ADD THE ID" TO TH-CASE-NAME
           MOVE ZERO TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

           MOVE "A" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "FIRST ADD IS ACCEPTED" TO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT
           MOVE "FIRST ADD MAKES THE COUNT 1" TO TH-CASE-NAME
           MOVE 1 TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "ADDED ID CHECKS AS POSTED IN THIS BATCH"
             TO TH-CASE-NAME
           MOVE "B" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT

           MOVE "A" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "SECOND ADD OF THE SAME ID IS REFUSED"
             TO TH-CASE-NAME
           MOVE "B" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT
           MOVE "REFUSED ADD LEAVES THE COUNT AT 1" TO TH-CASE-NAME
           MOVE 1 TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

      *    Ids that differ in one character are different ids.
           MOVE "TXN000000002" TO WS-TXN-ID
           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "ID DIFFERING IN THE LAST CHARACTER IS UNSEEN"
             TO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT

           MOVE "UXN000000001" TO WS-TXN-ID
           PERFORM 0900-CALL-STORE
           MOVE "ID DIFFERING IN THE FIRST CHARACTER IS UNSEEN"
             TO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT

      *    Same characters in another order hash differently or
      *    collide; either way they must not be confused.
           MOVE "TXN000000010" TO WS-TXN-ID
           MOVE "A" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "TXN000000100" TO WS-TXN-ID
           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "REORDERED CHARACTERS ARE A DIFFERENT ID"
             TO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT.

      *---------------------------------------------------------------
       2000-CAPACITY-CASES.
           MOVE "R" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE

           MOVE ZERO TO WS-UNEXPECTED-RESULTS
           MOVE "A" TO WS-FUNCTION
           PERFORM VARYING WS-FILL-NUMBER FROM 1 BY 1
                   UNTIL WS-FILL-NUMBER > WS-CAPACITY
               MOVE WS-FILL-NUMBER TO WS-GENERATED-NUMBER
               MOVE WS-GENERATED-ID TO WS-TXN-ID
               PERFORM 0900-CALL-STORE
               IF WS-RESULT NOT = "N"
                   ADD 1 TO WS-UNEXPECTED-RESULTS
               END-IF
           END-PERFORM
           MOVE "ALL 50000 DISTINCT IDS ARE ACCEPTED" TO TH-CASE-NAME
           MOVE ZERO TO TH-EXPECTED-NUMBER
           MOVE WS-UNEXPECTED-RESULTS TO TH-ACTUAL-NUMBER
           PERFORM TH-CHECK-NUMBER
           MOVE "THE STORE THEN HOLDS 50000 IDS" TO TH-CASE-NAME
           MOVE 50000 TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

      *    Every id added must still be found: none lost to a
      *    collision.
           MOVE ZERO TO WS-UNEXPECTED-RESULTS
           MOVE "C" TO WS-FUNCTION
           PERFORM VARYING WS-FILL-NUMBER FROM 1 BY 1
                   UNTIL WS-FILL-NUMBER > WS-CAPACITY
               MOVE WS-FILL-NUMBER TO WS-GENERATED-NUMBER
               MOVE WS-GENERATED-ID TO WS-TXN-ID
               PERFORM 0900-CALL-STORE
               IF WS-RESULT NOT = "B"
                   ADD 1 TO WS-UNEXPECTED-RESULTS
               END-IF
           END-PERFORM
           MOVE "ALL 50000 IDS ARE FOUND AGAIN" TO TH-CASE-NAME
           MOVE ZERO TO TH-EXPECTED-NUMBER
           MOVE WS-UNEXPECTED-RESULTS TO TH-ACTUAL-NUMBER
           PERFORM TH-CHECK-NUMBER

           MOVE "NEWID0000001" TO WS-TXN-ID
           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "UNSEEN ID WHEN FULL CHECKS AS STORE FULL"
             TO TH-CASE-NAME
           MOVE "F" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT

           MOVE "A" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "ADD WHEN FULL IS REFUSED" TO TH-CASE-NAME
           MOVE "F" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT
           MOVE "REFUSED ADD LEAVES THE COUNT AT 50000"
             TO TH-CASE-NAME
           MOVE 50000 TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "THE REFUSED ID WAS NOT STORED" TO TH-CASE-NAME
           MOVE "F" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT

      *    A duplicate is still recognised as one when the store is
      *    full: "already posted" outranks "no room".
           MOVE 50000 TO WS-GENERATED-NUMBER
           MOVE WS-GENERATED-ID TO WS-TXN-ID
           PERFORM 0900-CALL-STORE
           MOVE "DUPLICATE IS STILL DETECTED WHEN FULL"
             TO TH-CASE-NAME
           MOVE "B" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT.

      *---------------------------------------------------------------
       3000-RESET-CASES.
           MOVE "R" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "RESET EMPTIES A FULL STORE" TO TH-CASE-NAME
           MOVE ZERO TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT

           MOVE 1 TO WS-GENERATED-NUMBER
           MOVE WS-GENERATED-ID TO WS-TXN-ID
           MOVE "C" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "AN ID FROM BEFORE THE RESET IS UNSEEN"
             TO TH-CASE-NAME
           MOVE "N" TO TH-EXPECTED-TEXT
           PERFORM 0910-CHECK-RESULT

           MOVE "A" TO WS-FUNCTION
           PERFORM 0900-CALL-STORE
           MOVE "THE STORE ACCEPTS IDS AGAIN AFTER A RESET"
             TO TH-CASE-NAME
           MOVE 1 TO TH-EXPECTED-NUMBER
           PERFORM 0920-CHECK-COUNT.

       COPY "test-harness-pd.cpy".
