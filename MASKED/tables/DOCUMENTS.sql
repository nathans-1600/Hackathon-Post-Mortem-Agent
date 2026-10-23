-- POSTMORTEM.MASKED.DOCUMENTS (table)
-- Masked source documents per case (filings, call transcripts, sell-side notes and the Firm_X memo), dated in
-- days relative to D0. PIT_PACKET reads every type except the memo.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.DOCUMENTS (
	DOC_UUID VARCHAR(16777216),
	DECISION_KEY VARCHAR(16777216),
	CO_ID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(9,0),
	TEXT VARCHAR(16777216)
);
