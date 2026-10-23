-- POSTMORTEM.RESULTS.EVAL_HISTORY (table)
-- Mean score per metric for each evaluation run of the semantic view and the agents.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.EVAL_HISTORY (
	CAPTURED_AT TIMESTAMP_LTZ(9),
	RUN_NAME VARCHAR(16777216),
	TARGET VARCHAR(16777216),
	METRIC_NAME VARCHAR(16777216),
	METRIC_TYPE VARCHAR(16777216),
	AVG_SCORE FLOAT,
	N NUMBER(38,0),
	REF_BUILT_AT TIMESTAMP_LTZ(9)
);
