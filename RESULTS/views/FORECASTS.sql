-- POSTMORTEM.RESULTS.FORECASTS (view)
-- Every forecast as revenue per case, source, model and fiscal year: Claude's latest replay per mode and
-- model, Firm_X (label parnassus), consensus and the guidance midpoint.
--
-- Uses: MASKED.REVENUE_HISTORY, REPLAY_RUNS, MASKED.GUIDANCE, MASKED.PARNASSUS_PROJ, MASKED.CONSENSUS
--
-- A comment in the body refers to 11_learn.sql, from an earlier layout of the project.

create or replace view POSTMORTEM.RESULTS.FORECASTS(
	DECISION_KEY,
	SOURCE,
	MODEL,
	FY_REL,
	PROJ_CUR_M
) as
WITH fy0 AS (
  SELECT decision_key, revenue_cur_m AS fy0_cur FROM POSTMORTEM.MASKED.REVENUE_HISTORY WHERE period_rel = 'FY0'),
runs AS (
  SELECT * FROM POSTMORTEM.RESULTS.REPLAY_RUNS
  WHERE fy1_growth_pct IS NOT NULL AND model IN ('claude-opus-4-6', 'claude-opus-4-8')   -- Sonnet excluded
    AND mode IN ('independent', 'clone', 'factsheet', 'named', 'live')   -- learned runs are scored in 11_learn.sql
  QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, mode, model)),
claude AS (
  SELECT r.decision_key, 'claude_' || r.mode AS source, r.model, 'FY+1' AS fy_rel,
         f.fy0_cur * (1 + r.fy1_growth_pct / 100) AS proj_cur_m
  FROM runs r JOIN fy0 f USING (decision_key)
  UNION ALL
  SELECT r.decision_key, 'claude_' || r.mode, r.model, 'FY+2',
         f.fy0_cur * (1 + r.fy1_growth_pct / 100) * (1 + r.fy2_growth_pct / 100)
  FROM runs r JOIN fy0 f USING (decision_key)
  UNION ALL
  SELECT r.decision_key, 'claude_' || r.mode, r.model, 'FY+3',
         f.fy0_cur * (1 + r.fy1_growth_pct / 100) * (1 + r.fy2_growth_pct / 100) * (1 + r.fy3_growth_pct / 100)
  FROM runs r JOIN fy0 f USING (decision_key)),
guide AS (   -- latest pre-anchor full-year guide for FY+1, midpoint; growth-only guides (TEAM) compound off FY0
  SELECT g.decision_key, 'guidance_mid' AS source, NULL AS model, g.period_rel AS fy_rel,
         COALESCE((g.low_cur_m + g.high_cur_m) / 2,
                  f.fy0_cur * (1 + (g.growth_low_pct + g.growth_high_pct) / 200)) AS proj_cur_m
  FROM POSTMORTEM.MASKED.GUIDANCE g JOIN fy0 f USING (decision_key)
  WHERE g.period_rel = 'FY+1' AND (g.low_cur_m IS NOT NULL OR g.growth_low_pct IS NOT NULL)
  QUALIFY g.rel_day = MAX(g.rel_day) OVER (PARTITION BY g.decision_key))
SELECT * FROM claude
UNION ALL
SELECT decision_key, 'parnassus', NULL, fy_rel, revenue_cur_m FROM POSTMORTEM.MASKED.PARNASSUS_PROJ
UNION ALL
SELECT decision_key, 'consensus', NULL, fy_rel, revenue_cur_m FROM POSTMORTEM.MASKED.CONSENSUS
UNION ALL
SELECT * FROM guide;
