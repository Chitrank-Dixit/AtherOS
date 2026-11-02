# Recovery strategy comparison

**Status: NOT TESTED.** No snapshot, bootloader fallback, or generation rollback was exercised.

| Topic | Arch candidate | NixOS candidate |
|---|---|---|
| Mechanism | Btrfs snapshots with Snapper; previous kernel/recovery media | System generations and bootloader selection |
| Main integration work | Filesystem layout, snapshot timing, boot entry, restore documentation | Generation retention, bootloader behavior, state/data recovery boundaries |
| Failure tests | Failed update, broken boot, snapshot restore, recovery media | Failed activation, select prior generation, restore configuration |
| Disk/user cost | Snapshot storage and pruning policy | Store and generation retention policy |
| Limitation | Snapshot restore does not replace independent backups | System generation rollback does not automatically reverse user data or external state |

Measure implementation effort, reliability, disk use, user steps, and failure cases in disposable VMs. Snapshots and generations are not backups.
