-- POSTMORTEM.APP.RAW_TXT (file format)
-- Reads a whole staged file as one text value (no record or field delimiters), e.g. to read the app's
-- source back from APP_STAGE with SQL.

CREATE OR REPLACE FILE FORMAT POSTMORTEM.APP.RAW_TXT
	RECORD_DELIMITER = 'NONE'
	FIELD_DELIMITER = 'NONE'
	ESCAPE_UNENCLOSED_FIELD = 'NONE'
;
