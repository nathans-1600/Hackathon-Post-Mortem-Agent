-- POSTMORTEM.MASKED.PARNASSUS_PROJ (table)
-- Firm_X's own projections from each investment review, per fiscal year (revenue and growth).
--
-- The table name is the literal source label; leave it as-is.
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.PARNASSUS_PROJ (
	DECISION_KEY VARCHAR(16777216),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	GROWTH_PCT NUMBER(6,2)
);
