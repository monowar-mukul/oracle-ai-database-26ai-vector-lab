# Lab 03 — HNSW vector index

| | |
|---|---|
| **Script** | [`scripts/03_hnsw_index.sql`](../scripts/03_hnsw_index.sql) |
| **Run as** | `VEC_LAB` (checkpoint view: `SYS`) |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| 20,000 vectors loaded | 20000 | 20000 | ✅ |
| Index type and parameters | HNSW, cosine, accuracy 95 | as requested (see JSON below) | ✅ |
| Vector pool used by index | > 0 | ≈ 7 MB (1 MB pool) + 0.69 MB (64 KB pool) | ✅ |
| Plan uses the index | `VECTOR INDEX HNSW SCAN` | `VECTOR INDEX HNSW SCAN │ LAB_HNSW_IDX` | ✅ |
| **DML: own uncommitted row visible to own session** | `100001` | `100001` | ✅ |
| **DML: uncommitted row hidden from other session** | not `100001` | `10591` | ✅ |
| **DML: visible to other session after commit** | `100001` | `100001` | ✅ |
| UPDATE / DELETE on indexed table | succeed | 1 row updated, 1 row deleted | ✅ |
| Checkpoint row in `vecsys.vector$index$checkpoints` | ≥ 1 | 1 row (`num_vectors` = 20000) | ✅ |


## Captured output

### 3.5 Index definition (from `VECSYS.VECTOR$INDEX`)

```text
SQL> SELECT idx_name, JSON_SERIALIZE(idx_params RETURNING VARCHAR2 PRETTY) AS params
  2  FROM   vecsys.vector$index WHERE idx_name = 'LAB_HNSW_IDX';

IDX_NAME
------------
LAB_HNSW_IDX

PARAMS
------------------------------------------------------------
{
  "pdb_id" : 3,
  "vector_type" : "FLOAT32",
  "type" : "HNSW",
  "distribute_by" : "NONE",
  "vector_dimension" : 8,
  "distance" : "COSINE",
  "indexed_col" : "EMBEDDING",
  "degree_of_parallelism" : 1,
  "duplicate" : "DUPLICATE_ALL",
  "accuracy" : 95,
  "efConstruction" : 200,
  "num_neighbors" : 16
}
```

### Vector Memory Pool with the HNSW index loaded

```text
SQL> SELECT * FROM v$vector_memory_pool;

POOL          ALLOC_BYTES USED_BYTES POPULATE_STATUS     CON_ID
------------- ----------- ---------- --------------- ----------
1MB POOL        469762048    7340032 DONE                     3
64KB POOL        50331648     720896 DONE                     3
```

### 3.6 Execution plan

```text
SQL> EXPLAIN PLAN FOR
  2  SELECT id FROM lab_big
  3  ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
  4  FETCH APPROX FIRST 5 ROWS ONLY;

Plan hash value: 1951684143

-------------------------------------------------------
| Id  | Operation                      | Name         |
-------------------------------------------------------
|   0 | SELECT STATEMENT               |              |
|   1 |  COUNT STOPKEY                 |              |
|   2 |   VIEW                         |              |
|   3 |    SORT ORDER BY STOPKEY       |              |
|   4 |     TABLE ACCESS BY INDEX ROWID| LAB_BIG      |
|   5 |      VECTOR INDEX HNSW SCAN    | LAB_HNSW_IDX |     <-- index is used
-------------------------------------------------------

SQL> SELECT id FROM lab_big ORDER BY VECTOR_DISTANCE(...) FETCH APPROX FIRST 5 ROWS ONLY;

        ID
----------
     10591
     15160
     12651
      8388
      6419
```

### 3.7 DML with transactionally consistent results (two sessions)

```text
SESSION_A> INSERT INTO lab_big VALUES (100001, 1, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'));
1 row created.                                              -- not committed

SESSION_A> SELECT id FROM lab_big ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,...,0.5]'), COSINE)
           FETCH APPROX FIRST 1 ROWS ONLY;
        ID
----------
    100001                                                  -- A sees its own change  ✅

SESSION_B> SELECT id FROM lab_big ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,...,0.5]'), COSINE)
           FETCH APPROX FIRST 1 ROWS ONLY;
        ID
----------
     10591                                                  -- B does NOT see it      ✅

SESSION_A> COMMIT;
Commit complete.

SESSION_B> /
        ID
----------
    100001                                                  -- B sees it after commit ✅

SESSION_B> UPDATE lab_big SET embedding = TO_VECTOR('[0.9,0.9,0.9,0.9,0.9,0.9,0.9,0.9]') WHERE id = 100001;
1 row updated.
SESSION_B> DELETE FROM lab_big WHERE id = 100001;
1 row deleted.
SESSION_B> COMMIT;
Commit complete.
```

### 3.8 Enable checkpointing and force a refresh

```text
SESSION_A> EXEC DBMS_VECTOR.ENABLE_CHECKPOINT('VEC_LAB', 'LAB_HNSW_IDX');
PL/SQL procedure successfully completed.
Elapsed: 00:00:00.19

SESSION_A> EXEC DBMS_VECTOR.REBUILD_INDEX('LAB_HNSW_IDX');
PL/SQL procedure successfully completed.
Elapsed: 00:00:05.75
```

### 3.9 The on-disk checkpoint (as `SYS`)

```text
SQL> SELECT * FROM vecsys.vector$index$checkpoints;

INDEX_OBJN INDEX_OWNER_ID CHECKPOINT_ID CHECKPOINT_SCN CHECKPOINT_TYPE VERSION_NUMBER TABLESPACE_NUMBER
---------- -------------- ------------- -------------- --------------- -------------- -----------------
     72609            136             1        2137418               1              2                 ...
SPARE2 (JSON, truncated in the captured transcript):
{"num_vectors":20000,"num_deletes":0,"max_vid":20000,"index_objn":72609,"repop_c...
```

## Notes

- The **DML behaviour is the headline 26ai result**: the HNSW index accepts INSERT/UPDATE/DELETE and each session sees a read-consistent view. The lab log shows all three states (own change visible → hidden from others → visible after commit).
- Only **full checkpoints** exist (`CHECKPOINT_TYPE = 1`). The checkpoint stores graph structure, not the vectors, and records how many vectors it covers (20,000).
- The `INDEX_VECTOR_MEMORY_ADVISOR` (script step 3.3) and the exact-search baseline (step 3.2) were also not captured.
