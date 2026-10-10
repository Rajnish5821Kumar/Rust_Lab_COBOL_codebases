      *****************************************************************
      * RECON-RESULT.CPY
      *
      * Request and result areas for RECONCIL.  Reconciliation works
      * only from the three files named in the request; it shares no
      * memory with the posting run, which is what makes it an
      * independent check.
      *
      * At most 20 discrepancies are kept in detail.  The full number
      * found is always in RR-DISCREPANCY-COUNT.
      *****************************************************************
       01  RECON-REQUEST.
           05  RQ-OPENING-PATH             PIC X(256).
           05  RQ-JOURNAL-PATH             PIC X(256).
           05  RQ-CLOSING-PATH             PIC X(256).

       01  RECON-RESULT.
           05  RR-STATUS                   PIC X(1).
               88  RR-NOT-RUN              VALUE "N".
               88  RR-PASSED               VALUE "P".
               88  RR-FAILED               VALUE "F".
               88  RR-ABORTED              VALUE "A".
           05  RR-FATAL-CODE               PIC X(4).
           05  RR-FATAL-DETAIL             PIC X(60).
           05  RR-JOURNAL-ENTRIES          PIC 9(8) BINARY.
           05  RR-ACCOUNTS-COMPARED        PIC 9(8) BINARY.
           05  RR-TOTAL-DEBITS             PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  RR-TOTAL-CREDITS            PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  RR-OPENING-TOTAL            PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  RR-EXPECTED-CLOSING         PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  RR-CLOSING-TOTAL            PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  RR-CLEARING-POSITION        PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  RR-DISCREPANCY-COUNT        PIC 9(8) BINARY.
           05  RR-DETAIL-COUNT             PIC 9(4) BINARY.
           05  RR-DETAIL OCCURS 20 TIMES.
               10  RR-D-CODE               PIC X(4).
               10  RR-D-KEY                PIC X(12).
               10  RR-D-EXPECTED           PIC S9(15)V99
                                           PACKED-DECIMAL.
               10  RR-D-ACTUAL             PIC S9(15)V99
                                           PACKED-DECIMAL.
