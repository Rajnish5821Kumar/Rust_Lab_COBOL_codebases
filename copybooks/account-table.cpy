      *****************************************************************
      * ACCOUNT-TABLE.CPY
      *
      * In-memory account table, loaded from an account master file
      * by ACCTSTOR.  Entries are in ascending account-id order (the
      * master file is required to be in that order) so SEARCH ALL
      * can be used.
      *
      * The copybook is written with the tag :AT: so that a program
      * needing two tables at once (RECONCIL holds the opening and
      * the closing master) can copy it twice:
      *
      *     COPY "account-table.cpy" REPLACING ==:AT:== BY ==AT==.
      *
      * :AT:-CLEARING-POSITION is the running balance of the reserved
      * clearing account for the current batch.  It starts each batch
      * at zero; a debit to clearing (a deposit) increases it and a
      * credit to clearing (a withdrawal) decreases it.
      *
      * The table capacity (5000) is a documented resource limit;
      * ACCTSTOR reports F009 if a master file holds more accounts.
      * The limit appears three times below (once per VALUE/OCCURS).
      *****************************************************************
       01  :AT:-ACCOUNT-TABLE.
           05  :AT:-MAX-ACCOUNTS           PIC 9(8) BINARY
                                           VALUE 5000.
           05  :AT:-TOTAL-BALANCE          PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  :AT:-CLEARING-POSITION      PIC S9(15)V99
                                           PACKED-DECIMAL.
           05  :AT:-ACCOUNT-COUNT          PIC 9(8) BINARY.
           05  :AT:-ENTRY OCCURS 0 TO 5000 TIMES
                   DEPENDING ON :AT:-ACCOUNT-COUNT
                   ASCENDING KEY IS :AT:-ACCT-ID
                   INDEXED BY :AT:-IDX.
               10  :AT:-ACCT-ID            PIC X(10).
               10  :AT:-ACCT-NAME          PIC X(30).
               10  :AT:-ACCT-STATUS        PIC X(1).
                   88  :AT:-IS-ACTIVE      VALUE "A".
                   88  :AT:-STATUS-IS-VALID VALUE "A" "F" "C".
               10  :AT:-BALANCE            PIC S9(13)V99
                                           PACKED-DECIMAL.
               10  :AT:-DEBIT-TODAY        PIC S9(13)V99
                                           PACKED-DECIMAL.
