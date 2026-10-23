-- POSTMORTEM.RESULTS.LEARN_SUMMARY (view)
-- Learning loop per backtest case, FY+1: baseline vs round-1 and round-2 error and gain, rule counts, and
-- run-to-run noise.
--
-- Uses: LEARN_RUN_ERRORS, REPLAY_RUNS, MASKED.POSITIONS

create or replace view POSTMORTEM.RESULTS.LEARN_SUMMARY(
	DECISION_KEY,
	BASELINE_ABS_ERR,
	ROUND1_ABS_ERR,
	ROUND2_ABS_ERR,
	ROUND1_GAIN_PTS,
	ROUND2_GAIN_PTS,
	ROUND1_RULES,
	ROUND2_RULES,
	NOISE_PTS
) as
WITH latest AS (
  SELECT * FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS
  WHERE fy_rel = 'FY+1' AND purpose IN ('outer_r1', 'outer_r2')
  QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key, purpose ORDER BY run_at DESC) = 1),
noise AS (
  SELECT ROUND(AVG(ABS(n.fy1_growth_pct - i.fy1_growth_pct)), 2) AS noise_pts
  FROM (SELECT * FROM POSTMORTEM.RESULTS.REPLAY_RUNS WHERE mode = 'noise_check' AND fy1_growth_pct IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1) n
  JOIN (SELECT * FROM POSTMORTEM.RESULTS.REPLAY_RUNS
        WHERE mode = 'independent' AND model = 'claude-opus-4-6' AND fy1_growth_pct IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1) i USING (decision_key))
SELECT p.decision_key,
       r1.base_abs_err AS baseline_abs_err, r1.learned_abs_err AS round1_abs_err, r2.learned_abs_err AS round2_abs_err,
       r1.gain_pts AS round1_gain_pts, r2.gain_pts AS round2_gain_pts,
       ARRAY_SIZE(r1.rule_ids) AS round1_rules, ARRAY_SIZE(r2.rule_ids) AS round2_rules,
       n.noise_pts
FROM POSTMORTEM.MASKED.POSITIONS p
LEFT JOIN (SELECT * FROM latest WHERE purpose = 'outer_r1') r1 USING (decision_key)
LEFT JOIN (SELECT * FROM latest WHERE purpose = 'outer_r2') r2 USING (decision_key)
LEFT JOIN noise n ON TRUE
WHERE NOT p.is_live;
