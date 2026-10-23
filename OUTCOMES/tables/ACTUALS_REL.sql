-- POSTMORTEM.OUTCOMES.ACTUALS_REL (table)
-- Reported revenue per case and fiscal year after the review, with growth and the relative day it was
-- reported. Read only by scoring and post-mortems; never part of a packet.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.OUTCOMES.ACTUALS_REL (
	DECISION_KEY VARCHAR(16777216),
	FY_REL VARCHAR(16777216),
	ACTUAL_CUR_M FLOAT,
	ACTUAL_GROWTH_PCT NUMBER(32,2),
	REL_REPORT_DAY NUMBER(9,0)
);
