# MASKED functions

Secure SQL table functions that assemble prompt text from the masked tables. Replays call them; they return `(ORD, BODY)` rows to concatenate in order.

Creating a SQL function checks the objects it reads, so run these after the tables (see [`deploy.sql`](../../deploy.sql)).

| Object | Description | Uses |
|---|---|---|
| [`CLONE_CONTEXT`](CLONE_CONTEXT.sql) | Extra context for clone mode: the house process plus memos of OTHER cases (for style only, never the target case's own memo). | HOUSE_FRAMEWORK, DOCUMENTS |
| [`PIT_PACKET`](PIT_PACKET.sql) | Builds a case's point-in-time packet: case header, reported revenue, consensus, guidance, and documents newest first (capped at 150k characters). The only input a replay may use. | POSITIONS, REVENUE_HISTORY, CONSENSUS, GUIDANCE, DOCUMENTS |

Each file starts with a header (description, what it uses, what writes it). Full name of every object: `POSTMORTEM.MASKED.<NAME>`. Back to the [repo README](../../README.md).
