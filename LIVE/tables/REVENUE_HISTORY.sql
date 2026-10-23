-- POSTMORTEM.LIVE.REVENUE_HISTORY (table)
-- Reported revenue of the live case known at D0 (same shape as MASKED.REVENUE_HISTORY).
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.REVENUE_HISTORY (
	DECISION_KEY VARCHAR(16777216),
	PERIOD_REL VARCHAR(16777216),
	REL_REPORT_DAY NUMBER(38,0),
	REVENUE_CUR_M FLOAT
);
