-- POSTMORTEM.RESULTS.EVAL_POSTMORTEM_ANALYST (table)
-- Evaluation set for the POSTMORTEM_ANALYST agent: questions and ground-truth answers.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.EVAL_POSTMORTEM_ANALYST (
	INPUT_QUERY VARCHAR(16777216),
	GROUND_TRUTH VARIANT
);
