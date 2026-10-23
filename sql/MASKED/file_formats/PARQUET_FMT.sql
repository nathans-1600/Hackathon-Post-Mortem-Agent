-- POSTMORTEM.MASKED.PARQUET_FMT (file format)
-- Parquet file format for loading the masked data export.

CREATE OR REPLACE FILE FORMAT POSTMORTEM.MASKED.PARQUET_FMT
	TYPE = PARQUET
	NULL_IF = ()
;
