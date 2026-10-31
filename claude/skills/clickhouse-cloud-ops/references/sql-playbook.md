# SQL playbook — ClickHouse Cloud system tables

Read-only templates. Adapt names to the actual schema; never retry blindly on an unknown-column error.

## Before the first query

```sql
SELECT version(), currentUser(), getSetting('readonly') AS readonly;
SELECT DISTINCT cluster FROM system.clusters;           -- Cloud is usually 'default'
DESCRIBE TABLE system.query_log;                        -- confirm columns used below
```

- `readonly = 1` → the `SETTINGS` clause fails with code 164. Drop it, and compensate: query in windows of ≤ 6 h, filter `event_date` tightly, keep `LIMIT`. The connector's profile is then the only scan cap; say so in the report.
- Replace `'default'` below with the cluster name found.
- **Exclude your own diagnostic traffic**: templates carry a commented line `-- AND user != '<diag user>'`. Uncomment it with the connector's user (`currentUser()` above).
- **Upgrades rename logs** (`query_log` → `query_log_0`, …). Templates that compare across time use `merge('system', '^query_log')` so the baseline survives an upgrade. If `DESCRIBE` columns differ between the renamed tables, query them separately.
- **Latency over successful queries only is biased low.** Latency templates include `ExceptionWhileProcessing` (timeouts) and report failures separately.

**Scope rule:** `*_log`, `processes`, `merges` are per replica → wrap in `clusterAllReplicas`. `system.parts`, `system.tables`, `system.mutations` on SharedMergeTree reflect shared metadata → do **not** wrap (duplicates rows).

**Standard guard** — templates below omit it for brevity; **append it to every query you run** (drop only if `readonly = 1`):
```sql
SETTINGS max_execution_time = 60, timeout_before_checking_execution_speed = 0,
         max_rows_to_read = 2000000000, max_result_rows = 1000
```

## 0. Timeline: when did it start?

```sql
SELECT toStartOfHour(event_time) AS h,
       count()                                   AS n,
       countIf(type != 'QueryFinish')            AS failed,
       quantile(0.5)(query_duration_ms)          AS p50_ms,
       quantile(0.99)(query_duration_ms)         AS p99_ms,
       quantile(0.99)(read_bytes)                AS p99_read_bytes,
       groupUniqArray(revision)                  AS revisions
FROM clusterAllReplicas('default', merge('system', '^query_log'))
WHERE event_date >= today() - 2
  AND event_time >= now() - INTERVAL 48 HOUR
  AND type IN ('QueryFinish', 'ExceptionWhileProcessing')
  AND is_initial_query = 1
  AND query_kind = 'Select'
  -- AND user != '<diag user>'
GROUP BY h
ORDER BY h
LIMIT 100
```
Pins the onset hour (use it as `t0` in §2) and shows whether a `revision` change coincides.

## 1. Top patterns in a window (rank twice)

```sql
SELECT normalized_query_hash,
       any(query_kind)                                  AS kind,
       left(normalizeQuery(any(query)), 160)            AS sample,
       count()                                          AS n,
       sum(query_duration_ms)                           AS total_ms,
       quantile(0.5)(query_duration_ms)                 AS p50_ms,
       quantile(0.99)(query_duration_ms)                AS p99_ms,
       round(avg(read_bytes))                           AS avg_read_bytes,
       max(memory_usage)                                AS max_mem
FROM clusterAllReplicas('default', system.query_log)
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 24 HOUR
  AND type IN ('QueryFinish', 'ExceptionWhileProcessing') AND is_initial_query = 1
  -- AND user != '<diag user>'
GROUP BY normalized_query_hash
ORDER BY total_ms DESC          -- then re-run with ORDER BY p99_ms DESC
LIMIT 20
```

## 1b. Insert shape per table (ingestion)

```sql
SELECT toStartOfFifteenMinutes(event_time) AS t, user,
       arrayStringConcat(tables, ',')                          AS target,
       countIf(type = 'QueryFinish')                           AS ok,
       countIf(type != 'QueryFinish')                          AS failed,
       groupUniqArrayIf(errorCodeToName(exception_code), exception_code != 0) AS errors,
       round(avgIf(written_rows, type = 'QueryFinish'))        AS avg_rows_per_insert,
       quantile(0.9)(memory_usage)                             AS p90_mem
FROM clusterAllReplicas('default', merge('system', '^query_log'))
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 24 HOUR
  AND query_kind = 'Insert' AND is_initial_query = 1
  AND type IN ('QueryFinish', 'ExceptionBeforeStart', 'ExceptionWhileProcessing')
  -- AND has(tables, '<db>.<table>')
GROUP BY t, user, target
ORDER BY t DESC, failed DESC
LIMIT 300
```
`tables` lists the target **and** MV targets. Partitions touched per insert: §7 `partitions_touched`.

## 2. Regression compare: baseline vs incident window

Set `t0` = onset (from §0) and `w` = window length. Both windows have the same length so counts compare. For daily-cycle traffic, prefer `w` = a few hours and also run it with the baseline shifted 24 h.

```sql
WITH toDateTime('2026-10-26 14:00:00', 'UTC') AS t0,
     6 AS w                                                     -- hours per window
SELECT normalized_query_hash,
       left(normalizeQuery(any(query)), 160)                         AS sample,
       countIf(event_time <  t0)                                     AS n_before,   -- 0 = new pattern
       countIf(event_time >= t0)                                     AS n_after,
       countIf(event_time >= t0 AND type != 'QueryFinish')           AS failed_after,
       quantileIf(0.99)(query_duration_ms, event_time <  t0)        AS p99_before,
       quantileIf(0.99)(query_duration_ms, event_time >= t0)        AS p99_after,
       quantileIf(0.9)(read_bytes,   event_time <  t0)              AS p90_read_before,
       quantileIf(0.9)(read_bytes,   event_time >= t0)              AS p90_read_after,
       quantileIf(0.9)(memory_usage, event_time <  t0)              AS p90_mem_before,
       quantileIf(0.9)(memory_usage, event_time >= t0)              AS p90_mem_after,
       sumIf(query_duration_ms, event_time >= t0)
         - sumIf(query_duration_ms, event_time < t0)                 AS added_ms
FROM clusterAllReplicas('default', merge('system', '^query_log'))
WHERE event_date BETWEEN toDate(t0 - toIntervalHour(w)) AND toDate(t0 + toIntervalHour(w))
  AND event_time >= t0 - toIntervalHour(w)
  AND event_time <  t0 + toIntervalHour(w)
  AND type IN ('QueryFinish', 'ExceptionWhileProcessing')
  AND is_initial_query = 1
  -- AND user != '<diag user>'
GROUP BY normalized_query_hash
HAVING n_after >= 10
ORDER BY added_ms DESC          -- impact: regressions and new patterns both rank
LIMIT 20
```

Read it: `n_before = 0` → new workload. `p90_read` up → scan grew (data growth / lost pruning). `p90_mem` up → aggregation/JOIN width. Both flat but p99 up → contention; go to §3/§4/§8. `n_after` ≫ `n_before`, per-execution flat → traffic increase upstream.

## 3. CPU by pattern

```sql
SELECT normalized_query_hash,
       left(normalizeQuery(any(query)), 160)                               AS sample,
       count()                                                             AS n,
       round(sum(ProfileEvents['UserTimeMicroseconds'] + ProfileEvents['SystemTimeMicroseconds']) / 1e6) AS cpu_s,
       round(sum(ProfileEvents['OSCPUWaitMicroseconds']) / 1e6)            AS cpu_wait_s
FROM clusterAllReplicas('default', system.query_log)
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 1 HOUR       -- or the incident window
  AND type IN ('QueryFinish', 'ExceptionWhileProcessing')
  -- AND user != '<diag user>'
GROUP BY normalized_query_hash
ORDER BY cpu_s DESC
LIMIT 20
```
No `is_initial_query` filter on purpose: child queries (parallel replicas, distributed reads) burn CPU too. High `cpu_wait_s` across many patterns = saturation (too much concurrent work), not one bad query. Background merges also use CPU: check §8.

## 4. Running now

```sql
SELECT hostName() AS replica, query_id, user,
       round(elapsed) AS elapsed_s, read_rows,
       formatReadableSize(memory_usage) AS mem,
       left(normalizeQuery(query), 160) AS sample
FROM clusterAllReplicas('default', system.processes)
WHERE is_initial_query = 1
ORDER BY elapsed DESC
LIMIT 30
```
To stop one: report `query_id` and hand the user `KILL QUERY WHERE query_id = '<id>'` as a manual, approved action.

## 5. Errors grouped

```sql
SELECT exception_code,
       errorCodeToName(exception_code)          AS error,
       normalized_query_hash,
       count()                                  AS n,
       min(event_time) AS first_seen, max(event_time) AS last_seen,
       left(any(exception), 200)                AS sample_exception   -- redact before sharing
FROM clusterAllReplicas('default', system.query_log)
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 24 HOUR
  AND type IN ('ExceptionBeforeStart', 'ExceptionWhileProcessing')
  AND is_initial_query = 1
GROUP BY exception_code, normalized_query_hash
ORDER BY n DESC
LIMIT 30
```
Common: 241 `MEMORY_LIMIT_EXCEEDED`, 252 `TOO_MANY_PARTS`, 159 `TIMEOUT_EXCEEDED`, 202 `TOO_MANY_SIMULTANEOUS_QUERIES`.

## 6. Parts per partition vs real thresholds

```sql
SELECT name, value FROM system.merge_tree_settings
WHERE name IN ('parts_to_delay_insert', 'parts_to_throw_insert', 'max_parts_in_total');
```
Table-level overrides appear in `SHOW CREATE TABLE`. Then:

```sql
SELECT database, table, partition_id,
       count() AS active_parts,
       round(avg(rows)) AS avg_rows_per_part,
       formatReadableSize(sum(bytes_on_disk)) AS size
FROM system.parts
WHERE active AND database NOT IN ('system', 'INFORMATION_SCHEMA', 'information_schema')
GROUP BY database, table, partition_id
ORDER BY active_parts DESC
LIMIT 30
```
Small `avg_rows_per_part` (hundreds/thousands) = inserts too small. Many partitions with few parts each = partition key too granular.

## 7. Part creation vs merges (insert pressure)

```sql
SELECT toStartOfFiveMinutes(event_time) AS t, database, table,
       countIf(event_type = 'NewPart')                  AS new_parts,
       round(avgIf(rows, event_type = 'NewPart'))       AS avg_rows_new_part,
       uniqExactIf(partition_id, event_type = 'NewPart') AS partitions_touched,
       countIf(event_type = 'MergeParts')               AS merges,
       countIf(error != 0)                              AS errors
FROM clusterAllReplicas('default', system.part_log)
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 3 HOUR
GROUP BY t, database, table
ORDER BY t DESC, new_parts DESC
LIMIT 200
```
`new_parts` rising and `avg_rows_new_part` falling at the incident start = the insert pattern changed. Who inserts: §1b. `errors > 0` on `MergeParts` = merges failing (often memory).

**Optional logs:** `part_log`, `asynchronous_insert_log`, `query_views_log` may be disabled or absent. Unknown-table error or zero rows → report "not available", never "healthy".

## 8. Merges in progress

```sql
SELECT hostName() AS replica, database, table,
       round(elapsed) AS elapsed_s, round(progress, 2) AS progress,
       num_parts, is_mutation,
       formatReadableSize(total_size_bytes_compressed) AS size
FROM clusterAllReplicas('default', system.merges)
ORDER BY elapsed DESC
LIMIT 30
```
A snapshot. Backlog needs §7 over time or the Datadog merge metrics.

## 9. Mutations not finished

```sql
SELECT database, table, mutation_id, left(command, 120) AS command,
       create_time, parts_to_do, latest_fail_time, left(latest_fail_reason, 200) AS fail_reason
FROM system.mutations
WHERE NOT is_done
ORDER BY create_time
LIMIT 30
```
Old `create_time` with non-empty `fail_reason` = stuck. The fix (`KILL MUTATION`) is a manual approved action.

## 10. Async inserts

```sql
SELECT toStartOfFiveMinutes(event_time) AS t, database, table, status,
       count() AS n, sum(rows) AS rows, left(any(exception), 200) AS sample_exception
FROM clusterAllReplicas('default', system.asynchronous_insert_log)
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 3 HOUR
GROUP BY t, database, table, status
ORDER BY t DESC
LIMIT 200
```
Empty table = async inserts not used (or log disabled); say so instead of concluding "healthy".

## 11. Materialized view failures

```sql
SELECT view_name, status, exception_code, errorCodeToName(exception_code) AS error,
       count() AS n, max(event_time) AS last_seen,
       quantile(0.95)(view_duration_ms) AS p95_ms
FROM clusterAllReplicas('default', system.query_views_log)
WHERE event_date >= today() - 1
  AND event_time >= now() - INTERVAL 24 HOUR
GROUP BY view_name, status, exception_code
ORDER BY (status != 'QueryFinish') DESC, n DESC
LIMIT 50
```
A failing or slow MV makes the **insert into its source table** fail or slow down. Check this before blaming the ingestion client.

## 12. Version changes and restarts

```sql
SELECT hostName() AS replica, version() AS version, uptime() AS uptime_s
FROM clusterAllReplicas('default', system.one);

SELECT toStartOfHour(event_time) AS h, hostname, groupUniqArray(revision) AS revisions, count() AS queries
FROM clusterAllReplicas('default', merge('system', '^query_log'))
WHERE event_date >= today() - 2 AND type = 'QueryFinish'
GROUP BY h, hostname
ORDER BY h, hostname
LIMIT 500
```
A `revision` change or a host disappearing at the incident start = Cloud upgrade / replica replacement. Cold caches after restart explain a temporary p99 spike.

## Validate a change

Re-run the same query (§2 with `t0` = change time) over a comparable window. Report p99, total duration, read bytes and error count before vs after. One change at a time.
