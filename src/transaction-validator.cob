      *****************************************************************
      * TXNVALID - transaction record validation
      *
      * Decides whether one input record is a well-formed transaction
      * that the stateless business rules allow.  It performs no file
      * I/O and looks at no account data, so the same record always
      * gets the same answer for a given control file.
      *
      * Checks are made in the order below and the first failure is
      * the one reported, so a record has exactly one status code.
      *
      *   Structure                                          Code
      *    1. no non-printable characters                    V014
      *    2. not longer than 80 bytes                       V002
      *    3. long enough to hold the amount (54 bytes)      V001
      *    4. id is 12 characters A-Z 0-9                    V003
      *    5. type is D, W or T                              V006
      *    6. date is numeric                                V004
      *    7. date is a calendar date                        V005
      *    8. account is 10 digits                           V007
      *    9. account is not the reserved clearing account   V013
      *   10. transfer: destination is 10 digits             V008
      *       transfer: destination is not reserved          V013
      *       transfer: destination differs from source      V012
      *       otherwise: destination is blank                V009
      *   11. amount is 13 digits                            V010
      *   12. amount is not zero                             V011
      *   Stateless business rules
      *   13. date is not after the batch date               B001
      *   14. date is not older than MAX-BACKDATE-DAYS       B002
      *   15. amount is within the limit for its type        B003-5
      *
      * CALL "TXNVALID" USING TXN-INPUT-AREA, BATCH-CONTROL,
      *                       TXN-WORK-AREA
      *
      * On return TW-STATUS-CODE is "0000" or the failure code, and
      * the TW- text fields hold the record's fields as received.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. TXNVALID.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SPECIAL-NAMES.
           CLASS TXN-ID-CHARACTER IS "A" THRU "I" "J" THRU "R"
                                     "S" THRU "Z" "0" THRU "9".

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".

       01  WS-RECORD-LENGTH                PIC 9(4) BINARY VALUE 80.
       01  WS-MINIMUM-LENGTH               PIC 9(4) BINARY VALUE 54.

       01  WS-DATE-VALID-FLAG              PIC X(1).
           88  WS-DATE-IS-VALID            VALUE "Y".
       01  WS-DAY-NUMBER                   PIC 9(8) BINARY.
       01  WS-AGE-IN-DAYS                  PIC S9(8) BINARY.

       LINKAGE SECTION.
       COPY "transaction-record.cpy".
       COPY "batch-control.cpy".
       COPY "txn-work.cpy".

       PROCEDURE DIVISION USING TXN-INPUT-AREA
                                BATCH-CONTROL
                                TXN-WORK-AREA.
       0000-VALIDATE-TRANSACTION.
           PERFORM 1000-CAPTURE-RECORD-FIELDS

           PERFORM 2000-CHECK-RECORD-SHAPE
           IF TW-IS-ACCEPTED
               PERFORM 3000-CHECK-IDENTITY-FIELDS
           END-IF
           IF TW-IS-ACCEPTED
               PERFORM 4000-CHECK-ACCOUNT-FIELDS
           END-IF
           IF TW-IS-ACCEPTED
               PERFORM 5000-CHECK-AMOUNT
           END-IF
           IF TW-IS-ACCEPTED
               PERFORM 6000-CHECK-DATE-WINDOW
           END-IF
           IF TW-IS-ACCEPTED
               PERFORM 7000-CHECK-AMOUNT-LIMIT
           END-IF
           GOBACK.

      *    The fields are copied as text before any check so that a
      *    rejected record can be reported exactly as it arrived.
       1000-CAPTURE-RECORD-FIELDS.
           MOVE EC-NONE            TO TW-STATUS-CODE
           MOVE TXN-ID             TO TW-TXN-ID
           MOVE TXN-DATE           TO TW-TXN-DATE
           MOVE TXN-TYPE           TO TW-TXN-TYPE
           MOVE TXN-ACCOUNT        TO TW-ACCOUNT
           MOVE TXN-CONTRA-ACCOUNT TO TW-CONTRA-ACCOUNT
           MOVE TXN-AMOUNT         TO TW-AMOUNT-TEXT
           MOVE TXN-DESCRIPTION    TO TW-DESCRIPTION
           MOVE ZERO               TO TW-AMOUNT
           MOVE ZERO               TO TW-TXN-DAY-NUMBER.

       2000-CHECK-RECORD-SHAPE.
           EVALUATE TRUE
               WHEN TW-HAS-UNPRINTABLE
                   MOVE EC-UNPRINTABLE TO TW-STATUS-CODE
               WHEN TW-RAW-LENGTH > WS-RECORD-LENGTH
                   MOVE EC-REC-TOO-LONG TO TW-STATUS-CODE
               WHEN TW-RAW-LENGTH < WS-MINIMUM-LENGTH
                   MOVE EC-REC-TOO-SHORT TO TW-STATUS-CODE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       3000-CHECK-IDENTITY-FIELDS.
           EVALUATE TRUE
               WHEN TXN-ID IS NOT TXN-ID-CHARACTER
                   MOVE EC-TXN-ID-INVALID TO TW-STATUS-CODE
               WHEN NOT TW-TYPE-IS-VALID
                   MOVE EC-TYPE-INVALID TO TW-STATUS-CODE
               WHEN TXN-DATE IS NOT NUMERIC
                   MOVE EC-DATE-NOT-NUMERIC TO TW-STATUS-CODE
               WHEN OTHER
                   CALL "DATEVAL" USING TXN-DATE
                                        WS-DATE-VALID-FLAG
                                        WS-DAY-NUMBER
                   IF WS-DATE-IS-VALID
                       MOVE WS-DAY-NUMBER TO TW-TXN-DAY-NUMBER
                   ELSE
                       MOVE EC-DATE-INVALID TO TW-STATUS-CODE
                   END-IF
           END-EVALUATE.

       4000-CHECK-ACCOUNT-FIELDS.
           EVALUATE TRUE
               WHEN TXN-ACCOUNT IS NOT NUMERIC
                   MOVE EC-ACCT-FORMAT TO TW-STATUS-CODE
               WHEN TXN-ACCOUNT = BC-CLEARING-ACCOUNT
                   MOVE EC-RESERVED-ACCOUNT TO TW-STATUS-CODE
               WHEN TW-IS-TRANSFER
                   PERFORM 4100-CHECK-TRANSFER-DESTINATION
               WHEN TXN-CONTRA-ACCOUNT NOT = SPACES
                   MOVE EC-CONTRA-NOT-BLANK TO TW-STATUS-CODE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       4100-CHECK-TRANSFER-DESTINATION.
           EVALUATE TRUE
               WHEN TXN-CONTRA-ACCOUNT IS NOT NUMERIC
                   MOVE EC-CONTRA-FORMAT TO TW-STATUS-CODE
               WHEN TXN-CONTRA-ACCOUNT = BC-CLEARING-ACCOUNT
                   MOVE EC-RESERVED-ACCOUNT TO TW-STATUS-CODE
               WHEN TXN-CONTRA-ACCOUNT = TXN-ACCOUNT
                   MOVE EC-SAME-ACCOUNT TO TW-STATUS-CODE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

      *    TXN-AMOUNT-NUMERIC is only referenced after the NUMERIC
      *    class test has passed.
       5000-CHECK-AMOUNT.
           IF TXN-AMOUNT IS NOT NUMERIC
               MOVE EC-AMOUNT-NOT-NUMERIC TO TW-STATUS-CODE
           ELSE
               MOVE TXN-AMOUNT-NUMERIC TO TW-AMOUNT
               IF TW-AMOUNT = ZERO
                   MOVE EC-AMOUNT-ZERO TO TW-STATUS-CODE
               END-IF
           END-IF.

       6000-CHECK-DATE-WINDOW.
           COMPUTE WS-AGE-IN-DAYS =
               BC-BATCH-DAY-NUMBER - TW-TXN-DAY-NUMBER
           EVALUATE TRUE
               WHEN WS-AGE-IN-DAYS < ZERO
                   MOVE EC-DATE-FUTURE TO TW-STATUS-CODE
               WHEN WS-AGE-IN-DAYS > BC-MAX-BACKDATE-DAYS
                   MOVE EC-DATE-STALE TO TW-STATUS-CODE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.

       7000-CHECK-AMOUNT-LIMIT.
           EVALUATE TRUE
               WHEN TW-IS-DEPOSIT AND TW-AMOUNT > BC-MAX-DEPOSIT
                   MOVE EC-LIMIT-DEPOSIT TO TW-STATUS-CODE
               WHEN TW-IS-WITHDRAWAL
                       AND TW-AMOUNT > BC-MAX-WITHDRAWAL
                   MOVE EC-LIMIT-WITHDRAWAL TO TW-STATUS-CODE
               WHEN TW-IS-TRANSFER AND TW-AMOUNT > BC-MAX-TRANSFER
                   MOVE EC-LIMIT-TRANSFER TO TW-STATUS-CODE
               WHEN OTHER
                   CONTINUE
           END-EVALUATE.
