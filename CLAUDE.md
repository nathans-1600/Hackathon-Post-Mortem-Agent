@AGENTS.md

## Claude Code notes

- Use the `sql_exec` MCP tool for SQL and `postmortem_explorer` to test a deployed agent. The safety rules
  in AGENTS.md apply: ask before any DDL, write or `CALL`.
- To refresh the scripts from Snowflake, use the `export-ddl` skill (`.claude/skills/export-ddl`).
- Commit and push only when asked.
