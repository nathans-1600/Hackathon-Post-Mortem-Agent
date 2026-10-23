-- POSTMORTEM.LIVE.PRIOR_LESSONS (secure function (SQL table function))
-- Text block of backtest lessons for the full variant: mean error by source, bias tags, what each post-mortem
-- said to change, and the data checklist.
--
-- Uses: RESULTS.ERRORS, RESULTS.BIAS_TAGS, RESULTS.POSTMORTEMS

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
