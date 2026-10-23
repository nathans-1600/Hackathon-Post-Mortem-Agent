# APP Streamlit apps

The Streamlit in Snowflake dashboard over the backtest and the live case.

Exported verbatim with `GET_DDL(..., TRUE)`. Upload the source file to `APP_STAGE` first, then run this last:
the app's queries read views in `RESULTS` and `LIVE`.

| Object | Description | Uses |
|---|---|---|
| [`POSTMORTEM_APP`](POSTMORTEM_APP.sql) | "Decision Post-Mortem": a read-only seven-tab dashboard (how each forecaster did, where each went wrong, institutional biases, learning loop, live sanity check, evals, sources). Calls no model. Source: [`streamlit/streamlit_app_v9.py`](../../streamlit/streamlit_app_v9.py). | APP_STAGE |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.APP.<NAME>`. Back to the [repo README](../../README.md).
