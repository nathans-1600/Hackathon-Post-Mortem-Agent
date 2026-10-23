-- POSTMORTEM.APP.POSTMORTEM_APP (Streamlit app)
-- "Decision Post-Mortem": a read-only Streamlit in Snowflake app over the masked results. Tabs: how each
-- forecaster did, where each went wrong, institutional biases, the learning loop, the live sanity check, agent
-- evaluations, and sources. It calls no model, so opening it costs only warehouse time.
--
-- Uses: APP_STAGE (source), PM_WH. The app reads MASKED.POSITIONS, MASKED.DOCUMENTS, RESULTS.ERRORS,
--   RESULTS.PM_BRIEF, RESULTS.PM_REPORTS, RESULTS.PM_FINDINGS, RESULTS.PM_TAGS, RESULTS.LEARN_SUMMARY,
--   RESULTS.LEARN_RULE_SCORES, RESULTS.EVAL_HISTORY, RESULTS.PIPELINE_STATUS, LIVE.LIVE_COMPARISON,
--   LIVE.PLAYBOOK_RECORD, LIVE.LIVE_RUNS_LATEST, LIVE.SANITY_REPORT_LATEST, LIVE.DOCUMENTS
--
-- Source: POSTMORTEM_APP/streamlit_app_v9.py, the main file, exported byte for byte from APP_STAGE. Upload it
-- to @POSTMORTEM.APP.APP_STAGE (PUT, AUTO_COMPRESS = FALSE) before running this. The stage also holds earlier
-- drafts (streamlit_app.py, streamlit_app_v2.py to _v8.py) that the app does not use; they are not exported.
-- A comment in the source refers to sql/09c_eval_fixes.sql, a script from an earlier layout of this project.

create or replace streamlit POSTMORTEM.APP.POSTMORTEM_APP
	from '@POSTMORTEM.APP.APP_STAGE'
	main_file='streamlit_app_v9.py'
	query_warehouse='PM_WH'
	comment='Masked: how we and Claude did, where each went wrong, institutional biases, learning loop, live sanity check (Company_F), evals'
	title='Decision Post-Mortem';
