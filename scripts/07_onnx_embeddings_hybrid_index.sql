/* =============================================================================
   LAB 07  |  In-database ONNX embeddings + hybrid vector index
   -----------------------------------------------------------------------------
   Purpose   : Load an ONNX embedding model INTO the database, generate embeddings
               with SQL (no external API), and combine keyword + semantic search
               in one hybrid vector index.
   Run as    : STEP 7.1 -> SYS (PDB)     STEPS 7.3+ -> VEC_LAB
   Requires  : Lab 01, an ONNX model file on the database server
   Model     : all_MiniLM_L12_v2 (384 dimensions), Oracle's pre-built "augmented" package.
               Download it from Oracle's "pre-trained embedding models" page
               (search that phrase on oracle.com), then unzip on the DB server.
   Article   : "ONNX embedding models ... run inside the database"
   Output    : ../sample_output/07_onnx_embeddings_hybrid_index.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 300
SET PAGESIZE 100
SET LONG 100000
SET TIMING ON
COLUMN text FORMAT A100

-- 7.1  (SYS, PDB) Directory pointing at the unzipped model file
--      OS side:  mkdir -p /opt/oracle/models  &&  unzip all_MiniLM_L12_v2_augmented.zip -d /opt/oracle/models
--                (the .onnx file must be readable by the oracle OS user)
CREATE OR REPLACE DIRECTORY MODEL_DIR AS '/opt/oracle/models';
GRANT READ ON DIRECTORY MODEL_DIR TO vec_lab;

-- 7.2  Reconnect as VEC_LAB
--   CONNECT vec_lab/VecLab_2026@//localhost:1521/MORAL

-- 7.3  Load the model into the database (metadata is embedded in the "augmented" file)
BEGIN
  DBMS_VECTOR.LOAD_ONNX_MODEL(
    directory  => 'MODEL_DIR',
    file_name  => 'all_MiniLM_L12_v2.onnx',
    model_name => 'MINILM_L12');
END;
/

-- 7.4  Confirm: MINING_FUNCTION = EMBEDDING, ALGORITHM = ONNX
SELECT model_name, mining_function, algorithm FROM user_mining_models;

-- 7.5  Generate an embedding with SQL. EXPECT 384 dimensions.
SELECT VECTOR_DIMENSION_COUNT(VECTOR_EMBEDDING(MINILM_L12 USING 'hello oracle' AS data)) AS dims
FROM   dual;

-- 7.6  Semantic search over real text
CREATE TABLE lab_articles (
  id        NUMBER PRIMARY KEY,
  text      VARCHAR2(1000),
  embedding VECTOR(384, FLOAT32)
);
INSERT INTO lab_articles (id, text) VALUES (1, 'How to speed up a slow SQL query using indexes and execution plans');
INSERT INTO lab_articles (id, text) VALUES (2, 'A beginner recipe for baking sourdough bread at home');
INSERT INTO lab_articles (id, text) VALUES (3, 'Tuning database performance with statistics and optimizer hints');
INSERT INTO lab_articles (id, text) VALUES (4, 'Best hiking trails and camping gear for the summer season');
INSERT INTO lab_articles (id, text) VALUES (5, 'Backup and recovery strategy with RMAN for Oracle databases');

-- Embed every row using the in-database model
UPDATE lab_articles SET embedding = VECTOR_EMBEDDING(MINILM_L12 USING text AS data);
COMMIT;

-- Row 3 shares no words with the query text, row 1 only related word forms, yet both rank first.
SELECT id, text,
       ROUND(VECTOR_DISTANCE(embedding,
             VECTOR_EMBEDDING(MINILM_L12 USING 'my queries are running too slowly' AS data), COSINE), 4) AS dist
FROM   lab_articles
ORDER  BY dist
FETCH  FIRST 3 ROWS ONLY;

-- 7.7  Hybrid vector index = keyword (Oracle Text) + semantic (vector) in one index
BEGIN
  DBMS_VECTOR_CHAIN.CREATE_PREFERENCE(
    'LAB_VECTORIZER',
    DBMS_VECTOR_CHAIN.VECTORIZER,
    JSON('{ "vector_idxtype":"ivf", "distance":"cosine", "accuracy":95,
            "model":"MINILM_L12", "by":"words", "max":100, "overlap":0, "split":"recursively" }'));
END;
/

CREATE HYBRID VECTOR INDEX lab_articles_hvi ON lab_articles (text)
  PARAMETERS ('VECTORIZER LAB_VECTORIZER');

-- 7.8  Hybrid query. search_fusion: UNION = either signal, INTERSECT = both required.
--      TIP: SET PAGESIZE 0 and SET LONG 100000 so the JSON is not truncated.
SELECT JSON_SERIALIZE(
         DBMS_HYBRID_VECTOR.SEARCH(
           JSON('{ "hybrid_index_name" : "lab_articles_hvi",
                   "vector"            : { "search_text" : "my queries are running too slowly" },
                   "text"              : { "contains"    : "database OR SQL" },
                   "search_fusion"     : "UNION",
                   "return"            : { "values" : ["rowid","score","vector_score","text_score","chunk_text"],
                                           "topN"   : 5 } }'))
         RETURNING CLOB PRETTY) AS result
FROM   dual;
