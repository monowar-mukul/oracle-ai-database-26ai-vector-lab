# Lab 05 — Custom vector distance function (JavaScript / MLE)

| | |
|---|---|
| **Script** | [`scripts/05_custom_distance_mle.sql`](../scripts/05_custom_distance_mle.sql) |
| **Run as** | `VEC_LAB` |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| JavaScript function compiles as `PURE`, `DETERMINISTIC` | created | `Function created.` (0.69 s) | ✅ |
| Unit test `[1,2,3]` vs `[4,5,1]` | 3 | `3.0000` | ✅ |
| Use in `ORDER BY` | ordered by max abs difference | ids 1, 2 (0.05), 3 (0.10) | ✅ |
| HNSW index on the custom metric | created | `Index created.` — **1 min 54.57 s for 2,000 rows** | ✅ (slow) |
| Plan uses the index | `VECTOR INDEX HNSW SCAN` | `… HNSW SCAN │ LAB_CHEB_IDX` | ✅ |
| Non-`PURE` function rejected for HNSW | ORA- error | *not captured* | ⏳ |

## Captured output

```text
SQL> CREATE OR REPLACE FUNCTION chebyshev_vector_distance("a" VECTOR, "b" VECTOR)
  2  RETURN BINARY_DOUBLE DETERMINISTIC PARALLEL_ENABLE
  3  AS MLE LANGUAGE JAVASCRIPT PURE
  4  {{ ... }};
  5  /
Function created.
Elapsed: 00:00:00.69

SQL> SELECT chebyshev_vector_distance(TO_VECTOR('[1,2,3]'), TO_VECTOR('[4,5,1]')) AS chebyshev FROM dual;

CHEBYSHEV
---------
   3.0000

SQL> SELECT id, name, ROUND(chebyshev_vector_distance(embedding, TO_VECTOR('[0.9,0.1,0.0]')), 4) AS cheb
  2  FROM lab_products ORDER BY cheb FETCH FIRST 3 ROWS ONLY;

        ID NAME                 CHEB
---------- ------------------- -----
         1 Trail Rain Jacket     .05
         2 Alpine Tent 2P        .05
         3 Summit Backpack        .1

SQL> CREATE TABLE lab_custom AS SELECT * FROM lab_big WHERE id <= 2000;
Table created.

SQL> CREATE VECTOR INDEX lab_cheb_idx ON lab_custom (embedding)
  2    ORGANIZATION INMEMORY NEIGHBOR GRAPH
  3    DISTANCE CUSTOM chebyshev_vector_distance;
Index created.
Elapsed: 00:01:54.57

SQL> EXPLAIN PLAN FOR
  2  SELECT id FROM lab_custom
  3  ORDER BY chebyshev_vector_distance(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'))
  4  FETCH APPROX FIRST 5 ROWS ONLY;

Plan hash value: 1275552165

-------------------------------------------------------
| Id  | Operation                      | Name         |
-------------------------------------------------------
|   0 | SELECT STATEMENT               |              |
|   1 |  COUNT STOPKEY                 |              |
|   2 |   VIEW                         |              |
|   3 |    SORT ORDER BY STOPKEY       |              |
|   4 |     TABLE ACCESS BY INDEX ROWID| LAB_CUSTOM   |
|   5 |      VECTOR INDEX HNSW SCAN    | LAB_CHEB_IDX |
-------------------------------------------------------
```

## Notes

- Every distance call runs JavaScript in the Multilingual Engine, so index build cost is dominated by call overhead: **~2 minutes for 2,000 rows**. Plan on far longer for large tables, or prefer a built-in metric unless you truly need custom maths.
- The `PURE` keyword is what allows the function to back an HNSW index; the negative test in script step 5.6 (same function without `PURE`) was not run in this capture.
