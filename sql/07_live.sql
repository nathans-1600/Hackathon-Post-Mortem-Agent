-- 07_live.sql
-- POSTMORTEM.LIVE: the live sanity-check case (a masked case with no outcome yet).
-- Run after 05_results_procedures.sql (reads RESULTS views and tables).
-- DDL only. WARNING: CREATE OR REPLACE TABLE drops existing data.

create or replace TABLE POSTMORTEM.LIVE.CONSENSUS (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	NUM_ESTIMATES NUMBER(38,0)
);
create or replace TABLE POSTMORTEM.LIVE.DOCUMENTS (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	TEXT VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.LIVE.DOCUMENTS_PASS1 (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	TEXT VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.LIVE.EVAL_LIVE_SANITY (
	INPUT_QUERY VARCHAR(16777216),
	GROUND_TRUTH VARIANT
);
create or replace TABLE POSTMORTEM.LIVE.GUIDANCE (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	PERIOD_REL VARCHAR(16777216),
	LOW_CUR_M FLOAT,
	HIGH_CUR_M FLOAT,
	GROWTH_LOW_PCT FLOAT,
	GROWTH_HIGH_PCT FLOAT
);
create or replace TABLE POSTMORTEM.LIVE.LIVE_DOC_CHUNKS (
	DOC_UUID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	CHUNK_NO NUMBER(38,0),
	CHUNK VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.LIVE.LIVE_RUNS (
	RUN_ID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	VARIANT VARCHAR(16777216),
	MODEL VARCHAR(16777216),
	RUN_AT TIMESTAMP_LTZ(9),
	FY1_GROWTH_PCT FLOAT,
	FY2_GROWTH_PCT FLOAT,
	FY3_GROWTH_PCT FLOAT,
	CONFIDENCE NUMBER(38,0),
	PARSED VARIANT,
	RAW_RESPONSE VARCHAR(16777216),
	PROMPT_CHARS NUMBER(38,0),
	PLAYBOOK_ID VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.LIVE.PARNASSUS_PROJ (
	DECISION_KEY VARCHAR(16777216),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	GROWTH_PCT FLOAT
);
create or replace TABLE POSTMORTEM.LIVE.POSITIONS (
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	IS_LIVE BOOLEAN,
	FY1 VARCHAR(16777216),
	FY2 VARCHAR(16777216),
	FY3 VARCHAR(16777216),
	TIER VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.LIVE.REVENUE_HISTORY (
	DECISION_KEY VARCHAR(16777216),
	PERIOD_REL VARCHAR(16777216),
	REL_REPORT_DAY NUMBER(38,0),
	REVENUE_CUR_M FLOAT
);
create or replace TABLE POSTMORTEM.LIVE.SANITY_REPORTS (
	DECISION_KEY VARCHAR(16777216),
	CREATED_AT TIMESTAMP_LTZ(9),
	REPORT VARCHAR(16777216),
	CONTEXT VARCHAR(16777216)
);
create or replace view POSTMORTEM.LIVE.LIVE_RUNS_LATEST(
	VARIANT,
	MODEL,
	RUN_AT,
	FY1_GROWTH_PCT,
	FY2_GROWTH_PCT,
	FY3_GROWTH_PCT,
	CONFIDENCE,
	VS_CONSENSUS,
	KEY_RISKS,
	N_RULES_APPLIED
) as
SELECT variant, model, run_at, fy1_growth_pct, fy2_growth_pct, fy3_growth_pct, confidence,
       parsed:vs_consensus::STRING AS vs_consensus,
       ARRAY_TO_STRING(parsed:key_risks::ARRAY, '; ') AS key_risks,
       COALESCE(ARRAY_SIZE(parsed:rules_applied), 0) AS n_rules_applied
FROM POSTMORTEM.LIVE.LIVE_RUNS
WHERE fy1_growth_pct IS NOT NULL
QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, variant, model);
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
create or replace view POSTMORTEM.LIVE.LIVE_COMPARISON(
	FY_REL,
	CLAUDE_RAW,
	CLAUDE_PLAYBOOK,
	CLAUDE_PLAYBOOK_LESSONS,
	CLAUDE_RAW_BIAS_ADJUSTED,
	CONSENSUS,
	GUIDANCE_MID,
	ANALYST
) as   -- one row per FY: every view of the year, in growth %
WITH runs AS (
  SELECT * FROM POSTMORTEM.LIVE.LIVE_RUNS WHERE fy1_growth_pct IS NOT NULL AND model = 'claude-opus-4-6'
  QUALIFY run_at = MAX(run_at) OVER (PARTITION BY decision_key, variant)),
fy AS (SELECT column1 AS fy_rel, column2 AS ord FROM (VALUES ('FY+1', 1), ('FY+2', 2), ('FY+3', 3))),
claude AS (
  SELECT r.decision_key, f.fy_rel, r.variant,
         CASE f.ord WHEN 1 THEN r.fy1_growth_pct WHEN 2 THEN r.fy2_growth_pct ELSE r.fy3_growth_pct END AS g
  FROM runs r CROSS JOIN fy f),
fy0 AS (SELECT decision_key, revenue_cur_m AS v FROM POSTMORTEM.LIVE.REVENUE_HISTORY WHERE period_rel = 'FY0'),
cons AS (
  SELECT c.decision_key, c.fy_rel,
         ROUND(100 * (c.revenue_cur_m / COALESCE(LAG(c.revenue_cur_m) OVER (PARTITION BY c.decision_key ORDER BY c.fy_rel), z.v) - 1), 1) AS g
  FROM POSTMORTEM.LIVE.CONSENSUS c JOIN fy0 z USING (decision_key)),
guide AS (   -- latest full-year guide for FY+1, midpoint growth
  SELECT g.decision_key, 'FY+1' AS fy_rel,
         ROUND(COALESCE((g.growth_low_pct + g.growth_high_pct) / 2,
                        100 * (((g.low_cur_m + g.high_cur_m) / 2) / z.v - 1)), 1) AS g
  FROM POSTMORTEM.LIVE.GUIDANCE g JOIN fy0 z USING (decision_key)
  WHERE g.period_rel = 'FY+1'
  QUALIFY g.rel_day = MAX(g.rel_day) OVER (PARTITION BY g.decision_key)),
bias AS (    -- Opus 4.6's mean signed FY+1 error in its plain (independent) masked backtest replays
  SELECT AVG(pct_error) AS m, COUNT(*) AS n FROM POSTMORTEM.RESULTS.ERRORS
  WHERE source = 'claude_independent' AND model = 'claude-opus-4-6' AND fy_rel = 'FY+1')
SELECT f.fy_rel,
       MAX(IFF(c.variant = 'raw', c.g, NULL))      AS claude_raw,
       MAX(IFF(c.variant = 'playbook', c.g, NULL)) AS claude_playbook,
       MAX(IFF(c.variant = 'full', c.g, NULL))     AS claude_playbook_lessons,
       IFF(f.fy_rel = 'FY+1', ROUND(100 * ((1 + MAX(IFF(c.variant = 'raw', c.g, NULL)) / 100) / (1 + ANY_VALUE(b.m) / 100) - 1), 1), NULL)
                                                   AS claude_raw_bias_adjusted,
       ANY_VALUE(k.g)                              AS consensus,
       ANY_VALUE(gd.g)                             AS guidance_mid,
       ANY_VALUE(pp.growth_pct)                    AS analyst
FROM fy f
JOIN POSTMORTEM.LIVE.POSITIONS p ON TRUE
LEFT JOIN claude c ON c.decision_key = p.decision_key AND c.fy_rel = f.fy_rel
LEFT JOIN cons k ON k.decision_key = p.decision_key AND k.fy_rel = f.fy_rel
LEFT JOIN guide gd ON gd.decision_key = p.decision_key AND gd.fy_rel = f.fy_rel
LEFT JOIN POSTMORTEM.LIVE.PARNASSUS_PROJ pp ON pp.decision_key = p.decision_key AND pp.fy_rel = f.fy_rel
CROSS JOIN bias b
GROUP BY f.fy_rel, f.ord ORDER BY f.ord;
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
create or replace view POSTMORTEM.LIVE.SANITY_REPORT_LATEST(
	DECISION_KEY,
	CREATED_AT,
	REPORT
) as
SELECT decision_key, created_at, report FROM POSTMORTEM.LIVE.SANITY_REPORTS
QUALIFY created_at = MAX(created_at) OVER (PARTITION BY decision_key);
CREATE OR REPLACE FILE FORMAT POSTMORTEM.LIVE.NDJSON_FMT
	TYPE = JSON
	NULL_IF = ()
;
CREATE OR REPLACE SECURE FUNCTION POSTMORTEM.LIVE.LIVE_PACKET("DK" VARCHAR)
RETURNS TABLE ("ORD" NUMBER(38,0), "BODY" VARCHAR)
LANGUAGE SQL
AS '
  SELECT 1, ''CASE '' || decision_key || ''. You are standing on day D0 and know nothing after it. ''
         || ''FY0 = last fully reported fiscal year; FY+1 is the year in progress. Project FY+1, FY+2, FY+3. ''
         || ''Amounts are CUR millions on an undisclosed scale.''
  FROM POSTMORTEM.LIVE.POSITIONS WHERE decision_key = dk
  UNION ALL
  SELECT 2, ''REPORTED REVENUE (CUR m)\\n''
         || LISTAGG(period_rel || '': '' || revenue_cur_m || ''  [reported D'' || rel_report_day || '']'', ''\\n'')
              WITHIN GROUP (ORDER BY rel_report_day)
  FROM POSTMORTEM.LIVE.REVENUE_HISTORY WHERE decision_key = dk
  UNION ALL
  SELECT 3, ''CONSENSUS REVENUE AS OF D'' || MAX(rel_day) || '' (CUR m)\\n''
         || LISTAGG(fy_rel || '': '' || revenue_cur_m || '' ('' || num_estimates || '' estimates)'', ''\\n'')
              WITHIN GROUP (ORDER BY fy_rel)
  FROM POSTMORTEM.LIVE.CONSENSUS WHERE decision_key = dk
  UNION ALL
  SELECT 4, ''MANAGEMENT REVENUE GUIDANCE (CUR m)\\n''
         || LISTAGG(''issued D'' || rel_day || '' for '' || period_rel || '': ''
                    || COALESCE(low_cur_m::STRING, ''n/a'') || '' to '' || COALESCE(high_cur_m::STRING, ''n/a'')
                    || COALESCE('' (growth '' || growth_low_pct || ''% to '' || growth_high_pct || ''%)'', ''''), ''\\n'')
              WITHIN GROUP (ORDER BY rel_day)
  FROM POSTMORTEM.LIVE.GUIDANCE WHERE decision_key = dk
  UNION ALL
  SELECT 5, ''DOCUMENTS (newest first)\\n''
         || LEFT(LISTAGG(''### '' || doc_type || '' D'' || rel_day || ''\\n'' || text, ''\\n\\n'')
                   WITHIN GROUP (ORDER BY rel_day DESC), 150000)
  FROM POSTMORTEM.LIVE.DOCUMENTS WHERE decision_key = dk AND doc_type <> ''memo''
';
CREATE OR REPLACE SECURE FUNCTION POSTMORTEM.LIVE.PRIOR_LESSONS()
RETURNS TABLE ("ORD" NUMBER(38,0), "BODY" VARCHAR)
LANGUAGE SQL
AS '
  SELECT 1, ''TRACK RECORD: MEAN REVENUE ERROR BY SOURCE (error = forecast / actual - 1; positive = too high)\\n''
         || LISTAGG(source || COALESCE('' ['' || model || '']'', '''') || '' '' || fy_rel || '': mean '' || m || ''%, mean abs ''
                    || a || ''% (n='' || n || '')'', ''\\n'') WITHIN GROUP (ORDER BY fy_rel, a)
  FROM (SELECT source, model, fy_rel, ROUND(AVG(pct_error), 1) m, ROUND(AVG(abs_pct_error), 1) a, COUNT(*) n
        FROM POSTMORTEM.RESULTS.ERRORS GROUP BY 1, 2, 3)
  UNION ALL
  SELECT 2, ''BIAS TAGS FROM POST-MORTEMS (whose projection: tag, cases, example evidence)\\n''
         || LISTAGG(about || '': '' || tag || '', '' || n || '' cases - '' || ev, ''\\n'') WITHIN GROUP (ORDER BY about, n DESC)
  FROM (SELECT about, tag, COUNT(DISTINCT decision_key) n, ANY_VALUE(evidence) ev
        FROM POSTMORTEM.RESULTS.BIAS_TAGS
        WHERE postmortem_id IN (SELECT postmortem_id FROM POSTMORTEM.RESULTS.POSTMORTEMS WHERE COALESCE(mode, ''masked'') = ''masked'')
        GROUP BY 1, 2)
  UNION ALL
  SELECT 3, ''WHAT EACH POST-MORTEM SAID TO CHANGE NEXT TIME\\n''
         || LISTAGG(''- '' || parsed:change_next_time::STRING, ''\\n'') WITHIN GROUP (ORDER BY created_at)
  FROM (SELECT * FROM POSTMORTEM.RESULTS.POSTMORTEMS WHERE parsed IS NOT NULL AND COALESCE(mode, ''masked'') = ''masked''
        QUALIFY created_at = MAX(created_at) OVER (PARTITION BY decision_key))
  UNION ALL
  SELECT 4, ''DATA PAST POST-MORTEMS SAID WE SHOULD ALSO HAVE CHECKED (unverified)\\n''
         || LISTAGG(DISTINCT ''- '' || f.value::STRING, ''\\n'')
  FROM (SELECT * FROM POSTMORTEM.RESULTS.POSTMORTEMS
        WHERE parsed:data_to_add_next_time IS NOT NULL AND COALESCE(mode, ''masked'') = ''masked''
        QUALIFY created_at = MAX(created_at) OVER (PARTITION BY decision_key)) p,
       LATERAL FLATTEN(p.parsed:data_to_add_next_time) f
  WHERE f.value::STRING <> ''''
';
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
CREATE OR REPLACE PROCEDURE POSTMORTEM.LIVE.SP_LIVE_SANITY_TOOL("DK" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
  k STRING;
BEGIN
  k := COALESCE((SELECT MAX(decision_key) FROM POSTMORTEM.LIVE.POSITIONS WHERE decision_key = :dk AND is_live),
                (SELECT MIN(decision_key) FROM POSTMORTEM.LIVE.POSITIONS WHERE is_live));
  IF (k IS NULL) THEN
    RETURN ''No live case loaded in POSTMORTEM.LIVE.'';
  END IF;
  CALL POSTMORTEM.LIVE.SP_LIVE_SANITY(:k);
  RETURN (SELECT report FROM POSTMORTEM.LIVE.SANITY_REPORTS WHERE decision_key = :k ORDER BY created_at DESC LIMIT 1);
END;
';
