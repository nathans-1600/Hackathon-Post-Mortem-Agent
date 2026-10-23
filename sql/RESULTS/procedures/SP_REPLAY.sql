-- POSTMORTEM.RESULTS.SP_REPLAY (stored procedure)
-- Re-forecasts a case from its packet in a given mode (independent, clone, factsheet, learned, learned_inner,
-- noise_check) and model. Learned modes check the hindsight guards before calling the model.
--
-- Uses: MASKED.PIT_PACKET, MASKED.CLONE_CONTEXT, MASKED.POSITIONS, LEARN_PLAYBOOKS, LEARN_RULES, REPLAY_RUNS
-- Writes: REPLAY_RUNS
--
-- Known gap: named and live modes read POSTMORTEM.RAW.NAMED_PACKET and RESULTS.PRIOR_RUNS(), which do not
-- exist, so those modes cannot run. Live runs use LIVE.SP_LIVE_REPLAY instead.
-- Comments in the body refer to script numbers (07, 08, 11_learn.sql) from an earlier layout.
-- A CALL runs AI_COMPLETE (costs credits) and writes rows.

CREATE OR REPLACE PROCEDURE POSTMORTEM.RESULTS.SP_REPLAY("DK" VARCHAR, "MODE" VARCHAR, "MODEL" VARCHAR, "PB" VARCHAR DEFAULT null)
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
  live_ok BOOLEAN DEFAULT FALSE;
  pb_used STRING DEFAULT NULL;
  pb_text STRING;
  schema_extra STRING DEFAULT '''';
  n INT;
BEGIN
  IF (mode IN (''named'', ''live'')) THEN
    packet := (SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.RAW.NAMED_PACKET(:dk)));
    rules := ''Use only the packet below. Do not use anything you know about events after the date in the packet.'';
  ELSE
    packet := (SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.MASKED.PIT_PACKET(:dk)));
    rules := ''Names, dates and currency amounts are masked. Companies and people are tokens (Company_A, Exec_A1). ''
          || ''Dates are days relative to today (D-30 = 30 days ago). Fiscal years are relative (FY0 = last fully ''
          || ''reported year, FY+1 = the year in progress). Amounts are CUR on an undisclosed scale, so reason in growth ''
          || ''rates. Do not try to identify the company or the calendar period, and use only the packet below.'';
  END IF;

  IF (mode = ''clone'') THEN
    extra := (SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.MASKED.CLONE_CONTEXT(:dk)));
    extra := ''\\n\\nYou are an analyst at Firm_X. Project the way Firm_X analysts do, following the house process ''
          || ''and the style of the reviews below. They cover other companies; do not copy their numbers.\\n\\n''
          || COALESCE(extra, '''');
  END IF;

  IF (mode = ''live'') THEN
    live_ok := COALESCE((SELECT is_live FROM POSTMORTEM.MASKED.POSITIONS WHERE decision_key = :dk), FALSE);
    IF (NOT live_ok) THEN
      RETURN ''live mode is for live cases only: '' || dk || '' is a backtest case and would see its own outcome'';
    END IF;
    -- PRIOR_RUNS is created in 08 (it reads RESULTS.ERRORS from 07)
    extra := (SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.RESULTS.PRIOR_RUNS()));
    extra := ''\\n\\nLESSONS FROM PRIOR RUNS. Below is how past projections (yours, consensus, guidance and the analyst) ''
          || ''compared with reported revenue in earlier cases, and what the post-mortems said to change. Correct for the ''
          || ''systematic errors it shows. Those cases are other companies: use the patterns, not their numbers.\\n\\n''
          || COALESCE(extra, ''(no prior runs scored yet)'');
    -- Playbook from every scored case (11_learn.sql section J); a live case has no outcome, so no leave-one-out needed
    pb_used := (SELECT playbook_id FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE purpose = ''all''
                ORDER BY created_at DESC LIMIT 1);
  END IF;

  IF (mode IN (''learned'', ''learned_inner'')) THEN
    -- Hindsight guards. Any failure returns without calling the model.
    IF (model <> ''claude-opus-4-6'') THEN
      RETURN ''learned modes run on claude-opus-4-6 only (the backtest model: reliable knowledge May 2025, no outcome recall in the probes)'';
    END IF;
    n := (SELECT COUNT(*) FROM POSTMORTEM.MASKED.POSITIONS WHERE decision_key = :dk AND NOT is_live);
    IF (n = 0) THEN
      RETURN ''learned modes are for backtest cases only'';
    END IF;
    n := (SELECT COUNT(*) FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE playbook_id = :pb AND target_key = :dk);
    IF (n = 0) THEN
      RETURN ''playbook '' || COALESCE(pb, ''NULL'') || '' was not built for '' || dk;
    END IF;
    n := (SELECT COUNT(*) FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS p, LATERAL FLATTEN(input => p.rule_ids) f,
                 POSTMORTEM.RESULTS.LEARN_RULES r
          WHERE p.playbook_id = :pb AND r.rule_id = f.value::STRING
            AND (r.source_key = :dk OR r.source_key = p.holdout_key OR NOT COALESCE(r.gate_ok, FALSE)));
    IF (n > 0) THEN
      RETURN ''blocked: playbook '' || pb || '' holds a rule learned from this case''''s (or the holdout''''s) own outcome, or a gated rule'';
    END IF;
    pb_used := pb;
  END IF;

  IF (pb_used IS NOT NULL) THEN
    pb_text := (SELECT COALESCE(NULLIF(text, ''''), ''(no rules)'') FROM POSTMORTEM.RESULTS.LEARN_PLAYBOOKS WHERE playbook_id = :pb_used);
    extra := extra || ''\\n\\nPLAYBOOK. Rules learned from post-mortems of projections for OTHER companies (never this one). ''
          || ''Each rule names a signal. Apply a rule only if that signal is present in the packet above, and list the ids ''
          || ''of the rules you applied in rules_applied. The rules describe how projections tend to go wrong, not what ''
          || ''happened to any company or in any period.\\n'' || pb_text;
    schema_extra := '', "rules_applied": ["R1"]'';
  END IF;

  IF (mode = ''factsheet'') THEN
    -- masking ladder level 3: the projector sees only a structured sheet extracted from the masked packet
    packet := (SELECT AI_COMPLETE(
      model => :model,
      prompt => ''<packet>\\n'' || :packet || ''\\n</packet>\\n\\n''
             || ''TASK. Turn the masked packet above into a fact sheet of at most 600 words: reported growth trend by period, ''
             || ''latest guidance and how it changed, consensus, management tone change, sell-side bull and bear points, ''
             || ''KPI trends. Keep every token and relative date as written. No forecasts. Write the fact sheet now; ''
             || ''do not continue the documents.'',
      model_parameters => {''temperature'': 0, ''max_tokens'': 2000}));
  END IF;

  -- Packet first, instructions last: with the documents at the end, models can continue the transcript instead of answering
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

  INSERT INTO POSTMORTEM.RESULTS.REPLAY_RUNS (run_id, decision_key, mode, model, run_at, fy1_growth_pct, fy2_growth_pct,
                                              fy3_growth_pct, confidence, parsed, raw_response, prompt_chars, playbook_id)
  SELECT :rid, :dk, :mode, :model, CURRENT_TIMESTAMP(), 
         j:fy1_growth_pct::FLOAT, j:fy2_growth_pct::FLOAT, j:fy3_growth_pct::FLOAT, j:confidence_0_100::INT,
         j, :resp, LENGTH(:prompt), :pb_used
  FROM (SELECT TRY_PARSE_JSON(REGEXP_SUBSTR(:resp, ''\\\\{.*\\\\}'', 1, 1, ''s'')) AS j);
  RETURN rid;
END;
';
