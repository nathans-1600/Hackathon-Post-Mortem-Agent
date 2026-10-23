-- POSTMORTEM.RESULTS.LEARN_RULES (table)
-- Rules learned from post-mortems: rule text, signal, direction, which years it applies to, the case it came
-- from, and the hindsight-gate result (gate_ok, gate_hit).
--
-- Written by: SP_LEARN_EXTRACT
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.LEARN_RULES (
	RULE_ID VARCHAR(16777216),
	SOURCE_KEY VARCHAR(16777216),
	POSTMORTEM_ID VARCHAR(16777216),
	CREATED_AT TIMESTAMP_LTZ(9),
	RULE VARCHAR(16777216),
	SIGNAL VARCHAR(16777216),
	DIRECTION VARCHAR(16777216),
	APPLIES_TO VARCHAR(16777216),
	GATE_OK BOOLEAN,
	GATE_HIT VARCHAR(16777216)
);
