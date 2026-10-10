#!/usr/bin/awk -f
#
# generate-scale-data.awk - write large synthetic files for the scale
# and resource-limit tests.  The files are generated at test time
# rather than stored, because they are large and entirely regular.
#
# Usage:
#   awk -v mode=accounts     -v count=N           -f this-file
#   awk -v mode=transactions -v count=N -v accounts=A -f this-file
#   awk -v mode=history      -v count=N           -f this-file
#
# accounts      N active accounts 2000000001.. each with a balance of
#               1,000,000.00, then the trailer.
# transactions  N valid transactions dated 2026-01-15 against the
#               first A accounts: record i is a deposit, withdrawal
#               or transfer according to i mod 3, for an amount of
#               (i mod 5000) + 1 cents, so every one can be posted.
# history       N history records HST000000001.. dated 2026-01-01.
#
# Large numbers are printed with %.0f, not %d, because %d is limited
# to 32 bits in some awk implementations.

BEGIN {
    if (mode == "accounts") {
        for (i = 1; i <= count; i++)
            printf "A%.0f%-30s%s+%015.0f\n", 2000000000 + i, \
                   sprintf("SCALE ACCOUNT %05d", i), "A", 100000000
        printf "T%07d+%017.0f\n", count, count * 100000000
    } else if (mode == "transactions") {
        for (i = 1; i <= count; i++) {
            account = 2000000001 + (i % accounts)
            contra = ""
            if (i % 3 == 1) {
                type = "D"
            } else if (i % 3 == 2) {
                type = "W"
            } else {
                type = "T"
                contra = sprintf("%.0f", 2000000001 + ((i + 1) % accounts))
            }
            printf "SCL%09d20260115%s%.0f%-10s%013d%s\n", i, type, \
                   account, contra, (i % 5000) + 1, "SCALE TEST"
        }
    } else if (mode == "history") {
        for (i = 1; i <= count; i++)
            printf "HST%09d20260101\n", i
    } else {
        print "generate-scale-data.awk: unknown mode" > "/dev/stderr"
        exit 2
    }
}
