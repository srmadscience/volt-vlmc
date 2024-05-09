  -- Beginning of Payment Gateway DDL
  DROP PROCEDURE delete_message_pacs002 IF EXISTS;
  DROP PROCEDURE delete_message_pacs008 IF EXISTS;
  DROP PROCEDURE select_message_pacs002 IF EXISTS;
  DROP PROCEDURE select_message_pacs008 IF EXISTS;
  DROP PROCEDURE UpdateParticipant IF EXISTS;
  DROP PROCEDURE InsertPacs008Message IF EXISTS;
  DROP PROCEDURE InsertPacs002Message IF EXISTS;
  DROP TABLE T_MESSAGE_PACS002 IF EXISTS;
  DROP TABLE T_MESSAGE_PACS008 IF EXISTS;
  CREATE TABLE T_MESSAGE_PACS002 (
    MESSAGE_ID varchar(100) NOT NULL,
    MESSAGE varbinary(16384) NOT NULL,
    INSERT_TIMESTAMP timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL
  );
  PARTITION TABLE T_MESSAGE_PACS002 ON COLUMN MESSAGE_ID;
  CREATE INDEX INSERT_PACS002_TIMESTAMP_IDX ON T_MESSAGE_PACS002 (INSERT_TIMESTAMP);
  CREATE INDEX PACS002_MESSAGE_ID_IDX ON T_MESSAGE_PACS002 (MESSAGE_ID);
  CREATE TABLE T_MESSAGE_PACS008 (
    MESSAGE_ID varchar(100) NOT NULL,
    MESSAGE varbinary(16384) NOT NULL,
    INSERT_TIMESTAMP timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL
  );
  PARTITION TABLE T_MESSAGE_PACS008 ON COLUMN MESSAGE_ID;
  CREATE INDEX INSERT_PACS008_TIMESTAMP_IDX ON T_MESSAGE_PACS008 (INSERT_TIMESTAMP);
  CREATE INDEX PACS008_MESSAGE_ID_IDX ON T_MESSAGE_PACS008 (MESSAGE_ID);
  CREATE PROCEDURE select_message_pacs002 AS SELECT message_id, message FROM T_MESSAGE_PACS002 WHERE message_id = ?;
  PARTITION PROCEDURE select_message_pacs002 ON TABLE T_MESSAGE_PACS002 COLUMN MESSAGE_ID;
  CREATE PROCEDURE select_message_pacs008 AS SELECT message_id, message FROM T_MESSAGE_PACS008 WHERE message_id = ?;
  PARTITION PROCEDURE select_message_pacs008 ON TABLE T_MESSAGE_PACS008 COLUMN MESSAGE_ID;

  DROP PROCEDURE select_participant_by_routing_number IF EXISTS;
  DROP PROCEDURE select_latest_update_timestamp IF EXISTS;
  DROP TABLE T_PARTICIPANT IF EXISTS;
  DROP TABLE T_ROUTING_TABLE IF EXISTS;
  CREATE TABLE T_PARTICIPANT (
    ID varchar(100) NOT NULL,
    PARTICIPANT_CODE varchar(32) NOT NULL,
    ACCOUNT_NUMBER varchar(50) NOT NULL,
    UPDATED_TIMESTAMP timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY(ID)
  );
  CREATE INDEX INSERT_PARTICIPANT_TIMESTAMP_IDX ON T_PARTICIPANT (UPDATED_TIMESTAMP);
  CREATE INDEX PARTICIPANT_ID_IDX ON T_PARTICIPANT (ID);
  CREATE TABLE T_ROUTING_TABLE (
    ROUTING_NUMBER varchar(12) NOT NULL,
    PARTICIPANT_ID varchar(100) NOT NULL,
    INSERT_TIMESTAMP timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY(ROUTING_NUMBER)
  );
  CREATE INDEX INSERT_ROUTING_TABLE_TIMESTAMP_IDX ON T_ROUTING_TABLE (INSERT_TIMESTAMP);
  CREATE INDEX ROUTING_TABLE_PARTICIPANT_ID_IDX ON T_ROUTING_TABLE (ROUTING_NUMBER);
  CREATE PROCEDURE select_participants_by_routing_number
    AS
  BEGIN
      SELECT * FROM T_ROUTING_TABLE as R, T_PARTICIPANT as P WHERE R.ROUTING_NUMBER IN (?, ?) AND P.ID = R.PARTICIPANT_ID;
  END;
  CREATE PROCEDURE select_latest_update_timestamp AS
  BEGIN
    SELECT MAX(UPDATED_TIMESTAMP) as UPDATED_TIMESTAMP FROM T_PARTICIPANT;
  END;
  LOAD CLASSES /etc/stored-procedures/pg/pg-voltdb-procedures.jar;
  CREATE PROCEDURE FROM CLASS com.vocalink.mach1.dbprocedures.UpdateParticipant;
  CREATE PROCEDURE
    PARTITION ON TABLE T_MESSAGE_PACS008 COLUMN MESSAGE_ID
    FROM CLASS com.vocalink.mach1.dbprocedures.InsertPacs008Message;
  CREATE PROCEDURE
    PARTITION ON TABLE T_MESSAGE_PACS002 COLUMN MESSAGE_ID
  FROM CLASS com.vocalink.mach1.dbprocedures.InsertPacs002Message;
  -- End of Payment Gateway DDL
  -- Beginning of Payments Processor DDL
  DROP PROCEDURE GetTransactionsSummary IF EXISTS;
  DROP PROCEDURE select_summary_reconciliation_cycle IF EXISTS;
  DROP PROCEDURE InsertTransaction IF EXISTS;
  DROP VIEW v_reconciliation_cycle_summary IF EXISTS;
  DROP VIEW v_credits IF EXISTS;
  DROP VIEW v_debits IF EXISTS;
  DROP TABLE t_transaction IF EXISTS;

  CREATE TABLE t_transaction (
    transaction_id         VARCHAR(100)       NOT NULL,
    amount            	 INTEGER        	NOT NULL,
    reconciliation_cycle       VARCHAR(15)        NOT NULL,
    reconciliation_date        VARCHAR(50)        NOT NULL,
    sender_id        		 VARCHAR(50)        NOT NULL,
    receiver_id        	 VARCHAR(50)        NOT NULL,
    failed                 TINYINT        DEFAULT 0    NOT NULL,
    reason_code            VARCHAR(50)    DEFAULT ''   NOT NULL,
    insert_timestamp       TIMESTAMP      DEFAULT CURRENT_TIMESTAMP  NOT NULL,
  );
  PARTITION TABLE t_transaction ON COLUMN transaction_id;
  CREATE INDEX T_TRANSACTION_TIMESTAMP_IDX ON T_TRANSACTION (INSERT_TIMESTAMP);
  CREATE INDEX T_TRANSACTION_MESSAGE_ID_IDX ON T_TRANSACTION (TRANSACTION_ID);
  CREATE INDEX T_TRANSACTION_RECONCILIATION_CYCLE_IDX ON T_TRANSACTION (RECONCILIATION_CYCLE);
  DR TABLE t_transaction;
  CREATE VIEW v_reconciliation_cycle_summary (reconciliation_cycle, failed, total_amount, total_count) AS
  SELECT reconciliation_cycle, failed, SUM(amount), COUNT(*)
  FROM t_transaction GROUP BY reconciliation_cycle, failed;
  CREATE index v_reconciliation_cycle_summary_idx ON v_reconciliation_cycle_summary (reconciliation_cycle);
  CREATE VIEW v_credits(reconciliation_cycle, creditorId, failed, credit, ct) as
  SELECT reconciliation_cycle, receiver_id, failed, sum(amount), count(*)
  FROM t_transaction
  GROUP BY reconciliation_cycle, receiver_id, failed;
  CREATE index v_credits_idx ON v_credits (reconciliation_cycle);
  CREATE VIEW v_debits(reconciliation_cycle, debitorId, failed, debit, ct) as
  SELECT reconciliation_cycle, sender_id, failed, sum(amount), count(*)
  FROM t_transaction
  GROUP BY reconciliation_cycle, sender_id, failed;
  CREATE index v_debits_idx ON v_debits (reconciliation_cycle);
  LOAD CLASSES /etc/stored-procedures/pp/pp-voltdb-procedures.jar;
  CREATE PROCEDURE FROM CLASS com.vocalink.mach1.dbprocedures.GetTransactionsSummary;
  CREATE PROCEDURE PARTITION ON TABLE T_TRANSACTION COLUMN TRANSACTION_ID FROM CLASS com.vocalink.mach1.dbprocedures.InsertTransaction;
  -- End of Payments Processor DDL