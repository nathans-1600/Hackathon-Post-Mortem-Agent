-- POSTMORTEM.LIVE.SP_LIVE_REPLAY (stored procedure)
-- Forecasts the live case in one variant (raw, playbook, full), Opus 4.6 by default. Refuses any case that is
-- a backtest case or has an outcome.
--
-- Uses: POSITIONS, MASKED.POSITIONS, OUTCOMES.ACTUALS_REL, LIVE_PACKET, PRIOR_LESSONS,
--   RESULTS.LEARN_PLAYBOOKS, RESULTS.LEARN_RULES, LIVE_RUNS
-- Writes: LIVE_RUNS
--
-- A CALL runs AI_COMPLETE (costs credits) and writes rows.

CREATE OR REPLACE PROCEDURE POSTMORTEM.LIVE.SP_LIVE_REPLAY("DK" VARCHAR, "VARIANT" VARCHAR, "MODEL" VARCHAR DEFAULT 'claude-opus-4-6')
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
  packet STRING;
  rules STRING;
  extra STRING DEFAULT '''';
  prompt STRING;
  resp STRING;
  rid STRING DEFAULT UUID_STRING();
  pb_used STRING DEFAULT NULL;
  pb_text STRING;
  schema_extra STRING DEFAULT '''';
  n INT;
BEGIN
  -- Guards: a live, unscored case only, on a model whose training ends before D0
  IF (variant NOT IN (''raw'', ''playbook'', ''full'')) THEN
    RETURN ''variant must be raw, playbook or full'';
  END IF;
  IF (model NOT IN (''claude-opus-4-6'', ''claude-opus-4-8'')) THEN
    RETURN ''model must be claude-opus-4-6 (default; the playbook was tested on it) or claude-opus-4-8'';
  END IF;
  n := (SELECT COUNT(*) FROM POSTMORTEM.LIVE.POSITIONS WHERE decision_key = :dk AND is_live);
  IF (n = 0) THEN
    RETURN ''not a live case in POSTMORTEM.LIVE: '' || dk;
  END IF;
  n := (SELECT (SELECT COUNT(*) FROM POSTMORTEM.MASKED.POSITIONS WHERE decision_key = :dk)
             + (SELECT COUNT(*) FROM POSTMORTEM.OUTCOMES.ACTUALS_REL WHERE decision_key = :dk));
  IF (n > 0) THEN
    RETURN ''blocked: '' || dk || '' is a backtest key or has outcome rows'';
  END IF;

  packet := (SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.LIVE.LIVE_PACKET(:dk)));
  rules := ''Names, dates and currency amounts are masked. Companies and people are tokens (Company_A, Exec_A1). ''
        || ''Dates are days relative to today (D-30 = 30 days ago). Fiscal years are relative (FY0 = last fully ''
        || ''reported year, FY+1 = the year in progress). Amounts are CUR on an undisclosed scale, so reason in growth ''
        || ''rates. Do not try to identify the company or the calendar period, and use only the packet below.'';

  IF (variant = ''full'') THEN
    extra := (SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.LIVE.PRIOR_LESSONS()));
    extra := ''\\n\\nLESSONS FROM PRIOR RUNS. Below is how past projections (yours, consensus, guidance and the analyst) ''
          || ''compared with reported revenue in earlier cases, and what the post-mortems said to change. Correct for the ''
          || ''systematic errors it shows. Those cases are other companies: use the patterns, not their numbers.\\n\\n''
          || COALESCE(extra, ''(no prior runs scored yet)'');
  END IF;

  IF (variant IN (''playbook'', ''full'')) THEN
    pb_used := (SELECT playbook_id FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE purpose = ''all''
                ORDER BY created_at DESC LIMIT 1);
    IF (pb_used IS NULL) THEN
      RETURN ''no all-cases playbook yet: run 11_learn.sql section J'';
    END IF;
    n := (SELECT COUNT(*) FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS p, LATERAL FLATTEN(input => p.rule_ids) f,
                 POSTMORTEM.RESULTS.LEARN_RULES r
          WHERE p.playbook_id = :pb_used AND r.rule_id = f.value::STRING AND NOT COALESCE(r.gate_ok, FALSE));
    IF (n > 0) THEN
      RETURN ''blocked: playbook '' || pb_used || '' holds a gated rule'';
    END IF;
    pb_text := (SELECT COALESCE(NULLIF(text, ''''), ''(no rules)'') FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE playbook_id = :pb_used);
    extra := extra || ''\\n\\nPLAYBOOK. Rules learned from post-mortems of projections for OTHER companies (never this one). ''
          || ''Each rule names a signal. Apply a rule only if that signal is present in the packet above, and list the ids ''
          || ''of the rules you applied in rules_applied. The rules describe how projections tend to go wrong, not what ''
          || ''happened to any company or in any period.\\n'' || pb_text;
    schema_extra := '', "rules_applied": ["R1"]'';
  END IF;

  prompt := ''<packet>\\n'' || packet || ''\\n</packet>\\n\\n''
         || ''You are a buy-side equity analyst. '' || REPLACE(rules, ''packet below'', ''packet above'') || extra
         || ''\\n\\nTASK: Project total revenue growth for FY+1, FY+2 and FY+3 (named cases: the three fiscal years in ''
         || ''the packet header). Start from what is already reported for FY+1 and from management guidance. ''
         || ''Say where you differ from consensus and why. Return only JSON, no prose:\\n''
         || ''{"fy1_growth_pct": 0.0, "fy2_growth_pct": 0.0, "fy3_growth_pct": 0.0, ''
         || ''"drivers": [{"driver": "", "direction": "up|down", "fy": "FY+1", "evidence": "doc type + day"}], ''
         || ''"vs_consensus": "", "key_risks": [""], "confidence_0_100": 0'' || schema_extra || ''}''
         || ''\\nAnswer now with the JSON object only; do not continue the documents.'';

  resp := (SELECT AI_COMPLETE(model => :model, prompt => :prompt,
                              model_parameters => {''temperature'': 0, ''max_tokens'': 4000}));

  INSERT INTO POSTMORTEM.LIVE.LIVE_RUNS (run_id, decision_key, variant, model, run_at, fy1_growth_pct, fy2_growth_pct,
                                         fy3_growth_pct, confidence, parsed, raw_response, prompt_chars, playbook_id)
  SELECT :rid, :dk, :variant, :model, CURRENT_TIMESTAMP(),
         j:fy1_growth_pct::FLOAT, j:fy2_growth_pct::FLOAT, j:fy3_growth_pct::FLOAT, j:confidence_0_100::INT,
         j, :resp, LENGTH(:prompt), :pb_used
  FROM (SELECT TRY_PARSE_JSON(REGEXP_SUBSTR(:resp, ''\\\\{.*\\\\}'', 1, 1, ''s'')) AS j);
  RETURN rid;
END;
';
