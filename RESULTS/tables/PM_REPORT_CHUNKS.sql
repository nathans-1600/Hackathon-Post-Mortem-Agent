-- POSTMORTEM.RESULTS.PM_REPORT_CHUNKS (table)
-- Post-mortem report text split into sections and chunks; indexed by the PM_REPORT_SEARCH Cortex Search
-- service.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.PM_REPORT_CHUNKS (
	CHUNK_ID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	SECTION VARCHAR(50),
	CHUNK VARCHAR(16777216)
);
