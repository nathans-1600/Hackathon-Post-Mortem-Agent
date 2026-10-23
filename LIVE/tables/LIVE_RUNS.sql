-- POSTMORTEM.LIVE.LIVE_RUNS (table)
-- Live forecasts per variant (raw, playbook, full) and model: FY+1 to FY+3 growth, confidence, parsed and raw
-- response, and the playbook used.
--
-- Written by: SP_LIVE_REPLAY
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.LIVE_RUNS (
	RUN_ID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	VARIANT VARCHAR(16777216),
	MODEL VARCHAR(16777216),
	RUN_AT TIMESTAMP_LTZ(9),
	FY1_GROWTH_PCT FLOAT,
	FY2_GROWTH_PCT FLOAT,
	FY3_GROWTH_PCT FLOAT,
	CONFIDENCE NUMBER(38,0),
	PARSED VARIANT,
	RAW_RESPONSE VARCHAR(16777216),
	PROMPT_CHARS NUMBER(38,0),
	PLAYBOOK_ID VARCHAR(16777216)
);
