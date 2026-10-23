# RESULTS stored procedures

The backtest pipeline: replay a case, write its post-mortem, extract rules, build playbooks. Run in that order per case.

A `CALL` writes rows, and procedures that use `AI_COMPLETE` (Claude via Cortex) cost credits. Ask before calling one.

| Object | Description | Writes |
|---|---|---|
| [`SP_LEARN_EXTRACT`](SP_LEARN_EXTRACT.sql) | Turns a case's latest masked post-mortem (group 1 findings, tags that passed the 2% rule, process lesson) into at most 4 rules with Opus 4.6, then runs the hindsight gate over them. | LEARN_RULES |
| [`SP_LEARN_PLAYBOOK`](SP_LEARN_PLAYBOOK.sql) | Builds a playbook from gate-passing rules, leaving out rules from the target and holdout case. For outer_r2 and all, rules with a negative net score on the evidence runs are pruned. | LEARN_PLAYBOOKS |
| [`SP_POSTMORTEM`](SP_POSTMORTEM.sql) | Writes a post-mortem for a case with Opus 4.8: compares each forecast with reported revenue and sorts every explanation into one of three groups. In masked mode it also replaces the case's bias tags. | POSTMORTEMS, BIAS_TAGS |
| [`SP_REPLAY`](SP_REPLAY.sql) | Re-forecasts a case from its packet in a given mode (independent, clone, factsheet, learned, learned_inner, noise_check) and model. Learned modes check the hindsight guards before calling the model. | REPLAY_RUNS |

## Notes

- **`SP_LEARN_EXTRACT`:** A message in the body refers to script 07 from an earlier layout of the project.
- **`SP_POSTMORTEM`:** Known gap: named mode reads POSTMORTEM.RAW.* and OUTCOMES.ACTUALS, which do not exist, so it cannot run.
- **`SP_REPLAY`:** Known gap: named and live modes read POSTMORTEM.RAW.NAMED_PACKET and RESULTS.PRIOR_RUNS(), which do not exist, so those modes cannot run. Live runs use LIVE.SP_LIVE_REPLAY instead. Comments in the body refer to script numbers (07, 08, 11_learn.sql) from an earlier layout.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.RESULTS.<NAME>`. Back to the [repo README](../../README.md).
