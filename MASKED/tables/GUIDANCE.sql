-- POSTMORTEM.MASKED.GUIDANCE (table)
-- Management revenue guidance issued before the review: period, low/high amount and/or growth range, and the
-- relative day it was issued.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.GUIDANCE (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	PERIOD_REL VARCHAR(16777216),
	LOW_CUR_M FLOAT,
	HIGH_CUR_M FLOAT,
	GROWTH_LOW_PCT NUMBER(6,2),
	GROWTH_HIGH_PCT NUMBER(6,2)
);
