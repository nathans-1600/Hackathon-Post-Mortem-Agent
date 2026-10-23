-- POSTMORTEM.APP.POSTMORTEM_APP (Streamlit app)
-- "Decision Post-Mortem", a read-only Streamlit in Snowflake dashboard with six tabs: how each forecaster did,
-- where each went wrong, institutional biases, the learning loop, the live sanity check and the evals. It calls
-- no model, so opening it costs only warehouse time. Source: streamlit/streamlit_app_v3.py in this repo.
--
-- Uses: APP_STAGE (source files). The app's queries read MASKED.POSITIONS; RESULTS.ERRORS, PM_REPORTS,
--   PM_FINDINGS, PM_TAGS, LEARN_SUMMARY, LEARN_RULE_SCORES, PIPELINE_STATUS, EVAL_HISTORY; LIVE.LIVE_COMPARISON,
--   PLAYBOOK_RECORD, LIVE_RUNS_LATEST, SANITY_REPORT_LATEST.
--
-- Upload the source before creating the app (Snowflake CLI or SnowSQL, from the repo root):
--   PUT file://streamlit/streamlit_app_v3.py @POSTMORTEM.APP.APP_STAGE AUTO_COMPRESS = FALSE OVERWRITE = TRUE;
-- APP_STAGE on the source also holds earlier versions (streamlit_app.py, streamlit_app_v2.py); the app runs
--   only streamlit_app_v3.py.

create or replace streamlit POSTMORTEM.APP.POSTMORTEM_APP
	from '@POSTMORTEM.APP.APP_STAGE'
	main_file='streamlit_app_v3.py'
	query_warehouse='PM_WH'
	comment='Masked: how we and Claude did, where each went wrong, institutional biases, learning loop, live sanity check (Company_F), evals'
	title='Decision Post-Mortem';
