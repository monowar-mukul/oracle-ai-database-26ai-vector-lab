/* =============================================================================
   LAB 01  |  Environment setup: vector memory, lab users, grants
   -----------------------------------------------------------------------------
   Purpose   : Enable the Vector Memory Pool (needed for HNSW indexes) and create
               the two lab users.
   Run as    : PART A -> SYS in CDB$ROOT
               PART B -> SYS in your PDB
   Requires  : Oracle AI Database 26ai (multitenant)
   Output    : ../sample_output/01_setup_users_and_memory.md
   SECURITY  : The passwords below are DEMO values for a throw-away lab.
               Change them, and never reuse real passwords in scripts.
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET TIMING ON

/* ---------------------------------------------------------------------------
   PART A - Vector memory pool  (run in CDB$ROOT)
   --------------------------------------------------------------------------- */
-- A.1  Connect to the root and confirm
--   sqlplus / as sysdba
SHOW CON_NAME
SHOW PARAMETER vector_memory_size      -- default is 0 = HNSW indexes disabled

-- A.2  Size the pool (static parameter -> SPFILE + restart)
ALTER SYSTEM SET vector_memory_size = 512M SCOPE = SPFILE;

-- A.3  Restart the instance
--   SHUTDOWN IMMEDIATE          <- note: "SHUT IMME" is rejected (SP2-0717)
--   STARTUP
--   The startup banner should now include:  Vector Memory Area   536870912 bytes

-- A.4  PDBs are left MOUNTED after a plain STARTUP on some systems. Open them and
--      save their state so they open automatically next time.
ALTER PLUGGABLE DATABASE ALL OPEN;
ALTER PLUGGABLE DATABASE ALL SAVE STATE;

/* ---------------------------------------------------------------------------
   PART B - Lab users and grants  (run in the PDB)
   --------------------------------------------------------------------------- */
-- B.1  Switch to your PDB (replace MORAL with your PDB name)
ALTER SESSION SET CONTAINER = MORAL;
SHOW CON_NAME
SHOW PARAMETER vector_memory_size      -- expect 512M

-- B.2  Owner of all lab objects
CREATE USER vec_lab IDENTIFIED BY VecLab_2026 QUOTA UNLIMITED ON users;
GRANT DB_DEVELOPER_ROLE TO vec_lab;
GRANT CREATE MLE, CREATE PROPERTY GRAPH, CREATE MINING MODEL, CTXAPP TO vec_lab;
GRANT EXECUTE ON JAVASCRIPT TO vec_lab;              -- MLE / JavaScript (Lab 05)
GRANT EXECUTE ON SYS.DBMS_REDACT TO vec_lab;         -- masking (Lab 08)
GRANT EXECUTE ON SYS.DBMS_RLS    TO vec_lab;         -- row-level security (Lab 08)
GRANT ADMINISTER REDACTION POLICY TO vec_lab;        -- needed to create redaction policies

-- B.3  Dictionary access so vec_lab can inspect vector indexes and memory.
--      (On this release the fixed view V$VECTOR_INDEX is NOT exposed to ordinary users;
--       VECSYS.VECTOR$INDEX is used instead. Granting on V$ views directly fails with
--       ORA-02030 - grant on the underlying V_$ view.)
GRANT EXECUTE ON SYS.DBMS_VECTOR                 TO vec_lab;
GRANT SELECT  ON VECSYS.VECTOR$INDEX             TO vec_lab;
GRANT SELECT  ON SYS.V_$VECTOR_MEMORY_POOL       TO vec_lab;

-- B.4  Low-privilege user used to show security controls (Lab 08)
CREATE USER vec_reader IDENTIFIED BY VecRead_2026;
GRANT CREATE SESSION TO vec_reader;

-- B.5  Smoke test - connect as vec_lab and read the pool
--   CONNECT vec_lab/VecLab_2026@//localhost:1521/MORAL
--   SELECT con_id, pool, alloc_bytes/1024/1024 AS alloc_mb, used_bytes/1024/1024 AS used_mb
--   FROM   v$vector_memory_pool ORDER BY con_id, pool;
