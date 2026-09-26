# Lab 02 — AI Vector Search basics

| | |
|---|---|
| **Script** | [`scripts/02_vector_search_basics.sql`](../scripts/02_vector_search_basics.sql) |
| **Run as** | `VEC_LAB` |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| Table with `NUMBER`, `VARCHAR2`, `JSON`, `VECTOR` columns | created | created | ✅ |
| Cosine search for "outdoor" query vector | three OUTDOOR products first | ids **2, 1, 3** | ✅ |
| Euclidean / dot-product results | same top-3 set | ids 2, 1, 3 (Euclidean order) — dot product ranks id 1 first | ✅ |
| `<=>` shorthand operator | same as `VECTOR_DISTANCE(…, COSINE)` | identical distances | ✅ |
| `VECTOR_DIMENSION_COUNT`, `VECTOR_NORM` | 3 dims | 3 dims, norms 0.95 / 0.91 / 0.86 | ✅ |

## Captured output

### 2.2 Cosine similarity (query vector `[0.9, 0.1, 0.0]`)

```text
   ID NAME                      CATEGORY        COSINE_DIST
----- ------------------------- --------------- -----------
    2 Alpine Tent 2P            OUTDOOR              0.0015
    1 Trail Rain Jacket         OUTDOOR              0.0017
    3 Summit Backpack           OUTDOOR              0.0082
    7 Trail GPS Watch           ELECTRONICS          0.5768
```

### 2.3 Euclidean distance and (negative) dot product

```text
   ID NAME                       EUCLID NEG_DOT
----- ------------------------- ------- -------
    2 Alpine Tent 2P             0.0500 -0.8200
    1 Trail Rain Jacket          0.0707 -0.8600
    3 Summit Backpack            0.1225 -0.7700
    7 Trail GPS Watch            0.9912 -0.3600
```

### 2.4 Shorthand operator `<=>`

```text
   ID NAME                      COSINE
----- ------------------------- -------
    2 Alpine Tent 2P             0.0015
    1 Trail Rain Jacket          0.0017
    3 Summit Backpack            0.0082
```

### 2.5 Dimensions and norm

```text
   ID       DIMS       NORM
----- ---------- ----------
    1          3      .9513
    2          3      .9069
    3          3      .8573
```

## Notes

- Row 2 is closer than row 1 to `[0.9, 0.1, 0.0]` under cosine and Euclidean distance. Under the dot-product metric row 1 wins (−0.86 vs −0.82) because it has the larger magnitude. Different metrics can legitimately rank near neighbours differently — choose the metric your embedding model was trained for.
- The dot-product metric is returned **negated** so that "smaller = more similar" holds for every metric; that is why the values are negative.
