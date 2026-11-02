# Base distribution decision

**Status: NOT DECIDED — human approval required.** Candidate scores are withheld because comparable experimental evidence is unavailable. Assigning numeric scores now would imply evidence that does not exist.

| Criterion | Weight | Arch score | NixOS score | Evidence required |
|---|---:|---:|---:|---|
| Desktop integration | 15% | NOT TESTED | NOT TESTED | Six desktop/OS cells and session switching |
| ISO generation | 15% | BLOCKED | BLOCKED | Build, checksum, UEFI boot, clean boot |
| Reproducibility | 15% | NOT TESTED | NOT TESTED | Repeated build/deployment with revisions recorded |
| Update management | 15% | NOT TESTED | NOT TESTED | End-to-end update and promotion workflow |
| Recovery and rollback | 15% | NOT TESTED | NOT TESTED | Failure injection and recovery evidence |
| NVIDIA compatibility | 10% | NOT TESTED | NOT TESTED | Documentation plus clearly scoped VM/physical evidence |
| Developer ecosystem | 5% | NOT TESTED | NOT TESTED | Profile setup and maintenance comparison |
| Maintenance complexity | 10% | NOT TESTED | NOT TESTED | Documented staffing/operational estimate |
| **Total** | **100%** | — | — | — |

When evidence exists, score each candidate independently from 1–5, cite evidence per score, calculate raw weighted totals, then state an Aether-specific recommendation separately from the numeric result. Include risk, maintenance, and migration implications. A human must approve the final base choice.
