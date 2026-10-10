      *****************************************************************
      * ERRTEXT - status code to message text
      *
      * Returns the operator-facing message for a status code from
      * ERROR-CODES.CPY.  Keeping every message in one place means a
      * code reads the same in the job log, the reject report and
      * the summary report.
      *
      * CALL "ERRTEXT" USING status-code, message-text
      *
      *   status-code   PIC X(4)   in
      *   message-text  PIC X(48)  out
      *
      * A code with no entry here returns "UNKNOWN STATUS CODE"; the
      * unit test tests/unit/test-error-messages.cob fails when that
      * happens for any code in the copybook.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ERRTEXT.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".

       LINKAGE SECTION.
       01  LK-STATUS-CODE                  PIC X(4).
       01  LK-MESSAGE-TEXT                 PIC X(48).

       PROCEDURE DIVISION USING LK-STATUS-CODE
                                LK-MESSAGE-TEXT.
       0000-LOOK-UP-MESSAGE.
           EVALUATE LK-STATUS-CODE (1:1)
               WHEN "V"
                   PERFORM 1000-VALIDATION-MESSAGE
               WHEN "B"
                   PERFORM 2000-BUSINESS-MESSAGE
               WHEN "F"
                   PERFORM 3000-FATAL-MESSAGE
               WHEN "R"
                   PERFORM 4000-RECONCILIATION-MESSAGE
               WHEN OTHER
                   IF LK-STATUS-CODE = EC-NONE
                       MOVE "ACCEPTED" TO LK-MESSAGE-TEXT
                   ELSE
                       MOVE "UNKNOWN STATUS CODE" TO LK-MESSAGE-TEXT
                   END-IF
           END-EVALUATE
           GOBACK.

       1000-VALIDATION-MESSAGE.
           EVALUATE LK-STATUS-CODE
             WHEN EC-REC-TOO-SHORT
               MOVE "RECORD SHORTER THAN THE REQUIRED FIELDS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-REC-TOO-LONG
               MOVE "RECORD LONGER THAN 80 BYTES"
                 TO LK-MESSAGE-TEXT
             WHEN EC-TXN-ID-INVALID
               MOVE "TRANSACTION ID NOT 12 CHARACTERS A-Z 0-9"
                 TO LK-MESSAGE-TEXT
             WHEN EC-DATE-NOT-NUMERIC
               MOVE "TRANSACTION DATE NOT NUMERIC"
                 TO LK-MESSAGE-TEXT
             WHEN EC-DATE-INVALID
               MOVE "TRANSACTION DATE NOT A CALENDAR DATE"
                 TO LK-MESSAGE-TEXT
             WHEN EC-TYPE-INVALID
               MOVE "TRANSACTION TYPE NOT D, W OR T"
                 TO LK-MESSAGE-TEXT
             WHEN EC-ACCT-FORMAT
               MOVE "ACCOUNT NUMBER NOT 10 DIGITS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-CONTRA-FORMAT
               MOVE "TRANSFER DESTINATION ACCOUNT NOT 10 DIGITS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-CONTRA-NOT-BLANK
               MOVE "DESTINATION ACCOUNT GIVEN ON NON-TRANSFER"
                 TO LK-MESSAGE-TEXT
             WHEN EC-AMOUNT-NOT-NUMERIC
               MOVE "AMOUNT NOT 13 DIGITS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-AMOUNT-ZERO
               MOVE "AMOUNT IS ZERO"
                 TO LK-MESSAGE-TEXT
             WHEN EC-SAME-ACCOUNT
               MOVE "TRANSFER SOURCE AND DESTINATION ARE THE SAME"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RESERVED-ACCOUNT
               MOVE "ACCOUNT NUMBER IS RESERVED FOR INTERNAL USE"
                 TO LK-MESSAGE-TEXT
             WHEN EC-UNPRINTABLE
               MOVE "RECORD CONTAINS NON-PRINTABLE CHARACTERS"
                 TO LK-MESSAGE-TEXT
             WHEN OTHER
               MOVE "UNKNOWN STATUS CODE" TO LK-MESSAGE-TEXT
           END-EVALUATE.

       2000-BUSINESS-MESSAGE.
           EVALUATE LK-STATUS-CODE
             WHEN EC-DATE-FUTURE
               MOVE "TRANSACTION DATE IS AFTER THE BATCH DATE"
                 TO LK-MESSAGE-TEXT
             WHEN EC-DATE-STALE
               MOVE "TRANSACTION DATE IS OLDER THAN ALLOWED"
                 TO LK-MESSAGE-TEXT
             WHEN EC-LIMIT-DEPOSIT
               MOVE "DEPOSIT EXCEEDS THE PER-TRANSACTION LIMIT"
                 TO LK-MESSAGE-TEXT
             WHEN EC-LIMIT-WITHDRAWAL
               MOVE "WITHDRAWAL EXCEEDS THE PER-TRANSACTION LIMIT"
                 TO LK-MESSAGE-TEXT
             WHEN EC-LIMIT-TRANSFER
               MOVE "TRANSFER EXCEEDS THE PER-TRANSACTION LIMIT"
                 TO LK-MESSAGE-TEXT
             WHEN EC-DUP-IN-BATCH
               MOVE "DUPLICATE TRANSACTION ID IN THIS BATCH"
                 TO LK-MESSAGE-TEXT
             WHEN EC-DUP-PRIOR-BATCH
               MOVE "TRANSACTION ID ALREADY POSTED BY AN EARLIER RUN"
                 TO LK-MESSAGE-TEXT
             WHEN EC-ACCT-NOT-FOUND
               MOVE "ACCOUNT NOT ON THE ACCOUNT MASTER"
                 TO LK-MESSAGE-TEXT
             WHEN EC-CONTRA-NOT-FOUND
               MOVE "DESTINATION ACCOUNT NOT ON THE ACCOUNT MASTER"
                 TO LK-MESSAGE-TEXT
             WHEN EC-ACCT-NOT-ACTIVE
               MOVE "ACCOUNT IS NOT ACTIVE"
                 TO LK-MESSAGE-TEXT
             WHEN EC-CONTRA-NOT-ACTIVE
               MOVE "DESTINATION ACCOUNT IS NOT ACTIVE"
                 TO LK-MESSAGE-TEXT
             WHEN EC-INSUFFICIENT-FUNDS
               MOVE "INSUFFICIENT AVAILABLE FUNDS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-DAILY-LIMIT
               MOVE "ACCOUNT DAILY DEBIT LIMIT EXCEEDED"
                 TO LK-MESSAGE-TEXT
             WHEN EC-BALANCE-OVERFLOW
               MOVE "POSTING WOULD EXCEED THE LARGEST BALANCE HELD"
                 TO LK-MESSAGE-TEXT
             WHEN EC-ID-CAPACITY
               MOVE "DUPLICATE-CHECK TABLE FULL, CANNOT POST SAFELY"
                 TO LK-MESSAGE-TEXT
             WHEN OTHER
               MOVE "UNKNOWN STATUS CODE" TO LK-MESSAGE-TEXT
           END-EVALUATE.

       3000-FATAL-MESSAGE.
           EVALUATE LK-STATUS-CODE
             WHEN EC-CONTROL-OPEN
               MOVE "CONTROL FILE CANNOT BE OPENED OR READ"
                 TO LK-MESSAGE-TEXT
             WHEN EC-CONTROL-INVALID
               MOVE "CONTROL FILE CONTAINS AN INVALID ENTRY"
                 TO LK-MESSAGE-TEXT
             WHEN EC-BATCH-DATE
               MOVE "BATCH-DATE MISSING OR NOT A CALENDAR DATE"
                 TO LK-MESSAGE-TEXT
             WHEN EC-MASTER-OPEN
               MOVE "ACCOUNT MASTER CANNOT BE OPENED OR READ"
                 TO LK-MESSAGE-TEXT
             WHEN EC-MASTER-RECORD
               MOVE "ACCOUNT MASTER RECORD IS INVALID"
                 TO LK-MESSAGE-TEXT
             WHEN EC-MASTER-SEQUENCE
               MOVE "ACCOUNT MASTER OUT OF SEQUENCE OR DUPLICATED"
                 TO LK-MESSAGE-TEXT
             WHEN EC-MASTER-NO-TRAILER
               MOVE "ACCOUNT MASTER HAS NO TRAILER RECORD"
                 TO LK-MESSAGE-TEXT
             WHEN EC-MASTER-CONTROL-TOTAL
               MOVE "ACCOUNT MASTER DOES NOT MATCH ITS TRAILER"
                 TO LK-MESSAGE-TEXT
             WHEN EC-MASTER-CAPACITY
               MOVE "ACCOUNT MASTER HAS TOO MANY ACCOUNTS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-TXN-OPEN
               MOVE "TRANSACTION FILE CANNOT BE OPENED"
                 TO LK-MESSAGE-TEXT
             WHEN EC-TXN-READ
               MOVE "TRANSACTION FILE READ ERROR"
                 TO LK-MESSAGE-TEXT
             WHEN EC-HISTORY-OPEN
               MOVE "HISTORY FILE CANNOT BE OPENED OR READ"
                 TO LK-MESSAGE-TEXT
             WHEN EC-HISTORY-RECORD
               MOVE "HISTORY FILE RECORD IS INVALID OR DUPLICATED"
                 TO LK-MESSAGE-TEXT
             WHEN EC-OUTPUT-OPEN
               MOVE "OUTPUT FILE CANNOT BE OPENED"
                 TO LK-MESSAGE-TEXT
             WHEN EC-OUTPUT-WRITE
               MOVE "OUTPUT FILE WRITE ERROR"
                 TO LK-MESSAGE-TEXT
             WHEN EC-TOTAL-OVERFLOW
               MOVE "CONTROL TOTAL TOO LARGE TO HOLD"
                 TO LK-MESSAGE-TEXT
             WHEN EC-FILE-NAME-MISSING
               MOVE "REQUIRED FILE NAME VARIABLE IS NOT SET"
                 TO LK-MESSAGE-TEXT
             WHEN EC-HISTORY-CAPACITY
               MOVE "HISTORY FILE HAS TOO MANY TRANSACTION IDS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-SAME-IN-OUT-PATH
               MOVE "INPUT AND OUTPUT FILE NAMES ARE THE SAME"
                 TO LK-MESSAGE-TEXT
             WHEN EC-JOURNAL-OPEN
               MOVE "JOURNAL FILE CANNOT BE OPENED OR READ"
                 TO LK-MESSAGE-TEXT
             WHEN OTHER
               MOVE "UNKNOWN STATUS CODE" TO LK-MESSAGE-TEXT
           END-EVALUATE.

       4000-RECONCILIATION-MESSAGE.
           EVALUATE LK-STATUS-CODE
             WHEN EC-RECON-DR-CR
               MOVE "JOURNAL TOTAL DEBITS DO NOT EQUAL CREDITS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-BALANCE
               MOVE "CLOSING BALANCE NOT OPENING PLUS MOVEMENTS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-UNKNOWN-ACCT
               MOVE "JOURNAL ENTRY FOR ACCOUNT NOT ON THE MASTER"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-ACCOUNT-SET
               MOVE "OPENING AND CLOSING MASTERS LIST DIFFERENT ACCTS"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-RUNNING-BAL
               MOVE "JOURNAL BALANCE-AFTER DOES NOT FOLLOW ENTRIES"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-CONTROL-TOTAL
               MOVE "CLOSING TOTAL NOT OPENING TOTAL PLUS NET CASH"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-SEQUENCE
               MOVE "JOURNAL SEQUENCE NUMBER GAP OR REPEAT"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-RECORD
               MOVE "JOURNAL RECORD IS INVALID"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-PAIR
               MOVE "JOURNAL DEBIT/CREDIT PAIR DOES NOT MATCH"
                 TO LK-MESSAGE-TEXT
             WHEN EC-RECON-MEMORY-TOTALS
               MOVE "JOURNAL ON DISK DIFFERS FROM RUN CONTROL TOTALS"
                 TO LK-MESSAGE-TEXT
             WHEN OTHER
               MOVE "UNKNOWN STATUS CODE" TO LK-MESSAGE-TEXT
           END-EVALUATE.
