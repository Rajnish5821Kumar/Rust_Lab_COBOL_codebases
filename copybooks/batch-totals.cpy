      *****************************************************************
      * BATCH-TOTALS.CPY
      *
      * Control totals accumulated in memory while a batch runs.
      * They are printed in the summary report and compared with the
      * totals that reconciliation recomputes from the files on disk.
      *****************************************************************
       01  BATCH-TOTALS.
           05  BT-RECORDS-READ             PIC 9(8) BINARY.
           05  BT-POSTED-COUNT             PIC 9(8) BINARY.
           05  BT-REJECTED-COUNT           PIC 9(8) BINARY.
           05  BT-DEPOSIT-COUNT            PIC 9(8) BINARY.
           05  BT-WITHDRAWAL-COUNT         PIC 9(8) BINARY.
           05  BT-TRANSFER-COUNT           PIC 9(8) BINARY.
           05  BT-DEPOSIT-AMOUNT           PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-WITHDRAWAL-AMOUNT        PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-TRANSFER-AMOUNT          PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-JOURNAL-ENTRIES          PIC 9(8) BINARY.
           05  BT-TOTAL-DEBITS             PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-TOTAL-CREDITS            PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-OPENING-ACCOUNTS         PIC 9(8) BINARY.
           05  BT-OPENING-TOTAL            PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-CLOSING-TOTAL            PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-CLEARING-POSITION        PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  BT-HISTORY-LOADED           PIC 9(8) BINARY.
           05  BT-HISTORY-SAVED            PIC 9(8) BINARY.
           05  BT-RETURN-CODE              PIC 9(4) BINARY.
