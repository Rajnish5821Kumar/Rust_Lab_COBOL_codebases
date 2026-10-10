      *****************************************************************
      * ACCOUNT-RECORD.CPY
      *
      * Account master record (LINE SEQUENTIAL, 80 bytes of data).
      * The same layout is used for the opening master that a batch
      * reads and the closing master that it writes, so the closing
      * master of one batch is the opening master of the next.
      *
      * Detail record (one per account, ascending account id):
      *   Cols   Field             Format
      *   01-01  AM-RECORD-TYPE    "A"
      *   02-11  AM-ACCT-ID        10 digits, not all zeros
      *   12-41  AM-ACCT-NAME      printable text
      *   42-42  AM-ACCT-STATUS    A active, F frozen, C closed
      *   43-58  AM-BALANCE        sign (+/-) then 13 digits and
      *                            2 implied decimals
      *
      * Trailer record (exactly one, last record in the file):
      *   01-01  AM-RECORD-TYPE    "T"
      *   02-08  AM-TRAILER-COUNT  number of detail records
      *   09-26  AM-TRAILER-TOTAL  sign then 15 digits and 2 implied
      *                            decimals: sum of all balances
      *
      * The record area is 100 bytes so that a record longer than
      * the 80-byte layout is detected instead of being truncated.
      *****************************************************************
       01  ACCT-MASTER-AREA.
           05  ACCT-MASTER-RECORD.
               10  AM-RECORD-TYPE          PIC X(1).
                   88  AM-IS-DETAIL        VALUE "A".
                   88  AM-IS-TRAILER       VALUE "T".
               10  AM-DETAIL.
                   15  AM-ACCT-ID          PIC X(10).
                   15  AM-ACCT-NAME        PIC X(30).
                   15  AM-ACCT-STATUS      PIC X(1).
                   15  AM-BALANCE          PIC S9(13)V99
                           SIGN IS LEADING SEPARATE CHARACTER.
                   15  AM-DETAIL-FILLER    PIC X(22).
               10  AM-TRAILER REDEFINES AM-DETAIL.
                   15  AM-TRAILER-COUNT    PIC 9(7).
                   15  AM-TRAILER-TOTAL    PIC S9(15)V99
                           SIGN IS LEADING SEPARATE CHARACTER.
                   15  AM-TRAILER-FILLER   PIC X(54).
           05  AM-OVERFLOW-AREA            PIC X(20).
