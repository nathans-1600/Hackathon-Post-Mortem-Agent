# setup

Account prerequisites and the database skeleton. Run these first (they are the first three lines of
[`deploy.sql`](../deploy.sql)). All three are safe to re-run: every statement is `IF NOT EXISTS`.

| File | Creates |
|---|---|
| [`warehouse.sql`](warehouse.sql) | Warehouse `PM_WH` (XSMALL, auto-suspend 60 s, auto-resume) |
| [`database_and_schemas.sql`](database_and_schemas.sql) | Database `POSTMORTEM` and schemas `MASKED`, `OUTCOMES`, `RESULTS`, `EXPLORER`, `LIVE` |
| [`stages.sql`](stages.sql) | Five internal stages (evaluation, live and import stages) |

`GET_DDL` cannot export warehouses or stages, so these files are hand-written from `SHOW WAREHOUSES` and
`SHOW STAGES` on the source account, not exported verbatim. The source warehouse is a Gen2 standard
warehouse; set that in `warehouse.sql` if your account supports it. The empty `RAW` and `PUBLIC` schemas are
not created.

Back to the [repo README](../README.md).
