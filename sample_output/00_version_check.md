# Lab 00 — Version and release-update check

| | |
|---|---|
| **Script** | [`scripts/00_version_check.sql`](../scripts/00_version_check.sql) |
| **Run as** | `SYS` in the PDB |
| **Captured** | 24 Sep 2026 — Oracle AI Database 26ai EE, Linux x86-64 ([environment](../docs/TEST_ENVIRONMENT.md)) |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| Product name | "Oracle AI Database 26ai" | Oracle AI Database 26ai Enterprise Edition | ✅ |
| Release | 23.26.x | 23.26.1.0.0 | ✅ |
| `COMPATIBLE` | a 23.x value | **23.6.0** | ✅ (see note) |
| Release update recorded | 23.26.x RU | RU 23.26.1.0.0 (patch 38743669, *Gold Image*) — `SUCCESS` | ✅ |
| Feature-usage row for vector search | a row | *no rows selected* | ⚠️ not sampled yet |

## Captured output

```text
SQL> SELECT banner_full FROM v$version;

BANNER_FULL
------------------------------------------------------------------------------------------
Oracle AI Database 26ai Enterprise Edition Release 23.26.1.0.0 - Production
Version 23.26.1.0.0

SQL> SELECT version, version_full FROM v$instance;

VERSION           VERSION_FULL
----------------- -----------------
23.0.0.0.0        23.26.1.0.0

SQL> SHOW PARAMETER compatible

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
compatible                           string      23.6.0
noncdb_compatible                    boolean     FALSE

SQL> SELECT patch_id, action, status, description, action_time
  2  FROM   dba_registry_sqlpatch ORDER BY action_time;

  PATCH_ID ACTION  STATUS   DESCRIPTION                                                   ACTION_TIME
---------- ------- -------- ------------------------------------------------------------- ------------------------------
  38743669 APPLY   SUCCESS  Database Release Update : 23.26.1.0.0 (38743669) Gold Image   24-SEP-26 02.31.58.270092 AM

SQL> SELECT name, detected_usages, currently_used
  2  FROM   dba_feature_usage_statistics WHERE UPPER(name) LIKE '%VECTOR%';

no rows selected
```

## Notes

- `V$INSTANCE.VERSION` stays **23.0.0.0.0** while `VERSION_FULL` shows **23.26.1.0.0** — 26ai is the 23ai code line at a newer release update.
- `COMPATIBLE` was **23.6.0**, not the 23.0.0 the lab originally predicted. The important point holds: it is still a 23.x compatibility level.
- The patch row is a **Gold Image**, which indicates this system was built directly at 23.26.1 rather than patched up from a 23ai home. The article's "apply the release update, no upgrade" path was therefore *not* exercised here.
- Empty `dba_feature_usage_statistics` is normal on a newly built system; Oracle populates it on its own sampling schedule.
