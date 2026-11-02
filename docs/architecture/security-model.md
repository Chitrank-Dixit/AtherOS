# Security model

Sprint 0 establishes constraints, not a complete threat model. The eventual system must use least privilege, verify package/image provenance, protect signing credentials, and make privileged changes narrowly scoped and visible to users.

No product component should receive unrestricted root access. A system broker must validate typed requests and authorize operations. AI components are untrusted clients: they may propose actions but must not directly run privileged commands or bypass user approval. Preserve user data during upgrades and recovery. VM experiments use disposable guests; physical hardware procedures require explicit approval and must be non-destructive.
