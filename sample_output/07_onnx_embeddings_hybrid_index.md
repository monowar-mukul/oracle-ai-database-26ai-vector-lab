# Lab 07 — In-database ONNX embeddings and hybrid vector index

| | |
|---|---|
| **Script** | [`scripts/07_onnx_embeddings_hybrid_index.sql`](../scripts/07_onnx_embeddings_hybrid_index.sql) |
| **Run as** | `SYS` (directory), then `VEC_LAB` |
| **Model** | `all_MiniLM_L12_v2` (Oracle "augmented" ONNX package, 117 MB zip / 133 MB `.onnx`) |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| Model file present on the DB server | file listed | `all_MiniLM_L12_v2.onnx` 133,322,334 bytes | ✅ |
| `LOAD_ONNX_MODEL` | success | `PL/SQL procedure successfully completed.` | ✅ |
| Model registered | `EMBEDDING` / `ONNX` | `MINILM_L12 │ EMBEDDING │ ONNX` | ✅ |
| Embedding dimension | 384 | **384** | ✅ |
| Semantic ranking of "my queries are running too slowly" | DB-performance rows first | ids **1** (0.324), **3** (0.5443), then 4 (0.919) | ✅ |
| Hybrid vector index created | created | `Index created.` | ✅ |
| `DBMS_HYBRID_VECTOR.SEARCH` returns fused scores | JSON with scores | returned JSON, first hit score 69.12 (output truncated in capture) | ✅ / ⚠️ truncated |

## Captured output

### Model on the server

```text
$ ls -l /opt/oracle/models
-rw-rw-rw-. 1 oracle oracle 133322334 Oct 30  2025 all_MiniLM_L12_v2.onnx
-rw-rw-rw-. 1 oracle oracle     11561 Oct 30  2025 LICENSE_ATTRIBUTION.txt
-rw-rw-rw-. 1 oracle oracle      4232 Oct 30  2025 README-ALL_MINILM_L12_V2-augmented.txt
```

### Directory, load and verify

```text
SQL> CREATE OR REPLACE DIRECTORY MODEL_DIR AS '/opt/oracle/models';
Directory created.
SQL> GRANT READ ON DIRECTORY MODEL_DIR TO vec_lab;
Grant succeeded.

SQL> BEGIN
  2    DBMS_VECTOR.LOAD_ONNX_MODEL(directory => 'MODEL_DIR', file_name => 'all_MiniLM_L12_v2.onnx', model_name => 'MINILM_L12');
  3  END;
  4  /
PL/SQL procedure successfully completed.

SQL> SELECT model_name, mining_function, algorithm FROM user_mining_models;

MODEL_NAME       MINING_FUNCTION  ALGORITHM
---------------- ---------------- ----------
MINILM_L12       EMBEDDING        ONNX

SQL> SELECT VECTOR_DIMENSION_COUNT(VECTOR_EMBEDDING(MINILM_L12 USING 'hello oracle' AS data)) AS dims FROM dual;

      DIMS
----------
       384
```

### Semantic search on real text

```text
SQL> UPDATE lab_articles SET embedding = VECTOR_EMBEDDING(MINILM_L12 USING text AS data);
5 rows updated.

SQL> SELECT id, text, ROUND(VECTOR_DISTANCE(embedding,
  2         VECTOR_EMBEDDING(MINILM_L12 USING 'my queries are running too slowly' AS data), COSINE), 4) AS dist
  3  FROM lab_articles ORDER BY dist FETCH FIRST 3 ROWS ONLY;

  ID TEXT                                                                    DIST
---- ---------------------------------------------------------------------- ------
   1 How to speed up a slow SQL query using indexes and execution plans       .324
   3 Tuning database performance with statistics and optimizer hints         .5443
   4 Best hiking trails and camping gear for the summer season                .919
```

Row 3 shares no words with the query, and row 1 shares only related word forms (*slow*/*slowly*, *query*/*queries*), yet both rank first — this is semantic, not exact keyword, matching.

### Hybrid vector index and hybrid search

```text
SQL> BEGIN
  2    DBMS_VECTOR_CHAIN.CREATE_PREFERENCE('LAB_VECTORIZER', DBMS_VECTOR_CHAIN.VECTORIZER,
  3      JSON('{ "vector_idxtype":"ivf", "distance":"cosine", "accuracy":95, "model":"MINILM_L12",
  4              "by":"words", "max":100, "overlap":0, "split":"recursively" }'));
  5  END;
  6  /
PL/SQL procedure successfully completed.

SQL> CREATE HYBRID VECTOR INDEX lab_articles_hvi ON lab_articles (text)
  2    PARAMETERS ('VECTORIZER LAB_VECTORIZER');
Index created.

SQL> SELECT JSON_SERIALIZE(DBMS_HYBRID_VECTOR.SEARCH(JSON('{ "hybrid_index_name":"lab_articles_hvi", ... }'))
  2         RETURNING CLOB PRETTY) AS result FROM dual;

RESULT
--------------------------------------------------------------------------------
[
  {
    "rowid" : "AAARyVAAAAAAIeEAAA",
    "score" : 69.12,
    "vector_score  ...                                    <-- truncated in the captured transcript
```

## Notes

- **No external service, network call or API key** was used: the model runs inside the database process.
- The hybrid-search JSON was cut off in the transcript. Re-run with `SET LONG 100000` and `SET PAGESIZE 0` to capture the full result (`vector_score`, `text_score`, `chunk_text`).
- The downloaded model is subject to its own licence — see `LICENSE_ATTRIBUTION.txt` shipped in the zip. It is **not** included in this repository.
