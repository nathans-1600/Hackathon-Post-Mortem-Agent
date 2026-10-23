-- POSTMORTEM.LIVE.PARNASSUS_PROJ (table)
-- The Firm_X analyst's projections for the live case, per fiscal year (same shape as MASKED.PARNASSUS_PROJ).
--
-- The table name is the literal source label; leave it as-is.
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.PARNASSUS_PROJ (
	DECISION_KEY VARCHAR(16777216),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	GROWTH_PCT FLOAT
);
