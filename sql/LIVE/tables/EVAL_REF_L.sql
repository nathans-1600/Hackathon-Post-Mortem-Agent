-- POSTMORTEM.LIVE.EVAL_REF_L (table)
-- Snapshot of live reference numbers (FY+1 growth for each view, consensus, playbook rule count, source and
-- record) used to build evaluation ground truth.
--
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.LIVE.EVAL_REF_L (
	BUILT_AT TIMESTAMP_LTZ(9),
	DK VARCHAR(16777216),
	RAW1 FLOAT,
	PB1 FLOAT,
	FULL1 FLOAT,
	ADJ1 FLOAT,
	CONS1 FLOAT,
	GUIDE1 FLOAT,
	ANALYST1 FLOAT,
	CONS_ALL VARCHAR(16777216),
	PB_RULE_N NUMBER(18,0),
	PB_RULE_SRC VARCHAR(16777216),
	PB_RULE_RECORD VARCHAR(16777216)
);
