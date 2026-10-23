-- POSTMORTEM.LIVE.SANITY_REPORTS (table)
-- Written sanity-check reports, with the context each was written from.
--
-- Written by: SP_LIVE_SANITY
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.SANITY_REPORTS (
	DECISION_KEY VARCHAR(16777216),
	CREATED_AT TIMESTAMP_LTZ(9),
	REPORT VARCHAR(16777216),
	CONTEXT VARCHAR(16777216)
);
