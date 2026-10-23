-- POSTMORTEM.MASKED.CONSENSUS (table)
-- Consensus revenue estimates per case and fiscal year (FY+1 to FY+3) as of the day before the review, with
-- the number of estimates. Masked amounts (CUR m).
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.CONSENSUS (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	NUM_ESTIMATES NUMBER(38,0)
);
