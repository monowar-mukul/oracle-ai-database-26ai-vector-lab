# Lab 09 — Select AI Agent: prerequisites, setup, and a documented failure

| | |
|---|---|
| **Script** | [`scripts/09_select_ai_agent_prereqs.sql`](../scripts/09_select_ai_agent_prereqs.sql) |
| **Run as** | `SYS` (packages, ACLs, TLS wallet), then `VEC_LAB` (credentials, profile, agent) |
| **Captured** | 24 Sep 2026 — Oracle AI Database 26ai Enterprise Edition 23.26.1.0.0 ([environment](../docs/TEST_ENVIRONMENT.md)) |

## Headline result

Every prerequisite succeeded. **The agent call itself did not.** Three unrelated providers (OpenAI, Anthropic, Groq) were configured in turn and every one failed the same way: `ORA-20401: Authorization failed for URI`. This is reported in full because a documented failure, with everything that was checked along the way, is more useful to a reader than a quiet omission — and because it's the honest result of this test.

## Result summary

| Check | Observed | Status |
|---|---|---|
| `DBMS_CLOUD`, `DBMS_CLOUD_AI`, `DBMS_CLOUD_AI_AGENT` present and valid | all `VALID` (owner `C##CLOUD$SERVICE`, public synonyms) | ✅ |
| `EXECUTE` granted to `VEC_LAB` | done | ✅ |
| Network ACL to the AI provider host | `APPEND_HOST_ACE` succeeded | ✅ |
| `GRANT INHERIT PRIVILEGES … TO C##CLOUD$SERVICE` | done | ✅ |
| TLS wallet created, CA bundle loaded, `SSL_WALLET` set | wallet created, 141 certificates loaded, property set and verified | ✅ |
| Instance restarted after wallet configuration | `SHUTDOWN IMMEDIATE` / `STARTUP` completed | ✅ |
| Credential stored (OpenAI) | `CREATE_CREDENTIAL` succeeded, twice (see notes) | ✅ (storage only) |
| Credential stored (Anthropic) | `CREATE_CREDENTIAL` succeeded | ✅ (storage only) |
| Credential stored (Groq) | `CREATE_CREDENTIAL` succeeded | ✅ (storage only) |
| AI profile, agent, task, team created | `CREATE_PROFILE` / `CREATE_AGENT` / `CREATE_TASK` / `CREATE_TEAM` / `SET_TEAM` all `PL/SQL procedure successfully completed.` | ✅ |
| **`SELECT AI AGENT …` (OpenAI profile)** | **`ORA-20053` wrapping `ORA-20401: Authorization failed for URI - bearer://api.openai.com/v1/chat/completions`** | ❌ |
| **`DBMS_CLOUD_AI.GENERATE(...)` (Anthropic profile)** | **`ORA-20401: Authorization failed for URI - https://api.anthropic.com/v1/messages`** | ❌ |
| **`DBMS_CLOUD_AI.GENERATE(...)` (Groq profile)** | **`ORA-20401: Authorization failed for URI - bearer://api.groq.com/openai/v1/chat/completions`** | ❌ |
| API key validity (OpenAI), checked outside the database | confirmed live with `curl`, HTTP 200 and a full model list | ✅ (key was good; the database call still failed) |

## Captured output (secrets redacted)

Every credential value below has been replaced with a placeholder. The real values were live API keys and passwords and were never written to this repository.

### Packages, grants, network ACL

```text
SQL> SELECT owner, object_name, status
  2  FROM   dba_objects
  3  WHERE  object_name IN ('DBMS_CLOUD','DBMS_CLOUD_AI','DBMS_CLOUD_AI_AGENT')
  4  ORDER  BY object_name;

OWNER              OBJECT_NAME            STATUS
------------------ ---------------------- -------
C##CLOUD$SERVICE   DBMS_CLOUD             VALID
PUBLIC             DBMS_CLOUD             VALID
C##CLOUD$SERVICE   DBMS_CLOUD_AI          VALID
PUBLIC             DBMS_CLOUD_AI          VALID
C##CLOUD$SERVICE   DBMS_CLOUD_AI_AGENT    VALID
PUBLIC             DBMS_CLOUD_AI_AGENT    VALID

9 rows selected.

SQL> GRANT EXECUTE ON DBMS_CLOUD TO vec_lab;             Grant succeeded.
SQL> GRANT EXECUTE ON DBMS_CLOUD_AI TO vec_lab;          Grant succeeded.
SQL> GRANT EXECUTE ON DBMS_CLOUD_AI_AGENT TO vec_lab;    Grant succeeded.

SQL> BEGIN
  2    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(host => 'api.openai.com',
  3      ace => xs$ace_type(privilege_list => xs$name_list('http'),
  4                         principal_name => 'VEC_LAB', principal_type => xs_acl.ptype_db));
  5  END;
  6  /
PL/SQL procedure successfully completed.

SQL> GRANT INHERIT PRIVILEGES ON USER VEC_LAB TO C##CLOUD$SERVICE;
Grant succeeded.
```

> Note: the packages showed `VALID` on the very first check of this run, before any install step appears in the transcript — this on-premises 26ai image ships them pre-installed. The `catcon.pl` install steps recorded in the transcript (`catclouduser.sql`, `dbms_cloud_install.sql`) were therefore not needed to make the packages valid; they may still be worth keeping on hand if a future release does *not* ship them pre-installed.

### TLS wallet for outbound HTTPS calls

```text
$ curl -o /tmp/cacert.pem https://curl.se/ca/cacert.pem
100  184k  100  184k    0     0  2305k      0 --:--:-- --:--:-- --:--:-- 2305k

$ mkdir -p /opt/oracle/product/dbwallet
$ orapki wallet create -wallet /opt/oracle/product/dbwallet -pwd ******** -auto_login
Operation is successfully completed.

$ orapki wallet add -wallet /opt/oracle/product/dbwallet -trusted_cert -cert /tmp/cacert.pem -pwd ********
Operation is successfully completed.

$ orapki wallet display -wallet /opt/oracle/product/dbwallet -pwd ********
Trusted Certificates: [141 certificates listed; first shown]
Subject: CN=COMODO ECC Certification Authority,O=COMODO CA Limited,L=Salford,ST=Greater Manchester,C=GB

SQL> ALTER SESSION SET CONTAINER = CDB$ROOT;
SQL> ALTER DATABASE PROPERTY SET ssl_wallet = 'file:/opt/oracle/product/dbwallet';
Database altered.

SQL> SELECT property_name, property_value FROM database_properties WHERE property_name = 'SSL_WALLET';

PROPERTY_NAME     PROPERTY_VALUE
----------------- ---------------------------------------
SSL_WALLET        file:/opt/oracle/product/dbwallet

SQL> SHUTDOWN IMMEDIATE;
SQL> STARTUP;
Database closed. Database dismounted. ORACLE instance shut down.
[instance restarted; database opened]
```

### Credential, profile, agent, task, team — all created successfully

```text
SQL> CONNECT vec_lab/********@//localhost:1521/MORAL
Connected.

SQL> BEGIN
  2    DBMS_CLOUD.CREATE_CREDENTIAL(
  3      credential_name => 'AI_CRED',
  4      username        => 'AI_MMUKUL',
  5      password        => '<REDACTED_OPENAI_API_KEY>');
  6  END;
  7  /
PL/SQL procedure successfully completed.

SQL> BEGIN
  2    DBMS_CLOUD_AI.CREATE_PROFILE(
  3      profile_name => 'LAB_AI',
  4      attributes   => '{"provider":"openai","credential_name":"AI_CRED",
  5                        "object_list":[{"owner":"VEC_LAB","name":"LAB_PRODUCTS"}]}');
  6
  7    DBMS_CLOUD_AI_AGENT.CREATE_AGENT(
  8      agent_name => 'PRODUCT_AGENT',
  9      attributes => '{"profile_name":"LAB_AI","role":"You answer product questions using the database."}');
 10
 11    DBMS_CLOUD_AI_AGENT.CREATE_TASK(
 12      task_name  => 'PRODUCT_TASK',
 13      attributes => '{"instruction":"Answer the user request about products: {query}"}');
 14
 15    DBMS_CLOUD_AI_AGENT.CREATE_TEAM(
 16      team_name  => 'PRODUCT_TEAM',
 17      attributes => '{"agents":[{"name":"PRODUCT_AGENT","task":"PRODUCT_TASK"}],"process":"sequential"}');
 18  END;
 19  /
PL/SQL procedure successfully completed.

SQL> EXEC DBMS_CLOUD_AI_AGENT.SET_TEAM('PRODUCT_TEAM');
PL/SQL procedure successfully completed.
```

Every object needed to run an agent — credential, profile, agent, task, team — was created without error.

### The agent call: same failure, three different providers

```text
-- Provider 1: OpenAI
SQL> SELECT AI AGENT which outdoor products cost less than 200;
SELECT AI AGENT which outdoor products cost less than 200
*
ERROR at line 1:
ORA-20053: Job PRODUCT_TEAM_TASK_0 failed: ORA-20401: Authorization failed for
URI - bearer://api.openai.com/v1/chat/completions
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD", line 2243
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD_AI", line 18323
ORA-06512: at line 1

-- Provider 2: Anthropic (new credential, new profile, same profile object re-pointed)
SQL> BEGIN
  2    DBMS_CLOUD.CREATE_CREDENTIAL(credential_name => 'ANTHROPIC_CRED',
  3      username => 'ANTHROPIC', password => '<REDACTED_KEY_LABELED_ANTHROPIC>');
  4  END;
  5  /
PL/SQL procedure successfully completed.

SQL> BEGIN
  2    DBMS_CLOUD_AI.DROP_PROFILE(profile_name => 'LAB_AI', force => TRUE);
  3    DBMS_CLOUD_AI.CREATE_PROFILE(profile_name => 'LAB_AI',
  4      attributes => '{"provider":"anthropic","credential_name":"ANTHROPIC_CRED",
  5                       "model":"claude-sonnet-5",
  6                       "object_list":[{"owner":"VEC_LAB","name":"LAB_PRODUCTS"}]}');
  7  END;
  8  /
PL/SQL procedure successfully completed.

SQL> EXEC DBMS_CLOUD_AI.SET_PROFILE('LAB_AI');
PL/SQL procedure successfully completed.

SQL> SELECT DBMS_CLOUD_AI.GENERATE(
  2    prompt => 'which outdoor products cost less than 200',
  3    profile_name => 'LAB_AI', action => 'chat') FROM dual;
ERROR:
ORA-20401: Authorization failed for URI - https://api.anthropic.com/v1/messages
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD", line 2243
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD_AI", line 18271
ORA-06512: at line 1

-- Provider 3: Groq
SQL> BEGIN
  2    DBMS_CLOUD.CREATE_CREDENTIAL(credential_name => 'GROQ_CRED',
  3      username => 'GROQ', password => '<REDACTED_GROQ_API_KEY>');
  4  END;
  5  /
PL/SQL procedure successfully completed.

SQL> BEGIN
  2    DBMS_CLOUD_AI.DROP_PROFILE(profile_name => 'LAB_AI', force => TRUE);
  3    DBMS_CLOUD_AI.CREATE_PROFILE(profile_name => 'LAB_AI',
  4      attributes => '{"credential_name":"GROQ_CRED",
  5                       "provider_endpoint":"api.groq.com/openai",
  6                       "model":"openai/gpt-oss-120b",
  7                       "object_list":[{"owner":"VEC_LAB","name":"LAB_PRODUCTS"}]}');
  8  END;
  9  /
PL/SQL procedure successfully completed.

SQL> EXEC DBMS_CLOUD_AI.SET_PROFILE('LAB_AI');
SQL> SELECT DBMS_CLOUD_AI.GENERATE(
  2    prompt => 'which outdoor products cost less than 200',
  3    profile_name => 'LAB_AI', action => 'chat') FROM dual;
ERROR:
ORA-20401: Authorization failed for URI -
bearer://api.groq.com/openai/v1/chat/completions
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD", line 2243
ORA-06512: at "C##CLOUD$SERVICE.DBMS_CLOUD_AI", line 18271
ORA-06512: at line 1
```

### Ruled out during troubleshooting

The following were checked and confirmed correct before this test was recorded as a failure:

- The OpenAI API key itself was valid — confirmed independently with `curl https://api.openai.com/... -H "Authorization: Bearer <key>"`, which returned HTTP 200 and a full model list.
- Credential syntax matched Oracle's documented `DBMS_CLOUD.CREATE_CREDENTIAL` usage.
- The network ACL (`http` privilege) was granted to both `VEC_LAB` and `C##CLOUD$SERVICE` for the target host.
- The wallet ACL (`use_client_certificates`, `use_passwords`) was granted to `C##CLOUD$SERVICE`.
- The TLS wallet held a full CA bundle (141 certificates), and `SSL_WALLET` was set and verified in `database_properties`.
- The TDE keystore was confirmed `OPEN` in both `CDB$ROOT` and the PDB.
- A full instance restart was performed after every configuration change.
- `DBMS_CLOUD` was reinstalled with zero invalid objects.
- The same failure reproduced across three unrelated providers (OpenAI, Anthropic, Groq), and at both the `DBMS_CLOUD_AI` level and the lower-level `DBMS_CLOUD.SEND_REQUEST` level.

## Notes

- **This is a genuine, reproducible blocker, not a one-off typo.** Every documented prerequisite passed, the same credential/profile/agent/task/team pattern is what Oracle's own examples show, and the failure was identical across three unrelated providers. That pattern points at something in this specific on-premises 26ai instance's outbound HTTPS path (proxy, wallet trust chain, or a TLS handshake detail not covered by the checks above) rather than at any one provider or any one key.
- **One inconsistency worth flagging:** the key stored under `ANTHROPIC_CRED` is in the format `sk-proj-…`, which is an OpenAI key format. Genuine Anthropic API keys begin `sk-ant-…`. Whether this was a copy-paste mix-up or a placeholder, it means the Anthropic attempt above was not a clean test of that provider specifically — worth re-running with a verified `sk-ant-…` key before drawing any provider-specific conclusion.
- **Select AI Agent was not demonstrated working in this environment.** Every object that Select AI Agent needs (packages, grants, ACL, wallet, credential, profile, agent, task, team) was built successfully; the agent invocation itself failed every time it was attempted. Treat the feature's behavior as Oracle's documented description until this is resolved and a successful run is captured.
- 🔐 **Security — act on this immediately.** The original session that produced this output contained, in plaintext: two distinct OpenAI API keys, one Anthropic-labeled key, one Groq API key, the wallet password, and the database `SYS` password. None of these appear anywhere in this repository. If you have not already done so:
  1. Revoke/rotate all four API keys at their respective providers (OpenAI ×2, the key stored as `ANTHROPIC_CRED`, and Groq).
  2. Change the `SYS` password and the wallet password.
  3. Treat any copy of the raw session transcript as containing live secrets, and do not commit it to Git, even in a private repository.
