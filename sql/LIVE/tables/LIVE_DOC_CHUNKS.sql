-- POSTMORTEM.LIVE.LIVE_DOC_CHUNKS (table)
-- Live documents split into chunks; indexed by the LIVE_DOC_SEARCH Cortex Search service.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.LIVE_DOC_CHUNKS (
	DOC_UUID VARCHAR(16777216),
	DOC_TYPE VARCHAR(16777216),
	REL_DAY NUMBER(38,0),
	CHUNK_NO NUMBER(38,0),
	CHUNK VARCHAR(16777216)
);
