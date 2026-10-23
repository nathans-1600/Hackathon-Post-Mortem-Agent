-- POSTMORTEM.RESULTS.LEARN_RUN_ERRORS (view)
-- Learned and learned_inner replays scored per fiscal year, next to the plain Opus 4.6 independent replay
-- (gain_pts = error saved).
--
-- Uses: REPLAY_RUNS, LEARN_PLAYBOOKS, MASKED.REVENUE_HISTORY, OUTCOMES.ACTUALS_REL, ERRORS

create or replace view POSTMORTEM.RESULTS.LEARN_RUN_ERRORS(
	RUN_ID,
	DECISION_KEY,
	RUN_AT,
	PURPOSE,
	HOLDOUT_KEY,
	PLAYBOOK_ID,
	RULE_IDS,
	RULES_APPLIED,
	FY_REL,
	LEARNED_ABS_ERR,
	BASE_ABS_ERR,
	GAIN_PTS
) as
WITH runs AS (
  SELECT r.run_id, r.decision_key, r.run_at, r.parsed:rules_applied AS rules_applied,
         p.playbook_id, p.purpose, p.holdout_key, p.rule_ids, h.revenue_cur_m AS fy0_cur,
         r.fy1_growth_pct AS g1, r.fy2_growth_pct AS g2, r.fy3_growth_pct AS g3
  FROM POSTMORTEM.RESULTS.REPLAY_RUNS r
  JOIN POSTMORTEM.RESULTS.LEARN_PLAYBOOKS p ON p.playbook_id = r.playbook_id
  JOIN POSTMORTEM.MASKED.REVENUE_HISTORY h ON h.decision_key = r.decision_key AND h.period_rel = 'FY0'
  WHERE r.mode IN ('learned', 'learned_inner') AND r.fy1_growth_pct IS NOT NULL),
proj AS (
  SELECT *, 'FY+1' AS fy_rel, fy0_cur * (1 + g1 / 100) AS proj_cur_m FROM runs
  UNION ALL SELECT *, 'FY+2', fy0_cur * (1 + g1 / 100) * (1 + g2 / 100) FROM runs
  UNION ALL SELECT *, 'FY+3', fy0_cur * (1 + g1 / 100) * (1 + g2 / 100) * (1 + g3 / 100) FROM runs)
SELECT p.run_id, p.decision_key, p.run_at, p.purpose, p.holdout_key, p.playbook_id, p.rule_ids, p.rules_applied, p.fy_rel,
       ROUND(100 * ABS(p.proj_cur_m / a.actual_cur_m - 1), 2)                     AS learned_abs_err,
       e.abs_pct_error                                                            AS base_abs_err,
       ROUND(e.abs_pct_error - 100 * ABS(p.proj_cur_m / a.actual_cur_m - 1), 2)   AS gain_pts
FROM proj p
JOIN POSTMORTEM.OUTCOMES.ACTUALS_REL a ON a.decision_key = p.decision_key AND a.fy_rel = p.fy_rel
JOIN POSTMORTEM.RESULTS.ERRORS e ON e.decision_key = p.decision_key AND e.fy_rel = p.fy_rel
 AND e.source = 'claude_independent' AND e.model = 'claude-opus-4-6';
