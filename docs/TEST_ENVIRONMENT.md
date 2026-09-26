# Test environment

All sample outputs in this repository were captured on the system below on **24 September 2026**.

| Item | Value |
|---|---|
| Database | Oracle AI Database 26ai **Enterprise Edition**, Release 23.26.1.0.0 |
| Release update | RU 23.26.1.0.0 (patch 38743669), installed as a **Gold Image** (indicates the system was built directly at 23.26.1, not patched up from a 23ai home) |
| Deployment | On-premises Linux virtual machine (host name `vbox`) |
| Client | SQL*Plus 23.26.1.0.0 |
| Architecture | Multitenant: `CDB$ROOT` + `PDB$SEED` + one user PDB (`MORAL`) |
| `COMPATIBLE` | 23.6.0 |
| SGA | 1,641,255,040 bytes total, including a **512 MB Vector Memory Area** |
| `vector_memory_size` | 512M (set in `CDB$ROOT`, `SCOPE=SPFILE`, instance restarted) |
| Vector pool in the PDB | 1 MB pool 448 MB · 64 KB pool 48 MB |
| Embedding model (Lab 07) | `all_MiniLM_L12_v2` ONNX, 384 dimensions |
| TLS wallet (Lab 09) | Auto-login wallet with a 141-certificate CA bundle; `SSL_WALLET` set in `CDB$ROOT` |
| AI providers tried (Lab 09) | OpenAI, Anthropic, Groq — all three failed with `ORA-20401` at the agent-call step |
| Data volumes | 8 products · 20,000 random 8-dim vectors · 5 text articles · 4 secured documents |

## What this means for reproducing the results

- **Row counts, orderings and index plans** should match on any 26ai release update ≥ 23.26.x.
- **Timings will differ** — they depend on hardware, caching and data volume. Treat them as illustrations, not benchmarks.
- **Random data:** Lab 03 fills `LAB_BIG` with random vectors, so the specific ids returned for the `[0.5, …, 0.5]` query (10591, 15160, …) will differ on your system. The *shape* of the result (index used, DML visibility) is what to compare.
- **Views:** `V$VECTOR_INDEX` was not exposed on this release for ordinary users; the scripts use `VECSYS.VECTOR$INDEX`. On Autonomous Database `VECSYS.VECTOR$INDEX` is not available and `V$VECTOR_INDEX` is the documented alternative.
- **Edition/licensing:** Data Redaction, SQL Firewall, and some features used here can depend on edition and options. Check Oracle's licensing documentation for your environment.
