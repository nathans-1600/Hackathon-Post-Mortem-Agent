# MASKED tables

The masked backtest cases: everything the forecaster is allowed to see. Companies and people are tokens, dates are days relative to the review (D0), amounts are on a secret scale.

**Never run these against the populated database.** Each file is `CREATE OR REPLACE TABLE`, which drops the table and its data. They are for building a fresh, empty database.

| Object | Description |
|---|---|
| [`CONSENSUS`](CONSENSUS.sql) | Consensus revenue estimates per case and fiscal year (FY+1 to FY+3) as of the day before the review, with the number of estimates. Masked amounts (CUR m). |
| [`DOCUMENTS`](DOCUMENTS.sql) | Masked source documents per case (filings, call transcripts, sell-side notes and the Firm_X memo), dated in days relative to D0. PIT_PACKET reads every type except the memo. |
| [`DOC_CHUNKS`](DOC_CHUNKS.sql) | DOCUMENTS split into chunks; indexed by the DOC_SEARCH Cortex Search service. |
| [`EXPORT_MANIFEST`](EXPORT_MANIFEST.sql) | Row count and checksum per table of the masked data export, for checking that an import arrived intact. |
| [`GUIDANCE`](GUIDANCE.sql) | Management revenue guidance issued before the review: period, low/high amount and/or growth range, and the relative day it was issued. |
| [`HOUSE_FRAMEWORK`](HOUSE_FRAMEWORK.sql) | Firm_X house-process text, read by CLONE_CONTEXT for clone mode. |
| [`PARNASSUS_PROJ`](PARNASSUS_PROJ.sql) | Firm_X's own projections from each investment review, per fiscal year (revenue and growth). |
| [`POSITIONS`](POSITIONS.sql) | One row per case (decision_key): masked company id, live flag, fiscal-year labels and tier (A = review after the forecaster's training cutoff, B = before). |
| [`REVENUE_HISTORY`](REVENUE_HISTORY.sql) | Reported revenue per case and period (FY0, earlier years, FY+1 quarters) known at D0, with the relative day each figure was reported. |

## Notes

- **`HOUSE_FRAMEWORK`:** Known gap: empty on the source, so clone mode has no house-process text.
- **`PARNASSUS_PROJ`:** The table name is the literal source label; leave it as-is.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.MASKED.<NAME>`. Back to the [repo README](../../README.md).
