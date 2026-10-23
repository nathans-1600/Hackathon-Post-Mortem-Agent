# OUTCOMES tables

Reported results, kept apart from the masked packets. Only scoring (`RESULTS.ERRORS`) and post-mortems read them.

**Never run these against the populated database.** Each file is `CREATE OR REPLACE TABLE`, which drops the table and its data. They are for building a fresh, empty database.

| Object | Description |
|---|---|
| [`ACTUALS_REL`](ACTUALS_REL.sql) | Reported revenue per case and fiscal year after the review, with growth and the relative day it was reported. Read only by scoring and post-mortems; never part of a packet. |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.OUTCOMES.<NAME>`. Back to the [repo README](../../README.md).
