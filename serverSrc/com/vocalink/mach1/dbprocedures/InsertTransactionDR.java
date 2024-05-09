package com.vocalink.mach1.dbprocedures;

import org.voltdb.SQLStmt;
import org.voltdb.VoltProcedure;
import org.voltdb.VoltTable;
import org.voltdb.types.TimestampType;

public class InsertTransactionDR extends VoltProcedure {

    private final SQLStmt insert = new SQLStmt(
            "INSERT INTO T_TRANSACTION (transaction_id, amount, reconciliation_cycle, reconciliation_date, "
                    + "sender_id, receiver_id, failed, reason_code) " + "VALUES (?, ?, ?, ?, ?, ?, ?, ?);");

    private final SQLStmt selectOldest = new SQLStmt(
            "SELECT MIN(insert_timestamp) TS FROM T_TRANSACTION WHERE INSERT_TIMESTAMP < ?;");

    private final SQLStmt getDeletes = new SQLStmt("SELECT * FROM T_TRANSACTION "
            + "WHERE insert_timestamp = ? AND reconciliation_cycle||'' < ? ORDER BY transaction_id;");

    private final SQLStmt doDelete = new SQLStmt("DELETE FROM T_TRANSACTION WHERE transaction_id = ?;");

    public VoltTable[] run(String transactionId, int amount, String reconciliationCycle, String reconciliationDate,
            String senderId, String receiverId, int failed, String reasonCode, TimestampType removeBeforeTs)
            throws VoltProcedure.VoltAbortException {

        // Find oldest, but only if INSERT_TIMESTAMP < (delete date -DELETE_LAG)
        // seconds)..
        voltQueueSQL(selectOldest, removeBeforeTs);

        // Add row
        voltQueueSQL(insert, transactionId, amount, reconciliationCycle, reconciliationDate, senderId, receiverId,
                failed, reasonCode);

        VoltTable[] result = voltExecuteSQL();

        // We'll only have found a row here if there is at least one record 10
        // seconds older than our cutoff.
        if (result[0].advanceRow()) {

            TimestampType oldestTs = result[0].getTimestampAsTimestamp("TS");

            if (oldestTs != null) {

                voltQueueSQL(getDeletes, oldestTs, reconciliationCycle);
                VoltTable[] purgeList = voltExecuteSQL();

                while (purgeList[0].advanceRow()) {
                    
                    // Note that we could also export these rows...
                    voltQueueSQL(doDelete, purgeList[0].getString("transaction_id"));
                }

                voltExecuteSQL(true);
            }
        }

        return result;
    }

}
