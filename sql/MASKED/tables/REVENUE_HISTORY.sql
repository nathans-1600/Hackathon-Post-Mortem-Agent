-- POSTMORTEM.MASKED.REVENUE_HISTORY (table)
-- Reported revenue per case and period (FY0, earlier years, FY+1 quarters) known at D0, with the relative day
-- each figure was reported.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.REVENUE_HISTORY (
	DECISION_KEY VARCHAR(16777216),
	PERIOD_REL VARCHAR(16777216),
	REL_REPORT_DAY NUMBER(9,0),
	REVENUE_CUR_M FLOAT
);
