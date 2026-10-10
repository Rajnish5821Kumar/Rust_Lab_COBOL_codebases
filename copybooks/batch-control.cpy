      *****************************************************************
      * BATCH-CONTROL.CPY
      *
      * Business parameters for one batch run, as loaded from the
      * control file by CTLLOAD.  Nothing in the system reads the
      * system clock: the batch date comes from here, which is what
      * makes a run repeatable.
      *
      * BC-CLEARING-ACCOUNT is the reserved internal account that
      * carries the other side of every deposit and withdrawal.
      *****************************************************************
       01  BATCH-CONTROL.
           05  BC-BATCH-ID                 PIC X(8).
           05  BC-BATCH-DATE               PIC 9(8).
           05  BC-BATCH-DAY-NUMBER         PIC 9(8) BINARY.
           05  BC-MAX-DEPOSIT              PIC S9(11)V99
                                           PACKED-DECIMAL.
           05  BC-MAX-WITHDRAWAL           PIC S9(11)V99
                                           PACKED-DECIMAL.
           05  BC-MAX-TRANSFER             PIC S9(11)V99
                                           PACKED-DECIMAL.
           05  BC-DAILY-DEBIT-LIMIT        PIC S9(11)V99
                                           PACKED-DECIMAL.
           05  BC-OVERDRAFT-LIMIT          PIC S9(11)V99
                                           PACKED-DECIMAL.
           05  BC-MAX-BACKDATE-DAYS        PIC 9(4) BINARY.
           05  BC-CLEARING-ACCOUNT         PIC X(10).
