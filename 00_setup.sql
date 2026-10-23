-- 00_setup.sql
-- Account prerequisites and the database skeleton. Safe to re-run (IF NOT EXISTS).
--
-- NOTE: GET_DDL cannot export warehouses or stages. The statements below are
-- reconstructed from SHOW WAREHOUSES / SHOW STAGES on the source account, not
-- exported verbatim. PM_WH is a Gen2 standard warehouse on the source account;
-- set that here if your account supports it.

CREATE WAREHOUSE IF NOT EXISTS PM_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

CREATE DATABASE IF NOT EXISTS POSTMORTEM;

CREATE SCHEMA IF NOT EXISTS POSTMORTEM.MASKED;     -- masked packets: positions, revenue history, consensus, guidance, documents
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.OUTCOMES;   -- reported (actual) revenue, relative to the review date
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.RESULTS;    -- replays, post-mortems, learning loop, evals
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.EXPLORER;   -- read-only views for the Explorer agent
CREATE SCHEMA IF NOT EXISTS POSTMORTEM.LIVE;       -- the live (no outcome yet) sanity-check case

-- Internal stages (no credentials, no external URLs).
CREATE STAGE IF NOT EXISTS POSTMORTEM.RESULTS.EVAL_STAGE;
CREATE STAGE IF NOT EXISTS POSTMORTEM.EXPLORER.EVAL_STAGE;
CREATE STAGE IF NOT EXISTS POSTMORTEM.LIVE.EVAL_STAGE;

-- These two report type "INTERNAL NO CSE" (server-side encryption only).
CREATE STAGE IF NOT EXISTS POSTMORTEM.LIVE.LIVE_STAGE
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
CREATE STAGE IF NOT EXISTS POSTMORTEM.MASKED.IMPORT_STAGE
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
