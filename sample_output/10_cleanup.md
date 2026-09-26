# Lab 10 — Cleanup

| | |
|---|---|
| **Script** | [`scripts/10_cleanup.sql`](../scripts/10_cleanup.sql) |
| **Run as** | `SYS` in the PDB |
| **Captured** | 24 Sep 2026, 09:47 — Oracle AI Database 26ai EE 23.26.1.0.0 ([environment](../docs/TEST_ENVIRONMENT.md)) |

## Result summary

| Step | Expected | Observed | Status |
|---|---|---|---|
| Connected to the PDB | `MORAL` | `CON_NAME = MORAL` | ✅ |
| Disable SQL Firewall allow-list for `VEC_READER` | success | `PL/SQL procedure successfully completed.` | ✅ |
| Disable SQL Firewall | success | `PL/SQL procedure successfully completed.` | ✅ |
| Drop `MODEL_DIR` directory object | dropped | `Directory dropped.` | ✅ |
| `DROP USER vec_reader CASCADE` — first attempt | dropped | **`ORA-01940: cannot drop a user who is currently connected`** | ⚠️ |
| `DROP USER vec_reader CASCADE` — retry (`/`) | dropped | `User dropped.` | ✅ |
| `DROP USER vec_lab CASCADE` | dropped | `User dropped.` | ✅ |

## Captured output

Password removed from the connect line.

```text
$ sqlplus sys/'********'@localhost:1521/MORAL as sysdba

SQL*Plus: Release 23.26.1.0.0 - Production on Thu Sep 24 09:47:11 2026
Version 23.26.1.0.0

Last Successful login time: Thu Sep 24 2026 09:46:45 +00:00

Connected to:
Oracle AI Database 26ai Enterprise Edition Release 23.26.1.0.0 - Production
Version 23.26.1.0.0

SQL> SHOW CON_NAME

CON_NAME
------------------------------
MORAL

SQL> SET DEFINE OFF

SQL> EXEC DBMS_SQL_FIREWALL.DISABLE_ALLOW_LIST('VEC_READER');
PL/SQL procedure successfully completed.

SQL> EXEC DBMS_SQL_FIREWALL.DISABLE;
PL/SQL procedure successfully completed.

SQL> DROP DIRECTORY MODEL_DIR;
Directory dropped.

SQL> DROP USER vec_reader CASCADE;
DROP USER vec_reader CASCADE
*
ERROR at line 1:
ORA-01940: cannot drop a user who is currently connected

SQL> /
User dropped.

SQL> DROP USER vec_lab CASCADE;
User dropped.
```

## Notes

- **`ORA-01940` is normal and harmless.** Oracle refuses to drop a user that has an open session — here a leftover `VEC_READER` terminal from Lab 08. The retry succeeded once that session was no longer connected. If a session lingers, find and end it first:

  ```sql
  SELECT sid, serial#, username FROM v$session WHERE username IN ('VEC_READER','VEC_LAB');
  ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;   -- then repeat the DROP USER
  ```

- **SQL Firewall needed no extra clean-up.** The script's fallback comment warned that `DROP USER` might complain about firewall objects (capture / allow-list). It did not: disabling the allow-list and the firewall was enough, and `DROP USER … CASCADE` completed.
- `CASCADE` removed every object owned by the two users, including the lab tables, vector and hybrid indexes, the property graph, the JavaScript functions, the VPD/redaction policies on `LAB_SECURE_DOCS`, and the `MINILM_L12` ONNX model loaded by `VEC_LAB`. The transcript does not include a follow-up query, so removal of these was not individually verified (see the optional check below).
- **Not reverted:** `vector_memory_size` was left at 512 MB and the API-key credential lived inside `VEC_LAB` (so it was dropped with the user). Any provider API key that was exposed earlier still needs to be **revoked at the provider** — dropping a database user does not do that.

## Optional verification (not captured)

```sql
-- as SYS in the PDB: expect no rows for each query
SELECT username FROM dba_users WHERE username IN ('VEC_LAB','VEC_READER');
SELECT owner, object_name FROM dba_objects WHERE owner IN ('VEC_LAB','VEC_READER');
SELECT directory_name FROM dba_directories WHERE directory_name = 'MODEL_DIR';
```
