      *****************************************************************
      * POSTING-RESULT.CPY
      *
      * What ACCTPROC did with one accepted transaction: the pair of
      * journal entries to be written.  Entry 1 is always the debit
      * and entry 2 the credit, for the same amount.
      *
      *   Type        Entry 1 (DR)            Entry 2 (CR)
      *   Deposit     clearing account        customer account
      *   Withdrawal  customer account        clearing account
      *   Transfer    source account          destination account
      *
      * PR-ENTRY-COUNT is zero when the transaction was rejected.
      *****************************************************************
       01  POSTING-RESULT.
           05  PR-ENTRY-COUNT              PIC 9(1).
           05  PR-ENTRY OCCURS 2 TIMES.
               10  PR-ACCOUNT              PIC X(10).
               10  PR-SIDE                 PIC X(2).
               10  PR-AMOUNT               PIC S9(11)V99
                                           PACKED-DECIMAL.
               10  PR-BALANCE-AFTER        PIC S9(15)V99
                                           PACKED-DECIMAL.
               10  PR-CONTRA               PIC X(10).
