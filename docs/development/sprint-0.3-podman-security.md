# Sprint 0.3: Podman security profiles and runtime validation

## Scope and acceptance criteria

This increment adapts builder container policy to the supplied Ubuntu 26.04 WSL2 test matrix. It does not attempt Archiso or NixOS ISO builds. The base-distribution decision is unchanged.

| Criterion | Implementation/evidence |
| --- | --- |
| Keep ordinary-container isolation strict | `standard`: drop all capabilities, retain `no-new-privileges`, disable networking. |
| Support the tested nested namespace path without capability additions | `nested-namespace`: retain Podman rootless defaults; retain `no-new-privileges`, default seccomp and host LSM policy; use an explicit bridge network for package access. |
| Reject unsafe or unsupported builder runtime | Existing local/rootless check plus host user namespace and subordinate UID/GID prerequisites; nested probe inside the builder before the build command. |
| Report runtime capabilities separately from nested tests | Runtime report includes service locality, privilege mode, OCI runtime, network backend, storage driver/filesystem, root propagation, subordinate ranges, and host namespace checks. It labels nested-container execution NOT TESTED. |
| Exercise profiles and failure gates automatically | Regression tests are added for remote/rootful/override rejection, missing subordinate ranges, host namespace failure, profile arguments, `CAP_SYS_ADMIN` refusal, and unavailable nested namespace prerequisites. |
| Avoid unverified build claims | Archiso, Nix sandbox/ISO, and VM boot tests are not run in this increment. |

## Security decision

The WSL2 test matrix reports that nested user/mount namespace operations passed with Podman's default capability set and `no-new-privileges`; tests using `--cap-drop=ALL`, SETUID+SETGID, and SETUID+SETGID+SETPCAP failed. The observed incompatible setting is `--cap-drop=ALL`; the supplied results do not isolate which individual default capability is needed, and the tested additions did not restore the operation. Aether therefore preserves the runtime's default capability set only for namespace-dependent builders. It adds no capabilities. The probe fails closed if `CAP_SYS_ADMIN` appears in any effective, permitted, inheritable, bounding, or ambient capability set inside the builder. The standard profile remains unchanged and strict. The namespace profile uses an explicit bridge network. Neither profile uses `--privileged`, disables seccomp or host LSM policy, or mounts the host container socket.

Podman's runtime defaults vary by version, so the build wrapper records the Podman version, selected profile, capability policy, and explicit `CAP_SYS_ADMIN` guard in output metadata. A Podman version update requires reviewing its defaults and rerunning the namespace probe. Runtime prerequisite diagnostics are not a substitute for the in-container namespace test.

## Evidence provenance and limitations

The detailed machine-readable report is [PODMAN-WSL2-NAMESPACE-SECURITY-01](../../experiments/containers/results/sprint-0.3-wsl2-namespace-security.json). Its overall PASSED status means the reported matrix identified a namespace-capable profile; it does not mean the negative control profiles passed. The record reflects the operator-provided matrix: rootless Podman 5.7.0, Ubuntu 26.04 under WSL2, kernel 6.18.33.2. The test date and raw command transcripts were not supplied, and the experiment has not been independently repeated here.

The matrix covers rootless runtime and namespace probes, source/output mount modes, and capability-policy comparisons. It does not establish that Archiso builds, Nix's sandbox runs, either ISO builds, or an ISO boots. Those remain **NOT TESTED**. The new automated tests are intended to validate Aether's policy and failure handling; they do not reproduce the WSL integration experiment.

## Commands

Run the read-only prerequisites report with:

```bash
make podman-env-check
```

Inspect the profile arguments directly with:

```bash
bash scripts/podman/security-profile.sh standard
bash scripts/podman/security-profile.sh nested-namespace
```

Run the mocked policy and failure-gate tests with:

```bash
python3 -m unittest discover -s tests/unit -p 'test_podman_security.py' -v
```

The namespace operation itself is tested only by the builder probe, which executes inside the selected container before either build script. This Sprint 0.3 work does not invoke either ISO builder.
