# LIVE tables

The live case (masked, no outcome yet): its packet data in the same shapes as MASKED, the live forecasts and written reports, and evaluation data.

**Never run these against the populated database.** Each file is `CREATE OR REPLACE TABLE`, which drops the table and its data. They are for building a fresh, empty database.

| Object | Description | Written by |
|---|---|---|
| [`CONSENSUS`](CONSENSUS.sql) | Consensus revenue estimates for the live case, per fiscal year (same shape as MASKED.CONSENSUS). |  |
| [`DOCUMENTS`](DOCUMENTS.sql) | Masked documents of the live case, dated before D0 (same shape as MASKED.DOCUMENTS). LIVE_PACKET reads every type except the memo. |  |
| [`DOCUMENTS_PASS1`](DOCUMENTS_PASS1.sql) | First-pass copy of the live documents, same columns as DOCUMENTS. Nothing in the DDL reads it. |  |
| [`EVAL_LIVE_SANITY`](EVAL_LIVE_SANITY.sql) | Evaluation set for the live sanity check: questions and ground-truth answers. |  |
| [`EVAL_REF_L`](EVAL_REF_L.sql) | Snapshot of live reference numbers (FY+1 growth for each view, consensus, playbook rule count, source and record) used to build evaluation ground truth. |  |
| [`GUIDANCE`](GUIDANCE.sql) | Management revenue guidance for the live case (same shape as MASKED.GUIDANCE). |  |
| [`LIVE_DOC_CHUNKS`](LIVE_DOC_CHUNKS.sql) | Live documents split into chunks; indexed by the LIVE_DOC_SEARCH Cortex Search service. |  |
| [`LIVE_RUNS`](LIVE_RUNS.sql) | Live forecasts per variant (raw, playbook, full) and model: FY+1 to FY+3 growth, confidence, parsed and raw response, and the playbook used. | SP_LIVE_REPLAY |
| [`PARNASSUS_PROJ`](PARNASSUS_PROJ.sql) | The Firm_X analyst's projections for the live case, per fiscal year (same shape as MASKED.PARNASSUS_PROJ). |  |
| [`POSITIONS`](POSITIONS.sql) | The live case row (is_live = TRUE), same shape as MASKED.POSITIONS. |  |
| [`REVENUE_HISTORY`](REVENUE_HISTORY.sql) | Reported revenue of the live case known at D0 (same shape as MASKED.REVENUE_HISTORY). |  |
| [`SANITY_REPORTS`](SANITY_REPORTS.sql) | Written sanity-check reports, with the context each was written from. | SP_LIVE_SANITY |

## Notes

- **`PARNASSUS_PROJ`:** The table name is the literal source label; leave it as-is.

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
