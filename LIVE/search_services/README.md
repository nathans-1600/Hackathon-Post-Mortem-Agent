# LIVE Cortex Search services

Cortex Search over the live case's documents.

Each service indexes the `CHUNK` column of a chunk table on `PM_WH` (default embedding model), refreshing within a day. Load the table before the first refresh.

| Object | Description | Uses |
|---|---|---|
| [`LIVE_DOC_SEARCH`](LIVE_DOC_SEARCH.sql) | Cortex Search over the live case's masked documents (LIVE_DOC_CHUNKS), filterable by document type and relative day. | LIVE_DOC_CHUNKS |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.LIVE.<NAME>`. Back to the [repo README](../../README.md).
