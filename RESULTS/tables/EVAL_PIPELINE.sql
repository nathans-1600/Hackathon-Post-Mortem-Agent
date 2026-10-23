-- POSTMORTEM.RESULTS.EVAL_PIPELINE (table)
-- Results of the pipeline and hindsight-gate checks, one row per check per run. PIPELINE_STATUS shows the
-- latest run.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.EVAL_PIPELINE (
	CHECKED_AT TIMESTAMP_LTZ(9),
	CHECK_ID VARCHAR(16777216),
	KIND VARCHAR(16777216),
	CHECK_NAME VARCHAR(16777216),
	RESULT VARCHAR(16777216),
	DETAIL VARCHAR(16777216)
);
