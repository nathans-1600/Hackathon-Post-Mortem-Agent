-- 01_masked.sql
-- POSTMORTEM.MASKED: masked case data and the packet builders.
-- DDL only. WARNING: CREATE OR REPLACE TABLE drops existing data; run on a fresh database.

create or replace TABLE POSTMORTEM.MASKED.CONSENSUS (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	NUM_ESTIMATES NUMBER(38,0)
);
create or replace TABLE POSTMORTEM.MASKED.DOCUMENTS (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	TEXT VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.MASKED.DOC_CHUNKS (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	CHUNK_NO NUMBER(38,0),
	CHUNK VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.MASKED.EXPORT_MANIFEST (
	TABLE_NAME VARCHAR(16777216),
	N_ROWS NUMBER(18,0),
	CHECKSUM FLOAT
);
create or replace TABLE POSTMORTEM.MASKED.GUIDANCE (
	DECISION_KEY VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	PERIOD_REL VARCHAR(16777216),
	LOW_CUR_M FLOAT,
	HIGH_CUR_M FLOAT,
	GROWTH_LOW_PCT NUMBER(6,2),
	GROWTH_HIGH_PCT NUMBER(6,2)
);
create or replace TABLE POSTMORTEM.MASKED.HOUSE_FRAMEWORK (
	TEXT VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.MASKED.PARNASSUS_PROJ (
	DECISION_KEY VARCHAR(16777216),
	FY_REL VARCHAR(16777216),
	REVENUE_CUR_M FLOAT,
	GROWTH_PCT NUMBER(6,2)
);
create or replace TABLE POSTMORTEM.MASKED.POSITIONS (
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	IS_LIVE BOOLEAN,
	FY1 VARCHAR(16777216),
	FY2 VARCHAR(16777216),
	FY3 VARCHAR(16777216),
	TIER VARCHAR(16777216)
);
create or replace TABLE POSTMORTEM.MASKED.REVENUE_HISTORY (
	DECISION_KEY VARCHAR(16777216),
	PERIOD_REL VARCHAR(16777216),
	REL_REPORT_DAY NUMBER(9,0),
	REVENUE_CUR_M FLOAT
);
CREATE OR REPLACE FILE FORMAT POSTMORTEM.MASKED.PARQUET_FMT
	TYPE = PARQUET
	NULL_IF = ()
;
CREATE OR REPLACE SECURE FUNCTION POSTMORTEM.MASKED.CLONE_CONTEXT("DK" VARCHAR)
RETURNS TABLE ("ORD" NUMBER(38,0), "BODY" VARCHAR)
LANGUAGE SQL
AS '
  SELECT 1, ''FIRM_X HOUSE PROCESS\\n'' || text FROM POSTMORTEM.MASKED.HOUSE_FRAMEWORK
  UNION ALL
  SELECT 2, ''FIRM_X INVESTMENT REVIEW OF A DIFFERENT COMPANY (for style only)\\n'' || LEFT(text, 20000)
  FROM POSTMORTEM.MASKED.DOCUMENTS WHERE doc_type = ''memo'' AND decision_key <> dk
';
CREATE OR REPLACE SECURE FUNCTION POSTMORTEM.MASKED.PIT_PACKET("DK" VARCHAR)
RETURNS TABLE ("ORD" NUMBER(38,0), "BODY" VARCHAR)
LANGUAGE SQL
AS '
  SELECT 1, ''CASE '' || decision_key || ''. You are standing on day D0 and know nothing after it. ''
         || ''FY0 = last fully reported fiscal year; FY+1 is the year in progress. Project FY+1, FY+2, FY+3. ''
         || ''Amounts are CUR millions on an undisclosed scale.''
  FROM POSTMORTEM.MASKED.POSITIONS WHERE decision_key = dk
  UNION ALL
  SELECT 2, ''REPORTED REVENUE (CUR m)\\n''
         || LISTAGG(period_rel || '': '' || revenue_cur_m || ''  [reported D'' || rel_report_day || '']'', ''\\n'')
              WITHIN GROUP (ORDER BY rel_report_day)
  FROM POSTMORTEM.MASKED.REVENUE_HISTORY WHERE decision_key = dk
  UNION ALL
  SELECT 3, ''CONSENSUS REVENUE AS OF D'' || MAX(rel_day) || '' (CUR m)\\n''
         || LISTAGG(fy_rel || '': '' || revenue_cur_m || '' ('' || num_estimates || '' estimates)'', ''\\n'')
              WITHIN GROUP (ORDER BY fy_rel)
  FROM POSTMORTEM.MASKED.CONSENSUS WHERE decision_key = dk
  UNION ALL
  SELECT 4, ''MANAGEMENT REVENUE GUIDANCE (CUR m)\\n''
         || LISTAGG(''issued D'' || rel_day || '' for '' || period_rel || '': ''
                    || COALESCE(low_cur_m::STRING, ''n/a'') || '' to '' || COALESCE(high_cur_m::STRING, ''n/a'')
                    || COALESCE('' (growth '' || growth_low_pct || ''% to '' || growth_high_pct || ''%)'', ''''), ''\\n'')
              WITHIN GROUP (ORDER BY rel_day)
  FROM POSTMORTEM.MASKED.GUIDANCE WHERE decision_key = dk
  UNION ALL
  -- newest first, so the 150k-character cap drops the oldest material
  SELECT 5, ''DOCUMENTS (newest first)\\n''
         || LEFT(LISTAGG(''### '' || doc_type || '' D'' || rel_day || ''\\n'' || text, ''\\n\\n'')
                   WITHIN GROUP (ORDER BY rel_day DESC), 150000)
  FROM POSTMORTEM.MASKED.DOCUMENTS WHERE decision_key = dk AND doc_type <> ''memo''
';
