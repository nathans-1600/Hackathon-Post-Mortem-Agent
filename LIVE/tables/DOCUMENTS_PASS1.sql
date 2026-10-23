-- POSTMORTEM.LIVE.DOCUMENTS_PASS1 (table)
-- First-pass copy of the live documents, same columns as DOCUMENTS. Nothing in the DDL reads it.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.DOCUMENTS_PASS1 (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	TEXT VARCHAR(16777216)
);
