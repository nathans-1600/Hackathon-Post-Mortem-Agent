# APP file formats

File formats for reading files on the app stage.

| Object | Description |
|---|---|
| [`RAW_TXT`](RAW_TXT.sql) | Reads a whole staged file as one text value (no record or field delimiters), e.g. to read the app's source back from APP_STAGE with SQL. |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.APP.<NAME>`. Back to the [repo README](../../README.md).
