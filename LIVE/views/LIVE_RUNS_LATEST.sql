-- POSTMORTEM.LIVE.LIVE_RUNS_LATEST (view)
-- Latest live run per variant and model: growth, confidence, view vs consensus, key risks and number of rules
-- applied.
--
-- Uses: LIVE_RUNS

create or replace view POSTMORTEM.LIVE.LIVE_RUNS_LATEST(
	VARIANT,
	MODEL,
	RUN_AT,
	FY1_GROWTH_PCT,
	FY2_GROWTH_PCT,
	FY3_GROWTH_PCT,
	CONFIDENCE,
	VS_CONSENSUS,
	KEY_RISKS,
	N_RULES_APPLIED
) as
SELECT variant, model, run_at, fy1_growth_pct, fy2_growth_pct, fy3_growth_pct, confidence,
       parsed:vs_consensus::STRING AS vs_consensus,
       ARRAY_TO_STRING(parsed:key_risks::ARRAY, '; ') AS key_risks,
       COALESCE(ARRAY_SIZE(parsed:rules_applied), 0) AS n_rules_applied
FROM POSTMORTEM.LIVE.LIVE_RUNS
WHERE fy1_growth_pct IS NOT NULL
QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, variant, model);
