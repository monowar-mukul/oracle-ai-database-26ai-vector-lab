# Lab 08 — Security: row filtering, masking, SQL Firewall

| | |
|---|---|
| **Script** | [`scripts/08_security_vpd_redaction_firewall.sql`](../scripts/08_security_vpd_redaction_firewall.sql) |
| **Run as** | `VEC_LAB`, `VEC_READER`, `SYS` |

## Result summary

| Check | Expected | Observed | Status |
|---|---|---|---|
| VPD row policy created | created | `PL/SQL procedure successfully completed.` | ✅ |
| Redaction policy (amount, e-mail) created | created | created (after `GRANT ADMINISTER REDACTION POLICY`) | ✅ |
| Owner sees everything, unmasked | 4 rows, real values | 4 rows, real values | ✅ |
| **`VEC_READER` sees only PUBLIC rows, masked, through a vector query** | ids 1 & 3, amount 0, e-mail masked | *not captured* — the query in the transcript ran as the **owner** | ⏳ |
| SQL Firewall capture → allow-list → enforce | works | works | ✅ |
| Captured statement still runs | 2 rows | ids 1 and 3 returned | ✅ |
| Injection-style statement blocked | `ORA-47605` | `ORA-47605: SQL Firewall violation` | ✅ |
| Violation listed in `DBA_SQL_FIREWALL_VIOLATIONS` | 1 row | `no rows selected` | ⚠️ (see notes) |

## Captured output

### Privilege needed for redaction

```text
SQL> GRANT EXECUTE ON DBMS_REDACT TO vec_lab;
Grant succeeded.
SQL> GRANT ADMINISTER REDACTION POLICY TO vec_lab;
Grant succeeded.
```

### 8.4 Owner view (`VEC_LAB`) — unrestricted by design

The policies only act on `VEC_READER`, so the owner sees all four rows with real values:

```text
        ID DEPT       CONFIDENTIAL_AMOUNT CONTACT_EMAIL
---------- ---------- ------------------- ------------------------
         1 PUBLIC                    1000 anna.smith@example.com
         2 HR                       95000 hr.director@example.com
         3 PUBLIC                    2000 bob.jones@example.com
         4 FIN                     500000 cfo.office@example.com
```

Owner-side similarity query (no filtering applied to this user):

```text
  ID DEPT   CONTENT               CONFIDENTIAL_AMOUNT CONTACT_EMAIL             DIST
---- ------ --------------------- ------------------- ------------------------ ------
   1 PUBLIC Public product FAQ                   1000 anna.smith@example.com    0
   4 FIN    Merger planning memo               500000 cfo.office@example.com    .0017
   2 HR     Salary review notes                 95000 hr.director@example.com   .009
```

> ⏳ **The `VEC_READER` version of this query is the proof point for "AI agents only see authorised data" and still needs to be captured.** Expected result: ids **1 and 3** only, `CONFIDENTIAL_AMOUNT = 0`, e-mail name part masked. Run the query in script step 8.5 after `CONNECT vec_reader/…` and paste the output here.

### 8.6 SQL Firewall

```text
-- [SYS]
SQL> EXEC DBMS_SQL_FIREWALL.ENABLE;
SQL> EXEC DBMS_SQL_FIREWALL.CREATE_CAPTURE(username => 'VEC_READER', top_level_only => TRUE, start_capture => TRUE);

-- [VEC_READER]  while capture is running
SQL> SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC';

        ID CONTENT
---------- --------------------
         1 Public product FAQ
         3 Public release notes

-- [SYS]
SQL> EXEC DBMS_SQL_FIREWALL.STOP_CAPTURE('VEC_READER');
SQL> EXEC DBMS_SQL_FIREWALL.GENERATE_ALLOW_LIST('VEC_READER');
SQL> BEGIN DBMS_SQL_FIREWALL.ENABLE_ALLOW_LIST(username => 'VEC_READER',
  2         enforce => DBMS_SQL_FIREWALL.ENFORCE_ALL, block => TRUE); END;
PL/SQL procedure successfully completed.

-- [VEC_READER]  enforcement is now on
SQL> SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC';        <-- allowed

        ID CONTENT
---------- --------------------
         1 Public product FAQ
         3 Public release notes

SQL> SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC' OR 1 = 1;   <-- injection-style
SELECT id, content FROM vec_lab.lab_secure_docs WHERE dept = 'PUBLIC' OR 1 = 1
                                *   <-- statement rejected
ERROR at line 1:
ORA-47605: SQL Firewall violation

-- [SYS]
SQL> SELECT * FROM dba_sql_firewall_violations;
no rows selected
```

## Notes

- **Blocking works:** the exact captured statement runs, and the same statement with `OR 1 = 1` is stopped inside the database with `ORA-47605`.
- **Violation view was empty** immediately after the block. Violation logging is buffered — run `EXEC DBMS_SQL_FIREWALL.FLUSH_LOGS;` and query again (added to the script). Re-check on your system.
- VPD, Data Redaction and SQL Firewall are long-standing Oracle security features; what this lab demonstrates is that they operate on vector/AI queries against the same tables. Newer declarative security features in 26ai were **not** tested.
