-- POSTMORTEM.MASKED.POSITIONS (table)
-- One row per case (decision_key): masked company id, live flag, fiscal-year labels and tier (A = review
-- after the forecaster's training cutoff, B = before).
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.POSITIONS (
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	IS_LIVE BOOLEAN,
	FY1 VARCHAR(16777216),
	FY2 VARCHAR(16777216),
	FY3 VARCHAR(16777216),
	TIER VARCHAR(16777216)
);
