# LIVE functions

Secure SQL table functions that assemble prompt text for the live forecasts, returning `(ORD, BODY)` rows.

Creating a SQL function checks the objects it reads, so run these after the tables (see [`deploy.sql`](../../deploy.sql)).

| Object | Description | Uses |
|---|---|---|
| [`LIVE_PACKET`](LIVE_PACKET.sql) | Builds the live case's packet, the same way PIT_PACKET does for backtest cases, from the LIVE tables. | POSITIONS, REVENUE_HISTORY, CONSENSUS, GUIDANCE, DOCUMENTS |
| [`PRIOR_LESSONS`](PRIOR_LESSONS.sql) | Text block of backtest lessons for the full variant: mean error by source, bias tags, what each post-mortem said to change, and the data checklist. | RESULTS.ERRORS, RESULTS.BIAS_TAGS, RESULTS.POSTMORTEMS |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
