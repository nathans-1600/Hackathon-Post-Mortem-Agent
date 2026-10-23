-- POSTMORTEM.LIVE.PLAYBOOK_RECORD (view)
-- Every rule in the live playbook: direction, source case, backtest record (times applied, net wins), and
-- whether it fired in today's runs.
--
-- Uses: RESULTS.LEARN_PLAYBOOKS, RESULTS.LEARN_RUN_ERRORS, RESULTS.LEARN_RULES, LIVE_RULES_APPLIED

create or replace view POSTMORTEM.LIVE.PLAYBOOK_RECORD(
	RULE_ID,
	DIRECTION,
	LEARNED_FROM_CASE,
	RULE,
	TIMES_APPLIED_BACKTEST,
	NET_WINS_BACKTEST,
	FIRED_WITH_PLAYBOOK,
	FIRED_WITH_LESSONS
) as
WITH pb AS (SELECT rule_ids FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE purpose = 'all'
            ORDER BY created_at DESC LIMIT 1),
r1 AS (SELECT * FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS WHERE fy_rel = 'FY+1' AND purpose = 'outer_r1'
       QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1),
ids AS (SELECT f.value::STRING AS rule_id FROM pb, LATERAL FLATTEN(input => pb.rule_ids) f),
rec AS (
  SELECT lr.rule_id, lr.direction, lr.source_key AS learned_from_case, lr.rule,
         COUNT(e.run_id) AS times_applied_backtest, COALESCE(SUM(SIGN(e.gain_pts)), 0) AS net_wins_backtest
  FROM ids
  JOIN POSTMORTEM.RESULTS.LEARN_RULES lr ON lr.rule_id = ids.rule_id
  LEFT JOIN r1 e ON ARRAY_CONTAINS(lr.rule_id::VARIANT, e.rules_applied::ARRAY)
  GROUP BY 1, 2, 3, 4),
fired AS (
  SELECT rule_id, BOOLOR_AGG(variant = 'playbook') AS fired_with_playbook, BOOLOR_AGG(variant = 'full') AS fired_with_lessons
  FROM POSTMORTEM.LIVE.LIVE_RULES_APPLIED GROUP BY rule_id)
SELECT rec.*, COALESCE(fired.fired_with_playbook, FALSE) AS fired_with_playbook,
       COALESCE(fired.fired_with_lessons, FALSE) AS fired_with_lessons
FROM rec LEFT JOIN fired USING (rule_id);
