# APP Streamlit apps

The read-only Streamlit in Snowflake app that presents the masked results to people. Its source is in the folder named after the app, exported byte for byte from `APP_STAGE`.

`GET_DDL` exports the app object, not its code: upload the source file to `@POSTMORTEM.APP.APP_STAGE` (`PUT ... AUTO_COMPRESS = FALSE`) before creating the app. The app only reads, so run it after the views (see [`deploy.sql`](../../deploy.sql)).

| Object | Description | Uses |
|---|---|---|
| [`POSTMORTEM_APP`](POSTMORTEM_APP.sql) | "Decision Post-Mortem": a read-only Streamlit in Snowflake app over the masked results. Tabs: how each forecaster did, where each went wrong, institutional biases, the learning loop, the live sanity check, agent evaluations, and sources. It calls no model, so opening it costs only warehouse time. | APP_STAGE (source), PM_WH. The app reads MASKED.POSITIONS, MASKED.DOCUMENTS, RESULTS.ERRORS, RESULTS.PM_BRIEF, RESULTS.PM_REPORTS, RESULTS.PM_FINDINGS, RESULTS.PM_TAGS, RESULTS.LEARN_SUMMARY, RESULTS.LEARN_RULE_SCORES, RESULTS.EVAL_HISTORY, RESULTS.PIPELINE_STATUS, LIVE.LIVE_COMPARISON, LIVE.PLAYBOOK_RECORD, LIVE.LIVE_RUNS_LATEST, LIVE.SANITY_REPORT_LATEST, LIVE.DOCUMENTS |

## Notes

- **`POSTMORTEM_APP`:** Source: POSTMORTEM_APP/streamlit_app_v9.py, the main file, exported byte for byte from APP_STAGE. Upload it to @POSTMORTEM.APP.APP_STAGE (PUT, AUTO_COMPRESS = FALSE) before running this. The stage also holds earlier drafts (streamlit_app.py, streamlit_app_v2.py to _v8.py) that the app does not use; they are not exported. A comment in the source refers to sql/09c_eval_fixes.sql, a script from an earlier layout of this project.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.APP.<NAME>`. Back to the [repo README](../../README.md).
