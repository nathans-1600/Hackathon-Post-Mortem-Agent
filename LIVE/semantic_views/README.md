# LIVE semantic views

The Cortex Analyst semantic view for the live sanity check.

Exported verbatim with `GET_DDL(..., TRUE)`. Run after the views they read.

| Object | Description | Uses |
|---|---|---|
| [`LIVE_SV`](LIVE_SV.sql) | Cortex Analyst semantic view for the live sanity check: the comparison by fiscal year, latest runs, playbook record and the latest report. | LIVE_COMPARISON, LIVE_RUNS_LATEST, PLAYBOOK_RECORD, SANITY_REPORT_LATEST |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
