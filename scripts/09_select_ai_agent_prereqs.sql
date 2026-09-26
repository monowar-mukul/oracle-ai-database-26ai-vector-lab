/* =============================================================================
   LAB 09  |  Select AI Agent prerequisites (on-premises 26ai)  -  PARTIAL
   -----------------------------------------------------------------------------
   Purpose   : Check that the Select AI packages exist, grant access, open the
               network to the AI provider and store the provider credential.
   Status    : Prerequisites verified. The profile / agent / team objects (9.5)
               were NOT executed on the reference system.
   Run as    : STEPS 9.1-9.3 -> SYS (PDB)     STEPS 9.4+ -> VEC_LAB
   Article   : "Select AI Agent lets you define, run and govern AI agents"
   Output    : ../sample_output/09_select_ai_agent_prereqs.md
   SECURITY  : NEVER paste an API key into a script or a transcript. The key below is
               read with ACCEPT ... HIDE so it is not echoed. If a key was ever pasted
               into a file, chat or Git history, REVOKE it at the provider immediately.
   ============================================================================= */

SET LINESIZE 200
SET PAGESIZE 100
COLUMN owner       FORMAT A20
COLUMN object_name FORMAT A22

-- 9.1 [SYS] Are the packages installed and VALID?
--     Reference system: DBMS_CLOUD, DBMS_CLOUD_AI and DBMS_CLOUD_AI_AGENT all VALID
--     (owner C##CLOUD$SERVICE, public synonyms present).
SELECT owner, object_name, status
FROM   dba_objects
WHERE  object_name IN ('DBMS_CLOUD', 'DBMS_CLOUD_AI', 'DBMS_CLOUD_AI_AGENT')
ORDER  BY object_name, owner;

-- 9.2 [SYS] Grant package access to the lab user
GRANT EXECUTE ON DBMS_CLOUD          TO vec_lab;
GRANT EXECUTE ON DBMS_CLOUD_AI       TO vec_lab;
GRANT EXECUTE ON DBMS_CLOUD_AI_AGENT TO vec_lab;

-- 9.3 [SYS] Allow outbound HTTPS to the AI provider (host must match your provider)
BEGIN
  DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
    host => 'api.openai.com',
    ace  => xs$ace_type(
              privilege_list => xs$name_list('http'),
              principal_name => 'VEC_LAB',
              principal_type => xs_acl.ptype_db));
END;
/
-- Lets the DBMS_CLOUD owner act on behalf of VEC_LAB when it stores credentials
GRANT INHERIT PRIVILEGES ON USER VEC_LAB TO C##CLOUD$SERVICE;

-- 9.4 [VEC_LAB] Store the provider credential. The key is typed at the prompt (hidden).
SET DEFINE ON
ACCEPT ai_key CHAR PROMPT 'Enter AI provider API key: ' HIDE
BEGIN
  DBMS_CLOUD.CREATE_CREDENTIAL(
    credential_name => 'AI_CRED',
    username        => 'AI_USER',          -- any label; the API key is the "password"
    password        => '&ai_key');
END;
/
SET DEFINE OFF

/* ---------------------------------------------------------------------------
   9.5 [VEC_LAB] Profile -> agent -> task -> team -> run   (NOT EXECUTED)
       Attribute names follow Oracle's "Getting Started with Select AI Agent";
       confirm them against the documentation for your exact release before running.
   --------------------------------------------------------------------------- */
/*
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'LAB_AI',
    attributes   => '{"provider":"openai","credential_name":"AI_CRED",
                      "object_list":[{"owner":"VEC_LAB","name":"LAB_PRODUCTS"}]}');

  DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
    agent_name => 'PRODUCT_AGENT',
    attributes => '{"profile_name":"LAB_AI","role":"You answer product questions using the database."}');

  DBMS_CLOUD_AI_AGENT.CREATE_TASK(
    task_name  => 'PRODUCT_TASK',
    attributes => '{"instruction":"Answer the user request about products: {query}"}');

  DBMS_CLOUD_AI_AGENT.CREATE_TEAM(
    team_name  => 'PRODUCT_TEAM',
    attributes => '{"agents":[{"name":"PRODUCT_AGENT","task":"PRODUCT_TASK"}],"process":"sequential"}');
END;
/
EXEC DBMS_CLOUD_AI_AGENT.SET_TEAM('PRODUCT_TEAM');
SELECT AI AGENT which outdoor products cost less than 200;
*/

-- 9.6 Session encryption check (shows what the current connection uses).
--     On the reference system only "TCP/IP NT Protocol Adapter" was listed, i.e. no TLS or
--     native encryption was active - so this lab does NOT demonstrate quantum-resistant
--     (ML-KEM) transport. That needs a TLS-enabled listener plus packet-level verification.
SELECT network_service_banner
FROM   v$session_connect_info
WHERE  sid = SYS_CONTEXT('USERENV', 'SID');
