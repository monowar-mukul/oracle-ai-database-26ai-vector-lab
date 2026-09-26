/* =============================================================================
   LAB 05  |  Custom vector distance function in JavaScript (MLE)
   -----------------------------------------------------------------------------
   Purpose   : Write a Chebyshev distance in JavaScript, use it in SQL, and back an
               HNSW index with it.
   Run as    : VEC_LAB
   Requires  : Lab 03 (LAB_BIG), GRANT EXECUTE ON JAVASCRIPT (Lab 01)
   Rules     : function takes exactly two VECTOR args, returns BINARY_DOUBLE, is
               DETERMINISTIC, and must be declared PURE to back an HNSW index.
   Article   : "Custom vector distance functions written in JavaScript"
   Output    : ../sample_output/05_custom_distance_mle.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 100
SET TIMING ON
COLUMN chebyshev FORMAT 999.9999

-- 5.1  Chebyshev distance = the largest absolute difference across dimensions.
--      Do not put blank lines inside the {{ ... }} block (SQL*Plus would end the statement).
CREATE OR REPLACE FUNCTION chebyshev_vector_distance("a" VECTOR, "b" VECTOR)
RETURN BINARY_DOUBLE
DETERMINISTIC PARALLEL_ENABLE
AS MLE LANGUAGE JAVASCRIPT PURE
{{
  let max = 0;
  for (let i = 0; i < a.length; i++) {
    const d = Math.abs(a[i] - b[i]);
    if (d > max) max = d;
  }
  return max;
}};
/

-- 5.2  Unit test. EXPECT 3 : |1-4|=3, |2-5|=3, |3-1|=2 -> max = 3
SELECT chebyshev_vector_distance(TO_VECTOR('[1,2,3]'), TO_VECTOR('[4,5,1]')) AS chebyshev FROM dual;

-- 5.3  Use it like any built-in metric
SELECT id, name,
       ROUND(chebyshev_vector_distance(embedding, TO_VECTOR('[0.9,0.1,0.0]')), 4) AS cheb
FROM   lab_products
ORDER  BY cheb
FETCH  FIRST 3 ROWS ONLY;

-- 5.4  Back an HNSW index with it.
--      WARNING: JavaScript distance calls are much slower than built-in metrics. On the
--      reference system building this index over 2,000 rows took about 1 min 55 s.
--      Use fewer rows (e.g. id <= 500) for a quicker demo.
--      Run each statement separately - pasting two statements together gives ORA-03405.
CREATE TABLE lab_custom AS SELECT * FROM lab_big WHERE id <= 2000;

CREATE VECTOR INDEX lab_cheb_idx ON lab_custom (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE CUSTOM chebyshev_vector_distance;

ALTER TABLE lab_custom ADD PRIMARY KEY (id);

-- 5.5  EXPECT plan line: VECTOR INDEX HNSW SCAN | LAB_CHEB_IDX
EXPLAIN PLAN FOR
SELECT id
FROM   lab_custom
ORDER  BY chebyshev_vector_distance(embedding, TO_VECTOR('[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]'))
FETCH  APPROX FIRST 5 ROWS ONLY;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC'));

-- 5.6  Negative test (optional - not captured in the sample output):
--      the same function WITHOUT the PURE keyword must be rejected for an HNSW index.
--      EXPECT an ORA- error saying the function must be PURE.
CREATE OR REPLACE FUNCTION cheb_not_pure("a" VECTOR, "b" VECTOR)
RETURN BINARY_DOUBLE
DETERMINISTIC PARALLEL_ENABLE
AS MLE LANGUAGE JAVASCRIPT
{{
  let max = 0;
  for (let i = 0; i < a.length; i++) { max = Math.max(max, Math.abs(a[i] - b[i])); }
  return max;
}};
/

CREATE VECTOR INDEX lab_cheb_bad_idx ON lab_custom (embedding)
  ORGANIZATION INMEMORY NEIGHBOR GRAPH
  DISTANCE CUSTOM cheb_not_pure;
