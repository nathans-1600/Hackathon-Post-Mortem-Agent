# RESULTS Cortex Agents

The main Cortex Agent.

`GET_DDL` does not support agents: each spec comes from `DESCRIBE AGENT` and is written as YAML that parses to the stored JSON. Run these last: they reference semantic views, search services and procedures.

| Object | Description | Uses |
|---|---|---|
| [`POSTMORTEM_ANALYST`](POSTMORTEM_ANALYST.sql) | The main Cortex Agent (Opus 4.8): answers questions about the backtest and the live case, and can run a fresh sanity check. | PM_ALL_SV, LIVE.LIVE_SV, PM_REPORT_SEARCH, DOC_SEARCH, LIVE.LIVE_DOC_SEARCH, LIVE.SP_LIVE_SANITY_TOOL |

## Notes

- **`POSTMORTEM_ANALYST`:** It replaced the retired POSTMORTEM_EXPLORER agent.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.RESULTS.<NAME>`. Back to the [repo README](../../README.md).
