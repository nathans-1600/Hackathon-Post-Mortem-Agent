-- POSTMORTEM.RESULTS.REPLAY_DRIVERS (view)
-- Drivers Claude cited in the latest replays: direction, fiscal year and evidence.
--
-- Uses: REPLAY_LATEST, REPLAY_RUNS

create or replace view POSTMORTEM.RESULTS.REPLAY_DRIVERS(
	DRIVER_ID,
	RUN_ID,
	DECISION_KEY,
	MODE,
	MODEL,
	MODEL_ROLE,
	DRIVER,
	DIRECTION,
	FY,
	EVIDENCE
) as
SELECT l.run_id || '-' || d.index AS driver_id, l.run_id, l.decision_key, l.mode, l.model, l.model_role,
       d.value:driver::STRING AS driver, d.value:direction::STRING AS direction,
       d.value:fy::STRING AS fy, d.value:evidence::STRING AS evidence
FROM POSTMORTEM.RESULTS.REPLAY_LATEST l
JOIN POSTMORTEM.RESULTS.REPLAY_RUNS r USING (run_id), LATERAL FLATTEN(input => r.parsed:drivers) d;
