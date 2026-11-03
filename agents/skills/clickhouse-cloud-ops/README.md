# clickhouse-cloud-ops

Agent skill for diagnosing production problems on ClickHouse Cloud. It covers latency regressions, saturation, errors, parts and merges, mutations, ingestion and alert design, using Datadog metrics first and read-only SQL second.

It complements, and routes fixes to:
- `clickhouse-best-practices`: the schema, query and insert rules.
- `clickhouse-architecture-advisor`: design decisions.
- the Datadog skills `datadog/dbm-clickhouse` and `datadog/dbm-clickhouse/investigate`.

Contents:
- `SKILL.md`: safety, access paths, workflow, diagnostic modes, fix routing, report format.
- `references/sql-playbook.md`: bounded `system.*` queries (regression compare, CPU by pattern, errors, parts vs thresholds, part_log, merges, mutations, async inserts, MV failures, version and restarts).
- `references/datadog-signals.md`: the `clickhouse_cloud.*` / `clickhouse.*` metric map and alert templates.
- `references/access.md` (optional, not included): your organisation's connectors, IDs and dashboards.
- `references/official-resources.md`: documentation links.

Install: copy this directory to `~/.agents/skills/clickhouse-cloud-ops/` (or `~/.claude/skills/`). The skill holds no credentials and connects to nothing by itself.
