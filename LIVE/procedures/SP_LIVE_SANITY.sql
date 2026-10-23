-- POSTMORTEM.LIVE.SP_LIVE_SANITY (stored procedure)
-- Runs the three live variants, then has Opus 4.8 write the sanity-check report from the comparison, the
-- rules that fired and the backtest record.
--
-- Uses: SP_LIVE_REPLAY, LIVE_COMPARISON, LIVE_RULES_APPLIED, LIVE_RUNS, RESULTS.LEARN_RUN_ERRORS,
--   RESULTS.ERRORS, RESULTS.BIAS_TAGS, RESULTS.POSTMORTEMS, SANITY_REPORTS
-- Writes: SANITY_REPORTS
--
-- A CALL runs AI_COMPLETE (costs credits) and writes rows.

CREATE OR REPLACE PROCEDURE POSTMORTEM.LIVE.SP_LIVE_SANITY("DK" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
  ctx STRING;
  resp STRING;
BEGIN
  CALL POSTMORTEM.LIVE.SP_LIVE_REPLAY(:dk, ''raw'', ''claude-opus-4-6'');
  CALL POSTMORTEM.LIVE.SP_LIVE_REPLAY(:dk, ''playbook'', ''claude-opus-4-6'');
  CALL POSTMORTEM.LIVE.SP_LIVE_REPLAY(:dk, ''full'', ''claude-opus-4-6'');

  ctx := ''GROWTH BY FISCAL YEAR, % (Claude = Opus 4.6 replays of the same masked packet)\\n''
      || ''FY | Claude raw | + playbook | + playbook + lessons | raw bias-adjusted | consensus | guidance mid | analyst (Firm_X)\\n''
      || COALESCE((SELECT LISTAGG(fy_rel || '' | '' || COALESCE(claude_raw::STRING, ''-'') || '' | '' || COALESCE(claude_playbook::STRING, ''-'')
                     || '' | '' || COALESCE(claude_playbook_lessons::STRING, ''-'') || '' | '' || COALESCE(claude_raw_bias_adjusted::STRING, ''-'')
                     || '' | '' || COALESCE(consensus::STRING, ''-'') || '' | '' || COALESCE(guidance_mid::STRING, ''-'')
                     || '' | '' || COALESCE(analyst::STRING, ''-''), ''\\n'') WITHIN GROUP (ORDER BY fy_rel)
                   FROM POSTMORTEM.LIVE.LIVE_COMPARISON), ''(none)'')
      || ''\\n\\nRULES APPLIED (variant: rule, direction, learned from past case, rule text)\\n''
      || COALESCE((SELECT LISTAGG(variant || '': '' || rule_id || '', '' || COALESCE(direction, ''?'') || '', case ''
                     || COALESCE(learned_from_case, ''?'') || '' - '' || COALESCE(rule, ''''), ''\\n'') WITHIN GROUP (ORDER BY variant, rule_id)
                   FROM POSTMORTEM.LIVE.LIVE_RULES_APPLIED), ''(none)'')
      || ''\\n\\nCLAUDE''''S REASONING (latest run per variant: view vs consensus; drivers)\\n''
      || COALESCE((SELECT LISTAGG(variant || '': '' || COALESCE(parsed:vs_consensus::STRING, '''') || '' | drivers: ''
                     || LEFT(COALESCE(parsed:drivers::STRING, ''''), 800), ''\\n'') WITHIN GROUP (ORDER BY variant)
                   FROM (SELECT * FROM POSTMORTEM.LIVE.LIVE_RUNS WHERE decision_key = :dk AND model = ''claude-opus-4-6''
                         QUALIFY run_at = MAX(run_at) OVER (PARTITION BY variant))), ''(none)'')
      || ''\\n\\nHOW THE PLAYBOOK DID ON THE BACKTEST (leave-one-out, FY+1 mean abs error, Opus 4.6)\\n''
      || COALESCE((SELECT ''baseline '' || ROUND(AVG(base_abs_err), 2) || ''% -> with playbook '' || ROUND(AVG(learned_abs_err), 2)
                     || ''%; '' || COUNT_IF(gain_pts > 0) || '' better, '' || COUNT_IF(gain_pts < 0) || '' worse, ''
                     || COUNT_IF(gain_pts = 0) || '' unchanged, of '' || COUNT(*) || '' cases''
                   FROM (SELECT * FROM POSTMORTEM.RESULTS.LEARN_RUN_ERRORS WHERE fy_rel = ''FY+1'' AND purpose = ''outer_r1''
                         QUALIFY ROW_NUMBER() OVER (PARTITION BY decision_key ORDER BY run_at DESC) = 1)), ''(not run)'')
      || ''\\n\\nTRACK RECORD: FY+1 MEAN ERROR BY SOURCE IN PAST CASES\\n''
      || COALESCE((SELECT LISTAGG(source || COALESCE('' ['' || model || '']'', '''') || '': mean '' || m || ''%, mean abs '' || a || ''% (n='' || n || '')'', ''\\n'')
                   FROM (SELECT source, model, ROUND(AVG(pct_error), 1) m, ROUND(AVG(abs_pct_error), 1) a, COUNT(*) n
                         FROM POSTMORTEM.RESULTS.ERRORS WHERE fy_rel = ''FY+1'' GROUP BY 1, 2)), ''(none)'')
      || ''\\n\\nFIRM_X BIAS LIBRARY (tag: cases, example evidence)\\n''
      || COALESCE((SELECT LISTAGG(tag || '': '' || n || '' - '' || ev, ''\\n'')
                   FROM (SELECT tag, COUNT(DISTINCT decision_key) n, ANY_VALUE(evidence) ev FROM POSTMORTEM.RESULTS.BIAS_TAGS
                         WHERE about = ''firm_x''
                           AND postmortem_id IN (SELECT postmortem_id FROM POSTMORTEM.RESULTS.POSTMORTEMS WHERE COALESCE(mode, ''masked'') = ''masked'')
                         GROUP BY 1)), ''(none)'');

  resp := (SELECT AI_COMPLETE(model => ''claude-opus-4-8'',
    prompt => ''You are a sanity check for a buy-side analyst, working only in masked terms. The company, people, ''
           || ''brokers and dates are tokens; never try to identify them, and never name a real company, product, ''
           || ''broker, person, calendar year or month. Below: the same Opus 4.6 forecaster run three ways on one masked ''
           || ''packet (raw; with a playbook of rules learned from post-mortems of OTHER past cases; with the playbook ''
           || ''plus the track record of past runs), against consensus, the guidance midpoint and the analyst''''s model.\\n''
           || ''Write, in under 350 words:\\n''
           || ''1. A table: FY, Claude raw, + playbook, + playbook + lessons, raw bias-adjusted (FY+1), consensus, ''
           || ''guidance mid, analyst.\\n''
           || ''2. What the past learnings changed: which rules fired (by id and in a few words), which way they moved ''
           || ''FY+1 and by how much, and what the lessons added on top.\\n''
           || ''3. 2-4 flags: where the analyst or consensus resembles a past bias in the library, where the rules may ''
           || ''not fit this case (most learned rules push estimates up; say so if that matters here), and what to check.\\n''
           || ''4. One line of caveats: the playbook was tested on five past cases (an illustration, not proof), and this ''
           || ''is a forecast with no outcome yet.\\n\\n''
           || :ctx,
    model_parameters => {''temperature'': 0, ''max_tokens'': 2500}));

  INSERT INTO POSTMORTEM.LIVE.SANITY_REPORTS SELECT :dk, CURRENT_TIMESTAMP(), :resp, :ctx;
  RETURN resp;
END;
';
