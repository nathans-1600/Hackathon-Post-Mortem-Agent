-- POSTMORTEM.RESULTS.BIAS_TAGS (table)
-- Bias tags from the latest masked post-mortem per case: tag, whose forecast it describes (about), strength
-- and evidence.
--
-- Written by: SP_POSTMORTEM
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.BIAS_TAGS (
	POSTMORTEM_ID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	TAG VARCHAR(16777216),
	EVIDENCE VARCHAR(16777216),
	STRENGTH NUMBER(38,0),
	ABOUT VARCHAR(16777216)
);
