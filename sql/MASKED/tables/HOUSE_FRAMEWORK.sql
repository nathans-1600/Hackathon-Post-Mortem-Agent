-- POSTMORTEM.MASKED.HOUSE_FRAMEWORK (table)
-- Firm_X house-process text, read by CLONE_CONTEXT for clone mode.
--
-- Known gap: empty on the source, so clone mode has no house-process text.
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.MASKED.HOUSE_FRAMEWORK (
	TEXT VARCHAR(16777216)
);
