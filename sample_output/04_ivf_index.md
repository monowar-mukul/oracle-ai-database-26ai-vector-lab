# Lab 04 — IVF vector index

| | |
|---|---|
| **Script** | [`scripts/04_ivf_index.sql`](../scripts/04_ivf_index.sql) |
| **Run as** | `VEC_LAB` |

## Result summary

| Check | Expected (original lab) | Observed | Status |
|---|---|---|---|
| IVF index created | created | `Index created.` at 06:47:33 — `IVF_FLAT`, 50 centroids (≈ 4 s, from clock prompts) | ✅ |
| Approximate top-10 vs exact top-10 (one test query) | high overlap | **10 / 10** | ✅ |
| Faster or slower than HNSW | slower per query | 0.16 s (HNSW, first run) vs 0.05 s (IVF) | ⚠️ inconclusive at 20k rows |

## Captured output

### 4.2 / 4.4 Vector pool before and after creating the IVF index

```text
-- BEFORE
POOL                        ALLOC_BYTES USED_BYTES
-------------------------- ----------- ----------
1MB POOL                     469762048    7340032
64KB POOL                     50331648     720896

SQL> CREATE VECTOR INDEX lab_ivf_idx ON lab_big_ivf (embedding)
  2    ORGANIZATION NEIGHBOR PARTITIONS
  3    DISTANCE COSINE
  4    WITH TARGET ACCURACY 90
  5    PARAMETERS (TYPE IVF, NEIGHBOR PARTITIONS 50);
Index created.                                               -- ≈ 4 s, inferred from SET TIME prompts (06:47:29 -> 06:47:33); no Elapsed line captured

-- AFTER
POOL                        ALLOC_BYTES USED_BYTES
-------------------------- ----------- ----------
1MB POOL                     469762048    9437184            <-- +2,097,152
64KB POOL                     50331648     786432            <-- +65,536
```

### 4.5 Execution plan

```text
| Id | Operation                     | Name
|  0 | SELECT STATEMENT              |
|  1 |  VIEW                         |
|  2 |   NESTED LOOPS                |
|  3 |    VIEW                       | VW_IVPSR_11E7D7DE
|  4 |     COUNT STOPKEY             |
|  5 |      VIEW                     | VW_IVPSJ_578B79F1
|  6 |       SORT ORDER BY STOPKEY   |
|  7 |        HASH JOIN              |
|  8 |         PART JOIN FILTER CREATE| :BF0000
|  9 |          VIEW                 | VW_IVCR_B5B87E67
| 10 |           COUNT STOPKEY       |
| 11 |            VIEW               | VW_IVCN_9A1D2119
| 12 |             SORT ORDER BY STOPKEY
| 13 |              TABLE ACCESS FULL| VECTOR$LAB_IVF_IDX$72631_72635_0$IVF_FLAT_CENTROIDS
| 14 |         PARTITION LIST JOIN-FILTER
| 15 |          TABLE ACCESS FULL    | VECTOR$LAB_IVF_IDX$72631_72635_0$IVF_FLAT_CENTROID_PARTITIONS
| 16 |    TABLE ACCESS BY USER ROWID | LAB_BIG_IVF
```

### 4.6 Same query on both indexes

```text
-- HNSW (lab_big)            Elapsed: 00:00:00.16          -- IVF (lab_big_ivf)   Elapsed: 00:00:00.05
        ID                                                          ID
----------                                                  ----------
     10591                                                       10591
     15160                                                       15160
     12651                                                       12651
      8388                                                        8388
      6419                                                        6419
```

Both indexes return the **same five ids in the same order**.

### 4.7 Index catalog (JSON condensed onto fewer lines)

```text
IDX_OWNER# IDX_NAME       IDX_TYPE   PARAMS
---------- -------------- ---------- --------------------------------------------
       136 LAB_HNSW_IDX   HNSW       {"type":"HNSW","distance":"COSINE","accuracy":95,
                                      "efConstruction":200,"num_neighbors":16,"vector_dimension":8, ...}
       136 LAB_IVF_IDX    IVF_FLAT   {"type":"IVF_FLAT","distance":"COSINE","accuracy":90,
                                      "target_centroids":50,"num_centroids":50,"max_num_centroids":50,
                                      "avg_num_centroids":50,"min_vectors_per_partition":10,
                                      "samples_per_partition":256,"vector_dimension":8,
                                      "degree_of_parallelism":1, ...}
```

### 4.8 Approximate vs exact top-10 (single test query)

```text
OVERLAP_OUT_OF_10
-----------------
               10
Elapsed: 00:00:00.26
```

## Notes

- **Correction to the article-based expectation:** the IVF *vectors* live on disk in partition tables, but vector pool usage still rose by about 2 MB (≈ 27% of what the HNSW index used) after the index was created. This is consistent with cached IVF centroid data, though the log does not confirm the mechanism. "Not held in memory" is therefore a simplification; "not bounded by RAM" is the safer reading.
- The IVF plan is a nested-loops join through the centroid tables — there is no operator literally called *IVF SCAN* in this release.
- The elapsed-time comparison is **not** a benchmark: 20,000 rows is tiny and the HNSW query ran first (cold caches). Repeat with ≥ 1 M rows, real embedding dimensions and several runs each.
