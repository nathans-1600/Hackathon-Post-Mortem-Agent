-- POSTMORTEM.RESULTS.REPLAY_LATEST (view)
-- Latest independent, clone and factsheet replay per backtest case, mode and model, with model role (clean vs
-- contaminated control).
--
-- Uses: REPLAY_RUNS, MASKED.POSITIONS

create or replace view POSTMORTEM.RESULTS.REPLAY_LATEST(
	RUN_ID,
	DECISION_KEY,
	MODE,
	MODEL,
	RUN_AT,
	MODEL_ROLE,
	FY1_GROWTH_PCT,
	FY2_GROWTH_PCT,
	FY3_GROWTH_PCT,
	CONFIDENCE,
	VS_CONSENSUS,
	KEY_RISKS
) as
SELECT r.run_id, r.decision_key, r.mode, r.model, r.run_at,
       IFF(r.model = 'claude-opus-4-8', 'contaminated control', 'clean') AS model_role,
       r.fy1_growth_pct, r.fy2_growth_pct, r.fy3_growth_pct, r.confidence,
       r.parsed:vs_consensus::STRING AS vs_consensus,
       ARRAY_TO_STRING(r.parsed:key_risks::ARRAY, '; ') AS key_risks
FROM POSTMORTEM.RESULTS.REPLAY_RUNS r
JOIN POSTMORTEM.MASKED.POSITIONS d ON d.decision_key = r.decision_key AND NOT COALESCE(d.is_live, FALSE)
WHERE r.mode IN ('independent', 'clone', 'factsheet') AND r.model IN ('claude-opus-4-6', 'claude-opus-4-8')
  AND r.fy1_growth_pct IS NOT NULL
QUALIFY r.run_at = MAX(r.run_at) OVER (PARTITION BY r.decision_key, r.mode, r.model);
