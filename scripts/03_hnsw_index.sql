/* =============================================================================
   LAB 03  |  HNSW vector index (in-memory neighbor graph)
   -----------------------------------------------------------------------------
   Purpose   : Create an HNSW index, prove it uses the Vector Memory Pool, prove
               DML is allowed with transactionally consistent results, and inspect
               the on-disk checkpoint used for faster reload after restart.
   Run as    : VEC_LAB  (Section 3.9 needs SYS)
   Requires  : Labs 01-02, vector_memory_size > 0
   Article   : "HNSW ... supports DML ... checkpoint-based reload"
   Output    : ../sample_output/03_hnsw_index.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 100
SET LONG 100000
SET TIMING ON
COLUMN idx_name FORMAT A16
COLUMN params   FORMAT A70

-- 3.1  Build a 20,000-row table of random 8-dimension vectors
--      (use 384+ dimensions for realistic memory sizing on a real system)
CREATE TABLE lab_big (
  id        NUMBER PRIMARY KEY,
  grp       NUMBER,
  embedding VECTOR(8, FLOAT32)
);

DECLARE
  v VARCHAR2(400);
BEGIN
  FOR i IN 1 .. 20000 LOOP
    v := '[';
    FOR d IN 1 .. 8 LOOP
      v := v || '0.' || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 10000)), 4, '0')
                     || CASE WHEN d < 8 THEN ',' END;
    END LOOP;
    v := v || ']';
    INSERT INTO lab_big VALUES (i, MOD(i, 10), TO_VECTOR(v));
  END LOOP;
  COMMIT;
END;
/
SELECT COUNT(*) FROM lab_big;                       -- expect 20000

-- 3.2  (Optional baseline) EXACT search with no index = full scan + sort
SELECT id
FROM   lab_big
ORDER  BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
FETCH  EXACT FIRST 5 ROWS ONLY;

-- 3.3  (Optional) Ask Oracle how much vector memory an HNSW index would need
VARIABLE rjson CLOB
BEGIN
  DBMS_VECTOR.INDEX_VECTOR_MEMORY_ADVISOR(
    TABLE_OWNER   => 'VEC_LAB',
    TABLE_NAME    => 'LAB_BIG',
    COLUMN_NAME   => 'EMBEDDING',
    INDEX_TYPE    => 'HNSW',
    RESPONSE_JSON => :rjson);
END;
/
PRINT rjson

-- 3.4  Create the HNSW index
CREATE VECTOR INDEX lab_hnsw_idx ON lab_big (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE COSINE
  WITH TARGET ACCURACY 95
  PARAMETERS (TYPE HNSW, NEIGHBORS 16, EFCONSTRUCTION 200);

-- 3.5  Prove it is an in-memory HNSW index.
--      NOTE: V$VECTOR_INDEX is not available on this release for ordinary users, so the
--      index catalog VECSYS.VECTOR$INDEX and the memory pool view are used instead.
SELECT idx_name,
       JSON_VALUE(idx_params, '$.type')     AS idx_type,
       JSON_VALUE(idx_params, '$.distance') AS distance,
       JSON_SERIALIZE(idx_params RETURNING VARCHAR2 PRETTY) AS params
FROM   vecsys.vector$index
WHERE  idx_name = 'LAB_HNSW_IDX';

SELECT pool, alloc_bytes, used_bytes, populate_status FROM v$vector_memory_pool;

-- 3.6  Approximate search + execution plan (look for: VECTOR INDEX HNSW SCAN)
EXPLAIN PLAN FOR
SELECT id
FROM   lab_big
ORDER  BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
FETCH  APPROX FIRST 5 ROWS ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC'));

SELECT id
FROM   lab_big
ORDER  BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
FETCH  APPROX FIRST 5 ROWS ONLY;

/* ---------------------------------------------------------------------------
   3.7  DML on an HNSW-indexed table with transactionally consistent reads
        (26ai behaviour - earlier release updates blocked DML on such tables)

        Needs TWO terminals, both connected as VEC_LAB. Tip: label them
        with   SET SQLPROMPT 'SESSION_A> '   /   SET SQLPROMPT 'SESSION_B> '
   --------------------------------------------------------------------------- */

-- >>> SESSION A: insert a vector identical to the query vector, do NOT commit
INSERT INTO lab_big VALUES (100001, 1, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'));
SELECT id
FROM   lab_big
ORDER  BY VECTOR_DISTANCE(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'), COSINE)
FETCH  APPROX FIRST 1 ROWS ONLY;
--     EXPECT (A): 100001  -> a transaction sees its own uncommitted change through the index

-- >>> SESSION B: run the same query
--     EXPECT (B): 10591 (NOT 100001) -> uncommitted row is invisible to other sessions

-- >>> SESSION A: commit
COMMIT;

-- >>> SESSION B: run the same query again
--     EXPECT (B): 100001 -> committed change is now visible

-- >>> Either session: UPDATE and DELETE work too
UPDATE lab_big SET embedding = TO_VECTOR('[0.9,0.9,0.9,0.9,0.9,0.9,0.9,0.9]') WHERE id = 100001;
DELETE FROM lab_big WHERE id = 100001;
COMMIT;

/* ---------------------------------------------------------------------------
   3.8  Checkpoint (faster reload after instance restart)
   --------------------------------------------------------------------------- */
-- Checkpointing is on by default; this makes it explicit (arguments: owner, index name)
EXEC DBMS_VECTOR.ENABLE_CHECKPOINT('VEC_LAB', 'LAB_HNSW_IDX');

-- A checkpoint is written as part of the next graph refresh - force one
EXEC DBMS_VECTOR.REBUILD_INDEX('LAB_HNSW_IDX');

/* ---------------------------------------------------------------------------
   3.9  Inspect the checkpoint  (run as SYS in the PDB)
   --------------------------------------------------------------------------- */
--   SELECT * FROM vecsys.vector$index$checkpoints;
--   EXPECT >= 1 row: CHECKPOINT_ID, CHECKPOINT_SCN, and SPARE2 JSON with "num_vectors":20000

/* ---------------------------------------------------------------------------
   3.10 Restart test (optional, not captured in the sample output)
   --------------------------------------------------------------------------- */
--   1. As SYS in CDB$ROOT:  SHUTDOWN IMMEDIATE / STARTUP  / ALTER PLUGGABLE DATABASE ALL OPEN;
--   2. As VEC_LAB, poll every few seconds until the graph is loaded again:
--        SELECT pool, used_bytes, populate_status FROM v$vector_memory_pool;
--   3. A/B test: DBMS_VECTOR.DISABLE_CHECKPOINT('VEC_LAB','LAB_HNSW_IDX'), REBUILD_INDEX,
--      restart again and compare the reload time. Re-enable afterwards.
