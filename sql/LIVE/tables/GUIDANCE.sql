-- POSTMORTEM.LIVE.GUIDANCE (table)
-- Management revenue guidance for the live case (same shape as MASKED.GUIDANCE).
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.GUIDANCE (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	PERIOD_REL VARCHAR(16777216),
	LOW_CUR_M FLOAT,
	HIGH_CUR_M FLOAT,
	GROWTH_LOW_PCT FLOAT,
	GROWTH_HIGH_PCT FLOAT
);
