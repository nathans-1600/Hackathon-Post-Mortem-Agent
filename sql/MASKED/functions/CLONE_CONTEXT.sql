-- POSTMORTEM.MASKED.CLONE_CONTEXT (secure function (SQL table function))
-- Extra context for clone mode: the house process plus memos of OTHER cases (for style only, never the target
-- case's own memo).
--
-- Uses: HOUSE_FRAMEWORK, DOCUMENTS

CREATE OR REPLACE SECURE FUNCTION POSTMORTEM.MASKED.CLONE_CONTEXT("DK" VARCHAR)
RETURNS TABLE ("ORD" NUMBER(38,0), "BODY" VARCHAR)
LANGUAGE SQL
AS '
  SELECT 1, ''FIRM_X HOUSE PROCESS\\n'' || text FROM POSTMORTEM.MASKED.HOUSE_FRAMEWORK
  UNION ALL
  SELECT 2, ''FIRM_X INVESTMENT REVIEW OF A DIFFERENT COMPANY (for style only)\\n'' || LEFT(text, 20000)
  FROM POSTMORTEM.MASKED.DOCUMENTS WHERE doc_type = ''memo'' AND decision_key <> dk
';
