      *****************************************************************
      * TXN-WORK.CPY
      *
      * Working image of the transaction currently being processed.
      * TXNREAD fills the record number, raw length and unprintable
      * flag; TXNVALID fills the rest and sets TW-STATUS-CODE; ACCTPROC
      * may replace TW-STATUS-CODE with a business-rule code.
      *
      * The text fields always hold what was in the input record, even
      * when it is invalid, so the reject report can show the operator
      * exactly what was received.  TW-AMOUNT is only meaningful when
      * the amount field passed its numeric test; otherwise it is zero.
      *****************************************************************
       01  TXN-WORK-AREA.
           05  TW-RECORD-NUMBER            PIC 9(8) BINARY.
           05  TW-RAW-LENGTH               PIC 9(4) BINARY.
           05  TW-UNPRINTABLE-FLAG         PIC X(1).
               88  TW-HAS-UNPRINTABLE      VALUE "Y".
           05  TW-TXN-ID                   PIC X(12).
           05  TW-TXN-DATE                 PIC X(8).
           05  TW-TXN-DAY-NUMBER           PIC 9(8) BINARY.
           05  TW-TXN-TYPE                 PIC X(1).
               88  TW-IS-DEPOSIT           VALUE "D".
               88  TW-IS-WITHDRAWAL        VALUE "W".
               88  TW-IS-TRANSFER          VALUE "T".
               88  TW-TYPE-IS-VALID        VALUE "D" "W" "T".
           05  TW-ACCOUNT                  PIC X(10).
           05  TW-CONTRA-ACCOUNT           PIC X(10).
           05  TW-AMOUNT-TEXT              PIC X(13).
           05  TW-AMOUNT                   PIC S9(11)V99
                                           PACKED-DECIMAL.
           05  TW-DESCRIPTION              PIC X(26).
           05  TW-STATUS-CODE              PIC X(4).
               88  TW-IS-ACCEPTED          VALUE "0000".
