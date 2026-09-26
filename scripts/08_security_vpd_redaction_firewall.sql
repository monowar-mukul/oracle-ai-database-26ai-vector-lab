/* =============================================================================
   LAB 08  |  Security: row filtering, column masking, SQL Firewall
   -----------------------------------------------------------------------------
   Purpose   : Show that users (and therefore AI agents / RAG apps) only see data
               they are authorised to see, even through a vector similarity query,
               and that SQL Firewall blocks unexpected SQL.
   Run as    : Steps are labelled  [VEC_LAB] / [VEC_READER] / [SYS]
   Requires  : Labs 01-02
   Note      : VPD (DBMS_RLS), Data Redaction (DBMS_REDACT) and SQL Firewall are
               established Oracle features. The 26ai point is that they apply to
               AI / vector queries as well. Redaction and firewall availability
               depends on edition and licensing.
   Output    : ../sample_output/08_security_vpd_redaction_firewall.md
   ============================================================================= */

SET DEFINE OFF
SET LINESIZE 200
SET PAGESIZE 100
SET TIMING ON
COLUMN content       FORMAT A25
COLUMN contact_email FORMAT A26
COLUMN dept          FORMAT A6
COLUMN dist          FORMAT 0.0000

/* --------------------------------------------------------------------------
   8.1 [VEC_LAB] Sensitive table that also carries an embedding
   -------------------------------------------------------------------------- */
CREATE TABLE lab_secure_docs (
  id                  NUMBER PRIMARY KEY,
  dept                VARCHAR2(10),
  content             VARCHAR2(200),
  confidential_amount NUMBER,
  contact_email       VARCHAR2(100),
  embedding           VECTOR(3, FLOAT32)
);
INSERT INTO lab_secure_docs VALUES (1, 'PUBLIC', 'Public product FAQ',      1000, 'anna.smith@example.com',  '[0.9,0.1,0.0]');
INSERT INTO lab_secure_docs VALUES (2, 'HR',     'Salary review notes',    95000, 'hr.director@example.com', '[0.8,0.2,0.0]');
INSERT INTO lab_secure_docs VALUES (3, 'PUBLIC', 'Public release notes',    2000, 'bob.jones@example.com',   '[0.7,0.3,0.0]');
INSERT INTO lab_secure_docs VALUES (4, 'FIN',    'Merger planning memo',  500000, 'cfo.office@example.com',  '[0.85,0.1,0.05]');
COMMIT;
GRANT SELECT ON lab_secure_docs TO vec_reader;

/* --------------------------------------------------------------------------
   8.2 [VEC_LAB] ROW-level control (Virtual Private Database)
       VEC_READER may only see rows where dept = 'PUBLIC'. Everyone else: no filter.
   -------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION vpd_dept_fn (p_schema VARCHAR2, p_object VARCHAR2)
RETURN VARCHAR2 AS
BEGIN
  IF SYS_CONTEXT('USERENV', 'SESSION_USER') = 'VEC_READER' THEN
    RETURN 'dept = ''PUBLIC''';      -- predicate silently appended to every SELECT
  END IF;
  RETURN NULL;                       -- NULL = no restriction
END;
/

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema   => 'VEC_LAB',
    object_name     => 'LAB_SECURE_DOCS',
    policy_name     => 'DEPT_POLICY',
    function_schema => 'VEC_LAB',
    policy_function => 'VPD_DEPT_FN',
    statement_types => 'SELECT');
END;
/

/* --------------------------------------------------------------------------
   8.3 [VEC_LAB] COLUMN-level masking (Data Redaction), applied to VEC_READER only
       Needs: GRANT EXECUTE ON DBMS_REDACT and GRANT ADMINISTER REDACTION POLICY (Lab 01)
   -------------------------------------------------------------------------- */
BEGIN
  -- Full redaction of the numeric column (value shows as 0)
  DBMS_REDACT.ADD_POLICY(
    object_schema => 'VEC_LAB',
    object_name   => 'LAB_SECURE_DOCS',
    policy_name   => 'MASK_POLICY',
    column_name   => 'CONFIDENTIAL_AMOUNT',
    function_type => DBMS_REDACT.FULL,
    expression    => 'SYS_CONTEXT(''USERENV'',''SESSION_USER'') = ''VEC_READER''');

  -- Add a second column to the same policy: mask the name part of the e-mail address
  DBMS_REDACT.ALTER_POLICY(
    object_schema         => 'VEC_LAB',
    object_name           => 'LAB_SECURE_DOCS',
    policy_name           => 'MASK_POLICY',
    action                => DBMS_REDACT.ADD_COLUMN,
    column_name           => 'CONTACT_EMAIL',
    function_type         => DBMS_REDACT.REGEXP,
    regexp_pattern        => DBMS_REDACT.RE_PATTERN_EMAIL_ADDRESS,
    regexp_replace_string => DBMS_REDACT.RE_REDACT_EMAIL_NAME);
END;
/

/* --------------------------------------------------------------------------
   8.4 [VEC_LAB] Owner view - EXPECT all 4 rows, real amounts and e-mails
   -------------------------------------------------------------------------- */
SELECT id, dept, confidential_amount, contact_email FROM lab_secure_docs ORDER BY id;

/* --------------------------------------------------------------------------
   8.5 [VEC_READER] The SAME similarity query an AI agent / RAG app would run.
       CONNECT vec_reader/VecRead_2026@//localhost:1521/MORAL
       EXPECT: only ids 1 and 3 (HR and FIN rows filtered out),
               confidential_amount = 0, e-mail name part masked.
       (Not captured in the sample output - see docs/FINDINGS.md)
   -------------------------------------------------------------------------- */
SELECT id, dept, content, confidential_amount, contact_email,
       ROUND(VECTOR_DISTANCE(embedding, TO_VECTOR('[0.9,0.1,0.0]'), COSINE), 4) AS dist
FROM   vec_lab.lab_secure_docs
ORDER  BY dist
FETCH  FIRST 3 ROWS ONLY;

/* --------------------------------------------------------------------------
   8.6 SQL FIREWALL
   -------------------------------------------------------------------------- */
-- [SYS, PDB] switch it on and start recording VEC_READER's normal workload
EXEC DBMS_SQL_FIREWALL.ENABLE;
EXEC DBMS_SQL_FIREWALL.CREATE_CAPTURE(username => 'VEC_READER', top_level_only => TRUE, start_capture => TRUE);

-- [VEC_READER] run the NORMAL application statement while capture is on
--   SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC';

-- [SYS] stop capture, turn the recording into an allow-list, and enforce it (block = TRUE)
EXEC DBMS_SQL_FIREWALL.STOP_CAPTURE('VEC_READER');
EXEC DBMS_SQL_FIREWALL.GENERATE_ALLOW_LIST('VEC_READER');
BEGIN
  DBMS_SQL_FIREWALL.ENABLE_ALLOW_LIST(
    username => 'VEC_READER',
    enforce  => DBMS_SQL_FIREWALL.ENFORCE_ALL,
    block    => TRUE);
END;
/

-- [VEC_READER] (a) the captured statement still works
--   SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC';
-- [VEC_READER] (b) an injection-style variant is BLOCKED -> ORA-47605: SQL Firewall violation
--   SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC' OR 1 = 1;

-- [SYS] review violations. On the reference system this returned "no rows selected" right
-- after the block; violation logging is buffered - flush it first, then query again.
EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;
SELECT * FROM dba_sql_firewall_violations;
