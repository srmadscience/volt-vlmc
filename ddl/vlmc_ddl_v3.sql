
CREATE TABLE t_transaction (
    transaction_id         VARCHAR(100)       NOT NULL,
    amount               INTEGER                NOT NULL,
    reconciliation_cycle       VARCHAR(15)        NOT NULL,
    reconciliation_date        VARCHAR(50)        NOT NULL,
    sender_id                    VARCHAR(50)        NOT NULL,
    receiver_id          VARCHAR(50)        NOT NULL,
    failed                 TINYINT        DEFAULT 0    NOT NULL,
    reason_code            VARCHAR(50)    DEFAULT ''   NOT NULL,
    insert_timestamp       TIMESTAMP      DEFAULT CURRENT_TIMESTAMP  NOT NULL,
  );
  PARTITION TABLE t_transaction ON COLUMN transaction_id;
  CREATE INDEX T_TRANSACTION_TIMESTAMP_IDX ON T_TRANSACTION (INSERT_TIMESTAMP);
  CREATE INDEX T_TRANSACTION_MESSAGE_ID_IDX ON T_TRANSACTION (TRANSACTION_ID);
  CREATE INDEX T_TRANSACTION_RECONCILIATION_CYCLE_IDX ON T_TRANSACTION (RECONCILIATION_CYCLE);
 

load classes ../jars/vlmc-server.jar;

CREATE PROCEDURE 
   PARTITION ON TABLE t_transaction COLUMN transaction_id
   FROM CLASS com.vocalink.mach1.dbprocedures.InsertTransaction;

