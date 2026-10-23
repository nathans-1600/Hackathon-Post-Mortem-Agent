-- POSTMORTEM.RESULTS.SP_LEARN_EXTRACT (stored procedure)
-- Turns a case's latest masked post-mortem (group 1 findings, tags that passed the 2% rule, process lesson)
-- into at most 4 rules with Opus 4.6, then runs the hindsight gate over them.
--
-- Uses: POSTMORTEMS, LEARN_RULES, BIAS_TAGS, LEARN_RULE_SEQ
-- Writes: LEARN_RULES
--
-- A message in the body refers to script 07 from an earlier layout of the project.
-- A CALL runs AI_COMPLETE (costs credits) and writes rows.

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
