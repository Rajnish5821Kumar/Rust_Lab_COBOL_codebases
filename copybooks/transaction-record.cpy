      *****************************************************************
      * TRANSACTION-RECORD.CPY
      *
      * Input transaction record (LINE SEQUENTIAL, 80 bytes of data).
      *
      * Every field is held as text so that a damaged record can be
      * read, diagnosed and reported without a data exception.  The
      * validator (TXNVALID) is the only program allowed to treat
      * TXN-AMOUNT-NUMERIC as a number, and only after an explicit
      * NUMERIC class test.
      *
      * The record area is deliberately longer than the layout.  The
      * overflow area lets the reader detect a record that is longer
      * than 80 bytes instead of silently truncating it.
      *
      *   Cols   Field                 Format
      *   01-12  TXN-ID                12 chars, A-Z and 0-9 only
      *   13-20  TXN-DATE              YYYYMMDD
      *   21-21  TXN-TYPE              D deposit, W withdrawal,
      *                                T transfer
      *   22-31  TXN-ACCOUNT           10 digits (account credited
      *                                by D, debited by W and T)
      *   32-41  TXN-CONTRA-ACCOUNT    10 digits for T (account
      *                                credited), spaces otherwise
      *   42-54  TXN-AMOUNT            13 digits, 2 implied decimals
      *   55-80  TXN-DESCRIPTION       free text, optional
      *****************************************************************
       01  TXN-INPUT-AREA.
           05  TXN-RECORD.
               10  TXN-ID                  PIC X(12).
               10  TXN-DATE                PIC X(8).
               10  TXN-TYPE                PIC X(1).
               10  TXN-ACCOUNT             PIC X(10).
               10  TXN-CONTRA-ACCOUNT      PIC X(10).
               10  TXN-AMOUNT              PIC X(13).
               10  TXN-AMOUNT-NUMERIC REDEFINES TXN-AMOUNT
                                           PIC 9(11)V99.
               10  TXN-DESCRIPTION         PIC X(26).
           05  TXN-OVERFLOW-AREA           PIC X(120).
