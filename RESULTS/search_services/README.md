# RESULTS Cortex Search services

Cortex Search services the agents use to quote documents and post-mortems.

Each service indexes the `CHUNK` column of a chunk table on `PM_WH` (default embedding model), refreshing within a day. Load the table before the first refresh.

| Object | Description | Uses |
|---|---|---|
| [`DOC_SEARCH`](DOC_SEARCH.sql) | Cortex Search over the masked case documents (MASKED.DOC_CHUNKS), filterable by case, document type and relative day. | MASKED.DOC_CHUNKS |
| [`PM_REPORT_SEARCH`](PM_REPORT_SEARCH.sql) | Cortex Search over the post-mortem report text (PM_REPORT_CHUNKS), filterable by case and section. | PM_REPORT_CHUNKS |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.RESULTS.<NAME>`. Back to the [repo README](../../README.md).
