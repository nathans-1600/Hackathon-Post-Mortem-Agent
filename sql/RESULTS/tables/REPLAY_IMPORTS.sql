-- POSTMORTEM.RESULTS.REPLAY_IMPORTS (table)
-- Replay runs imported from another account, with the document checksum at export time; read by
-- REPLAY_RUN_FRESH.
--
-- Empty on the source.
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.REPLAY_IMPORTS (
	RUN_ID VARCHAR(16777216),
	SOURCE_ACCOUNT VARCHAR(16777216),
	DOCS_CHECKSUM NUMBER(38,0),
	EXPORTED_AT TIMESTAMP_LTZ(9),
	IMPORTED_AT TIMESTAMP_LTZ(9)
);
