-- POSTMORTEM.LIVE.NDJSON_FMT (file format)
-- JSON (newline-delimited) file format for loading live data.

CREATE OR REPLACE FILE FORMAT POSTMORTEM.LIVE.NDJSON_FMT
	TYPE = JSON
	NULL_IF = ()
;
