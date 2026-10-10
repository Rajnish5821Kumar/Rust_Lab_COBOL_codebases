      *****************************************************************
      * ACCTPROC - account posting engine
      *
      * Applies one validated transaction to the account table, or
      * refuses it.  It performs no file I/O.
      *
      * Posting is all-or-nothing.  Every new balance is first worked
      * out in a work field and every rule is checked against those
      * work fields; the table is changed only when the whole
      * transaction has passed, so a refused transaction leaves no
      * trace in the table.
      *
      * Rules, in the order they are checked                    Code
      *    1. account is on the master                          B008
      *    2. account is active                                 B010
      *    3. transfer: destination is on the master            B009
      *    4. transfer: destination is active                   B011
      *    5. debit leaves the balance at or above
      *       minus OVERDRAFT-LIMIT                             B012
      *    6. debit keeps the account's debits for the batch
      *       within DAILY-DEBIT-LIMIT                          B013
      *    7. no balance grows beyond what its field holds      B014
      *
      * Accounting convention.  Customer accounts are liabilities of
      * the institution: a credit (CR) increases the balance and a
      * debit (DR) decreases it.  The clearing account is an asset
      * (cash): a debit increases its position, a credit decreases
      * it.  Every posting is a debit and a credit of the same
      * amount, so the journal always balances.
      *
      * CALL "ACCTPROC" USING BATCH-CONTROL, TXN-WORK-AREA,
      *                       account-table, POSTING-RESULT
      *
      * On return TW-STATUS-CODE is "0000" and POSTING-RESULT holds
      * the two journal entries, or TW-STATUS-CODE is a B code and
      * PR-ENTRY-COUNT is zero.
      *****************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCTPROC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY "error-codes.cpy".

       01  WS-SEARCH-ACCT-ID               PIC X(10).
       01  WS-FOUND-ENTRY                  PIC 9(8) BINARY.
       01  WS-PRIMARY-ENTRY                PIC 9(8) BINARY.
       01  WS-CONTRA-ENTRY                 PIC 9(8) BINARY.

       01  WS-NEW-PRIMARY-BALANCE          PIC S9(13)V99
                                           PACKED-DECIMAL.
       01  WS-NEW-CONTRA-BALANCE           PIC S9(13)V99
                                           PACKED-DECIMAL.
       01  WS-NEW-DEBIT-TODAY              PIC S9(13)V99
                                           PACKED-DECIMAL.
       01  WS-NEW-CLEARING-POSITION        PIC S9(15)V99
                                           PACKED-DECIMAL.
       01  WS-LOWEST-ALLOWED-BALANCE       PIC S9(13)V99
                                           PACKED-DECIMAL.

       LINKAGE SECTION.
       COPY "batch-control.cpy".
       COPY "txn-work.cpy".
       COPY "account-table.cpy" REPLACING ==:AT:== BY ==AT==.
       COPY "posting-result.cpy".

       PROCEDURE DIVISION USING BATCH-CONTROL
                                TXN-WORK-AREA
                                AT-ACCOUNT-TABLE
                                POSTING-RESULT.
       0000-POST-TRANSACTION.
           MOVE EC-NONE TO TW-STATUS-CODE
           INITIALIZE POSTING-RESULT
           MOVE ZERO TO WS-PRIMARY-ENTRY
           MOVE ZERO TO WS-CONTRA-ENTRY

           PERFORM 1000-LOCATE-ACCOUNTS
           IF TW-IS-ACCEPTED
               EVALUATE TRUE
                   WHEN TW-IS-DEPOSIT
                       PERFORM 2000-PLAN-DEPOSIT
                   WHEN TW-IS-WITHDRAWAL
                       PERFORM 3000-PLAN-WITHDRAWAL
                   WHEN TW-IS-TRANSFER
                       PERFORM 4000-PLAN-TRANSFER
               END-EVALUATE
           END-IF
           IF TW-IS-ACCEPTED
               PERFORM 5000-APPLY-POSTING
           END-IF
           GOBACK.

      *---------------------------------------------------------------
      * Account lookup
      *---------------------------------------------------------------
       1000-LOCATE-ACCOUNTS.
           MOVE TW-ACCOUNT TO WS-SEARCH-ACCT-ID
           PERFORM 1100-FIND-ACCOUNT
           MOVE WS-FOUND-ENTRY TO WS-PRIMARY-ENTRY
           IF WS-PRIMARY-ENTRY = ZERO
               MOVE EC-ACCT-NOT-FOUND TO TW-STATUS-CODE
               EXIT PARAGRAPH
           END-IF
           IF NOT AT-IS-ACTIVE (WS-PRIMARY-ENTRY)
               MOVE EC-ACCT-NOT-ACTIVE TO TW-STATUS-CODE
               EXIT PARAGRAPH
           END-IF

           IF TW-IS-TRANSFER
               MOVE TW-CONTRA-ACCOUNT TO WS-SEARCH-ACCT-ID
               PERFORM 1100-FIND-ACCOUNT
               MOVE WS-FOUND-ENTRY TO WS-CONTRA-ENTRY
               IF WS-CONTRA-ENTRY = ZERO
                   MOVE EC-CONTRA-NOT-FOUND TO TW-STATUS-CODE
                   EXIT PARAGRAPH
               END-IF
               IF NOT AT-IS-ACTIVE (WS-CONTRA-ENTRY)
                   MOVE EC-CONTRA-NOT-ACTIVE TO TW-STATUS-CODE
               END-IF
           END-IF.

      *    Binary search; the table is in ascending account-id order.
      *    WS-FOUND-ENTRY is zero when the account is not held.
       1100-FIND-ACCOUNT.
           MOVE ZERO TO WS-FOUND-ENTRY
           IF AT-ACCOUNT-COUNT > ZERO
               SEARCH ALL AT-ENTRY
                   AT END
                       CONTINUE
                   WHEN AT-ACCT-ID (AT-IDX) = WS-SEARCH-ACCT-ID
                       SET WS-FOUND-ENTRY TO AT-IDX
               END-SEARCH
           END-IF.

      *---------------------------------------------------------------
      * Planning: work out the new figures and check the rules.
      * Nothing in the table is changed here.
      *---------------------------------------------------------------
       2000-PLAN-DEPOSIT.
           ADD TW-AMOUNT TO AT-BALANCE (WS-PRIMARY-ENTRY)
               GIVING WS-NEW-PRIMARY-BALANCE
               ON SIZE ERROR
                   MOVE EC-BALANCE-OVERFLOW TO TW-STATUS-CODE
           END-ADD
           IF TW-IS-ACCEPTED
               ADD TW-AMOUNT TO AT-CLEARING-POSITION
                   GIVING WS-NEW-CLEARING-POSITION
                   ON SIZE ERROR
                       MOVE EC-BALANCE-OVERFLOW TO TW-STATUS-CODE
               END-ADD
           END-IF.

       3000-PLAN-WITHDRAWAL.
           PERFORM 4100-PLAN-DEBIT-OF-PRIMARY
           IF TW-IS-ACCEPTED
               SUBTRACT TW-AMOUNT FROM AT-CLEARING-POSITION
                   GIVING WS-NEW-CLEARING-POSITION
                   ON SIZE ERROR
                       MOVE EC-BALANCE-OVERFLOW TO TW-STATUS-CODE
               END-SUBTRACT
           END-IF.

       4000-PLAN-TRANSFER.
           PERFORM 4100-PLAN-DEBIT-OF-PRIMARY
           IF TW-IS-ACCEPTED
               ADD TW-AMOUNT TO AT-BALANCE (WS-CONTRA-ENTRY)
                   GIVING WS-NEW-CONTRA-BALANCE
                   ON SIZE ERROR
                       MOVE EC-BALANCE-OVERFLOW TO TW-STATUS-CODE
               END-ADD
           END-IF.

      *    Shared by withdrawals and transfers: the customer account
      *    being debited must keep enough funds and stay within its
      *    daily debit limit.  A subtraction too large for the field
      *    can only mean the balance would fall far below any floor,
      *    so it is reported as insufficient funds.
       4100-PLAN-DEBIT-OF-PRIMARY.
           COMPUTE WS-LOWEST-ALLOWED-BALANCE =
               ZERO - BC-OVERDRAFT-LIMIT

           SUBTRACT TW-AMOUNT FROM AT-BALANCE (WS-PRIMARY-ENTRY)
               GIVING WS-NEW-PRIMARY-BALANCE
               ON SIZE ERROR
                   MOVE EC-INSUFFICIENT-FUNDS TO TW-STATUS-CODE
           END-SUBTRACT
           IF TW-IS-ACCEPTED
               IF WS-NEW-PRIMARY-BALANCE < WS-LOWEST-ALLOWED-BALANCE
                   MOVE EC-INSUFFICIENT-FUNDS TO TW-STATUS-CODE
               END-IF
           END-IF

           IF TW-IS-ACCEPTED
               ADD TW-AMOUNT TO AT-DEBIT-TODAY (WS-PRIMARY-ENTRY)
                   GIVING WS-NEW-DEBIT-TODAY
                   ON SIZE ERROR
                       MOVE EC-DAILY-LIMIT TO TW-STATUS-CODE
               END-ADD
           END-IF
           IF TW-IS-ACCEPTED
               IF WS-NEW-DEBIT-TODAY > BC-DAILY-DEBIT-LIMIT
                   MOVE EC-DAILY-LIMIT TO TW-STATUS-CODE
               END-IF
           END-IF.

      *---------------------------------------------------------------
      * Applying: the transaction passed, so commit the planned
      * figures and describe the two journal entries.
      *---------------------------------------------------------------
       5000-APPLY-POSTING.
           MOVE 2 TO PR-ENTRY-COUNT
           MOVE "DR" TO PR-SIDE (1)
           MOVE "CR" TO PR-SIDE (2)
           MOVE TW-AMOUNT TO PR-AMOUNT (1)
           MOVE TW-AMOUNT TO PR-AMOUNT (2)

           EVALUATE TRUE
               WHEN TW-IS-DEPOSIT
                   PERFORM 5100-APPLY-DEPOSIT
               WHEN TW-IS-WITHDRAWAL
                   PERFORM 5200-APPLY-WITHDRAWAL
               WHEN TW-IS-TRANSFER
                   PERFORM 5300-APPLY-TRANSFER
           END-EVALUATE.

       5100-APPLY-DEPOSIT.
           MOVE WS-NEW-PRIMARY-BALANCE
             TO AT-BALANCE (WS-PRIMARY-ENTRY)
           MOVE WS-NEW-CLEARING-POSITION TO AT-CLEARING-POSITION

           MOVE BC-CLEARING-ACCOUNT      TO PR-ACCOUNT (1)
           MOVE TW-ACCOUNT               TO PR-CONTRA (1)
           MOVE WS-NEW-CLEARING-POSITION TO PR-BALANCE-AFTER (1)

           MOVE TW-ACCOUNT               TO PR-ACCOUNT (2)
           MOVE BC-CLEARING-ACCOUNT      TO PR-CONTRA (2)
           MOVE WS-NEW-PRIMARY-BALANCE   TO PR-BALANCE-AFTER (2).

       5200-APPLY-WITHDRAWAL.
           MOVE WS-NEW-PRIMARY-BALANCE
             TO AT-BALANCE (WS-PRIMARY-ENTRY)
           MOVE WS-NEW-DEBIT-TODAY
             TO AT-DEBIT-TODAY (WS-PRIMARY-ENTRY)
           MOVE WS-NEW-CLEARING-POSITION TO AT-CLEARING-POSITION

           MOVE TW-ACCOUNT               TO PR-ACCOUNT (1)
           MOVE BC-CLEARING-ACCOUNT      TO PR-CONTRA (1)
           MOVE WS-NEW-PRIMARY-BALANCE   TO PR-BALANCE-AFTER (1)

           MOVE BC-CLEARING-ACCOUNT      TO PR-ACCOUNT (2)
           MOVE TW-ACCOUNT               TO PR-CONTRA (2)
           MOVE WS-NEW-CLEARING-POSITION TO PR-BALANCE-AFTER (2).

       5300-APPLY-TRANSFER.
           MOVE WS-NEW-PRIMARY-BALANCE
             TO AT-BALANCE (WS-PRIMARY-ENTRY)
           MOVE WS-NEW-DEBIT-TODAY
             TO AT-DEBIT-TODAY (WS-PRIMARY-ENTRY)
           MOVE WS-NEW-CONTRA-BALANCE
             TO AT-BALANCE (WS-CONTRA-ENTRY)

           MOVE TW-ACCOUNT               TO PR-ACCOUNT (1)
           MOVE TW-CONTRA-ACCOUNT        TO PR-CONTRA (1)
           MOVE WS-NEW-PRIMARY-BALANCE   TO PR-BALANCE-AFTER (1)

           MOVE TW-CONTRA-ACCOUNT        TO PR-ACCOUNT (2)
           MOVE TW-ACCOUNT               TO PR-CONTRA (2)
           MOVE WS-NEW-CONTRA-BALANCE    TO PR-BALANCE-AFTER (2).
