-- POSTMORTEM.RESULTS.LEARN_RULE_SCORES (view)
-- Each learned rule with its gate result, how often round-1 runs applied it, net wins, and whether it is in
-- the live playbook.
--
-- Uses: LEARN_RUN_ERRORS, LEARN_PLAYBOOKS, LEARN_RULES

create or replace view POSTMORTEM.RESULTS.LEARN_RULE_SCORES(
	RULE_ID,
	SOURCE_KEY,
	DIRECTION,
	SIGNAL,
	APPLIES_TO,
	RULE,
	GATE_OK,
	GATE_HIT,
	TIMES_APPLIED,
	NET_WINS,
	IN_LIVE_PLAYBOOK
) as
WITH r1 AS (SELECT * FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS WHERE fy_rel = 'FY+1' AND purpose = 'outer_r1'
            QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1),
live AS (SELECT rule_ids FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE purpose = 'all'
         ORDER BY created_at DESC LIMIT 1)
SELECT r.rule_id, r.source_key, r.direction, r.signal, r.applies_to, r.rule,
       COALESCE(r.gate_ok, FALSE) AS gate_ok, r.gate_hit,
       COUNT(e.run_id) AS times_applied, COALESCE(SUM(SIGN(e.gain_pts)), 0) AS net_wins,
       ARRAY_CONTAINS(r.rule_id::VARIANT, ANY_VALUE(l.rule_ids)) AS in_live_playbook
FROM POSTMORTEM.RESULTS.LEARN_RULES r
LEFT JOIN r1 e ON ARRAY_CONTAINS(r.rule_id::VARIANT, e.rules_applied::ARRAY) AND ARRAY_CONTAINS(r.rule_id::VARIANT, e.rule_ids)
LEFT JOIN live l ON TRUE
GROUP BY r.rule_id, r.source_key, r.direction, r.signal, r.applies_to, r.rule, r.gate_ok, r.gate_hit;
