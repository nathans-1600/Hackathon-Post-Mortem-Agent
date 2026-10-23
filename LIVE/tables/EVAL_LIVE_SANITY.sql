-- POSTMORTEM.LIVE.EVAL_LIVE_SANITY (table)
-- Evaluation set for the live sanity check: questions and ground-truth answers.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.EVAL_LIVE_SANITY (
	INPUT_QUERY VARCHAR(16777216),
	GROUND_TRUTH VARIANT
);
