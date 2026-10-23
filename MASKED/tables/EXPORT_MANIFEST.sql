-- POSTMORTEM.MASKED.EXPORT_MANIFEST (table)
-- Row count and checksum per table of the masked data export, for checking that an import arrived intact.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.EXPORT_MANIFEST (
	TABLE_NAME VARCHAR(16777216),
	N_ROWS NUMBER(18,0),
	CHECKSUM FLOAT
);
