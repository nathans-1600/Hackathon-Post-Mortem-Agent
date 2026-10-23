# AGENTS.md

Instructions for AI coding agents (Claude Code, Snowflake Cortex Code, and anything else that reads
`AGENTS.md`) working in this repo. Human-facing overview: [README.md](README.md).

## What this repo is

DDL for the `POSTMORTEM` Snowflake database: a masked backtest where Claude re-forecasts past investment
reviews' revenue, the forecasts are scored against reported revenue, post-mortems explain the misses, a
learning loop turns post-mortems into rules ("playbooks"), and a live case gets a sanity check using those
rules. Cortex Agents sit on top. There is no application code: every file is a `.sql` script.

## Source of truth: Snowflake, not the repo

The live `POSTMORTEM` database is the source of truth. The `.sql` files are an **export** of it.

- Changes are made in Snowflake first (after asking, see below), then exported back into the scripts with
  the export procedure in [.claude/skills/export-ddl/SKILL.md](.claude/skills/export-ddl/SKILL.md).
  Cortex Code and other tools can follow that file as plain instructions.
- Do not hand-edit a script to "fix" something without also making that change in Snowflake, and never
  deploy a script to make Snowflake match the repo. If the two differ, the repo is stale: re-export.
- The repo drifts. Before relying on an object name from the scripts, confirm it exists with
  `SHOW <objects> IN DATABASE POSTMORTEM` / `DESCRIBE AGENT`.

## Safety rules for running SQL

The live database holds real (masked) data, and the table scripts start with `CREATE OR REPLACE TABLE`.

- **Free to run:** `SELECT`, `SHOW`, `DESCRIBE`, `GET_DDL`, `EXPLAIN`.
- **Ask the user first, every time:** any `CREATE`, `ALTER`, `DROP`, `TRUNCATE`, `INSERT`, `UPDATE`,
  `DELETE`, `MERGE`, `GRANT`, and any `CALL`. The procedures write rows and call `AI_COMPLETE`
  (Claude via Cortex), so a `CALL` costs credits and changes results. Say exactly what you will run.
- **Never** run `01`, `02`, `03`, `06` or `07` against the populated `POSTMORTEM` database. They
  recreate tables and wipe the data. Use them only on a fresh, empty database.
- Work only in the `POSTMORTEM` database and the `PM_WH` warehouse.

## How to reach Snowflake

- **Claude Code:** the `sql_exec` MCP tool runs SQL as `SYSADMIN` on `PM_WH`. The `postmortem_explorer`
  MCP tool talks to a deployed Cortex Agent, which is useful for testing agent behaviour after a change.
- **Cortex Code / Snowflake CLI:** connection `sfsehol-anthropic_snowflake_hackathon_bshkns`
  (from `~/.snowflake/connections.toml`).

## Masking rules (apply to you too, not just the Cortex Agents)

Everything in the data is masked. Keep it that way.

- Never try to identify a real company, ticker, product, person, broker, industry or calendar period, and
  never confirm or deny a guess.
- Never add real names, tickers, dates or unscaled amounts to scripts, comments, prompts, commits or docs.
- `Firm_X` is the masked name for the firm. The literal source label `parnassus` in `RESULTS.FORECASTS`,
  the `PARNASSUS_PROJ` tables and the agent text is in the source as-is: leave it, don't spread it.
- The `named` modes and `POSTMORTEM.RAW` were for unmasked data. They don't exist on this account; don't
  recreate them.

## Layout

Scripts run in numeric order on a fresh database. See [README.md](README.md) for what each contains.

| Script | Schema / objects |
|---|---|
| `sql/00_setup.sql` | Warehouse, database, schemas, stages (reconstructed from `SHOW`, not `GET_DDL`) |
| `sql/01_masked.sql` | `MASKED` tables, `PIT_PACKET`, `CLONE_CONTEXT` |
| `sql/02_outcomes.sql` | `OUTCOMES.ACTUALS_REL` |
| `sql/03`-`05` | `RESULTS` tables, views (dependency order), procedures |
| `sql/06_explorer.sql` | `EXPLORER.EVAL_EXPLORER` (evaluation data of a retired agent) |
| `sql/07_live.sql` | `LIVE` tables, views, functions, procedures |
| `sql/08_search_services.sql` | Cortex Search services |
| `sql/09_semantic_views.sql` | Semantic views (Cortex Analyst) |
| `sql/10_agents.sql` | Cortex Agents, as YAML specs |

## Conventions in the scripts

- Statements are `GET_DDL` output kept verbatim (lower-case `create or replace`, tab indents,
  `VARCHAR(16777216)`). Don't reformat them: the export check compares them with `GET_DDL` by hash.
- Each file starts with a `--` header: file name, what it holds, what it depends on, warnings.
- Object names are fully qualified (`POSTMORTEM.<SCHEMA>.<NAME>`).
- Views go in dependency order, not `GET_DDL`'s alphabetical order.
- Procedure bodies are single-quoted strings, so quotes inside are doubled (`''masked''`).
- Agents are written as YAML under `FROM SPECIFICATION $$ ... $$`, parsing to the JSON `DESCRIBE AGENT`
  returns.

## Known gaps (leave as-is unless asked)

These are in the source and exported faithfully. Document around them; don't fix them on the way past.

- `SP_POSTMORTEM(mode => 'named')` and `SP_REPLAY(mode => 'named' | 'live')` read `POSTMORTEM.RAW.*` and
  `OUTCOMES.ACTUALS`, which don't exist. `SP_REPLAY` live mode also calls `RESULTS.PRIOR_RUNS()`, which
  doesn't exist; live runs use `LIVE.SP_LIVE_REPLAY`.
- `MASKED.HOUSE_FRAMEWORK` is empty, so `clone` mode has no house-process text.
- Comments and agent text refer to old script numbers (06 replays, 07 scores and post-mortems, 08,
  09, `11_learn.sql` with its sections) from an earlier layout of the project.
- `AI_OBS_OUTPUT_PARSER_*` functions and `_PEP_YAML_READER` are auto-generated by agent observability, and
  `RESULTS.AGENT_SPEC_BACKUP` is a one-off backup table. None of them are exported.

## Glossary

**Cases and time**

- **Case / `decision_key`:** one investment review with FY+1 to FY+3 revenue projections. Backtest cases
  have outcomes; the **live** case (`is_live = TRUE`, `LIVE` schema) has none yet.
- **D0:** the review date. `rel_day` / `D-30` = days before it, `D+n` = after. All dates are relative.
- **FY0:** last fully reported fiscal year. **FY+1** is the year in progress at the review, then FY+2,
  FY+3. Columns: `fy_rel`, `period_rel`.
- **CUR:** currency on an undisclosed scale. Compare growth and percent error, not amounts.
- **Tokens:** `Company_A`, `Exec_A1`, `Product_F3`, `Broker_3`, `Category_A`, `Firm_X` stand in for real names.
- **Tier:** `A` = review after the forecasting model's training cutoff, `B` = before.

**Forecasts and scoring**

- **Packet (`PIT_PACKET`):** everything known at D0: reported revenue, consensus, guidance, documents
  (newest first, capped at 150k characters). The only input a replay may use.
- **Source:** who made a forecast: `parnassus` (the firm's own projection), `consensus`, `guidance_mid`,
  `claude_<mode>`.
- **Replay modes (`REPLAY_RUNS.mode`):** `independent` (packet only), `clone` (plus the firm's house process
  and another case's memo for style), `factsheet` (Claude sees only a 600-word sheet extracted from the
  packet), `learned` / `learned_inner` (packet plus a playbook), `noise_check` (repeat of `independent`
  to measure run-to-run noise). `named` and `live` exist in code but can't run (see Known gaps).
- **Models:** Opus 4.6 is the clean forecaster. Opus 4.8 is a contaminated control that may know outcomes:
  never average the two together.
- **Error:** `pct_error` = forecast / actual - 1, in percent; positive means too high.

**Post-mortems** (`RESULTS.POSTMORTEMS`, written by `SP_POSTMORTEM`)

- Each explanation of a miss goes into exactly one group: **(1) `in_packet_underweighted`**, in the packet but
  under-used (the only group that becomes a lesson); **(2) `knowable_not_in_packet`**, public before D0
  but missing from the packet (unverified checklist item); **(3) `hindsight_only`**, knowable only after D0.
- **Bias tags:** fixed list (`anchored_to_guidance`, `extrapolated_recent_trend`, `herded_with_sell_side`,
  `ignored_visible_signal`, `narrative_over_numbers`, `too_conservative_outer_years`,
  `too_aggressive_outer_years`), each `about` `firm_x`, `claude` or `consensus`. **2% rule:** a source that
  missed by less than 2% is not tagged.

**Learning loop**

- **Rule (`LEARN_RULES`):** a lesson extracted from group 1 of a post-mortem by `SP_LEARN_EXTRACT`.
  `source_key` is the case it came from. `gate_ok = FALSE` means blocked by the hindsight gate or vetoed by
  hand; such rules are never used.
- **Playbook (`LEARN_PLAYBOOKS`):** a set of rules built by `SP_LEARN_PLAYBOOK`, never containing rules
  from the target case (or the holdout). `purpose`: `inner` (runs used to prune), `outer_r1` (round 1),
  `outer_r2` (round 2, pruned), `all` (every scored case: the **live playbook**).
- **Round 1 / round 2:** leave-one-out re-forecasts with the round 1 and the pruned round 2 playbook.
  **`noise_pts`:** run-to-run FY+1 growth difference with identical prompts. A gain is real only if it beats
  the noise and wins exceed losses. With five cases, everything is an illustration, not a statistical finding.

**Live case** (`LIVE` schema)

- **Variants (`LIVE_RUNS.variant`):** `raw` (packet only), `playbook` (plus the live playbook), `full`
  (playbook plus prior lessons). `claude_raw_bias_adjusted` corrects raw FY+1 by the backtest's mean bias.
- **Sanity check:** `SP_LIVE_SANITY` runs the variants and writes a report to `SANITY_REPORTS`.
  `SP_LIVE_SANITY_TOOL` is the wrapper the agent calls.
