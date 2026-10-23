# Post-Mortem Agent

Snowflake x Anthropic hackathon project (2026). This repo is the DDL for the `POSTMORTEM` database,
exported from the live Snowflake account on 2026-10-23. It replaces the earlier contents of this repo.

## What it does

A masked backtest of revenue projections. Each *case* (`decision_key`) is one investment review with
FY+1 to FY+3 revenue projections. Claude re-forecasts each case from only what was known at the review
date, the forecasts are scored against reported revenue, and a post-mortem explains each miss. A learning
loop turns post-mortems into rules ("playbooks") that are tested leave-one-out, and a live case
(no outcome yet) gets a sanity check using those rules. Three Cortex Agents sit on top.

Everything is masked: companies and people are tokens, dates are relative to the review (`D-30`),
fiscal years are relative (`FY+1`), amounts are on an undisclosed scale.

## Layout and run order

Run the scripts in order, as a role that can create databases (the source objects are owned by `SYSADMIN`).

| Script | Contents |
|---|---|
| `sql/00_setup.sql` | Warehouse `PM_WH`, database, schemas, stages |
| `sql/01_masked.sql` | `MASKED` tables, `PIT_PACKET`, `CLONE_CONTEXT` |
| `sql/02_outcomes.sql` | `OUTCOMES.ACTUALS_REL` |
| `sql/03_results_tables.sql` | `RESULTS` tables, rule-id sequence |
| `sql/04_results_views.sql` | `RESULTS` views (dependency order) |
| `sql/05_results_procedures.sql` | `SP_REPLAY`, `SP_POSTMORTEM`, `SP_LEARN_EXTRACT`, `SP_LEARN_PLAYBOOK` |
| `sql/06_explorer.sql` | `EXPLORER` tables and views |
| `sql/07_live.sql` | `LIVE` tables, views, functions, `SP_LIVE_REPLAY`, `SP_LIVE_SANITY`, `SP_LIVE_SANITY_TOOL` |
| `sql/08_search_services.sql` | Four Cortex Search services |
| `sql/09_semantic_views.sql` | `PM_SV`, `LEARN_SV`, `PM_EXPLORER_SV`, `LIVE_SV` |
| `sql/10_agents.sql` | `POSTMORTEM_ANALYST`, `POSTMORTEM_EXPLORER`, `LIVE_SANITY_AGENT` |

**Warning:** the table scripts use `CREATE OR REPLACE TABLE`, which drops existing data. Run them on a
fresh database, not on top of a populated one.

## What is not included

- **Data.** DDL only. The tables are created empty; the views, search services and agents need data to be useful.
- **Warehouse and stage details.** `GET_DDL` cannot export these, so `00_setup.sql` is reconstructed from
  `SHOW WAREHOUSES` / `SHOW STAGES` (size, auto-suspend, stage encryption). The source warehouse is a Gen2
  standard warehouse; set that if your account supports it.
- **Grants and ownership.** Everything is owned by `SYSADMIN` on the source; no grants were exported.
- **Auto-generated objects.** The `AI_OBS_OUTPUT_PARSER_*` functions and the `_PEP_YAML_READER` file format
  in `EXPLORER` are created by Snowflake agent observability and are intentionally omitted.
- **`POSTMORTEM.RAW` and `PUBLIC` schemas.** Both are empty on the source.

## Known gaps in the source (exported as-is)

- `SP_POSTMORTEM(mode => 'named')` and `SP_REPLAY(mode => 'named' | 'live')` read `POSTMORTEM.RAW.*` and
  `POSTMORTEM.OUTCOMES.ACTUALS`, which do not exist, so those modes cannot run. `SP_REPLAY` in `live` mode
  also calls `RESULTS.PRIOR_RUNS()`, which does not exist; live runs use `LIVE.SP_LIVE_REPLAY`.
- `MASKED.HOUSE_FRAMEWORK` is empty on the source, so `clone` mode has no house-process text.
- Comments in some bodies refer to script numbers (07, 08, 09, 11) from an earlier layout of this project.
- `RESULTS.FORECASTS` and the agent text use the literal source label `parnassus` for the firm's own projections.

## Verification

- Every statement in `01`-`09` was compared with `GET_DDL` output from the source account using a
  whitespace-normalised SHA-256: 82 of 82 identical (semantic view names are schema-qualified here; `GET_DDL`
  returns them unqualified, and the comparison accounts for that).
- Each agent YAML in `10_agents.sql` parses to the same JSON as the spec stored on the source account (hash match).
- **Not verified:** the scripts have not been executed against an empty account, so syntax that depends on
  your account's features (Cortex Agents, semantic views, search services, `AI_COMPLETE` model access) is untested.
