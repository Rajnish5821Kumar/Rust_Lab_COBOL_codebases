      *****************************************************************
      * TXNREAD - transaction file reader
      *
      * The only program that touches the transaction input file.
      * It hands each record to the caller as text, together with
      * what the caller needs to judge it: its ordinal number, its
      * length, and whether it held non-printable characters.  It
      * does not interpret the fields; that is TXNVALID's job.
      *
      * Non-printable characters (anything outside space to tilde)
      * are replaced with "?" before the record is returned.  A
      * record that needed this is flagged and will be rejected, but
      * replacing the characters first means its image can be written
      * to the reject report safely on every runtime.
      *
      * CALL "TXNREAD" USING function, path, TXN-INPUT-AREA,
      *                      TXN-WORK-AREA, read-result,
      *                      status-code, status-detail
      *
      *   function     "O" open, "R" read next record, "C" close
      *   read-result  "0" a record was returned
      *                "E" end of file, no record returned
      *                "F" fatal error, see status-code
      *   status-code  "0000", F010 (cannot open) or F011 (read)
      *
      * On a successful read TW-RECORD-NUMBER, TW-RAW-LENGTH and
      * TW-UNPRINTABLE-FLAG are set; the other TW- fields are not
      * touched.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXNREAD.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           CLASS PRINTABLE-CHARACTER IS " " THRU "~".
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT TRANSACTION-FILE ASSIGN TO DYNAMIC WS-TXN-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  TRANSACTION-FILE.
       01  TRANSACTION-FILE-RECORD         PIC X(200).

       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".

       01  WS-TXN-PATH                     PIC X(256).
       01  WS-FILE-STATUS                  PIC X(2).
       01  WS-FILE-OPEN-FLAG               PIC X(1) VALUE "N".
           88  WS-FILE-IS-OPEN             VALUE "Y".
       01  WS-RECORD-COUNT                 PIC 9(8) BINARY VALUE 0.
       01  WS-RECORD-COUNT-DISPLAY         PIC 9(8).
       01  WS-POSITION                     PIC 9(4) BINARY.
       01  WS-RECORD-AREA-LENGTH           PIC 9(4) BINARY VALUE 200.

       LINKAGE SECTION.
       01  LK-FUNCTION                     PIC X(1).
           88  LK-FUNCTION-OPEN            VALUE "O".
           88  LK-FUNCTION-READ            VALUE "R".
           88  LK-FUNCTION-CLOSE           VALUE "C".
       01  LK-TXN-PATH                     PIC X(256).
       COPY "transaction-record.cpy".
       COPY "txn-work.cpy".
       01  LK-READ-RESULT                  PIC X(1).
           88  LK-RECORD-RETURNED          VALUE "0".
           88  LK-END-OF-FILE              VALUE "E".
           88  LK-READ-FAILED              VALUE "F".
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-STATUS-DETAIL                PIC X(60).

       PROCEDURE DIVISION USING LK-FUNCTION
                                LK-TXN-PATH
                                TXN-INPUT-AREA
                                TXN-WORK-AREA
                                LK-READ-RESULT
                                LK-STATUS-CODE
                                LK-STATUS-DETAIL.
       0000-DISPATCH.
           MOVE EC-NONE TO LK-STATUS-CODE
           MOVE SPACES TO LK-STATUS-DETAIL
           SET LK-RECORD-RETURNED TO TRUE
           EVALUATE TRUE
               WHEN LK-FUNCTION-OPEN
                   PERFORM 1000-OPEN-FILE
               WHEN LK-FUNCTION-READ
                   PERFORM 2000-READ-RECORD
               WHEN LK-FUNCTION-CLOSE
                   PERFORM 3000-CLOSE-FILE
           END-EVALUATE
           GOBACK.

       1000-OPEN-FILE.
           MOVE LK-TXN-PATH TO WS-TXN-PATH
           MOVE ZERO TO WS-RECORD-COUNT
           OPEN INPUT TRANSACTION-FILE
           IF WS-FILE-STATUS = "00"
               SET WS-FILE-IS-OPEN TO TRUE
           ELSE
               SET LK-READ-FAILED TO TRUE
               MOVE EC-TXN-OPEN TO LK-STATUS-CODE
               STRING "OPEN FILE STATUS " WS-FILE-STATUS
                   DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-IF.

      *    A file status in the "successful" class other than 00 means
      *    the runtime has a reservation about the record (too long
      *    for the record area, or unusual characters).  The record is
      *    still returned: the checks below and in TXNVALID decide its
      *    fate, so the outcome does not depend on the runtime.
       2000-READ-RECORD.
           MOVE SPACES TO TRANSACTION-FILE-RECORD
           READ TRANSACTION-FILE
           EVALUATE TRUE
               WHEN WS-FILE-STATUS = "10"
                   SET LK-END-OF-FILE TO TRUE
               WHEN WS-FILE-STATUS (1:1) = "0"
                   ADD 1 TO WS-RECORD-COUNT
                   MOVE TRANSACTION-FILE-RECORD TO TXN-INPUT-AREA
                   MOVE WS-RECORD-COUNT TO TW-RECORD-NUMBER
                   PERFORM 2100-REPLACE-UNPRINTABLE
                   PERFORM 2200-MEASURE-RECORD
               WHEN OTHER
                   SET LK-READ-FAILED TO TRUE
                   MOVE EC-TXN-READ TO LK-STATUS-CODE
                   MOVE WS-RECORD-COUNT TO WS-RECORD-COUNT-DISPLAY
                   STRING "READ FILE STATUS " WS-FILE-STATUS
                          " AFTER RECORD " WS-RECORD-COUNT-DISPLAY
                       DELIMITED BY SIZE INTO LK-STATUS-DETAIL
           END-EVALUATE.

       2100-REPLACE-UNPRINTABLE.
           MOVE "N" TO TW-UNPRINTABLE-FLAG
           IF TXN-INPUT-AREA IS NOT PRINTABLE-CHARACTER
               SET TW-HAS-UNPRINTABLE TO TRUE
               PERFORM VARYING WS-POSITION FROM 1 BY 1
                       UNTIL WS-POSITION > WS-RECORD-AREA-LENGTH
                   IF TXN-INPUT-AREA (WS-POSITION:1)
                           IS NOT PRINTABLE-CHARACTER
                       MOVE "?" TO TXN-INPUT-AREA (WS-POSITION:1)
                   END-IF
               END-PERFORM
           END-IF.

      *    The length of a record is the position of its last
      *    non-space character; trailing spaces carry no information
      *    in a LINE SEQUENTIAL file.
       2200-MEASURE-RECORD.
           MOVE WS-RECORD-AREA-LENGTH TO WS-POSITION
           PERFORM UNTIL WS-POSITION = ZERO
               IF TXN-INPUT-AREA (WS-POSITION:1) NOT = SPACE
                   EXIT PERFORM
               END-IF
               SUBTRACT 1 FROM WS-POSITION
           END-PERFORM
           MOVE WS-POSITION TO TW-RAW-LENGTH.

       3000-CLOSE-FILE.
           IF WS-FILE-IS-OPEN
               CLOSE TRANSACTION-FILE
               MOVE "N" TO WS-FILE-OPEN-FLAG
           END-IF.
