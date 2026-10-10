      *****************************************************************
      * HISTSTOR - posted-transaction-id store (duplicate detection)
      *
      * Owns the set of transaction ids that have been posted: those
      * loaded from the history file (posted by earlier batches) and
      * those posted so far by the current batch.  It is the only
      * program that reads or writes the history file.
      *
      * The ids are kept in arrival order in WS-ID-ENTRY and found
      * through an open-addressing hash table (WS-SLOT) that holds
      * entry numbers, so a lookup costs a handful of comparisons
      * however large the batch is.  The store is state held in
      * WORKING-STORAGE: it lives for the life of the run unit.
      *
      * CALL "HISTSTOR" USING function, path, txn-id, posted-date,
      *                       result, id-count, status-code,
      *                       status-detail
      *
      *   function  "R"  reset: forget every id
      *             "L"  reset, then load the history file at path
      *             "C"  check txn-id; result is
      *                    "N" not posted before, may be posted
      *                    "B" already posted by this batch
      *                    "P" already posted by a prior batch
      *                    "F" not posted, but the store is full
      *             "A"  add txn-id with posted-date; result is
      *                    "N" added, or "F" store full (not added)
      *             "S"  save every id to the history file at path
      *   id-count      PIC 9(8) BINARY  out  ids now held
      *   status-code   PIC X(4)         out  "0000" or an F code
      *   status-detail PIC X(60)        out
      *
      * Capacity is 50000 ids (a documented resource limit).  With
      * 65537 slots the table is never more than 77% full, which
      * keeps linear probing short.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. HISTSTOR.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           CLASS TXN-ID-CHARACTER IS "A" THRU "I" "J" THRU "R"
                                     "S" THRU "Z" "0" THRU "9".
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT HISTORY-FILE ASSIGN TO DYNAMIC WS-HISTORY-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  HISTORY-FILE.
       01  HISTORY-FILE-RECORD             PIC X(40).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".
       COPY "history-record.cpy".

       01  WS-HISTORY-PATH                 PIC X(256).
       01  WS-FILE-STATUS                  PIC X(2).
       01  WS-END-OF-FILE-FLAG             PIC X(1).
           88  WS-END-OF-FILE              VALUE "Y".
       01  WS-RECORD-NUMBER                PIC 9(8).

       01  WS-STORE-READY-FLAG             PIC X(1) VALUE "N".
           88  WS-STORE-IS-READY           VALUE "Y".

       01  WS-MAX-IDS                      PIC 9(8) BINARY
                                           VALUE 50000.
       01  WS-SLOT-COUNT                   PIC 9(8) BINARY
                                           VALUE 65537.
       01  WS-ID-COUNT                     PIC 9(8) BINARY VALUE 0.
       01  WS-PRIOR-COUNT                  PIC 9(8) BINARY VALUE 0.

       01  WS-ID-STORE.
           05  WS-ID-ENTRY OCCURS 50000 TIMES.
               10  WS-ID-VALUE             PIC X(12).
               10  WS-ID-POSTED-DATE       PIC X(8).

       01  WS-SLOT-TABLE.
           05  WS-SLOT                     PIC 9(8) BINARY
                                           OCCURS 65537 TIMES.

      *    Work fields for one lookup.
       01  WS-SEARCH-ID                    PIC X(12).
       01  WS-HASH                         PIC 9(9) BINARY.
       01  WS-CHAR-NUMBER                  PIC 9(4) BINARY.
       01  WS-PROBE                        PIC 9(8) BINARY.
       01  WS-FOUND-ENTRY                  PIC 9(8) BINARY.
       01  WS-PROBE-DONE-FLAG              PIC X(1).
           88  WS-PROBE-DONE               VALUE "Y".
       01  WS-ENTRY-NUMBER                 PIC 9(8) BINARY.

       LINKAGE SECTION.
       01  LK-FUNCTION                     PIC X(1).
           88  LK-FUNCTION-RESET           VALUE "R".
           88  LK-FUNCTION-LOAD            VALUE "L".
           88  LK-FUNCTION-CHECK           VALUE "C".
           88  LK-FUNCTION-ADD             VALUE "A".
           88  LK-FUNCTION-SAVE            VALUE "S".
       01  LK-HISTORY-PATH                 PIC X(256).
       01  LK-TXN-ID                       PIC X(12).
       01  LK-POSTED-DATE                  PIC X(8).
       01  LK-RESULT                       PIC X(1).
           88  LK-RESULT-NOT-FOUND         VALUE "N".
           88  LK-RESULT-IN-BATCH          VALUE "B".
           88  LK-RESULT-PRIOR-BATCH       VALUE "P".
           88  LK-RESULT-STORE-FULL        VALUE "F".
       01  LK-ID-COUNT                     PIC 9(8) BINARY.
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-STATUS-DETAIL                PIC X(60).

       PROCEDURE DIVISION USING LK-FUNCTION
                                LK-HISTORY-PATH
                                LK-TXN-ID
                                LK-POSTED-DATE
                                LK-RESULT
                                LK-ID-COUNT
                                LK-STATUS-CODE
                                LK-STATUS-DETAIL.
       0000-DISPATCH.
           MOVE EC-NONE TO LK-STATUS-CODE
           MOVE SPACES TO LK-STATUS-DETAIL
           SET LK-RESULT-NOT-FOUND TO TRUE
           IF NOT WS-STORE-IS-READY
               PERFORM 1000-RESET-STORE
           END-IF

           EVALUATE TRUE
               WHEN LK-FUNCTION-RESET
                   PERFORM 1000-RESET-STORE
               WHEN LK-FUNCTION-LOAD
                   PERFORM 1000-RESET-STORE
                   PERFORM 2000-LOAD-HISTORY
               WHEN LK-FUNCTION-CHECK
                   PERFORM 3000-CHECK-ID
               WHEN LK-FUNCTION-ADD
                   PERFORM 4000-ADD-ID
               WHEN LK-FUNCTION-SAVE
                   PERFORM 5000-SAVE-HISTORY
           END-EVALUATE

           MOVE WS-ID-COUNT TO LK-ID-COUNT
           GOBACK.

       1000-RESET-STORE.
           MOVE ZERO TO WS-ID-COUNT
           MOVE ZERO TO WS-PRIOR-COUNT
           INITIALIZE WS-SLOT-TABLE
           SET WS-STORE-IS-READY TO TRUE.

      *---------------------------------------------------------------
      * LOAD
      *---------------------------------------------------------------
       2000-LOAD-HISTORY.
           MOVE LK-HISTORY-PATH TO WS-HISTORY-PATH
           MOVE ZERO TO WS-RECORD-NUMBER
           MOVE "N" TO WS-END-OF-FILE-FLAG

           OPEN INPUT HISTORY-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-HISTORY-OPEN TO LK-STATUS-CODE
               STRING "OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           PERFORM 2100-READ-HISTORY-RECORD
           PERFORM UNTIL WS-END-OF-FILE
                      OR LK-STATUS-CODE NOT = EC-NONE
               PERFORM 2200-STORE-HISTORY-RECORD
               IF LK-STATUS-CODE = EC-NONE
                   PERFORM 2100-READ-HISTORY-RECORD
               END-IF
           END-PERFORM

           CLOSE HISTORY-FILE
           MOVE WS-ID-COUNT TO WS-PRIOR-COUNT.

       2100-READ-HISTORY-RECORD.
           MOVE SPACES TO HISTORY-FILE-RECORD
           READ HISTORY-FILE
           EVALUATE TRUE
               WHEN WS-FILE-STATUS = "10"
                   SET WS-END-OF-FILE TO TRUE
               WHEN WS-FILE-STATUS (1:1) = "0"
                   ADD 1 TO WS-RECORD-NUMBER
                   MOVE HISTORY-FILE-RECORD TO HISTORY-AREA
               WHEN OTHER
                   MOVE EC-HISTORY-OPEN TO LK-STATUS-CODE
                   STRING "READ FILE STATUS " WS-FILE-STATUS
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
                   SET WS-END-OF-FILE TO TRUE
           END-EVALUATE.

       2200-STORE-HISTORY-RECORD.
           IF HR-TXN-ID IS NOT TXN-ID-CHARACTER
                   OR HR-POSTED-DATE IS NOT NUMERIC
                   OR HR-OVERFLOW-AREA NOT = SPACES
               MOVE EC-HISTORY-RECORD TO LK-STATUS-CODE
               STRING "RECORD " WS-RECORD-NUMBER " IS NOT WELL FORMED"
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           MOVE HR-TXN-ID TO WS-SEARCH-ID
           PERFORM 6000-FIND-ID
           IF WS-FOUND-ENTRY NOT = ZERO
               MOVE EC-HISTORY-RECORD TO LK-STATUS-CODE
               STRING "RECORD " WS-RECORD-NUMBER
                      " REPEATS ID " HR-TXN-ID
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           IF WS-ID-COUNT NOT < WS-MAX-IDS
               MOVE EC-HISTORY-CAPACITY TO LK-STATUS-CODE
               STRING "RECORD " WS-RECORD-NUMBER
                      " EXCEEDS STORE CAPACITY"
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           PERFORM 6100-INSERT-AT-PROBE
           MOVE HR-POSTED-DATE TO WS-ID-POSTED-DATE (WS-ID-COUNT).

      *---------------------------------------------------------------
      * CHECK and ADD
      *---------------------------------------------------------------
       3000-CHECK-ID.
           MOVE LK-TXN-ID TO WS-SEARCH-ID
           PERFORM 6000-FIND-ID
           EVALUATE TRUE
               WHEN WS-FOUND-ENTRY = ZERO
                       AND WS-ID-COUNT NOT < WS-MAX-IDS
                   SET LK-RESULT-STORE-FULL TO TRUE
               WHEN WS-FOUND-ENTRY = ZERO
                   SET LK-RESULT-NOT-FOUND TO TRUE
               WHEN WS-FOUND-ENTRY > WS-PRIOR-COUNT
                   SET LK-RESULT-IN-BATCH TO TRUE
               WHEN OTHER
                   SET LK-RESULT-PRIOR-BATCH TO TRUE
           END-EVALUATE.

      *    Adding an id that is already held is reported the same
      *    way a check would report it and leaves the store unchanged.
       4000-ADD-ID.
           PERFORM 3000-CHECK-ID
           IF LK-RESULT-NOT-FOUND
               PERFORM 6100-INSERT-AT-PROBE
               MOVE LK-POSTED-DATE TO WS-ID-POSTED-DATE (WS-ID-COUNT)
           END-IF.

      *---------------------------------------------------------------
      * SAVE
      *---------------------------------------------------------------
       5000-SAVE-HISTORY.
           MOVE LK-HISTORY-PATH TO WS-HISTORY-PATH
           OPEN OUTPUT HISTORY-FILE
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-OUTPUT-OPEN TO LK-STATUS-CODE
               STRING "HISTORY OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
               EXIT PARAGRAPH
           END-IF

           PERFORM 5100-WRITE-HISTORY-RECORD
               VARYING WS-ENTRY-NUMBER FROM 1 BY 1
               UNTIL WS-ENTRY-NUMBER > WS-ID-COUNT
                  OR LK-STATUS-CODE NOT = EC-NONE

           CLOSE HISTORY-FILE
           IF LK-STATUS-CODE = EC-NONE AND WS-FILE-STATUS NOT = "00"
               MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
               STRING "HISTORY CLOSE FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.

       5100-WRITE-HISTORY-RECORD.
           MOVE SPACES TO HISTORY-AREA
           MOVE WS-ID-VALUE (WS-ENTRY-NUMBER) TO HR-TXN-ID
           MOVE WS-ID-POSTED-DATE (WS-ENTRY-NUMBER)
             TO HR-POSTED-DATE
           MOVE HISTORY-AREA TO HISTORY-FILE-RECORD
           WRITE HISTORY-FILE-RECORD
           IF WS-FILE-STATUS NOT = "00"
               MOVE EC-OUTPUT-WRITE TO LK-STATUS-CODE
               STRING "HISTORY WRITE FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.

      *---------------------------------------------------------------
      * HASH TABLE
      *---------------------------------------------------------------
      *    Looks WS-SEARCH-ID up.  On return WS-FOUND-ENTRY is the
      *    entry number holding the id, or zero if it is not held, in
      *    which case WS-PROBE is the empty slot where it belongs.
      *    The table always has empty slots (capacity is below the
      *    slot count), so the probe loop always ends.
       6000-FIND-ID.
           MOVE ZERO TO WS-HASH
           PERFORM VARYING WS-CHAR-NUMBER FROM 1 BY 1
                   UNTIL WS-CHAR-NUMBER > 12
               COMPUTE WS-HASH = FUNCTION MOD (
                   WS-HASH * 31
                   + FUNCTION ORD (WS-SEARCH-ID (WS-CHAR-NUMBER:1)),
                   WS-SLOT-COUNT)
           END-PERFORM
           COMPUTE WS-PROBE = WS-HASH + 1

           MOVE ZERO TO WS-FOUND-ENTRY
           MOVE "N" TO WS-PROBE-DONE-FLAG
           PERFORM UNTIL WS-PROBE-DONE
               IF WS-SLOT (WS-PROBE) = ZERO
                   SET WS-PROBE-DONE TO TRUE
               ELSE
                   IF WS-ID-VALUE (WS-SLOT (WS-PROBE)) = WS-SEARCH-ID
                       MOVE WS-SLOT (WS-PROBE) TO WS-FOUND-ENTRY
                       SET WS-PROBE-DONE TO TRUE
                   ELSE
                       ADD 1 TO WS-PROBE
                       IF WS-PROBE > WS-SLOT-COUNT
                           MOVE 1 TO WS-PROBE
                       END-IF
                   END-IF
               END-IF
           END-PERFORM.

      *    Appends WS-SEARCH-ID as a new entry and records it in the
      *    empty slot that 6000-FIND-ID left in WS-PROBE.
       6100-INSERT-AT-PROBE.
           ADD 1 TO WS-ID-COUNT
           MOVE WS-SEARCH-ID TO WS-ID-VALUE (WS-ID-COUNT)
           MOVE WS-ID-COUNT TO WS-SLOT (WS-PROBE).
