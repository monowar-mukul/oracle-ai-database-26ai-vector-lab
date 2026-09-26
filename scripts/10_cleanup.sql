/* =============================================================================
   LAB 10  |  Cleanup
   -----------------------------------------------------------------------------
   Run as    : SYS in the PDB
   WARNING   : Drops the lab users and ALL their objects. Read before running.
   ============================================================================= */

SET DEFINE OFF

-- SQL Firewall (only if Lab 08 was run)
EXEC DBMS_SQL_FIREWALL.DISABLE_ALLOW_LIST('VEC_READER');
EXEC DBMS_SQL_FIREWALL.DISABLE;
-- If DROP USER later complains about firewall objects, drop VEC_READER's capture and
-- allow-list with DBMS_SQL_FIREWALL first, then retry.

-- ONNX model and directory (only if Lab 07 was run) - the model is dropped with the user,
-- the directory object is not:
DROP DIRECTORY MODEL_DIR;

-- If you get ORA-01940 (user is connected), close that terminal or kill the session:
--   SELECT sid, serial#, username FROM v$session WHERE username IN ('VEC_READER','VEC_LAB');
--   ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
DROP USER vec_reader CASCADE;
DROP USER vec_lab    CASCADE;

-- Optional: give the memory back (needs CDB$ROOT and a restart)
--   ALTER SYSTEM SET vector_memory_size = 0 SCOPE = SPFILE;

-- Verify (expect no rows):
--   SELECT username FROM dba_users WHERE username IN ('VEC_LAB','VEC_READER');
--   SELECT owner, object_name FROM dba_objects WHERE owner IN ('VEC_LAB','VEC_READER');
