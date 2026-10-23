# RESULTS semantic views

The Cortex Analyst semantic view the agents use to answer numeric questions about the backtest.

Exported verbatim with `GET_DDL(..., TRUE)`. Run after the views they read.

| Object | Description | Uses |
|---|---|---|
| [`PM_ALL_SV`](PM_ALL_SV.sql) | Cortex Analyst semantic view for the masked backtest: errors, bias tags, post-mortems and findings, Claude replays and drivers, learning loop, pipeline checks, evals and replay provenance. | MASKED.POSITIONS, ERRORS, PM_TAGS, PM_REPORTS, PM_FINDINGS, REPLAY_LATEST, REPLAY_DRIVERS, LEARN_SUMMARY, LEARN_RULE_SCORES, PIPELINE_STATUS, EVAL_HISTORY, REPLAY_PROVENANCE |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.RESULTS.<NAME>`. Back to the [repo README](../../README.md).
