# LIVE views

Read-only views that line up the live forecasts, the rules that fired and the latest report. They feed the `LIVE_SV` semantic view.

Views must be created after everything they read: run them in [`deploy.sql`](../../deploy.sql) order, not alphabetically.

| Object | Description | Uses |
|---|---|---|
| [`LIVE_COMPARISON`](LIVE_COMPARISON.sql) | One row per fiscal year with every view of growth: Claude raw, with playbook, with playbook and lessons, bias-adjusted raw (FY+1), consensus, guidance midpoint and the analyst. | LIVE_RUNS, REVENUE_HISTORY, CONSENSUS, GUIDANCE, RESULTS.ERRORS, POSITIONS, PARNASSUS_PROJ |
| [`LIVE_RULES_APPLIED`](LIVE_RULES_APPLIED.sql) | Rules the latest playbook and full runs applied, with direction, rule text and the past case each was learned from. | LIVE_RUNS, RESULTS.LEARN_RULES |
| [`LIVE_RUNS_LATEST`](LIVE_RUNS_LATEST.sql) | Latest live run per variant and model: growth, confidence, view vs consensus, key risks and number of rules applied. | LIVE_RUNS |
| [`PLAYBOOK_RECORD`](PLAYBOOK_RECORD.sql) | Every rule in the live playbook: direction, source case, backtest record (times applied, net wins), and whether it fired in today's runs. | RESULTS.LEARN_PLAYBOOKS, RESULTS.LEARN_RUN_ERRORS, RESULTS.LEARN_RULES, LIVE_RULES_APPLIED |
| [`SANITY_REPORT_LATEST`](SANITY_REPORT_LATEST.sql) | The latest written sanity-check report per case. | SANITY_REPORTS |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
