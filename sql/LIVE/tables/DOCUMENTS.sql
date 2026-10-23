-- POSTMORTEM.LIVE.DOCUMENTS (table)
-- Masked documents of the live case, dated before D0 (same shape as MASKED.DOCUMENTS). LIVE_PACKET reads
-- every type except the memo.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.DOCUMENTS (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	TEXT VARCHAR(16777216)
);
