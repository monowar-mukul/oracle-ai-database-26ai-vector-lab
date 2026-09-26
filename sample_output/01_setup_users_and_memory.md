# Lab 01 — Environment setup (vector memory, users, grants)

| | |
|---|---|
| **Script** | [`scripts/01_setup_users_and_memory.sql`](../scripts/01_setup_users_and_memory.sql) |
| **Run as** | `SYS` (root for Part A, PDB for Part B) |

## Result summary

| Step | Observed | Status |
|---|---|---|
| Default `vector_memory_size` | `0` (HNSW indexes disabled) | ✅ |
| Set to 512 MB, restart | Startup banner shows *Vector Memory Area 536870912 bytes* | ✅ |
| Lab users and grants | `vec_lab`, `vec_reader` created | ✅ |
| `V$VECTOR_MEMORY_POOL` as `vec_lab` | Works after granting on `SYS.V_$VECTOR_MEMORY_POOL` | ✅ |

## Captured output

### Vector memory pool: before and after

```text
SQL> SHOW PARAMETER vector_memory_size

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
vector_memory_size                   big integer 0

SQL> conn / as sysdba
SQL> SHOW CON_NAME
CON_NAME
------------------------------
CDB$ROOT

SQL> ALTER SYSTEM SET vector_memory_size = 512M SCOPE = SPFILE;
System altered.

SQL> SHUTDOWN IMMEDIATE
Database closed.
Database dismounted.
ORACLE instance shut down.

SQL> STARTUP
ORACLE instance started.

Total System Global Area 1641255040 bytes
Fixed Size                  5009536 bytes
Variable Size            1040187392 bytes
Database Buffers           50331648 bytes
Redo Buffers                8855552 bytes
Vector Memory Area        536870912 bytes          <-- new
Database mounted.
Database opened.

SQL> ALTER SESSION SET CONTAINER = MORAL;
SQL> SHOW PARAMETER vector_memory_size

NAME                                 TYPE        VALUE
------------------------------------ ----------- ------------------------------
vector_memory_size                   big integer 512M
```

### Users and grants

```text
SQL> CREATE USER vec_lab IDENTIFIED BY ******** QUOTA UNLIMITED ON users;
User created.
SQL> GRANT DB_DEVELOPER_ROLE TO vec_lab;                                    Grant succeeded.
SQL> GRANT CREATE MLE, CREATE PROPERTY GRAPH, CREATE MINING MODEL, CTXAPP TO vec_lab;   Grant succeeded.
SQL> GRANT EXECUTE ON JAVASCRIPT TO vec_lab;                                Grant succeeded.
SQL> GRANT EXECUTE ON SYS.DBMS_REDACT TO vec_lab;                           Grant succeeded.
SQL> GRANT EXECUTE ON SYS.DBMS_RLS TO vec_lab;                              Grant succeeded.
SQL> CREATE USER vec_reader IDENTIFIED BY ********;                         User created.
SQL> GRANT CREATE SESSION TO vec_reader;                                    Grant succeeded.

SQL> GRANT SELECT ON VECSYS.VECTOR$INDEX TO vec_lab;                        Grant succeeded.
SQL> GRANT SELECT ON V$VECTOR_MEMORY_POOL TO vec_lab;
ERROR at line 1:
ORA-02030: can only select from fixed tables/views          <-- grant on the V_$ view instead

SQL> GRANT SELECT ON SYS.V_$VECTOR_MEMORY_POOL TO vec_lab;                  Grant succeeded.
SQL> GRANT EXECUTE ON DBMS_VECTOR TO vec_lab;                               Grant succeeded.
```

### Pool contents as `vec_lab`

> Captured **after** the HNSW index of Lab 03 already existed, which is why `USED_MB` is above zero.

```text
SQL> CONNECT vec_lab/********@//localhost:1521/MORAL
SQL> SELECT con_id, pool, alloc_bytes/1024/1024 AS alloc_mb, used_bytes/1024/1024 AS used_mb
  2  FROM   v$vector_memory_pool ORDER BY con_id, pool;

    CON_ID POOL                          ALLOC_MB    USED_MB
---------- -------------------------- ---------- ----------
         3 1MB POOL                          448          7
         3 64KB POOL                          48      .6875
```

## Notes

- 448 MB + 48 MB = 496 MB is what the PDB can use of the 512 MB Vector Memory Area.

