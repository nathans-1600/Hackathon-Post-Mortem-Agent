# LIVE Cortex Agents

A smaller Cortex Agent for the live case only.

`GET_DDL` does not support agents: each spec comes from `DESCRIBE AGENT` and is written as YAML that parses to the stored JSON. Run these last: they reference semantic views, search services and procedures.

| Object | Description | Uses |
|---|---|---|
| [`LIVE_SANITY_AGENT`](LIVE_SANITY_AGENT.sql) | A smaller Cortex Agent (Opus 4.8) for the live case only: explains or reruns the sanity check. | LIVE_SV, LIVE_DOC_SEARCH, SP_LIVE_SANITY_TOOL |

## Notes

- **`LIVE_SANITY_AGENT`:** max_results is the string "6" in the stored spec; keep it a string.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
