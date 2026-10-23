-- POSTMORTEM.LIVE.LIVE_PACKET (secure function (SQL table function))
-- Builds the live case's packet, the same way PIT_PACKET does for backtest cases, from the LIVE tables.
--
-- Uses: POSITIONS, REVENUE_HISTORY, CONSENSUS, GUIDANCE, DOCUMENTS

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
