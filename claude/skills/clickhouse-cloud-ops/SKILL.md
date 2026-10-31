---
name: clickhouse-cloud-ops
description: Use when investigating a live or recent problem on a ClickHouse Cloud service - slow or regressed queries, p95/p99 latency spikes, CPU or memory pressure, MEMORY_LIMIT_EXCEEDED, TOO_MANY_PARTS, merge backlog, stuck mutations, failing inserts or materialized views, Kafka/ClickPipes ingestion lag, rising error rate, storage growth - or when defining ClickHouse alerts. For schema or query design with no observed production symptom, use clickhouse-best-practices instead.
---

# ClickHouse Cloud Ops

Diagnose production ClickHouse Cloud problems from evidence, then hand the fix to the design skills. This skill owns **"what is wrong and why, measured"**; `clickhouse-best-practices` and `clickhouse-architecture-advisor` own **"how it should be built"**.

**Principle:** every claim is a measurement with a time window and scope, or it is labelled a hypothesis.

## Safety (non-negotiable)

1. **Read-only.** Never run or propose to auto-run `ALTER`, `OPTIMIZE`, `SYSTEM`, `KILL`, `CREATE`, `DROP`, `TRUNCATE`, `INSERT`, server/user/profile/table setting changes, connector config changes, or scaling. (A query-scoped `SETTINGS` guard on your own `SELECT` is fine.) Write the statement out and leave it as a manual action the user approves. When a running query must stop, report its `query_id` and the `KILL QUERY` text; do not run it.
2. Every SQL query follows `clickhouse-best-practices` rule `agent-query-safety` (scan caps, `max_execution_time`, `LIMIT`) **and** filters `event_date` as well as `event_time` on `system.*_log` tables (they are ordered by `event_date`).
3. "Fix it now" pressure does not change rule 1. Offer the safest mitigation as text with its risk.
4. Never ask for credentials in chat. Redact query literals and exception text that may carry customer data.

## Access paths — pick by what exists

Check which of these the session has, in this order. Use the first that can answer the question; do not block on a missing one.

| Path | Use for | Notes |
|---|---|---|
| **Datadog** (`clickhouse_cloud.*` Prometheus + `clickhouse.*` integration metrics, APM, logs) | First stop for any incident: onset time, broad vs per-replica, parts/merges, memory, errors, correlation with deploys. Per-pattern detail only if DBM `clickhouse.queries.*` exists; otherwise SQL | Does not touch the service. Load Datadog skills `datadog/dbm-clickhouse` (metric catalog) and `datadog/dbm-clickhouse/investigate` (RCA method). Signal map: `references/datadog-signals.md` |
| **SQL via a BI/SQL connector** (e.g. Superset `execute_sql`) | Per-query drill-down in `system.*` tables, history beyond metric retention, table/partition detail | Production read: confirm with the user before the first query. Queries: `references/sql-playbook.md` |
| **User runs SQL** (console, `clickhouse-client`) | When no connector has access, or the agent is not permitted to read production | Hand over ready-to-paste SQL from the playbook and ask for the result as text/CSV |
| **Cloud Console / Query Insights** | Visual pattern ranking, per-replica resource charts | The agent cannot open it. Ask the user for a screenshot or export of the specific view you name |
| **ClickHouse MCP** | Same as SQL path | Only if connected |

Organisation-specific connectors, IDs, roles and dashboards: `references/access.md` if present (not shipped; each organisation adds its own).

## Workflow

1. **Frame.** Service (prod/staging), symptom, start time converted to UTC (system tables and Datadog queries use UTC; watch DST changes). Windows: fresh incident = last hour vs same hour previous day; started earlier = equal windows either side of the onset (playbook §0 finds it); trend = 7 days.
2. **Classify** into one mode below. More than one symptom: start with the earliest in time.
3. **Datadog first** for the mode's signals (`references/datadog-signals.md`). Establish:
   - Is the time spent in ClickHouse? Compare APM client spans with server-side query duration. Server flat and client slow → pool/network/app, not ClickHouse.
   - When it started; broad or one signature/table.
   - What changed then: app deploys (`datadog/change-tracking`), **ClickHouse version change or restart** (Cloud auto-upgrades; playbook §12), replica count, an ETL/backfill/mutation starting.
4. **Drill with SQL** only for what metrics cannot show (which query shape, which partition, which MV, exception text).
5. **Name the mechanism**, not the symptom. "Too many parts" is a symptom; "insert batches dropped from 50k to 200 rows after deploy X" is a mechanism.
6. **Hand off the fix** using the routing table. Cite the rule file.
7. **Report** (format below).

## Diagnostic modes

| Mode | Key question | Primary evidence | SQL (playbook §) |
|---|---|---|---|
| Latency regression | Same queries slower, or different/more queries? | per-signature `time/count`, `read_bytes/count`, `memory/count`, count | §2 regression compare, §1 top patterns |
| Ongoing slowness / saturation | What is running now? | active queries, CPU, memory | §4 processes |
| CPU / memory pressure | Broad or concentrated in few patterns? | CPU/memory per replica, per-pattern CPU | §3 CPU by pattern |
| Errors | Which code, which pattern, since when? | `FailedQuery`, error metrics by code | §5 errors |
| Parts / merges | Per-**partition** count vs real thresholds; inserts vs merges rate | `MaxPartCountForPartition`, merges, DelayedInserts | §6 parts, §7 part creation, §8 merges |
| Mutations | Stuck or slow mutation? | mutation metrics | §9 mutations |
| Ingestion (Kafka Connect/ClickPipes/async/MV) | Client batching, a failing MV, or server pressure? | connector lag + logs, rows per insert, async-insert queue, MV errors | §1b insert shape, §7 part creation, §11 MV failures, §9 mutations, §10 async inserts |
| Cost / capacity | Which workload drives usage? | resource history, bytes read per pattern | §1 sorted by total |
| Alert design | What would have caught this earlier? | `references/datadog-signals.md` → Alerts | §6 for real thresholds |

For ingestion errors (`TOO_MANY_PARTS`, `MEMORY_LIMIT_EXCEEDED` as retriable exceptions) the server error is usually the effect. Measure rows per insert and partitions per insert (playbook §1b) first, then discriminate:

| Evidence | Mechanism |
|---|---|
| Rows per insert dropped at onset; parts per partition rising | Batches got smaller / more tasks → `TOO_MANY_PARTS` |
| Many partitions per insert | Partition key too fine or late data spread → parts multiply per insert |
| Insert `memory_usage` high, MV on target table slow/failing (§11) | MV work per insert → `MEMORY_LIMIT_EXCEEDED` on insert |
| `MergesMutationsMemoryTracking` high, mutation open (§9) | Background work starving inserts of memory and merges |
| Insert count up with same data volume, failures ≥ successes | **Retry storm**: failed inserts are retried, adding parts and memory pressure. Check connector retry/backoff and that retries are deduplicated (`insert_deduplicate`, exactly-once) |

Mitigations are proposals with risk, never applied: pausing the connector (lag grows, offsets kept) is the lowest-risk way to let merges catch up; restoring the previous batch/`tasks.max` config is next. Never raise `parts_to_throw_insert`.

Interpretation:
- p99 up, p50 flat → tail: concurrency, one tenant/filter, cold cache, merges competing.
- Per-execution `read_bytes` up → data growth or lost pruning (filter no longer matches sort key / partition).
- Count up, per-execution flat → upstream traffic change, not ClickHouse.
- Rising parts is an effect. Find the insert pattern or mutation that caused it.
- Part thresholds apply **per partition**. Read real values from `system.merge_tree_settings` (playbook §6); do not assume defaults.

## Routing the fix

| Diagnosed mechanism | Hand off to |
|---|---|
| Scan too large, filter not on sort key | `clickhouse-best-practices`: `schema-pk-filter-on-orderby`, `schema-pk-prioritize-filters`, `query-index-skipping-indices` |
| JOIN memory / slow JOIN | `query-join-choose-algorithm`, `query-join-filter-before`, `query-join-use-any`, `query-join-consider-alternatives` |
| Small inserts → parts explosion | `insert-batch-size`, `insert-async-small-batches`; partition too granular → `schema-partition-low-cardinality` |
| Mutations (`ALTER UPDATE/DELETE`) | `insert-mutation-avoid-update`, `insert-mutation-avoid-delete`; `OPTIMIZE FINAL` used → `insert-optimize-avoid-final` |
| Heavy repeated aggregation | `query-mv-incremental` / `query-mv-refreshable`, then `clickhouse-architecture-advisor` (`decision-real-time-preaggregation`) |
| Late-arriving data / upserts | `clickhouse-architecture-advisor` (`decision-late-arriving-upserts`) |
| Ingestion architecture change | `clickhouse-architecture-advisor` (`decision-ingestion-strategy`) |
| Wide types / Nullable everywhere | `schema-types-*` rules |

Scaling is a separate option, never the default fix. Offer it only with evidence that the workload is already efficient.

## Report format

```
## What happened        — symptom, exact window (UTC), scope (service/replica/table/signature)
## Why it broke         — mechanism, one paragraph
## Evidence             — measured facts (source + window), then hypotheses, labelled
## Root cause           — "confirmed" or "suspected: missing <exact evidence>"
## What to do           — Immediate mitigation / Follow-up; each with risk, owner, and "needs approval" if it changes anything
## Validation           — metric, baseline value, target, observation window
```

## Common mistakes

| Mistake | Correct |
|---|---|
| Ranking by highest p99 only | Also rank by total duration: a frequent moderate query often costs more |
| `system.query_log` on one replica | `clusterAllReplicas('default', ...)` for logs; check cluster name in `system.clusters` |
| Wrapping `system.parts` in `clusterAllReplicas` | SharedMergeTree parts are shared metadata; that duplicates rows |
| Counting child queries of distributed reads | `is_initial_query = 1` |
| Comparing total table parts to `parts_to_throw_insert` | Compare max parts **per partition** |
| `SETTINGS` clause rejected with code 164 (`READONLY`) | The user is `readonly=1`; drop `SETTINGS`, keep tight `event_date` + `LIMIT`, mention it |
| Claiming a fix worked | Show before/after on the same metric and window |
