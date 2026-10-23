# sql/

One file per object of the `POSTMORTEM` database, at `<SCHEMA>/<type>/<NAME>.sql`. Each file starts with a
`--` header (description, what it uses, what writes it, warnings) followed by the `GET_DDL` statement, verbatim.
[`deploy.sql`](deploy.sql) runs them all in dependency order on a fresh account.

**Never run anything under `*/tables/` (or `deploy.sql`) against the populated database:** table files use
`CREATE OR REPLACE TABLE` and wipe the data.

## Setup

| File | Contents |
|---|---|
| [`00_setup/warehouse.sql`](00_setup/warehouse.sql) | Warehouse `PM_WH` |
| [`00_setup/database_and_schemas.sql`](00_setup/database_and_schemas.sql) | Database `POSTMORTEM` and its schemas |
| [`00_setup/stages.sql`](00_setup/stages.sql) | Internal stages |

## MASKED

Everything the forecaster is allowed to see: masked case data and the packet builders.

| Object | Type | Description |
|---|---|---|
| [`CONSENSUS`](MASKED/tables/CONSENSUS.sql) | table | Consensus revenue estimates per case and fiscal year (FY+1 to FY+3) as of the day before the review, with the number of estimates. Masked amounts (CUR m). |
| [`DOCUMENTS`](MASKED/tables/DOCUMENTS.sql) | table | Masked source documents per case (filings, call transcripts, sell-side notes and the Firm_X memo), dated in days relative to D0. PIT_PACKET reads every type except the memo. |
| [`DOC_CHUNKS`](MASKED/tables/DOC_CHUNKS.sql) | table | DOCUMENTS split into chunks; indexed by the DOC_SEARCH Cortex Search service. |
| [`EXPORT_MANIFEST`](MASKED/tables/EXPORT_MANIFEST.sql) | table | Row count and checksum per table of the masked data export, for checking that an import arrived intact. |
| [`GUIDANCE`](MASKED/tables/GUIDANCE.sql) | table | Management revenue guidance issued before the review: period, low/high amount and/or growth range, and the relative day it was issued. |
| [`HOUSE_FRAMEWORK`](MASKED/tables/HOUSE_FRAMEWORK.sql) | table | Firm_X house-process text, read by CLONE_CONTEXT for clone mode. |
| [`PARNASSUS_PROJ`](MASKED/tables/PARNASSUS_PROJ.sql) | table | Firm_X's own projections from each investment review, per fiscal year (revenue and growth). |
| [`PARQUET_FMT`](MASKED/file_formats/PARQUET_FMT.sql) | file format | Parquet file format for loading the masked data export. |
| [`POSITIONS`](MASKED/tables/POSITIONS.sql) | table | One row per case (decision_key): masked company id, live flag, fiscal-year labels and tier (A = review after the forecaster's training cutoff, B = before). |
| [`REVENUE_HISTORY`](MASKED/tables/REVENUE_HISTORY.sql) | table | Reported revenue per case and period (FY0, earlier years, FY+1 quarters) known at D0, with the relative day each figure was reported. |
| [`CLONE_CONTEXT`](MASKED/functions/CLONE_CONTEXT.sql) | secure function | Extra context for clone mode: the house process plus memos of OTHER cases (for style only, never the target case's own memo). |
| [`PIT_PACKET`](MASKED/functions/PIT_PACKET.sql) | secure function | Builds a case's point-in-time packet: case header, reported revenue, consensus, guidance, and documents newest first (capped at 150k characters). The only input a replay may use. |

## OUTCOMES

Reported results, read only by scoring and post-mortems.

| Object | Type | Description |
|---|---|---|
| [`ACTUALS_REL`](OUTCOMES/tables/ACTUALS_REL.sql) | table | Reported revenue per case and fiscal year after the review, with growth and the relative day it was reported. Read only by scoring and post-mortems; never part of a packet. |

## RESULTS

Replays, scores, post-mortems, the learning loop, evaluations, and the backtest Cortex objects.

| Object | Type | Description |
|---|---|---|
| [`BIAS_TAGS`](RESULTS/tables/BIAS_TAGS.sql) | table | Bias tags from the latest masked post-mortem per case: tag, whose forecast it describes (about), strength and evidence. |
| [`EVAL_HISTORY`](RESULTS/tables/EVAL_HISTORY.sql) | table | Mean score per metric for each evaluation run of the semantic view and the agents. |
| [`EVAL_PIPELINE`](RESULTS/tables/EVAL_PIPELINE.sql) | table | Results of the pipeline and hindsight-gate checks, one row per check per run. PIPELINE_STATUS shows the latest run. |
| [`EVAL_POSTMORTEM_ANALYST`](RESULTS/tables/EVAL_POSTMORTEM_ANALYST.sql) | table | Evaluation set for the POSTMORTEM_ANALYST agent: questions and ground-truth answers. |
| [`EVAL_REF`](RESULTS/tables/EVAL_REF.sql) | table | Snapshot of reference numbers (best source, Firm_X and guidance error, biggest miss, top tags) used to build evaluation ground truth. |
| [`LEARN_PLAYBOOKS`](RESULTS/tables/LEARN_PLAYBOOKS.sql) | table | Playbooks: a set of rule ids and their text, by purpose (inner, outer_r1, outer_r2, all), never holding rules from the target or holdout case. |
| [`LEARN_RULES`](RESULTS/tables/LEARN_RULES.sql) | table | Rules learned from post-mortems: rule text, signal, direction, which years it applies to, the case it came from, and the hindsight-gate result (gate_ok, gate_hit). |
| [`LEARN_RULE_SEQ`](RESULTS/sequences/LEARN_RULE_SEQ.sql) | sequence | Sequence behind LEARN_RULES rule ids (R1, R2, ...). |
| [`PM_REPORT_CHUNKS`](RESULTS/tables/PM_REPORT_CHUNKS.sql) | table | Post-mortem report text split into sections and chunks; indexed by the PM_REPORT_SEARCH Cortex Search service. |
| [`POSTMORTEMS`](RESULTS/tables/POSTMORTEMS.sql) | table | Post-mortems: the parsed JSON (findings in three groups, bias tags, lessons, data checklist) and the raw model response, per case and mode. |
| [`REPLAY_IMPORTS`](RESULTS/tables/REPLAY_IMPORTS.sql) | table | Replay runs imported from another account, with the document checksum at export time; read by REPLAY_RUN_FRESH. |
| [`REPLAY_RUNS`](RESULTS/tables/REPLAY_RUNS.sql) | table | Every replay forecast: case, mode, model, FY+1 to FY+3 growth, confidence, parsed and raw response, prompt size and the playbook used. |
| [`ERRORS`](RESULTS/views/ERRORS.sql) | view | FORECASTS scored against reported revenue: pct_error, abs_pct_error, and how many FY+1 quarters were already reported at the review. |
| [`FORECASTS`](RESULTS/views/FORECASTS.sql) | view | Every forecast as revenue per case, source, model and fiscal year: Claude's latest replay per mode and model, Firm_X (label parnassus), consensus and the guidance midpoint. |
| [`LEARN_RULE_SCORES`](RESULTS/views/LEARN_RULE_SCORES.sql) | view | Each learned rule with its gate result, how often round-1 runs applied it, net wins, and whether it is in the live playbook. |
| [`LEARN_RUN_ERRORS`](RESULTS/views/LEARN_RUN_ERRORS.sql) | view | Learned and learned_inner replays scored per fiscal year, next to the plain Opus 4.6 independent replay (gain_pts = error saved). |
| [`LEARN_SUMMARY`](RESULTS/views/LEARN_SUMMARY.sql) | view | Learning loop per backtest case, FY+1: baseline vs round-1 and round-2 error and gain, rule counts, and run-to-run noise. |
| [`PIPELINE_STATUS`](RESULTS/views/PIPELINE_STATUS.sql) | view | The latest run of the EVAL_PIPELINE checks. |
| [`PM_FINDINGS`](RESULTS/views/PM_FINDINGS.sql) | view | One row per post-mortem finding, labelled with its group (1 in packet, 2 knowable but not collected, 3 hindsight only). Only group 1 is usable as a lesson. |
| [`PM_REPORTS`](RESULTS/views/PM_REPORTS.sql) | view | Latest masked post-mortem per backtest case, flattened: projected, reported, gap, closer sources, change next time, data to add, and finding counts per group. |
| [`PM_TAGS`](RESULTS/views/PM_TAGS.sql) | view | Bias tags of the post-mortems shown in PM_REPORTS. |
| [`REPLAY_DRIVERS`](RESULTS/views/REPLAY_DRIVERS.sql) | view | Drivers Claude cited in the latest replays: direction, fiscal year and evidence. |
| [`REPLAY_LATEST`](RESULTS/views/REPLAY_LATEST.sql) | view | Latest independent, clone and factsheet replay per backtest case, mode and model, with model role (clean vs contaminated control). |
| [`REPLAY_PROVENANCE`](RESULTS/views/REPLAY_PROVENANCE.sql) | view | Replay counts per mode and model: total, imported, fresh, unparsed, and the last run. |
| [`REPLAY_RUN_FRESH`](RESULTS/views/REPLAY_RUN_FRESH.sql) | view | Per run: whether it is fresh (run after the masked documents last changed, or imported with a matching checksum) and whether it was imported. |
| [`SP_LEARN_EXTRACT`](RESULTS/procedures/SP_LEARN_EXTRACT.sql) | stored procedure | Turns a case's latest masked post-mortem (group 1 findings, tags that passed the 2% rule, process lesson) into at most 4 rules with Opus 4.6, then runs the hindsight gate over them. |
| [`SP_LEARN_PLAYBOOK`](RESULTS/procedures/SP_LEARN_PLAYBOOK.sql) | stored procedure | Builds a playbook from gate-passing rules, leaving out rules from the target and holdout case. For outer_r2 and all, rules with a negative net score on the evidence runs are pruned. |
| [`SP_POSTMORTEM`](RESULTS/procedures/SP_POSTMORTEM.sql) | stored procedure | Writes a post-mortem for a case with Opus 4.8: compares each forecast with reported revenue and sorts every explanation into one of three groups. In masked mode it also replaces the case's bias tags. |
| [`SP_REPLAY`](RESULTS/procedures/SP_REPLAY.sql) | stored procedure | Re-forecasts a case from its packet in a given mode (independent, clone, factsheet, learned, learned_inner, noise_check) and model. Learned modes check the hindsight guards before calling the model. |
| [`DOC_SEARCH`](RESULTS/search_services/DOC_SEARCH.sql) | Cortex Search service | Cortex Search over the masked case documents (MASKED.DOC_CHUNKS), filterable by case, document type and relative day. |
| [`PM_REPORT_SEARCH`](RESULTS/search_services/PM_REPORT_SEARCH.sql) | Cortex Search service | Cortex Search over the post-mortem report text (PM_REPORT_CHUNKS), filterable by case and section. |
| [`PM_ALL_SV`](RESULTS/semantic_views/PM_ALL_SV.sql) | semantic view | Cortex Analyst semantic view for the masked backtest: errors, bias tags, post-mortems and findings, Claude replays and drivers, learning loop, pipeline checks, evals and replay provenance. |
| [`POSTMORTEM_ANALYST`](RESULTS/agents/POSTMORTEM_ANALYST.sql) | Cortex Agent | The main Cortex Agent (Opus 4.8): answers questions about the backtest and the live case, and can run a fresh sanity check. |

## EXPLORER

Evaluation data left over from the retired Explorer agent.

| Object | Type | Description |
|---|---|---|
| [`EVAL_EXPLORER`](EXPLORER/tables/EVAL_EXPLORER.sql) | table | Evaluation set (questions and ground truth) of the retired Post-Mortem Explorer agent. The only object left in EXPLORER. |

## LIVE

The live sanity-check case (masked, no outcome yet).

| Object | Type | Description |
|---|---|---|
| [`CONSENSUS`](LIVE/tables/CONSENSUS.sql) | table | Consensus revenue estimates for the live case, per fiscal year (same shape as MASKED.CONSENSUS). |
| [`DOCUMENTS`](LIVE/tables/DOCUMENTS.sql) | table | Masked documents of the live case, dated before D0 (same shape as MASKED.DOCUMENTS). LIVE_PACKET reads every type except the memo. |
| [`DOCUMENTS_PASS1`](LIVE/tables/DOCUMENTS_PASS1.sql) | table | First-pass copy of the live documents, same columns as DOCUMENTS. Nothing in the DDL reads it. |
| [`EVAL_LIVE_SANITY`](LIVE/tables/EVAL_LIVE_SANITY.sql) | table | Evaluation set for the live sanity check: questions and ground-truth answers. |
| [`EVAL_REF_L`](LIVE/tables/EVAL_REF_L.sql) | table | Snapshot of live reference numbers (FY+1 growth for each view, consensus, playbook rule count, source and record) used to build evaluation ground truth. |
| [`GUIDANCE`](LIVE/tables/GUIDANCE.sql) | table | Management revenue guidance for the live case (same shape as MASKED.GUIDANCE). |
| [`LIVE_DOC_CHUNKS`](LIVE/tables/LIVE_DOC_CHUNKS.sql) | table | Live documents split into chunks; indexed by the LIVE_DOC_SEARCH Cortex Search service. |
| [`LIVE_RUNS`](LIVE/tables/LIVE_RUNS.sql) | table | Live forecasts per variant (raw, playbook, full) and model: FY+1 to FY+3 growth, confidence, parsed and raw response, and the playbook used. |
| [`NDJSON_FMT`](LIVE/file_formats/NDJSON_FMT.sql) | file format | JSON (newline-delimited) file format for loading live data. |
| [`PARNASSUS_PROJ`](LIVE/tables/PARNASSUS_PROJ.sql) | table | The Firm_X analyst's projections for the live case, per fiscal year (same shape as MASKED.PARNASSUS_PROJ). |
| [`POSITIONS`](LIVE/tables/POSITIONS.sql) | table | The live case row (is_live = TRUE), same shape as MASKED.POSITIONS. |
| [`REVENUE_HISTORY`](LIVE/tables/REVENUE_HISTORY.sql) | table | Reported revenue of the live case known at D0 (same shape as MASKED.REVENUE_HISTORY). |
| [`SANITY_REPORTS`](LIVE/tables/SANITY_REPORTS.sql) | table | Written sanity-check reports, with the context each was written from. |
| [`LIVE_COMPARISON`](LIVE/views/LIVE_COMPARISON.sql) | view | One row per fiscal year with every view of growth: Claude raw, with playbook, with playbook and lessons, bias-adjusted raw (FY+1), consensus, guidance midpoint and the analyst. |
| [`LIVE_PACKET`](LIVE/functions/LIVE_PACKET.sql) | secure function | Builds the live case's packet, the same way PIT_PACKET does for backtest cases, from the LIVE tables. |
| [`LIVE_RULES_APPLIED`](LIVE/views/LIVE_RULES_APPLIED.sql) | view | Rules the latest playbook and full runs applied, with direction, rule text and the past case each was learned from. |
| [`LIVE_RUNS_LATEST`](LIVE/views/LIVE_RUNS_LATEST.sql) | view | Latest live run per variant and model: growth, confidence, view vs consensus, key risks and number of rules applied. |
| [`PLAYBOOK_RECORD`](LIVE/views/PLAYBOOK_RECORD.sql) | view | Every rule in the live playbook: direction, source case, backtest record (times applied, net wins), and whether it fired in today's runs. |
| [`PRIOR_LESSONS`](LIVE/functions/PRIOR_LESSONS.sql) | secure function | Text block of backtest lessons for the full variant: mean error by source, bias tags, what each post-mortem said to change, and the data checklist. |
| [`SANITY_REPORT_LATEST`](LIVE/views/SANITY_REPORT_LATEST.sql) | view | The latest written sanity-check report per case. |
| [`SP_LIVE_REPLAY`](LIVE/procedures/SP_LIVE_REPLAY.sql) | stored procedure | Forecasts the live case in one variant (raw, playbook, full), Opus 4.6 by default. Refuses any case that is a backtest case or has an outcome. |
| [`SP_LIVE_SANITY`](LIVE/procedures/SP_LIVE_SANITY.sql) | stored procedure | Runs the three live variants, then has Opus 4.8 write the sanity-check report from the comparison, the rules that fired and the backtest record. |
| [`SP_LIVE_SANITY_TOOL`](LIVE/procedures/SP_LIVE_SANITY_TOOL.sql) | stored procedure | Wrapper the agents call: resolves the live case key (falls back to the live case if the key is unknown), runs SP_LIVE_SANITY and returns the report. |
| [`LIVE_DOC_SEARCH`](LIVE/search_services/LIVE_DOC_SEARCH.sql) | Cortex Search service | Cortex Search over the live case's masked documents (LIVE_DOC_CHUNKS), filterable by document type and relative day. |
| [`LIVE_SV`](LIVE/semantic_views/LIVE_SV.sql) | semantic view | Cortex Analyst semantic view for the live sanity check: the comparison by fiscal year, latest runs, playbook record and the latest report. |
| [`LIVE_SANITY_AGENT`](LIVE/agents/LIVE_SANITY_AGENT.sql) | Cortex Agent | A smaller Cortex Agent (Opus 4.8) for the live case only: explains or reruns the sanity check. |
