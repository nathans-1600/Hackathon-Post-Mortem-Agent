-- PM_WH (warehouse)
-- The warehouse every query, procedure, search service and agent in POSTMORTEM runs on.
--
-- Reconstructed from SHOW WAREHOUSES on the source account (GET_DDL cannot export warehouses).
-- The source warehouse is a Gen2 standard warehouse; set that here if your account supports it.
-- Safe to re-run (IF NOT EXISTS).

CREATE WAREHOUSE IF NOT EXISTS PM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
