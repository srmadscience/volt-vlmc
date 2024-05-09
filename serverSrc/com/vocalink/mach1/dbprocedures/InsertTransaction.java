package com.vocalink.mach1.dbprocedures;

import org.voltdb.SQLStmt;
import org.voltdb.VoltProcedure;
import org.voltdb.VoltTable;
import org.voltdb.types.TimestampType;

import java.util.Optional;

public class InsertTransaction extends VoltProcedure {

  private final SQLStmt insert = new SQLStmt(
      "INSERT INTO T_TRANSACTION (transaction_id, amount, reconciliation_cycle, reconciliation_date, " +
          "sender_id, receiver_id, failed, reason_code) " +
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?);"
  );

  private final SQLStmt selectOldest = new SQLStmt(
      "SELECT MIN(insert_timestamp) TS FROM T_TRANSACTION WHERE reconciliation_cycle < ? AND INSERT_TIMESTAMP <= ?;"
  );

  private final SQLStmt delete = new SQLStmt(
      "DELETE FROM T_TRANSACTION WHERE insert_timestamp <= ?;"
  );

  public VoltTable[] run(String transactionId, int amount, String reconciliationCycle, String reconciliationDate,
                         String senderId, String receiverId, int failed, String reasonCode, TimestampType removeBeforeTs)
      throws VoltProcedure.VoltAbortException {

    voltQueueSQL(insert, transactionId, amount, reconciliationCycle, reconciliationDate, senderId, receiverId, failed, reasonCode);
    VoltTable[] result = voltExecuteSQL();
    removeRecordsBefore(reconciliationCycle, removeBeforeTs);

    return result;
  }

  private Optional<TimestampType> getLastRecord(String cycleId, TimestampType removeBeforeTs) {
    voltQueueSQL(selectOldest, cycleId, removeBeforeTs);

    VoltTable[] oldest = voltExecuteSQL();

    Optional<TimestampType> maybeOldestTs = oldest[0].getRowCount() > 0
        ? Optional.ofNullable(oldest[0].fetchRow(0).getTimestampAsTimestamp("TS"))
        : Optional.empty();

    return maybeOldestTs;
  }

  private void delete(TimestampType lastRecordTs) {
    voltQueueSQL(delete, lastRecordTs);
    voltExecuteSQL(true);
  }

  private void removeRecordsBefore(String reconciliationCycle, TimestampType removeBeforeTs) {
    getLastRecord(reconciliationCycle, removeBeforeTs).ifPresent(this::delete);
  }

}
