-- POSTMORTEM.LIVE.CONSENSUS (table)
-- Consensus revenue estimates for the live case, per fiscal year (same shape as MASKED.CONSENSUS).
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.CONSENSUS (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	NUM_ESTIMATES NUMBER(38,0)
);
