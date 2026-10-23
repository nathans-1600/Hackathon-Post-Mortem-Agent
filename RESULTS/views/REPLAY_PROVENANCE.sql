-- POSTMORTEM.RESULTS.REPLAY_PROVENANCE (view)
-- Replay counts per mode and model: total, imported, fresh, unparsed, and the last run.
--
-- Uses: REPLAY_RUNS, REPLAY_RUN_FRESH

create or replace view POSTMORTEM.RESULTS.REPLAY_PROVENANCE(
	PROVENANCE_ID,
	MODE,
	MODEL,
	RUNS,
	IMPORTED_RUNS,
	FRESH_RUNS,
	UNPARSED_RUNS,
	LAST_RUN
) as
SELECT r.mode || '|' || r.model AS provenance_id, r.mode, r.model, COUNT(*) AS runs,
       COUNT_IF(f.imported) AS imported_runs, COUNT_IF(f.is_fresh) AS fresh_runs,
       COUNT_IF(r.fy1_growth_pct IS NULL) AS unparsed_runs, MAX(r.run_at) AS last_run
FROM POSTMORTEM.RESULTS.REPLAY_RUNS r LEFT JOIN POSTMORTEM.RESULTS.REPLAY_RUN_FRESH f USING (run_id)
GROUP BY r.mode, r.model;
