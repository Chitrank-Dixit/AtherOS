# Update strategy comparison

**Status: research framework; no update operation tested.**

| Area | Arch candidate | NixOS candidate | Sprint 0 evidence |
|---|---|---|---|
| Upstream model | Rolling package stream | Pinned nixpkgs input/configuration | Research only |
| Repeatability | Archive/mirror and coherent snapshot policy required | Flake lock and declared configuration | No lock generated |
| Promotion | Aether-managed package set/repository and regression testing | Promote tested nixpkgs/configuration revisions and caches | Not implemented |
| Signing | Verify upstream and any Aether repository package signatures | Verify upstream/cache trust model | Not tested |
| Rollback | Requires snapshots/recovery integration; package state alone not assumed reversible | Generations provide a candidate system rollback | Not tested |

The desired future path is Development → Beta → Stable. Sprint 0 should estimate operations and testing needs, not build production repositories. For Arch, evaluate full-system upgrades, avoid partial upgrades, inspect Archive snapshots and mirroring options, and model how to test/promote a coherent package set. For NixOS, pin a reviewed revision, build/activate it, and compare cache and generation behavior.
