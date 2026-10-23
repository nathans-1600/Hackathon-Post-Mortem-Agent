-- POSTMORTEM.RESULTS.SP_POSTMORTEM (stored procedure)
-- Writes a post-mortem for a case with Opus 4.8: compares each forecast with reported revenue and sorts every
-- explanation into one of three groups. In masked mode it also replaces the case's bias tags.
--
-- Uses: ERRORS, REPLAY_RUNS, OUTCOMES.ACTUALS_REL, MASKED.DOCUMENTS, MASKED.PIT_PACKET, POSTMORTEMS,
--   BIAS_TAGS
-- Writes: POSTMORTEMS, BIAS_TAGS
--
-- Known gap: named mode reads POSTMORTEM.RAW.* and OUTCOMES.ACTUALS, which do not exist, so it cannot run.
-- A CALL runs AI_COMPLETE (costs credits) and writes rows.

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
