/* =============================================================================
   LAB 04  |  IVF vector index (neighbor partitions, disk based)
   -----------------------------------------------------------------------------
   Purpose   : Create an IVF index, inspect its plan and catalog entry, measure
               recall against exact search, and observe vector-pool impact.
   Run as    : VEC_LAB
   Requires  : Lab 03 (table LAB_BIG)
   Article   : "IVF ... not held in memory, scales beyond RAM"
   Output    : ../sample_output/04_ivf_index.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 100
SET LONG 100000
SET TIMING ON

-- 4.1  Copy the data so HNSW and IVF can be compared on identical rows
CREATE TABLE lab_big_ivf AS SELECT * FROM lab_big;
ALTER TABLE lab_big_ivf ADD PRIMARY KEY (id);

-- 4.2  Vector pool usage BEFORE the IVF index
SELECT pool, alloc_bytes, used_bytes FROM v$vector_memory_pool;

-- 4.3  Create the IVF index (50 centroids / neighbor partitions)
CREATE VECTOR INDEX lab_ivf_idx ON lab_big_ivf (embedding)
  ORGANIZATION NEIGHBOR PARTITIONS
  DISTANCE COSINE
  WITH TARGET ACCURACY 90
  PARAMETERS (TYPE IVF, NEIGHBOR PARTITIONS 50);

-- 4.4  Vector pool usage AFTER.
--      OBSERVED on the reference system: a small increase (~2 MB in the 1 MB pool).
--      The vectors themselves stay on disk; the increase is consistent with cached IVF centroid data.
SELECT pool, alloc_bytes, used_bytes FROM v$vector_memory_pool;

-- 4.5  Execution plan. IVF does NOT show a line named "IVF SCAN": look instead for the
--      centroid tables (..._IVF_FLAT_CENTROIDS / ..._CENTROID_PARTITIONS) driving a
--      NESTED LOOPS into TABLE ACCESS BY USER ROWID on the base table.
EXPLAIN PLAN FOR
SELECT id
FROM   lab_big_ivf
ORDER  BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
FETCH  APPROX FIRST 5 ROWS ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC'));

-- 4.6  Same query on both indexes (SET TIMING ON shows elapsed time).
--      20k rows is far too small for a fair speed comparison - the first run also pays
--      cache warm-up. Repeat with 1M+ rows and run each query several times.
SELECT id FROM lab_big     ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE) FETCH APPROX FIRST 5 ROWS ONLY;
SELECT id FROM lab_big_ivf ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE) FETCH APPROX FIRST 5 ROWS ONLY;

-- 4.7  Index catalog: both indexes side by side
COLUMN idx_name FORMAT A16
COLUMN params   FORMAT A70
SELECT idx_owner#, idx_name,
       JSON_VALUE(idx_params, '$.type') AS idx_type,
       JSON_SERIALIZE(idx_params RETURNING VARCHAR2 PRETTY) AS params
FROM   vecsys.vector$index
ORDER  BY idx_name;

-- 4.8  Recall check: how many of the exact top-10 does the approximate search find?
WITH exact_top AS (
  SELECT id FROM lab_big_ivf
  ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
  FETCH EXACT FIRST 10 ROWS ONLY),
approx_top AS (
  SELECT id FROM lab_big_ivf
  ORDER BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
  FETCH APPROX FIRST 10 ROWS ONLY)
SELECT COUNT(*) AS overlap_out_of_10
FROM   exact_top e JOIN approx_top a ON a.id = e.id;
