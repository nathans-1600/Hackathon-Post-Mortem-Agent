-- POSTMORTEM.RESULTS.PM_BRIEF (table)
-- A plain-English brief for each backtest case: a headline, why Firm_X and Claude missed, fixes for next time,
-- and what was only knowable afterwards. Opus 4.8 writes the brief from the masked post-mortem, scored errors
-- and findings; the closest forecaster and Firm_X's rank are computed in SQL, not by the model.
--
-- Read by APP.POSTMORTEM_APP, which shows it first on its "Where each went wrong" tab. No stored procedure
-- in this database writes it.
-- WARNING: CREATE OR REPLACE TABLE drops existing data. Run only on a fresh, empty database.

create or replace TABLE POSTMORTEM.RESULTS.PM_BRIEF (
	DECISION_KEY VARCHAR(16777216),
	CLOSEST VARCHAR(16777216),
	CLOSEST_ERR FLOAT,
	N_CLOSER_THAN_US NUMBER(13,0),
	N_OTHERS NUMBER(19,0),
	BRIEF VARIANT,
	RAW_RESPONSE VARIANT,
	MODEL VARCHAR(15),
	CREATED_AT TIMESTAMP_LTZ(9)
)COMMENT='Plain-English brief per backtest case (Opus 4.8, from the masked post-mortem, scored errors and findings). Closest forecaster and our rank are computed in SQL, not by the model. Shown first in the app tab Where each went wrong.'
;
