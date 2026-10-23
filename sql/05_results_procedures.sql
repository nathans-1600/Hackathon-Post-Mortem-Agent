-- 05_results_procedures.sql
-- POSTMORTEM.RESULTS stored procedures.
--
-- Known limitations in the source database (exported as-is, not fixed):
--   * SP_POSTMORTEM(mode => 'named') and SP_REPLAY(mode => 'named' | 'live') read
--     POSTMORTEM.RAW.* (KEYS, POSITIONS, DOC_TEXT, NAMED_PACKET) and
--     POSTMORTEM.OUTCOMES.ACTUALS. Those objects do not exist in the source
--     database (the RAW schema is empty), so those modes cannot run.
--   * SP_REPLAY(mode => 'live') calls POSTMORTEM.RESULTS.PRIOR_RUNS(), which does
--     not exist. Live runs are handled by POSTMORTEM.LIVE.SP_LIVE_REPLAY instead.
--   * Comments inside the bodies refer to earlier script numbers (07, 08, 09,
--     11_learn.sql) from a previous layout of this project.

CREATE OR REPLACE PROCEDURE POSTMORTEM.RESULTS.SP_LEARN_EXTRACT("DK" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
  pid STRING;
  ctx STRING;
  resp STRING;
  n INT;
BEGIN
  pid := (SELECT postmortem_id FROM POSTMORTEM.RESULTS.POSTMORTEMS
          WHERE decision_key = :dk AND COALESCE(mode, ''masked'') = ''masked'' AND parsed:in_packet_underweighted IS NOT NULL
          ORDER BY created_at DESC LIMIT 1);
  IF (pid IS NULL) THEN
    RETURN ''no masked post-mortem for '' || dk || '': run 07 first'';
  END IF;
  n := (SELECT COUNT(*) FROM POSTMORTEM.RESULTS.LEARN_RULES WHERE postmortem_id = :pid);
  IF (n > 0) THEN
    RETURN ''rules already extracted from post-mortem '' || pid;
  END IF;

  -- Process fields only (see header): no outcome numbers, no recalled outside data, no hindsight-only events
  ctx := (SELECT ''INPUTS THAT WERE IN THE PACKET BUT UNDER-USED\\n'' || COALESCE(parsed:in_packet_underweighted::STRING, ''[]'')
              -- tags from BIAS_TAGS, not the raw JSON: only tags that passed the 2% rule become lessons
              || ''\\n\\nBIAS TAGS (whose projection, tag, evidence)\\n'' || COALESCE((
                   SELECT ARRAY_AGG(OBJECT_CONSTRUCT(''about'', b.about, ''tag'', b.tag, ''evidence'', b.evidence))::STRING
                   FROM POSTMORTEM.RESULTS.BIAS_TAGS b WHERE b.postmortem_id = :pid), ''[]'')
              || ''\\n\\nPROCESS LESSON\\n'' || COALESCE(parsed:change_next_time::STRING, '''')
          FROM POSTMORTEM.RESULTS.POSTMORTEMS WHERE postmortem_id = :pid);

  resp := (SELECT AI_COMPLETE(model => ''claude-opus-4-6'',
    prompt => ''<postmortem>\\n'' || :ctx || ''\\n</postmortem>\\n\\n''
           || ''TASK. From the post-mortem notes above, write at most 4 rules a forecaster could apply when projecting ''
           || ''revenue for a DIFFERENT company. Each rule must be conditional: "When <a signal that can be seen in a ''
           || ''point-in-time packet: filings, transcripts, guidance, consensus, broker notes>, <how to adjust the revenue ''
           || ''projection>". Write about forecasting process only. Never mention this company or any token such as ''
           || ''Company_, Exec_, Broker_ or Product_; never give amounts, days, dates, years or months; never say what was ''
           || ''reported afterwards; never describe the economy, markets or events of any period. Drop any lesson that ''
           || ''only makes sense with hindsight. Return only JSON: {"rules": [{"rule": "", "signal": "", ''
           || ''"direction": "raise|lower|widen_range", "applies_to": "FY+1|FY+2|FY+3|all"}]}. ''
           || ''Answer now with the JSON object only.'',
    model_parameters => {''temperature'': 0, ''max_tokens'': 1500}));

  INSERT INTO POSTMORTEM.RESULTS.LEARN_RULES (rule_id, source_key, postmortem_id, created_at, rule, signal, direction, applies_to)
  SELECT ''R'' || POSTMORTEM.RESULTS.LEARN_RULE_SEQ.NEXTVAL, :dk, :pid, CURRENT_TIMESTAMP(),
         f.value:rule::STRING, f.value:signal::STRING, f.value:direction::STRING, f.value:applies_to::STRING
  FROM (SELECT TRY_PARSE_JSON(REGEXP_SUBSTR(:resp, ''\\\\{.*\\\\}'', 1, 1, ''s'')) AS j) x,
       LATERAL FLATTEN(input => x.j:rules) f
  WHERE COALESCE(f.value:rule::STRING, '''') <> '''';

  -- Gate: mask tokens, amounts, signed relative days, calendar years, month names, hindsight phrasing
  UPDATE POSTMORTEM.RESULTS.LEARN_RULES
  SET gate_hit = REGEXP_SUBSTR(rule || '' | '' || COALESCE(signal, ''''),
        ''(Analyst|Broker|Competitor|Product|Exec|Customer|Company|Partner|Provider|IR|Acquired|Place|Conference|Investor|Parent|Region)_[A-Z0-9]''
        || ''|CUR ?[0-9]|(^|[^A-Za-z0-9])D[+-][0-9]|(^|[^0-9])(19|20)[0-9][0-9]([^0-9]|$)|(^|[^A-Za-z])Y[+-][0-9]''
        || ''|January|February|March|April|June|July|August|September|October|November|December''
        || ''|turned out|subsequently|in hindsight|ended up|later reported|actual outcome|eventual'', 1, 1, ''i''),
      gate_ok = REGEXP_SUBSTR(rule || '' | '' || COALESCE(signal, ''''),
        ''(Analyst|Broker|Competitor|Product|Exec|Customer|Company|Partner|Provider|IR|Acquired|Place|Conference|Investor|Parent|Region)_[A-Z0-9]''
        || ''|CUR ?[0-9]|(^|[^A-Za-z0-9])D[+-][0-9]|(^|[^0-9])(19|20)[0-9][0-9]([^0-9]|$)|(^|[^A-Za-z])Y[+-][0-9]''
        || ''|January|February|March|April|June|July|August|September|October|November|December''
        || ''|turned out|subsequently|in hindsight|ended up|later reported|actual outcome|eventual'', 1, 1, ''i'') IS NULL
  WHERE postmortem_id = :pid;

  RETURN (SELECT COUNT(*) || '' rules, '' || COUNT_IF(gate_ok) || '' passed the gate''
          FROM POSTMORTEM.RESULTS.LEARN_RULES WHERE postmortem_id = :pid);
END;
';
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
CREATE OR REPLACE PROCEDURE POSTMORTEM.RESULTS.SP_POSTMORTEM("DK" VARCHAR, "MODE" VARCHAR DEFAULT 'masked')
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
  ctx STRING;
  intro STRING;
  prompt STRING;
  resp STRING;
  pid STRING DEFAULT UUID_STRING();
BEGIN
  IF (mode = ''named'') THEN
    -- Real amounts = masked amounts / k; % errors are identical either way
    ctx := ''CASE\\n'' || (SELECT ''Company: '' || p.ticker || ''. Investment review dated '' || p.decision_date
                               || ''. FY+1 = '' || p.fy1_label || '', FY+2 = '' || p.fy2_label || '', FY+3 = '' || p.fy3_label
                               || ''. Amounts in millions of reporting currency.''
                        FROM POSTMORTEM.RAW.KEYS x JOIN POSTMORTEM.RAW.POSITIONS p USING (decision_id) WHERE x.decision_key = :dk)
        || ''\\n\\nFORECASTS VS ACTUALS (error = forecast / actual - 1)\\n'' || COALESCE((
             SELECT LISTAGG(e.source || COALESCE('' ['' || e.model || '']'', '''') || '' '' || e.fy_rel || '': forecast ''
                            || ROUND(e.proj_cur_m / x.k, 1) || '', actual '' || ROUND(e.actual_cur_m / x.k, 1)
                            || '', error '' || e.pct_error || ''%'', ''\\n'') WITHIN GROUP (ORDER BY e.fy_rel, e.source)
             FROM POSTMORTEM.RESULTS.ERRORS e JOIN POSTMORTEM.RAW.KEYS x ON x.decision_key = e.decision_key
             WHERE e.decision_key = :dk), ''(none)'')
        || ''\\n\\nREPORTED AFTER THE REVIEW (yoy growth)\\n'' || COALESCE((
             SELECT LISTAGG(a.fy_label || '': '' || a.revenue_m || '' (reported '' || a.report_date || '')'', ''\\n'')
                      WITHIN GROUP (ORDER BY a.report_date)
             FROM POSTMORTEM.OUTCOMES.ACTUALS a JOIN POSTMORTEM.RAW.KEYS x ON x.ticker = a.ticker
             WHERE x.decision_key = :dk), ''(none)'')
        || ''\\n\\nCLAUDE INDEPENDENT REPLAY (drivers; written on masked data)\\n'' || COALESCE((
             SELECT parsed::STRING FROM POSTMORTEM.RESULTS.REPLAY_RUNS
             WHERE decision_key = :dk AND mode = ''independent'' AND model = ''claude-opus-4-6''
             ORDER BY run_at DESC LIMIT 1), ''(none)'')
        || ''\\n\\nFIRM_X INVESTMENT REVIEW (source of its projections)\\n'' || COALESCE((
             SELECT LEFT(d.text, 40000) FROM POSTMORTEM.RAW.DOC_TEXT d JOIN POSTMORTEM.RAW.KEYS x ON x.ticker = d.ticker
             WHERE x.decision_key = :dk AND d.doc_type = ''memo''), ''(none)'')
        || ''\\n\\nOUR PACKET: EVERYTHING WE HAD AT THE REVIEW DATE\\n'' || COALESCE((
             SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.RAW.NAMED_PACKET(:dk))), ''(none)'');
    intro := ''Names, dates and amounts are real. Use your own knowledge of what was public before the review date for ''
          || ''knowable_not_in_packet, and give each item the date it became public (YYYY-MM-DD).'';
  ELSE
    ctx := ''FORECASTS VS ACTUALS (error = forecast / actual - 1)\\n'' || COALESCE((
             SELECT LISTAGG(source || COALESCE('' ['' || model || '']'', '''') || '' '' || fy_rel || '': forecast '' || proj_cur_m
                            || '', actual '' || actual_cur_m || '', error '' || pct_error || ''%'', ''\\n'')
                      WITHIN GROUP (ORDER BY fy_rel, source)
             FROM POSTMORTEM.RESULTS.ERRORS WHERE decision_key = :dk), ''(none)'')
        || ''\\n\\nREPORTED AFTER D0 (CUR m, yoy growth)\\n'' || COALESCE((
             SELECT LISTAGG(fy_rel || '': '' || actual_cur_m || '' ('' || actual_growth_pct || ''%, reported D+'' || rel_report_day || '')'', ''\\n'')
                      WITHIN GROUP (ORDER BY rel_report_day)
             FROM POSTMORTEM.OUTCOMES.ACTUALS_REL WHERE decision_key = :dk), ''(none)'')
        || ''\\n\\nCLAUDE INDEPENDENT REPLAY (drivers)\\n'' || COALESCE((
             SELECT parsed::STRING FROM POSTMORTEM.RESULTS.REPLAY_RUNS
             WHERE decision_key = :dk AND mode = ''independent'' AND model = ''claude-opus-4-6''
             ORDER BY run_at DESC LIMIT 1), ''(none)'')
        || ''\\n\\nFIRM_X INVESTMENT REVIEW AT D0 (source of its projections)\\n'' || COALESCE((
             SELECT LEFT(text, 40000) FROM POSTMORTEM.MASKED.DOCUMENTS WHERE decision_key = :dk AND doc_type = ''memo''), ''(none)'')
        || ''\\n\\nOUR PACKET: EVERYTHING WE HAD AT D0\\n'' || COALESCE((
             SELECT LISTAGG(body, ''\\n\\n'') WITHIN GROUP (ORDER BY ord) FROM TABLE(POSTMORTEM.MASKED.PIT_PACKET(:dk))), ''(none)'');
    intro := ''Names, dates and amounts are masked (D-n = days before the review, FY+1 = the year in progress at the review, ''
          || ''CUR = scaled currency). Do not try to identify the company. If you nonetheless know of information that was ''
          || ''public before D0 but is not in the packet, list it under knowable_not_in_packet with its relative day.'';
  END IF;

  -- Context first, instructions last: with the documents at the end, the model kept continuing the transcript.
  prompt := ''<context>\\n'' || ctx || ''\\n</context>\\n\\n''
         || ''TASK. You are writing a revenue-projection post-mortem for Firm_X, using the context above. '' || intro || '' ''
         || ''Judge only how close the revenue projections were to reported revenue. Ignore the investment decision, ''
         || ''valuation and price targets: whether buying, passing or selling was right is out of scope. ''
         || ''State what Firm_X projected and the assumptions behind it, what was reported, and the size and direction ''
         || ''of the gap. Say which sources came closer and why. Then sort everything that explains the gap into exactly ''
         || ''one of three groups: (1) in_packet_underweighted: inputs that were in our packet but under-used, citing ''
         || ''document type and day; (2) knowable_not_in_packet: information or data that was public BEFORE the review ''
         || ''date but missing from our packet (other companies'''' disclosures, industry data, alternative data, events), ''
         || ''each with the date it became public and verified = false; (3) hindsight_only: things that only became ''
         || ''knowable AFTER the review date (events, macro moves, later disclosures). Never put a post-review fact in ''
         || ''group 1 or 2. Bias tags must rest on group 1 only, from this list: anchored_to_guidance, ''
         || ''extrapolated_recent_trend, herded_with_sell_side, ignored_visible_signal, narrative_over_numbers, ''
         || ''too_conservative_outer_years, too_aggressive_outer_years. Each tag must say whose projection it describes ''
         || ''in "about": firm_x (the investment review), claude (the replays) or consensus (sell-side and guidance). Tag ''
         || ''firm_x only for biases visible in the investment review itself. Do not tag a source that missed by less ''
         || ''than 2%. Use at most 3 tags. change_next_time is a process lesson from group 1 and from general patterns; ''
         || ''data_to_add_next_time is a checklist from group 2. Return only JSON:\\n''
         || ''{"projected": "", "reported": "", "gap": "", "closer_sources": "", ''
         || ''"in_packet_underweighted": [{"input": "", "evidence": "doc type + day", "effect": "raise|lower FY+1"}], ''
         || ''"knowable_not_in_packet": [{"input": "", "source_type": "", "public_date": "", "effect": "raise|lower FY+1", "verified": false}], ''
         || ''"hindsight_only": [{"event": "", "when": "", "effect": "raise|lower FY+1", "risk_category": ""}], ''
         || ''"bias_tags": [{"tag": "", "about": "firm_x|claude|consensus", "evidence": "", "strength_1_3": 1}], ''
         || ''"change_next_time": "", "data_to_add_next_time": [""]}''
         || ''\\nAnswer now with the JSON object only. Do not continue or quote the documents.'';

  resp := (SELECT AI_COMPLETE(model => ''claude-opus-4-8'', prompt => :prompt,
                              model_parameters => {''temperature'': 0, ''max_tokens'': 6000}));

  INSERT INTO POSTMORTEM.RESULTS.POSTMORTEMS (postmortem_id, decision_key, model, created_at, parsed, raw_response, mode)
  SELECT :pid, :dk, ''claude-opus-4-8'', CURRENT_TIMESTAMP(), TRY_PARSE_JSON(REGEXP_SUBSTR(:resp, ''\\\\{.*\\\\}'', 1, 1, ''s'')), :resp, :mode;

  -- Bias tags come from the masked run only (one source of truth); a named run leaves them alone
  IF (mode <> ''named'') THEN
    DELETE FROM POSTMORTEM.RESULTS.BIAS_TAGS WHERE decision_key = :dk;   -- keep only the latest post-mortem''s tags
    INSERT INTO POSTMORTEM.RESULTS.BIAS_TAGS
    SELECT :pid, :dk, t.value:tag::STRING, t.value:evidence::STRING, t.value:strength_1_3::INT, t.value:about::STRING
    FROM POSTMORTEM.RESULTS.POSTMORTEMS p, LATERAL FLATTEN(p.parsed:bias_tags) t
    WHERE p.postmortem_id = :pid
      AND t.value:tag::STRING IN (''anchored_to_guidance'', ''extrapolated_recent_trend'', ''herded_with_sell_side'',
          ''ignored_visible_signal'', ''narrative_over_numbers'', ''too_conservative_outer_years'', ''too_aggressive_outer_years'');
  END IF;

  RETURN (SELECT parsed::STRING FROM POSTMORTEM.RESULTS.POSTMORTEMS WHERE postmortem_id = :pid);
END;
';
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
