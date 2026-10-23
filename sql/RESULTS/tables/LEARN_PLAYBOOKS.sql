-- POSTMORTEM.RESULTS.LEARN_PLAYBOOKS (table)
-- Playbooks: a set of rule ids and their text, by purpose (inner, outer_r1, outer_r2, all), never holding
-- rules from the target or holdout case.
--
-- Written by: SP_LEARN_PLAYBOOK
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.LEARN_PLAYBOOKS (
	PLAYBOOK_ID VARCHAR(16777216),
	PURPOSE VARCHAR(16777216),
	TARGET_KEY VARCHAR(16777216),
	HOLDOUT_KEY VARCHAR(16777216),
	CREATED_AT TIMESTAMP_LTZ(9),
	RULE_IDS ARRAY,
	TEXT VARCHAR(16777216)
);
