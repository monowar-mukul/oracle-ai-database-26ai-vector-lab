# Lab 06 — Unified hybrid search (vector + relational + JSON + text + graph)

| | |
|---|---|
| **Script** | [`scripts/06_hybrid_search.sql`](../scripts/06_hybrid_search.sql) |
| **Run as** | `VEC_LAB` |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| Oracle Text index on `description` | created | `Index created.` (6.5 s) | ✅ |
| One query with relational + JSON + text + vector predicates | id 1 only | id **1** Trail Rain Jacket | ✅ |
| JSON numeric filter (`rating ≥ 4.5`) + vector rank | ids 2, 1, 7 | ids **2, 1, 7** | ✅ |
| SQL property graph created over existing tables | created | `Property graph created.` | ✅ |
| Graph traversal + vector ranking | ids 2, 3, 7 | ids **2, 3, 7** | ✅ |

## Captured output

### 6.2 Four predicate types and vector ranking in one statement

```sql
WHERE category = 'OUTDOOR'                       -- relational
AND   price < 200                                -- relational
AND   JSON_VALUE(attrs, '$.color') = 'red'       -- JSON
AND   CONTAINS(description, 'waterproof') > 0    -- full text
ORDER BY VECTOR_DISTANCE(...)                    -- vector
```

```text
  ID NAME                 PRICE COLOR    COSINE_DIST
---- ------------------- ------ -------- -----------
   1 Trail Rain Jacket      129 red            .0017

Elapsed: 00:00:00.55
```

Only product 1 satisfies *all* filters: product 2 is OUTDOOR/waterproof but costs 349 and is green; product 3 is red but its description says "rain cover", not "waterproof".

### 6.3 JSON filter + vector ranking

```text
        ID NAME                     RATING
---------- ------------------------- ------
         2 Alpine Tent 2P               4.8
         1 Trail Rain Jacket            4.6
         7 Trail GPS Watch              4.5
```

### 6.4 Graph traversal + vector ranking

```text
SQL> CREATE PROPERTY GRAPH lab_graph
  2    VERTEX TABLES ( lab_products KEY (id) PROPERTIES (id, name) )
  3    EDGE TABLES ( lab_related KEY (src_id, dst_id)
  4        SOURCE KEY (src_id) REFERENCES lab_products (id)
  5        DESTINATION KEY (dst_id) REFERENCES lab_products (id)
  6        PROPERTIES (relation) );
Property graph created.

SQL> SELECT p.id, p.name, g.relation, ROUND(VECTOR_DISTANCE(p.embedding, TO_VECTOR('[0.9,0.1,0.0]'), COSINE), 4) AS cosine_dist
  2  FROM GRAPH_TABLE (lab_graph MATCH (a) -[e]-> (b) WHERE a.id = 1
  3                    COLUMNS (b.id AS related_id, e.relation AS relation)) g
  4  JOIN lab_products p ON p.id = g.related_id
  5  ORDER BY cosine_dist FETCH FIRST 3 ROWS ONLY;

        ID NAME                 RELATION       COSINE_DIST
---------- -------------------- -------------- -----------
         2 Alpine Tent 2P       BOUGHT_WITH          .0015
         3 Summit Backpack      BOUGHT_WITH          .0082
         7 Trail GPS Watch      BOUGHT_WITH          .5768
```

Product 6 (`VIEWED_WITH`) is also connected to product 1 but is the least similar, so it is cut off by `FETCH FIRST 3`.

## Notes

- All of this ran inside **one database** with no data copied: the graph is a *view over the existing tables*, the JSON column is native, and the text index is a standard Oracle Text index.
- Spatial predicates (also mentioned in the article) were not exercised.
