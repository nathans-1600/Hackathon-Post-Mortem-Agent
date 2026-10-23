# RESULTS tables

Everything the backtest produces: replay runs, post-mortems and bias tags, learned rules and playbooks, search chunks, and evaluation data.

**Never run these against the populated database.** Each file is `CREATE OR REPLACE TABLE`, which drops the table and its data. They are for building a fresh, empty database.

| Object | Description | Written by |
|---|---|---|
| [`BIAS_TAGS`](BIAS_TAGS.sql) | Bias tags from the latest masked post-mortem per case: tag, whose forecast it describes (about), strength and evidence. | SP_POSTMORTEM |
| [`EVAL_HISTORY`](EVAL_HISTORY.sql) | Mean score per metric for each evaluation run of the semantic view and the agents. |  |
| [`EVAL_PIPELINE`](EVAL_PIPELINE.sql) | Results of the pipeline and hindsight-gate checks, one row per check per run. PIPELINE_STATUS shows the latest run. |  |
| [`EVAL_POSTMORTEM_ANALYST`](EVAL_POSTMORTEM_ANALYST.sql) | Evaluation set for the POSTMORTEM_ANALYST agent: questions and ground-truth answers. |  |
| [`EVAL_REF`](EVAL_REF.sql) | Snapshot of reference numbers (best source, Firm_X and guidance error, biggest miss, top tags) used to build evaluation ground truth. |  |
| [`LEARN_PLAYBOOKS`](LEARN_PLAYBOOKS.sql) | Playbooks: a set of rule ids and their text, by purpose (inner, outer_r1, outer_r2, all), never holding rules from the target or holdout case. | SP_LEARN_PLAYBOOK |
| [`LEARN_RULES`](LEARN_RULES.sql) | Rules learned from post-mortems: rule text, signal, direction, which years it applies to, the case it came from, and the hindsight-gate result (gate_ok, gate_hit). | SP_LEARN_EXTRACT |
| [`PM_BRIEF`](PM_BRIEF.sql) | A plain-English brief for each backtest case: a headline, why Firm_X and Claude missed, fixes for next time, and what was only knowable afterwards. Opus 4.8 writes the brief from the masked post-mortem, scored errors and findings; the closest forecaster and Firm_X's rank are computed in SQL, not by the model. |  |
| [`PM_REPORT_CHUNKS`](PM_REPORT_CHUNKS.sql) | Post-mortem report text split into sections and chunks; indexed by the PM_REPORT_SEARCH Cortex Search service. |  |
| [`POSTMORTEMS`](POSTMORTEMS.sql) | Post-mortems: the parsed JSON (findings in three groups, bias tags, lessons, data checklist) and the raw model response, per case and mode. | SP_POSTMORTEM |
| [`REPLAY_IMPORTS`](REPLAY_IMPORTS.sql) | Replay runs imported from another account, with the document checksum at export time; read by REPLAY_RUN_FRESH. |  |
| [`REPLAY_RUNS`](REPLAY_RUNS.sql) | Every replay forecast: case, mode, model, FY+1 to FY+3 growth, confidence, parsed and raw response, prompt size and the playbook used. | SP_REPLAY |

## Notes

- **`PM_BRIEF`:** Read by APP.POSTMORTEM_APP, which shows it first on its "Where each went wrong" tab. No stored procedure in this database writes it.
- **`REPLAY_IMPORTS`:** Empty on the source.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.RESULTS.<NAME>`. Back to the [repo README](../../README.md).
