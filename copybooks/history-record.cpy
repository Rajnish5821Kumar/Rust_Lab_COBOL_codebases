      *****************************************************************
      * HISTORY-RECORD.CPY
      *
      * Posted-transaction history record (LINE SEQUENTIAL, 20 bytes).
      * One record per transaction id that has ever been posted.  The
      * file is what lets a later batch recognise a transaction that
      * an earlier batch already posted.
      *
      *   Cols   Field             Format
      *   01-12  HR-TXN-ID         transaction id
      *   13-20  HR-POSTED-DATE    YYYYMMDD batch date of posting
      *
      * The record area is 40 bytes so that an over-long record is
      * detected instead of being truncated.
      *****************************************************************
       01  HISTORY-AREA.
           05  HISTORY-RECORD.
               10  HR-TXN-ID               PIC X(12).
               10  HR-POSTED-DATE          PIC X(8).
           05  HR-OVERFLOW-AREA            PIC X(20).
