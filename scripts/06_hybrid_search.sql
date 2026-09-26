/* =============================================================================
   LAB 06  |  Unified hybrid search: vector + relational + JSON + text + graph
   -----------------------------------------------------------------------------
   Purpose   : Combine every predicate type in ONE query against ONE database.
   Run as    : VEC_LAB
   Requires  : Lab 02 (LAB_PRODUCTS), role CTXAPP and CREATE PROPERTY GRAPH (Lab 01)
   Article   : "Unified Hybrid Vector Search"
   Output    : ../sample_output/06_hybrid_search.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 100
SET TIMING ON
COLUMN id          FORMAT 9999
COLUMN name        FORMAT A25
COLUMN color       FORMAT A8
COLUMN relation    FORMAT A14
COLUMN cosine_dist FORMAT 0.0000

-- 6.1  Oracle Text index for keyword search.
--      Create it AFTER loading data (otherwise call CTX_DDL.SYNC_INDEX).
CREATE INDEX lab_products_txt ON lab_products (description) INDEXTYPE IS CTXSYS.CONTEXT;

-- 6.2  FOUR predicate types + vector ranking in one statement:
--        relational  : category = 'OUTDOOR' AND price < 200
--        JSON        : JSON_VALUE(attrs,'$.color') = 'red'
--        full text   : CONTAINS(description,'waterproof')
--        vector      : ORDER BY VECTOR_DISTANCE(...)
--      EXPECT exactly one row: id 1 (Trail Rain Jacket).
SELECT id, name, price,
       JSON_VALUE(attrs, '$.color')                                             AS color,
       ROUND(VECTOR_DISTANCE(embedding, TO_VECTOR('[0.9,0.1,0.0]'), COSINE), 4) AS cosine_dist
FROM   lab_products
WHERE  category = 'OUTDOOR'
AND    price < 200
AND    JSON_VALUE(attrs, '$.color') = 'red'
AND    CONTAINS(description, 'waterproof') > 0
ORDER  BY cosine_dist
FETCH  FIRST 3 ROWS ONLY;

-- 6.3  JSON numeric filter + vector ranking
SELECT id, name, JSON_VALUE(attrs, '$.rating' RETURNING NUMBER) AS rating
FROM   lab_products
WHERE  JSON_VALUE(attrs, '$.rating' RETURNING NUMBER) >= 4.5
ORDER  BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.9,0.1,0.0]'), COSINE)
FETCH  FIRST 3 ROWS ONLY;

-- 6.4  Graph + vector: "products related to product 1, ranked by similarity"
CREATE TABLE lab_related (
  src_id   NUMBER REFERENCES lab_products(id),
  dst_id   NUMBER REFERENCES lab_products(id),
  relation VARCHAR2(20),
  PRIMARY KEY (src_id, dst_id)
);
INSERT INTO lab_related VALUES (1, 2, 'BOUGHT_WITH');
INSERT INTO lab_related VALUES (1, 3, 'BOUGHT_WITH');
INSERT INTO lab_related VALUES (1, 7, 'BOUGHT_WITH');
INSERT INTO lab_related VALUES (1, 6, 'VIEWED_WITH');
COMMIT;

-- SQL property graph over the existing tables (no data is copied)
CREATE PROPERTY GRAPH lab_graph
  VERTEX TABLES (
    lab_products KEY (id) PROPERTIES (id, name)
  )
  EDGE TABLES (
    lab_related
      KEY (src_id, dst_id)
      SOURCE      KEY (src_id) REFERENCES lab_products (id)
      DESTINATION KEY (dst_id) REFERENCES lab_products (id)
      PROPERTIES (relation)
  );

-- Traverse edges from product 1, then rank the neighbours by vector similarity.
-- EXPECT ids 2, 3, 7 (product 6 is cut off by FETCH FIRST 3).
SELECT p.id, p.name, g.relation,
       ROUND(VECTOR_DISTANCE(p.embedding, TO_VECTOR('[0.9,0.1,0.0]'), COSINE), 4) AS cosine_dist
FROM   GRAPH_TABLE (lab_graph
         MATCH (a) -[e]-> (b)
         WHERE a.id = 1
         COLUMNS (b.id AS related_id, e.relation AS relation)
       ) g
JOIN   lab_products p ON p.id = g.related_id
ORDER  BY cosine_dist
FETCH  FIRST 3 ROWS ONLY;

-- 6.5  Spatial predicates follow the same pattern (SDO_GEOMETRY column + spatial index +
--      SDO_WITHIN_DISTANCE in the WHERE clause). Not scripted: it needs spatial metadata
--      specific to your data.
