-- POSTMORTEM.LIVE.LIVE_COMPARISON (view)
-- One row per fiscal year with every view of growth: Claude raw, with playbook, with playbook and lessons,
-- bias-adjusted raw (FY+1), consensus, guidance midpoint and the analyst.
--
-- Uses: LIVE_RUNS, REVENUE_HISTORY, CONSENSUS, GUIDANCE, RESULTS.ERRORS, POSITIONS, PARNASSUS_PROJ

create or replace view POSTMORTEM.LIVE.LIVE_COMPARISON(
	FY_REL,
	CLAUDE_RAW,
	CLAUDE_PLAYBOOK,
	CLAUDE_PLAYBOOK_LESSONS,
	CLAUDE_RAW_BIAS_ADJUSTED,
	CONSENSUS,
	GUIDANCE_MID,
	ANALYST
) as   -- one row per FY: every view of the year, in growth %
WITH runs AS (
  SELECT * FROM POSTMORTEM.LIVE.LIVE_RUNS WHERE fy1_growth_pct IS NOT NULL AND model = 'claude-opus-4-6'
  QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, variant)),
fy AS (SELECT column1 AS fy_rel, column2 AS ord FROM (VALUES ('FY+1', 1), ('FY+2', 2), ('FY+3', 3))),
claude AS (
  SELECT r.decision_key, f.fy_rel, r.variant,
         CASE f.ord WHEN 1 THEN r.fy1_growth_pct WHEN 2 THEN r.fy2_growth_pct ELSE r.fy3_growth_pct END AS g
  FROM runs r CROSS JOIN fy f),
fy0 AS (SELECT decision_key, revenue_cur_m AS v FROM POSTMORTEM.LIVE.REVENUE_HISTORY WHERE period_rel = 'FY0'),
cons AS (
  SELECT c.decision_key, c.fy_rel,
         ROUND(100 * (c.revenue_cur_m / COALESCE(LAG(c.revenue_cur_m) OVER (PARTITION BY c.decision_key ORDER BY c.fy_rel), z.v) - 1), 1) AS g
  FROM POSTMORTEM.LIVE.CONSENSUS c JOIN fy0 z USING (decision_key)),
guide AS (   -- latest full-year guide for FY+1, midpoint growth
  SELECT g.decision_key, 'FY+1' AS fy_rel,
         ROUND(COALESCE((g.growth_low_pct + g.growth_high_pct) / 2,
                        100 * (((g.low_cur_m + g.high_cur_m) / 2) / z.v - 1)), 1) AS g
  FROM POSTMORTEM.LIVE.GUIDANCE g JOIN fy0 z USING (decision_key)
  WHERE g.period_rel = 'FY+1'
  QUALIFY g.rel_day = MAX(g.rel_day) OVER (PARTITION BY g.decision_key)),
bias AS (    -- Opus 4.6's mean signed FY+1 error in its plain (independent) masked backtest replays
  SELECT AVG(pct_error) AS m, COUNT(*) AS n FROM POSTMORTEM.RESULTS.ERRORS
  WHERE source = 'claude_independent' AND model = 'claude-opus-4-6' AND fy_rel = 'FY+1')
SELECT f.fy_rel,
       MAX(IFF(c.variant = 'raw', c.g, NULL))      AS claude_raw,
       MAX(IFF(c.variant = 'playbook', c.g, NULL)) AS claude_playbook,
       MAX(IFF(c.variant = 'full', c.g, NULL))     AS claude_playbook_lessons,
       IFF(f.fy_rel = 'FY+1', ROUND(100 * ((1 + MAX(IFF(c.variant = 'raw', c.g, NULL)) / 100) / (1 + ANY_VALUE(b.m) / 100) - 1), 1), NULL)
                                                   AS claude_raw_bias_adjusted,
       ANY_VALUE(k.g)                              AS consensus,
       ANY_VALUE(gd.g)                             AS guidance_mid,
       ANY_VALUE(pp.growth_pct)                    AS analyst
FROM fy f
JOIN POSTMORTEM.LIVE.POSITIONS p ON TRUE
LEFT JOIN claude c ON c.decision_key = p.decision_key AND c.fy_rel = f.fy_rel
LEFT JOIN cons k ON k.decision_key = p.decision_key AND k.fy_rel = f.fy_rel
LEFT JOIN guide gd ON gd.decision_key = p.decision_key AND gd.fy_rel = f.fy_rel
LEFT JOIN POSTMORTEM.LIVE.PARNASSUS_PROJ pp ON pp.decision_key = p.decision_key AND pp.fy_rel = f.fy_rel
CROSS JOIN bias b
GROUP BY f.fy_rel, f.ord ORDER BY f.ord;
