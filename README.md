<div align="center">

# Oracle AI Database 26ai — Vector & AI Feature Lab

**Hands-on SQL scripts and real captured output that test the headline features of Oracle AI Database 26ai**

![Oracle AI Database](https://img.shields.io/badge/Oracle_AI_Database-26ai-F80000?logo=oracle&logoColor=white)
![Release](https://img.shields.io/badge/release-23.26.1-blue)
![Language](https://img.shields.io/badge/language-SQL%20%7C%20PL%2FSQL-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

</div>

---

## Overview

This repository turns the article *"Oracle AI Database 26ai: What IT and Cloud Administrators Actually Need to Know"* into **runnable evidence**. Each lab has

- a heavily commented **SQL script** (`scripts/`) you can run yourself, and
- the **real output** captured from an on-premises 26ai Enterprise Edition system (`sample_output/`), with expected-vs-observed tables.

Where the database behaved differently from what the article or the first draft of the lab predicted, this repo says so ([`docs/FINDINGS.md`](docs/FINDINGS.md)).

## Companion article

This repository backs the blog article **"Oracle AI Database 26ai: What IT and Cloud Administrators Actually Need to Know"**. The article's *Try it* notes link to the labs below, and its closing section lists what was and wasn't verified. A Markdown copy is in [`docs/ARTICLE.md`](docs/ARTICLE.md).

## What was tested

| Lab | Topic | Script | Sample output | Result |
|:--:|---|---|---|:--:|
| 00 | Version and release-update proof | [sql](scripts/00_version_check.sql) | [output](sample_output/00_version_check.md) | ✅ |
| 01 | Vector memory, users, grants | [sql](scripts/01_setup_users_and_memory.sql) | [output](sample_output/01_setup_users_and_memory.md) | ✅ |
| 02 | AI Vector Search basics, distance metrics | [sql](scripts/02_vector_search_basics.sql) | [output](sample_output/02_vector_search_basics.md) | ✅ |
| 03 | **HNSW** index, **DML consistency**, checkpoint | [sql](scripts/03_hnsw_index.sql) | [output](sample_output/03_hnsw_index.md) | ✅ / ⏳ |
| 04 | **IVF** index, recall | [sql](scripts/04_ivf_index.sql) | [output](sample_output/04_ivf_index.md) | ⚠️ |
| 05 | Custom **JavaScript** distance function (MLE) | [sql](scripts/05_custom_distance_mle.sql) | [output](sample_output/05_custom_distance_mle.md) | ✅ |
| 06 | Hybrid search: vector + relational + JSON + text + **graph** | [sql](scripts/06_hybrid_search.sql) | [output](sample_output/06_hybrid_search.md) | ✅ |
| 07 | In-database **ONNX embeddings**, hybrid vector index | [sql](scripts/07_onnx_embeddings_hybrid_index.sql) | [output](sample_output/07_onnx_embeddings_hybrid_index.md) | ✅ |
| 08 | Row filtering, masking, **SQL Firewall** | [sql](scripts/08_security_vpd_redaction_firewall.sql) | [output](sample_output/08_security_vpd_redaction_firewall.md) | ✅ / ⏳ |
| 09 | Select AI Agent: prerequisites, setup, and a documented auth failure | [sql](scripts/09_select_ai_agent_prereqs.sql) | [output](sample_output/09_select_ai_agent_prereqs.md) | ⚠️ |
| 10 | Cleanup | [sql](scripts/10_cleanup.sql) | [output](sample_output/10_cleanup.md) | ✅ |

✅ demonstrated · ⚠️ behaved differently from expectation (documented) · ⏳ partly or not yet captured

## Highlights from the captured run

| | Result |
|---|---|
| 🧬 Product | Oracle AI Database **26ai** Enterprise Edition, **23.26.1.0.0** |
| ⚡ HNSW index | Used by the optimizer (`VECTOR INDEX HNSW SCAN`), ≈ 7 MB of vector memory for 20,000 vectors |
| 🔄 **DML on HNSW table** | Uncommitted row visible only to the writing session; visible to others after `COMMIT` |
| 📦 IVF index | 50 centroids; approximate top-10 matched the exact top-10 for the test query |
| 🧩 Custom metric | JavaScript Chebyshev distance backing an HNSW index (build ≈ 2 min for 2,000 rows) |
| 🔎 Hybrid query | Relational + JSON + full-text + vector in **one** SQL statement; graph traversal ranked by vector similarity |
| 🤖 In-database embeddings | ONNX MiniLM model loaded into the database → 384-dim vectors from plain SQL, no external API |
| 🛡️ SQL Firewall | Injection-style statement blocked with `ORA-47605` |
| ⚠️ Select AI Agent | Every prerequisite succeeded (packages, ACL, TLS wallet, credential, profile, agent, task, team) — but the live agent call failed with `ORA-20401` against all three providers tried (OpenAI, Anthropic, Groq). Full troubleshooting log in Lab 09 |

See [`docs/FINDINGS.md`](docs/FINDINGS.md) for the full claim-by-claim verdict, including what was **not** proven (RAFT, True Cache, ML-KEM) and what was attempted but did not succeed (a live Select AI Agent run — see Lab 09).

## Repository layout

```text
oracle-ai-database-26ai-vector-lab/
├── README.md
├── LICENSE
├── .gitignore
├── .gitattributes
├── docs/
│   ├── ARTICLE.md                # Markdown copy of the companion blog article
│   ├── images/                   # figures used by ARTICLE.md
│   ├── FINDINGS.md               # article claims vs. what the database did
│   ├── TEST_ENVIRONMENT.md       # exact system the outputs came from
│   ├── TROUBLESHOOTING.md        # every error hit while building the labs
│   └── GITHUB_UPLOAD_GUIDE.md    # how to publish this repo
├── scripts/                      # run these, in numeric order
│   ├── 00_version_check.sql
│   ├── 01_setup_users_and_memory.sql
│   ├── 02_vector_search_basics.sql
│   ├── 03_hnsw_index.sql
│   ├── 04_ivf_index.sql
│   ├── 05_custom_distance_mle.sql
│   ├── 06_hybrid_search.sql
│   ├── 07_onnx_embeddings_hybrid_index.sql
│   ├── 08_security_vpd_redaction_firewall.sql
│   ├── 09_select_ai_agent_prereqs.sql
│   └── 10_cleanup.sql
└── sample_output/                # real captured results, one file per lab
    └── 00_… to 10_…  (.md)
```

## Prerequisites

- Oracle AI Database 26ai (release 23.26.x): Enterprise Edition on Linux x86-64, Free, or a cloud service. Some features are edition-dependent.
- Multitenant architecture (the scripts assume a PDB; change `MORAL` to your PDB name).
- `SYS` access to set `vector_memory_size` and create the lab users.
- SQL*Plus or SQLcl. Two terminals are needed for Lab 03's DML test and three roles (`SYS`, `VEC_LAB`, `VEC_READER`) for Lab 08.
- ≈ 512 MB free memory for the Vector Memory Pool.
- Lab 07 only: an ONNX embedding model (not included; see the script header) and OS access to copy it to the server.
- Lab 09 only: an AI provider account and API key.

## Quick start

```bash
# 1. Get the code
git clone https://github.com/YOUR-USER/oracle-ai-database-26ai-vector-lab.git
cd oracle-ai-database-26ai-vector-lab/scripts

# 2. Check the version (as SYS in your PDB)
sqlplus sys@//localhost:1521/YOUR_PDB as sysdba @00_version_check.sql

# 3. One-time setup: open the file and run it in sections
#    (Part A needs CDB$ROOT + an instance restart, Part B runs inside the PDB;
#     edit the PDB name inside the file first)
sqlplus / as sysdba
SQL> -- copy/paste or @-run each part as described in the file header

# 4. Run the labs as the lab user
sqlplus vec_lab/VecLab_2026@//localhost:1521/YOUR_PDB @02_vector_search_basics.sql
sqlplus vec_lab/VecLab_2026@//localhost:1521/YOUR_PDB @03_hnsw_index.sql
# ...and so on in numeric order
```

> The scripts are meant to be **read and run in sections**: several steps need a restart, a second session or a different user, so there is deliberately no single "run everything" file. Each section header tells you who to connect as.

## How to read a sample-output file

Every file in `sample_output/` follows the same layout:

1. **Result summary** — a table of *check · expected · observed · status*.
2. **Captured output** — cleaned-up SQL*Plus output (column layouts tidied, secrets removed, nothing invented).
3. **Notes** — what the result does and does not prove.

## Security notes

- The passwords in the scripts (`VecLab_2026`, `VecRead_2026`) are **demo values for a disposable lab**. Change them.
- **Never commit API keys, wallets or real passwords.** Lab 09 reads the key with `ACCEPT … HIDE`; the repository's `.gitignore` blocks common secret files. The session that produced Lab 09's captured output exposed four live API keys (two OpenAI, one Anthropic-labeled, one Groq) plus the wallet and `SYS` passwords — none of these appear in this repository, and all four keys plus both passwords should be treated as compromised and rotated.
- `SYS`-level steps change instance parameters and create users. Run them on a lab system, not production.
- `10_cleanup.sql` drops the lab users with `CASCADE`.

## Known limitations

- Timings are from a small virtual machine and 20,000 tiny vectors — **not benchmarks**.
- Not demonstrated: 23ai→26ai patch path, HNSW restart-reload timing, the restricted `VEC_READER` query, RAFT / globally distributed database, True Cache, quantum-resistant transport, spatial predicates.
- **Attempted but not achieved:** a live Select AI Agent run. Every prerequisite succeeded; the agent call itself failed with `ORA-20401` against three different providers. See [Lab 09](sample_output/09_select_ai_agent_prereqs.md) for the full troubleshooting log.
- `V$VECTOR_INDEX` was unavailable on the test release; scripts use `VECSYS.VECTOR$INDEX` instead.

## Contributing

Found a different result on your release update? Open an issue or pull request with your `VERSION_FULL`, the statement, and the output.

## License

[MIT](LICENSE). Oracle, Oracle AI Database and related names are trademarks of Oracle Corporation; this project is an independent educational resource and is not affiliated with or endorsed by Oracle. Downloaded models (e.g. all-MiniLM-L12-v2) carry their own licences.
