-- POSTMORTEM.RESULTS.PIPELINE_STATUS (view)
-- The latest run of the EVAL_PIPELINE checks.
--
-- Uses: EVAL_PIPELINE

create or replace view POSTMORTEM.RESULTS.PIPELINE_STATUS(
	CHECK_ID,
	KIND,
	CHECK_NAME,
	RESULT,
	DETAIL,
	CHECKED_AT
) as
SELECT check_id, kind, check_name, result, detail, checked_at FROM POSTMORTEM.RESULTS.EVAL_PIPELINE
QUALIFY checked_at = MAX(checked_at) OVER ();
