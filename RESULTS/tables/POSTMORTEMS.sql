-- POSTMORTEM.RESULTS.POSTMORTEMS (table)
-- Post-mortems: the parsed JSON (findings in three groups, bias tags, lessons, data checklist) and the raw
-- model response, per case and mode.
--
-- Written by: SP_POSTMORTEM
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.POSTMORTEMS (
	POSTMORTEM_ID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	MODEL VARCHAR(16777216),
	CREATED_AT TIMESTAMP_LTZ(9),
	PARSED VARIANT,
	RAW_RESPONSE VARCHAR(16777216),
	MODE VARCHAR(16777216)
);
