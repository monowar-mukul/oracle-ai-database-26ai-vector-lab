/* =============================================================================
   LAB 02  |  AI Vector Search basics
   -----------------------------------------------------------------------------
   Purpose   : Store vectors next to relational + JSON data and run similarity
               queries with every distance metric. Uses tiny 3-D vectors so the
               maths can be checked by eye:
                   x-axis ~ "outdoor"   y-axis ~ "kitchen"   z-axis ~ "electronics"
   Run as    : VEC_LAB
   Requires  : Lab 01
   Article   : "AI Vector Search, built in - no separate vector database"
   Output    : ../sample_output/02_vector_search_basics.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 50
SET TIMING ON
COLUMN id          FORMAT 9999
COLUMN name        FORMAT A25
COLUMN category    FORMAT A15
COLUMN cosine_dist FORMAT 0.0000
COLUMN euclid      FORMAT 0.0000
COLUMN neg_dot     FORMAT 0.0000

-- 2.1  One table holding relational, JSON, text and VECTOR columns
CREATE TABLE lab_products (
  id          NUMBER        PRIMARY KEY,
  name        VARCHAR2(60)  NOT NULL,
  category    VARCHAR2(20)  NOT NULL,
  price       NUMBER(8,2),
  attrs       JSON,                       -- native JSON type
  description VARCHAR2(400),
  embedding   VECTOR(3, FLOAT32)          -- 3 dimensions, 32-bit floats
);

INSERT INTO lab_products VALUES (1, 'Trail Rain Jacket', 'OUTDOOR',     129.00, JSON('{"color":"red","rating":4.6}'),    'Lightweight waterproof jacket for hiking',         '[0.95,0.05,0.00]');
INSERT INTO lab_products VALUES (2, 'Alpine Tent 2P',    'OUTDOOR',     349.00, JSON('{"color":"green","rating":4.8}'),  'Two person waterproof tent for camping',           '[0.90,0.10,0.05]');
INSERT INTO lab_products VALUES (3, 'Summit Backpack',   'OUTDOOR',     159.00, JSON('{"color":"red","rating":4.2}'),    'Durable hiking backpack with rain cover',          '[0.85,0.05,0.10]');
INSERT INTO lab_products VALUES (4, 'Chef Knife 8in',    'KITCHEN',      89.00, JSON('{"color":"silver","rating":4.9}'), 'Forged steel kitchen knife for daily cooking',     '[0.05,0.95,0.00]');
INSERT INTO lab_products VALUES (5, 'Cast Iron Skillet', 'KITCHEN',      45.00, JSON('{"color":"black","rating":4.7}'),  'Heavy skillet for searing and baking',             '[0.10,0.90,0.05]');
INSERT INTO lab_products VALUES (6, 'Noise Cancel Buds', 'ELECTRONICS', 199.00, JSON('{"color":"white","rating":4.4}'),  'Wireless earbuds with active noise cancelling',   '[0.00,0.05,0.95]');
INSERT INTO lab_products VALUES (7, 'Trail GPS Watch',   'ELECTRONICS', 249.00, JSON('{"color":"red","rating":4.5}'),    'Rugged waterproof GPS watch for runners',          '[0.40,0.00,0.85]');
INSERT INTO lab_products VALUES (8, 'Espresso Machine',  'KITCHEN',     399.00, JSON('{"color":"black","rating":4.3}'),  'Semi automatic espresso machine for the kitchen', '[0.00,0.80,0.40]');
COMMIT;

-- 2.2  Similarity search: "products like outdoor gear" (query vector = mostly x-axis)
--      EXPECT: ids 2, 1, 3 (all OUTDOOR) closest, then 7.
SELECT id, name, category,
       ROUND(VECTOR_DISTANCE(embedding, TO_VECTOR('[0.9,0.1,0.0]'), COSINE), 4) AS cosine_dist
FROM   lab_products
ORDER  BY cosine_dist
FETCH  FIRST 4 ROWS ONLY;

-- 2.3  Other distance metrics (EUCLIDEAN, DOT = negative dot product)
SELECT id, name,
       ROUND(VECTOR_DISTANCE(embedding, TO_VECTOR('[0.9,0.1,0.0]'), EUCLIDEAN), 4) AS euclid,
       ROUND(VECTOR_DISTANCE(embedding, TO_VECTOR('[0.9,0.1,0.0]'), DOT), 4)       AS neg_dot
FROM   lab_products
ORDER  BY euclid
FETCH  FIRST 4 ROWS ONLY;

-- 2.4  Shorthand distance operator  <=>  (cosine).  Also available: <-> and <#>
SELECT id, name, embedding <=> TO_VECTOR('[0.9,0.1,0.0]') AS cosine_dist
FROM   lab_products
ORDER  BY cosine_dist
FETCH  FIRST 3 ROWS ONLY;

-- 2.5  Vector utility functions
SELECT id, VECTOR_DIMENSION_COUNT(embedding) AS dims,
       ROUND(VECTOR_NORM(embedding), 4)      AS norm
FROM   lab_products
WHERE  id <= 3;
