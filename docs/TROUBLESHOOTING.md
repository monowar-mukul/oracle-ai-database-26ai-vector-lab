# Troubleshooting — errors seen while building this lab

| Error | Cause | Fix |
|---|---|---|
| `SP2-0717: illegal SHUTDOWN option` | Abbreviated `SHUT IMME` | Type `SHUTDOWN IMMEDIATE` |
| `ORA-00922: missing or invalid option` on `alter pluggable database X read write` | Wrong syntax | `ALTER PLUGGABLE DATABASE X OPEN READ WRITE;` |
| PDB shows `MOUNTED` after restart | Saved state not set | `ALTER PLUGGABLE DATABASE ALL OPEN; ALTER PLUGGABLE DATABASE ALL SAVE STATE;` |
| HNSW `CREATE VECTOR INDEX` fails / no memory | `vector_memory_size` is 0 | Set it in `CDB$ROOT` with `SCOPE=SPFILE` and restart (Lab 01) |
| `ORA-02030: can only select from fixed tables/views` on `GRANT SELECT ON V$…` | You cannot grant on a `V$` synonym | Grant on the underlying `SYS.V_$…` view |
| `ORA-00942 … "SYS"."V_$VECTOR_INDEX" does not exist` | View not available on this release | Query `VECSYS.VECTOR$INDEX` (grant `SELECT` to your user) |
| `ORA-00904: "IDX_OWNER": invalid identifier` | Column is `IDX_OWNER#` (with a hash) | Use `IDX_OWNER#` |
| `ORA-01749: Cannot GRANT or REVOKE privileges to or from yourself` | Grant script run as `VEC_LAB` instead of `SYS` | Run grants as `SYS` in the PDB |
| Statements run together: `ORA-03405: End of query reached; no additional text should follow` | Two statements pasted on one line | End each with `;` and a newline, or run separately |
| Custom-distance index takes ~2 min for 2,000 rows | JavaScript call per distance computation | Use fewer rows for demos, or a built-in metric |
| `ORA-47605: SQL Firewall violation` | **Expected** — the statement is not in the allow-list | That is the feature working |
| `DBA_SQL_FIREWALL_VIOLATIONS` empty right after a block | Log buffering | `EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;` then query again |
| Hybrid-search JSON cut off | `LONG` / `PAGESIZE` too small | `SET LONG 100000`, `SET PAGESIZE 0` |
| SQL*Plus terminates a statement early inside a JavaScript function | Blank line inside `{{ … }}` | Remove blank lines in the function body |
| Passwords or keys containing `#`, `&`, `!` misbehave | Shell / SQL*Plus special characters | Quote them in the shell (`'pwd'`) and use `SET DEFINE OFF` in SQL*Plus |
| `ORA-01940: cannot drop a user who is currently connected` | A session for that user is still open (e.g. a leftover `VEC_READER` terminal) | Close the session, or `ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;`, then repeat `DROP USER` |
| `ORA-20401: Authorization failed for URI` from `DBMS_CLOUD_AI` / `SELECT AI AGENT` | Reproduced across three providers (OpenAI, Anthropic, Groq) even with a wallet, ACLs, grants and a valid key all confirmed correct | Not resolved in this test. Next to try: confirm the provider key is in the correct format (an Anthropic key must start `sk-ant-…`, not `sk-proj-…`), check for a required outbound proxy, and compare `DBMS_CLOUD.SEND_REQUEST` directly against `curl` from the same host |
