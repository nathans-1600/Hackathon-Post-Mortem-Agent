-- POSTMORTEM.RESULTS.SP_LEARN_PLAYBOOK (stored procedure)
-- Builds a playbook from gate-passing rules, leaving out rules from the target and holdout case. For outer_r2
-- and all, rules with a negative net score on the evidence runs are pruned.
--
-- Uses: LEARN_PLAYBOOKS, POSTMORTEMS, LEARN_RULES, LEARN_RUN_ERRORS
-- Writes: LEARN_PLAYBOOKS

CREATE OR REPLACE PROCEDURE POSTMORTEM.RESULTS.SP_LEARN_PLAYBOOK("PB" VARCHAR, "PURPOSE" VARCHAR, "TARGET" VARCHAR, "HOLDOUT" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
BEGIN
  INSERT INTO POSTMORTEM.RESULTS.LEARN_PLAYBOOKS (playbook_id, purpose, target_key, holdout_key, created_at, rule_ids, text)
  WITH latest_pm AS (
    SELECT postmortem_id FROM POSTMORTEM.RESULTS.POSTMORTEMS
    WHERE COALESCE(mode, ''masked'') = ''masked'' AND parsed:in_packet_underweighted IS NOT NULL
    QUALIFY created_at = MAX(created_at) OVER (PARTITION BY decision_key)),
  cand AS (
    SELECT r.rule_id, r.rule FROM POSTMORTEM.RESULTS.LEARN_RULES r JOIN latest_pm USING (postmortem_id)
    WHERE r.gate_ok AND r.source_key <> COALESCE(:target, '''') AND r.source_key <> COALESCE(:holdout, '''')),
  evidence AS (
    SELECT e.decision_key, e.rules_applied, e.rule_ids, SIGN(e.gain_pts) AS s
    FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS e
    WHERE e.fy_rel = ''FY+1''
      AND ((:purpose = ''outer_r2'' AND e.purpose = ''inner'' AND e.holdout_key = :holdout)
        OR (:purpose = ''all'' AND e.purpose = ''outer_r1''))
    QUALIFY ROW_NUMBER() OVER (PARTITION BY e.decision_key, e.purpose, e.holdout_key ORDER BY e.run_at DESC) = 1),
  score AS (
    SELECT f.value::STRING AS rule_id, SUM(ev.s) AS sc
    FROM evidence ev, LATERAL FLATTEN(input => ev.rules_applied) f
    WHERE ARRAY_CONTAINS(f.value, ev.rule_ids)   -- ignore ids the model cited that weren''t in its playbook
    GROUP BY 1),
  kept AS (
    SELECT c.rule_id, c.rule FROM cand c LEFT JOIN score s USING (rule_id) WHERE COALESCE(s.sc, 0) >= 0)
  SELECT :pb, :purpose, :target, :holdout, CURRENT_TIMESTAMP(),
         COALESCE(ARRAY_AGG(rule_id) WITHIN GROUP (ORDER BY rule_id), ARRAY_CONSTRUCT()),
         LISTAGG(rule_id || '': '' || rule, ''\\n'') WITHIN GROUP (ORDER BY rule_id)
  FROM kept;
  RETURN pb;
END;
';
