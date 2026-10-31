# Datadog signals for ClickHouse Cloud

Two metric families may be present. Discover what exists with `search_datadog_metrics` (`name_filter: clickhouse_cloud` / `clickhouse.`) and tags with `get_metric_tags` before querying.

| Family | Source | Scope tags |
|---|---|---|
| `clickhouse_cloud.*` | ClickHouse Cloud Prometheus endpoint (pre-scraped; does **not** wake an idle service) | `clickhouse_service_name`, `clickhouse_service`, `hostname` (= replica) |
| `clickhouse.*` | Datadog ClickHouse integration / DBM agent querying the service | `database_instance`, `db`, `server` |
| `trace.clickhouse.query` | APM client spans from the application | `service`, `resource` |

Method for root-cause work and DBM tool gotchas (which DBM tools reject ClickHouse, units, `clickhouse.queries.*` vs `clickhouse.query.*`): load Datadog skills `datadog/dbm-clickhouse/investigate` and `datadog/dbm-clickhouse`. Do not repeat that work here.

**Per-pattern metrics:** `clickhouse.queries.*` (per `query_signature`) exists only when DBM query metrics are enabled. If absent, per-pattern latency/read/memory analysis must come from SQL (`sql-playbook.md` §1–§3). Prometheus metrics are service/replica aggregates with **no percentiles**: server-side p99 needs SQL or APM spans.

## Signal map

Rates: counters ending in `.count` → use `.as_rate()` or `sum` per interval. Ratios: divide two counters over the same rollup.

| Question | Metric(s) (`clickhouse_cloud.` prefix unless noted) |
|---|---|
| Query volume | `ClickHouseProfileEvents_Query.count`, `_SelectQuery.count`, `_InsertQuery.count` |
| Avg server time per query | `ClickHouseProfileEvents_QueryTimeMicroseconds.count / ClickHouseProfileEvents_Query.count` (also `SelectQueryTimeMicroseconds`) |
| Client-observed latency (p99) | APM spans of the ClickHouse client (`trace.clickhouse.query` if that integration is used; otherwise find the span with `search_datadog_spans` on the calling `service`) — compare with server time to split server vs pool/network |
| Concurrency | `ClickHouseMetrics_Query`; `clickhouse.query.active`, `clickhouse.query.waiting` |
| Failures | `ClickHouseProfileEvents_FailedQuery.count`, `_FailedSelectQuery.count`; per code `ClickHouseErrorMetric_<CODE_NAME>.count` (list them with `name_filter: ClickHouseErrorMetric`); `clickhouse.query.memory.limit_exceeded.count` |
| CPU | `ClickHouseAsyncMetrics_CGroupUserTimeNormalized`, `_CGroupSystemTimeNormalized` vs `_CGroupMaxCPU`; IO wait `ClickHouseProfileEvents_OSIOWaitMicroseconds.count` |
| Memory | `ClickHouseAsyncMetrics_CGroupMemoryUsed`, `_MemoryResident`; query vs background: `ClickHouseMetrics_MemoryTracking` vs `_MergesMutationsMemoryTracking` |
| Parts pressure | **`ClickHouseAsyncMetrics_MaxPartCountForPartition`** (the one to compare with `parts_to_delay/throw_insert`); `ClickHouseMetrics_PartsActive`, `ClickHouseAsyncMetrics_TotalPartsOfMergeTreeTables`; inserts being throttled: `ClickHouseMetrics_DelayedInserts` |
| Merges | `ClickHouseMetrics_Merge`, `ClickHouseMetrics_BackgroundMergesAndMutationsPoolTask` vs `_PoolSize` (pool saturated = backlog), `ClickHouseMetrics_DiskSpaceReservedForMerge`, `ClickHouseProfileEvents_Merge.count` |
| Mutations | `ClickHouseMetrics_PartMutation`; `clickhouse.query.mutation` |
| Ingestion | `ClickHouseProfileEvents_InsertedRows.count`, `_InsertedBytes.count`; rows per insert = `InsertedRows / InsertQuery`; async: `_AsyncInsertQuery.count`, `_AsyncInsertRows.count`, `ClickHouseMetrics_PendingAsyncInsert` |
| Scan volume | `ClickHouseProfileEvents_SelectedRows.count`, `_SelectedBytes.count`, `_ReadCompressedBytes.count` |
| Cache / S3 | `ClickHouseProfileEvents_MarkCacheHits/Misses.count`, `ClickHouseMetrics_FilesystemCacheSize`; `_S3ReadMicroseconds.count`, `_S3ReadRequestsErrors.count` |
| Restart / upgrade | `ClickHouseAsyncMetrics_Uptime` drops to ~0 per `hostname`; `ClickHouse_ServiceInfo` tags (version); replica set changes = new `hostname` values |
| Storage growth | `ClickHouseAsyncMetrics_TotalBytesOfMergeTreeTables`, `_TotalRowsOfMergeTreeTables` |

Always group by `hostname` once before concluding "service-wide": one hot replica hides in averages.

## Quick reads

- `MaxPartCountForPartition` climbing + `DelayedInserts > 0` → inserts outpacing merges; next: rows per insert and `sql-playbook.md` §7.
- `MergesMutationsMemoryTracking` high while queries fail with 241 → merges/mutations compete for memory; look for a running mutation (§9) or huge merges (§8).
- `QueryTimeMicroseconds/Query` flat but APM p99 up → not the server.
- `Uptime` reset at incident start → restart/upgrade; expect cold-cache p99 for a while.

## Alerts

Define for each: metric + scope (`clickhouse_service_name`), aggregation, baseline or threshold, sustained duration (≥10 min, never one point), severity, owner, runbook link. Candidates:

| Signal | Condition sketch |
|---|---|
| Parts near limit | `max:…MaxPartCountForPartition` > 60–70% of real `parts_to_delay_insert` for 10 min |
| Inserts throttled | `…DelayedInserts` > 0 for 10 min |
| Error rate | `FailedQuery / Query` above baseline (anomaly) for 15 min; any `ErrorMetric_NOT_ENOUGH_SPACE` |
| Memory | `CGroupMemoryUsed` > 85% of limit for 15 min |
| Latency | APM `trace.clickhouse.query` p99 vs SLO for 15 min |
| Restarts | `Uptime` < 600 on any replica outside maintenance window |

Read the real thresholds from SQL (`sql-playbook.md` §6) before writing an alert; never hard-code 150/300. Never claim an alert exists unless you saw it (`search_datadog_monitors`). Creating monitors is a write: show the definition and get approval.
