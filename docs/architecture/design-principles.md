# Design principles

- Keep product services independent from distribution and desktop command details.
- Express desired state where the underlying distribution supports it; preserve a practical path for imperative package operations where needed.
- Keep desktop, developer, and AI choices modular and independently testable.
- Treat updates and rollback as system lifecycle capabilities, not UI-only features.
- Design for least privilege, auditable actions, and explicit user intent.
- Do not trade recoverability or security for a faster demo.
