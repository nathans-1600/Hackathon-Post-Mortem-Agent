-- POSTMORTEM.LIVE.LIVE_RULES_APPLIED (view)
-- Rules the latest playbook and full runs applied, with direction, rule text and the past case each was
-- learned from.
--
-- Uses: LIVE_RUNS, RESULTS.LEARN_RULES

create or replace view POSTMORTEM.LIVE.LIVE_RULES_APPLIED(
	VARIANT,
	RULE_ID,
	DIRECTION,
	LEARNED_FROM_CASE,
	RULE
) as
WITH applied AS (
  SELECT r.variant, a.value::STRING AS rule_id
  FROM (SELECT * FROM POSTMORTEM.LIVE.LIVE_RUNS WHERE model = 'claude-opus-4-6' AND variant IN ('playbook', 'full')
        QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, variant)) r,
       LATERAL FLATTEN(input => r.parsed:rules_applied) a)
SELECT a.variant, a.rule_id, lr.direction, lr.source_key AS learned_from_case, lr.rule
FROM applied a LEFT JOIN POSTMORTEM.RESULTS.LEARN_RULES lr ON lr.rule_id = a.rule_id;
