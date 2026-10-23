# Decision Post-Mortem

*Learning from our own forecasting misses, without hindsight.* Parnassus Hackathon, October 23, 2026
(Snowflake x Anthropic).

This repo holds the Snowflake DDL for the `POSTMORTEM` database that runs the project. It was exported from
the live Snowflake account on 2026-10-23 and re-exported the same day, after the agents were consolidated.

The live database is the source of truth and these scripts are its export: change Snowflake first, then
re-export (see [.claude/skills/export-ddl/SKILL.md](.claude/skills/export-ddl/SKILL.md)). Rules for AI agents
working here, plus a glossary, are in [AGENTS.md](AGENTS.md) (Claude Code reads it through [CLAUDE.md](CLAUDE.md)).

## The problem

Every investment review makes a forecast, and almost nobody checks it afterwards.

- **We forecast.** Every investment review projects revenue for the next three fiscal years.
- **We rarely look back.** Nobody systematically compares those numbers with what the company later reported.
- **Hindsight wins.** When we do look back, knowing the ending makes every miss look obvious, so we learn the
  wrong lessons.

## The idea

> To learn from a forecast, you need a judge who doesn't know how the story ended.

People can't un-know an outcome. A model can be chosen, and tested, so that it doesn't know it. Decision
Post-Mortem uses Claude as that judge: it re-forecasts past reviews from only what we knew at the time, then
explains where each forecast went wrong and turns those explanations into rules that have to prove
themselves on cases they never saw.

## How it works

The process has six steps, starting from old reviews and ending with checks on live names.

### 1. Prep: rebuild each review as it stood

We used five past investment reviews. None of them is a current holding, for compliance reasons. Each case
(a `decision_key`) is a packet holding:

- the investment review, with our FY+1 to FY+3 revenue projections
- filings, transcripts and broker notes dated before the review
- FactSet consensus as of the day before the review, and guidance issued before it
- reported revenue history up to that day

**Point-in-time rule:** nothing in a packet is dated on or after the review date. Later results live in a
separate schema (`OUTCOMES`) that the forecaster can't read.

### 2. Mask: stop the model "forecasting" from memory

The reviews are months old. A model trained after the results came out could recall them instead of
reasoning about them. So we hide everything it might recognise:

| Real | What the model sees |
|---|---|
| Names | `Company_A`, `Exec_A1`, `Broker_7` |
| Dates | `D-30` (days before the review) |
| Years | `FY0`, `FY+1`, `FY+2` |
| Amounts | Scaled by a secret factor |

Then we test the masking:

- **Leak gates:** we checked that no names, dates, years or raw amounts are left in the 46 documents.
- **Recall probes:** when asked what happened, both models said they didn't know, and their guesses missed.
- **Named control:** famous companies still get recognised when named, so we run a named version and measure
  how much that moves the forecast.

### Choice of model

The forecaster must not know the future. The reviewer may.

| Job | Model | Why |
|---|---|---|
| Replay forecasts | Opus 4.6 | Training cutoff around May 2025, no later than the earliest review |
| Learning loop | Opus 4.6 | Its rules feed forecasts, so the same cutoff applies |
| Contaminated control | Opus 4.8 | Newer, so it may know outcomes; shows how much that moves a forecast |
| Post-mortems, sanity check, agents | Opus 4.8 | The strongest model. These jobs are meant to know the outcome, or face one that hasn't happened yet |
| Not used | Sonnet 4.5 | July 2025 cutoff overlaps the earliest review |

### 3. Replay: Claude re-forecasts from the same packet

| Mode | What Claude sees |
|---|---|
| Independent | The masked packet; Claude forms its own view |
| Clone | The masked packet, plus our house process and the style of our other reviews |
| Fact sheet | Only a 600-word summary: the strictest masking |
| Named control | Real names, to show how much recognising the company changes the forecast |

Every run uses a fixed prompt at temperature 0, and every call is logged: 5 cases × 3 masked modes × 2 models
= 30 runs.

### 4. Score: every forecast against reported revenue

| Source | What it is |
|---|---|
| Firm_X | Our investment review's projection |
| Claude | Each replay mode and model |
| Consensus | FactSet mean as of the day before the review |
| Guidance | Midpoint of the latest full-year guide |

**Error = forecast ÷ reported − 1.** Today the scoring covers FY+1. FY+2 and FY+3 join automatically once
they are reported.

### 5. Post-mortem: every miss, sorted three ways

| Cause | Meaning | Becomes |
|---|---|---|
| In the packet, under-used | We had it and didn't weigh it enough | A lesson and a bias tag |
| Public, but not collected | Knowable before the review, but missing from our packet | A dated data checklist, unverified until someone checks it |
| Hindsight only | Only knowable after the review | Explains the miss; never a lesson |

Each bias tag names whose forecast it describes (Firm_X, Claude or consensus). The tags are: *anchored to
guidance*, *extrapolated recent trend*, *herded with sell-side*, *ignored visible signal*, *narrative over
numbers*, and *too conservative / too aggressive outer years*.

### 6. Learn and check: every post-mortem becomes a rule that has to earn its place

1. **Learn:** each post-mortem yields up to 4 rules of the form "when this signal shows, adjust this way".
2. **Apply:** Claude re-forecasts past cases with the rules and cites the ones it used.
3. **Judge:** a rule scores +1 when a run using it beat the plain replay, and −1 when it did worse.
4. **Prune:** rules with a net negative score are dropped.
5. **Use:** the surviving rules form the playbook for live names.

Each newly reported result adds rules and more evidence about the old ones. The model never changes; the
playbook does.

**No case learns from its own ending.** Rules are tested leave-one-out: when case 1 is scored, it uses rules
from cases 2 to 5 but never its own, and the same holds for every other case. The guards:

- The replay refuses any playbook holding a rule that came from the case's own outcome.
- Pruning for a case is judged only on runs that never saw it.
- Rules come from process notes only: no outcome numbers, recalled data or hindsight events.
- A filter drops any rule that contains names, amounts, dates or phrases such as "turned out".
- Every learned forecast runs on Opus 4.6.
- A gain counts only if it beats run-to-run noise.

*Remaining risk:* the five FY+1 years overlap in time, so a rule can carry a pattern from that period. Five
cases illustrate the method; they don't prove it.

### Live sanity check: where a new name looks like past mistakes

For a name under review now, the sanity check lays out, for FY+1 to FY+3, Claude's raw forecast, the forecast
with the playbook applied, a bias-adjusted figure (FY+1), consensus, guidance (FY+1) and the analyst's
projection. It then flags where the analyst's forecast resembles past misses, for example: "This looks like
past cases tagged *anchored to guidance*; in those, FY+1 missed by X%."

Ground rules: public data as of today, never masked (there is no outcome yet), and never a current holding.

## Built on Snowflake

The design is one database with four walls between its schemas:

| Schema | Holds |
|---|---|
| `RAW` | Real names and source documents. Never leaves Parnassus. (Empty in this export; see below.) |
| `MASKED` | Everything the forecaster is allowed to see |
| `OUTCOMES` | Reported results, read only by scoring and post-mortems |
| `RESULTS` | Replays, scores, post-mortems, rules and playbooks |

Two more schemas sit on top: `LIVE` holds the live sanity-check case, and `EXPLORER` keeps only the
evaluation data of a retired Explorer agent.

| Snowflake feature | What it does here |
|---|---|
| `AI_PARSE_DOCUMENT`, `AI_REDACT` | Read the PDFs and catch personal details the masking missed |
| `AI_COMPLETE` | Replays, post-mortems and rules: fixed prompts, every call logged |
| Cortex Search, Cortex Analyst | Search the masked documents and ask questions about errors and bias tags |
| Cortex Agents, AI evaluations | The post-mortem analyst and the sanity check, scored against ground truth |

Two Cortex Agents sit on top: `POSTMORTEM_ANALYST` answers questions about both the backtest and the live
case, and `LIVE_SANITY_AGENT` is a smaller agent for the live case only.

**In one line:** every post-mortem becomes a rule, every rule must prove itself on cases it never saw, and
only the survivors shape the next forecast.

---

## Repository layout and run order

Run the scripts in `sql/` in order, as a role that can create databases (the source objects are owned by
`SYSADMIN`).

| Script | Contents |
|---|---|
| [`sql/00_setup.sql`](sql/00_setup.sql) | Warehouse `PM_WH`, database, schemas, stages |
| [`sql/01_masked.sql`](sql/01_masked.sql) | `MASKED` tables, `PIT_PACKET`, `CLONE_CONTEXT` |
| [`sql/02_outcomes.sql`](sql/02_outcomes.sql) | `OUTCOMES.ACTUALS_REL` |
| [`sql/03_results_tables.sql`](sql/03_results_tables.sql) | `RESULTS` tables, rule-id sequence |
| [`sql/04_results_views.sql`](sql/04_results_views.sql) | `RESULTS` views (dependency order) |
| [`sql/05_results_procedures.sql`](sql/05_results_procedures.sql) | `SP_REPLAY`, `SP_POSTMORTEM`, `SP_LEARN_EXTRACT`, `SP_LEARN_PLAYBOOK` |
| [`sql/06_explorer.sql`](sql/06_explorer.sql) | `EXPLORER.EVAL_EXPLORER` (evaluation data only) |
| [`sql/07_live.sql`](sql/07_live.sql) | `LIVE` tables, views, functions, `SP_LIVE_REPLAY`, `SP_LIVE_SANITY`, `SP_LIVE_SANITY_TOOL` |
| [`sql/08_search_services.sql`](sql/08_search_services.sql) | Three Cortex Search services |
| [`sql/09_semantic_views.sql`](sql/09_semantic_views.sql) | `PM_ALL_SV` (backtest), `LIVE_SV` (live case) |
| [`sql/10_agents.sql`](sql/10_agents.sql) | `POSTMORTEM_ANALYST`, `LIVE_SANITY_AGENT` |

**Warning:** the table scripts use `CREATE OR REPLACE TABLE`, which drops existing data. Run them on a fresh
database, not on top of a populated one.

## What is not included

- **Data.** This is DDL only. The tables are created empty, and the views, search services and agents need
  data before they are useful.
- **Warehouse and stage details.** `GET_DDL` cannot export these, so `00_setup.sql` is reconstructed from
  `SHOW WAREHOUSES` / `SHOW STAGES` (size, auto-suspend, stage encryption). The source warehouse is a Gen2
  standard warehouse; set that if your account supports it.
- **Grants and ownership.** Everything is owned by `SYSADMIN` on the source, and no grants were exported.
- **Auto-generated objects.** The `AI_OBS_OUTPUT_PARSER_*` functions and the `_PEP_YAML_READER` file format are
  created by Snowflake agent observability and are left out on purpose.
- **`RESULTS.AGENT_SPEC_BACKUP`.** A one-off backup of agent specs taken before the agents were consolidated.
- **`POSTMORTEM.RAW` and `PUBLIC` schemas.** Both are empty on the source.

## Known gaps in the source (exported as-is)

- `SP_POSTMORTEM(mode => 'named')` and `SP_REPLAY(mode => 'named' | 'live')` read `POSTMORTEM.RAW.*` and
  `POSTMORTEM.OUTCOMES.ACTUALS`, which do not exist, so those modes cannot run. `SP_REPLAY` in `live` mode also
  calls `RESULTS.PRIOR_RUNS()`, which does not exist; live runs use `LIVE.SP_LIVE_REPLAY` instead.
- `MASKED.HOUSE_FRAMEWORK` is empty on the source, so `clone` mode has no house-process text.
- Comments in some procedure bodies refer to script numbers (07, 08, 09, 11) from an earlier layout of this
  project.
- `RESULTS.FORECASTS` and the agent text use the literal source label `parnassus` for the firm's own
  projections.

## Verification

- Every statement in `01` to `09` was compared with `GET_DDL` output from the source account using a
  whitespace-normalised SHA-256: 71 of 71 were identical, and every exported object appears exactly once.
- Each agent YAML in `10_agents.sql` (2 agents) parses to the same JSON as the spec stored on the source
  account.
- **Not verified:** the scripts have not been run against an empty account, so syntax that depends on your
  account's features (Cortex Agents, semantic views, search services, `AI_COMPLETE` model access) is untested.
