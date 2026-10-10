      *****************************************************************
      * LEDGER-RECORD.CPY
      *
      * Journal (ledger) entry record (LINE SEQUENTIAL, 98 bytes).
      *
      * Every posted transaction produces exactly two entries with
      * consecutive sequence numbers: the debit entry first (odd
      * sequence number) and the matching credit entry second (even
      * sequence number), both for the same amount.  Rejected
      * transactions produce no entries.
      *
      *   Cols   Field             Format
      *   01-08  JR-SEQUENCE       8 digits, 1..n with no gaps
      *   09-20  JR-TXN-ID         transaction id
      *   21-28  JR-TXN-DATE       YYYYMMDD from the transaction
      *   29-29  JR-TXN-TYPE       D, W or T
      *   30-39  JR-ACCOUNT        account the entry is posted to
      *   40-41  JR-SIDE           DR or CR
      *   42-54  JR-AMOUNT         13 digits, 2 implied decimals
      *   55-72  JR-BALANCE-AFTER  sign then 15 digits, 2 implied
      *                            decimals: balance of JR-ACCOUNT
      *                            after this entry
      *   73-82  JR-CONTRA         the other account of the pair
      *   83-90  JR-BATCH-DATE     YYYYMMDD of the posting batch
      *   91-98  JR-SOURCE-RECORD  input record number of the
      *                            transaction in its batch file
      *
      * The record area is 120 bytes so that an over-long record is
      * detected by the reconciliation program.
      *****************************************************************
       01  JOURNAL-AREA.
           05  JOURNAL-RECORD.
               10  JR-SEQUENCE             PIC 9(8).
               10  JR-TXN-ID               PIC X(12).
               10  JR-TXN-DATE             PIC X(8).
               10  JR-TXN-TYPE             PIC X(1).
               10  JR-ACCOUNT              PIC X(10).
               10  JR-SIDE                 PIC X(2).
                   88  JR-IS-DEBIT         VALUE "DR".
                   88  JR-IS-CREDIT        VALUE "CR".
               10  JR-AMOUNT               PIC 9(11)V99.
               10  JR-BALANCE-AFTER        PIC S9(15)V99
                       SIGN IS LEADING SEPARATE CHARACTER.
               10  JR-CONTRA               PIC X(10).
               10  JR-BATCH-DATE           PIC 9(8).
               10  JR-SOURCE-RECORD        PIC 9(8).
           05  JR-OVERFLOW-AREA            PIC X(22).
