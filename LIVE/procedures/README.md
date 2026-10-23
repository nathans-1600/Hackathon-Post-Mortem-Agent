# LIVE stored procedures

The live sanity check: forecast the live case three ways, then write the report. `SP_LIVE_SANITY_TOOL` is what the agents call.

A `CALL` writes rows, and procedures that use `AI_COMPLETE` (Claude via Cortex) cost credits. Ask before calling one.

| Object | Description | Writes |
|---|---|---|
| [`SP_LIVE_REPLAY`](SP_LIVE_REPLAY.sql) | Forecasts the live case in one variant (raw, playbook, full), Opus 4.6 by default. Refuses any case that is a backtest case or has an outcome. | LIVE_RUNS |
| [`SP_LIVE_SANITY`](SP_LIVE_SANITY.sql) | Runs the three live variants, then has Opus 4.8 write the sanity-check report from the comparison, the rules that fired and the backtest record. | SANITY_REPORTS |
| [`SP_LIVE_SANITY_TOOL`](SP_LIVE_SANITY_TOOL.sql) | Wrapper the agents call: resolves the live case key (falls back to the live case if the key is unknown), runs SP_LIVE_SANITY and returns the report. |  |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
