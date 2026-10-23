# RESULTS views

Read-only views over the RESULTS tables: scoring, the learning loop, post-mortem findings, replay provenance. Most feed the `PM_ALL_SV` semantic view.

Views must be created after everything they read: run them in [`deploy.sql`](../../deploy.sql) order, not alphabetically.

| Object | Description | Uses |
|---|---|---|
| [`ERRORS`](ERRORS.sql) | FORECASTS scored against reported revenue: pct_error, abs_pct_error, and how many FY+1 quarters were already reported at the review. | FORECASTS, OUTCOMES.ACTUALS_REL, MASKED.REVENUE_HISTORY |
| [`FORECASTS`](FORECASTS.sql) | Every forecast as revenue per case, source, model and fiscal year: Claude's latest replay per mode and model, Firm_X (label parnassus), consensus and the guidance midpoint. | MASKED.REVENUE_HISTORY, REPLAY_RUNS, MASKED.GUIDANCE, MASKED.PARNASSUS_PROJ, MASKED.CONSENSUS |
| [`LEARN_RULE_SCORES`](LEARN_RULE_SCORES.sql) | Each learned rule with its gate result, how often round-1 runs applied it, net wins, and whether it is in the live playbook. | LEARN_RUN_ERRORS, LEARN_PLAYBOOKS, LEARN_RULES |
| [`LEARN_RUN_ERRORS`](LEARN_RUN_ERRORS.sql) | Learned and learned_inner replays scored per fiscal year, next to the plain Opus 4.6 independent replay (gain_pts = error saved). | REPLAY_RUNS, LEARN_PLAYBOOKS, MASKED.REVENUE_HISTORY, OUTCOMES.ACTUALS_REL, ERRORS |
| [`LEARN_SUMMARY`](LEARN_SUMMARY.sql) | Learning loop per backtest case, FY+1: baseline vs round-1 and round-2 error and gain, rule counts, and run-to-run noise. | LEARN_RUN_ERRORS, REPLAY_RUNS, MASKED.POSITIONS |
| [`PIPELINE_STATUS`](PIPELINE_STATUS.sql) | The latest run of the EVAL_PIPELINE checks. | EVAL_PIPELINE |
| [`PM_FINDINGS`](PM_FINDINGS.sql) | One row per post-mortem finding, labelled with its group (1 in packet, 2 knowable but not collected, 3 hindsight only). Only group 1 is usable as a lesson. | POSTMORTEMS, PM_REPORTS |
| [`PM_REPORTS`](PM_REPORTS.sql) | Latest masked post-mortem per backtest case, flattened: projected, reported, gap, closer sources, change next time, data to add, and finding counts per group. | POSTMORTEMS, MASKED.POSITIONS |
| [`PM_TAGS`](PM_TAGS.sql) | Bias tags of the post-mortems shown in PM_REPORTS. | BIAS_TAGS, PM_REPORTS |
| [`REPLAY_DRIVERS`](REPLAY_DRIVERS.sql) | Drivers Claude cited in the latest replays: direction, fiscal year and evidence. | REPLAY_LATEST, REPLAY_RUNS |
| [`REPLAY_LATEST`](REPLAY_LATEST.sql) | Latest independent, clone and factsheet replay per backtest case, mode and model, with model role (clean vs contaminated control). | REPLAY_RUNS, MASKED.POSITIONS |
| [`REPLAY_PROVENANCE`](REPLAY_PROVENANCE.sql) | Replay counts per mode and model: total, imported, fresh, unparsed, and the last run. | REPLAY_RUNS, REPLAY_RUN_FRESH |
| [`REPLAY_RUN_FRESH`](REPLAY_RUN_FRESH.sql) | Per run: whether it is fresh (run after the masked documents last changed, or imported with a matching checksum) and whether it was imported. | REPLAY_RUNS, MASKED.DOCUMENTS, REPLAY_IMPORTS |

## Notes

- **`FORECASTS`:** A comment in the body refers to 11_learn.sql, from an earlier layout of the project.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.RESULTS.<NAME>`. Back to the [repo README](../../README.md).
