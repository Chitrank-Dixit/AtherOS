# Architecture overview

The target architecture separates the user-facing product from the base distribution. Product services express desired capabilities; a future OS adapter translates package, update, and system-information operations. A controlled privileged broker mediates system changes.

```text
User interfaces (desktop-independent)
  ├── Aether Studio
  ├── Developer profiles ── optional AI capabilities
  └── User configuration
            │
     Product services and system broker
            │
       OS adapter boundary
        ├── Arch implementation
        └── NixOS implementation
```

This is a direction, not an implemented interface. Sprint 0 keeps the adapter as an evaluation concern and avoids product code tied to a selected base or desktop. Desktop profiles remain isolated; user data and configuration must be preserved. See [system boundaries](system-boundaries.md) and [security model](security-model.md).
