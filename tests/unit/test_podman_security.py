"""Regression tests for Aether's Podman profiles and runtime gates."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROFILE_HELPER = ROOT / "scripts/podman/security-profile.sh"
RUNTIME_CHECK = ROOT / "scripts/podman/check-runtime.sh"
LINUX_BASH = shutil.which("bash")


@unittest.skipUnless(LINUX_BASH and sys.platform.startswith("linux"), "requires Linux Bash")
class PodmanSecurityTests(unittest.TestCase):
    def run_bash(self, script: str, *args: str, env: dict[str, str] | None = None):
        return subprocess.run(
            [str(LINUX_BASH), "-c", script, "aether-test", *args],
            capture_output=True,
            text=True,
            check=False,
            env=env,
        )

    def test_standard_profile_drops_all_capabilities_and_network(self) -> None:
        result = subprocess.run(
            [str(LINUX_BASH), str(PROFILE_HELPER), "standard"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            ["--security-opt=no-new-privileges", "--cap-drop=ALL", "--network=none"],
            result.stdout.splitlines(),
        )

    def test_namespace_profile_keeps_no_new_privileges_without_adding_capabilities(self) -> None:
        result = subprocess.run(
            [str(LINUX_BASH), str(PROFILE_HELPER), "nested-namespace"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(
            ["--security-opt=no-new-privileges", "--network=bridge"],
            result.stdout.splitlines(),
        )
        self.assertNotIn("--privileged", result.stdout)
        self.assertNotIn("seccomp=unconfined", result.stdout)
        self.assertNotIn("--cap-add", result.stdout)
        self.assertNotIn("CAP_SYS_ADMIN", result.stdout)

    def test_namespace_probe_rejects_missing_container_marker(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "missing-container-marker"
            result = self.run_bash(
                'source "$1"; aether_check_nested_namespace_prerequisites "$2"',
                str(PROFILE_HELPER), str(marker),
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("must run inside a Podman container", result.stderr)

    def test_namespace_profile_fails_closed_if_sys_admin_is_effective(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            status = Path(directory) / "status"
            status.write_text(
                self.capability_status(cap_effective="0000000000200000"), encoding="utf-8"
            )
            result = self.run_bash(
                'source "$1"; aether_require_no_sys_admin "$2"',
                str(PROFILE_HELPER), str(status),
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("CAP_SYS_ADMIN is present in CapEff", result.stderr)

    def test_namespace_profile_rejects_sys_admin_in_permitted_or_bounding_sets(self) -> None:
        for field in ("CapPrm", "CapBnd"):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                status = Path(directory) / "status"
                status.write_text(self.capability_status(**{field: "0000000000200000"}), encoding="utf-8")
                result = self.run_bash(
                    'source "$1"; aether_require_no_sys_admin "$2"',
                    str(PROFILE_HELPER), str(status),
                )
            self.assertNotEqual(0, result.returncode)
            self.assertIn(f"CAP_SYS_ADMIN is present in {field}", result.stderr)

    def test_namespace_profile_accepts_effective_capabilities_without_sys_admin(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            status = Path(directory) / "status"
            status.write_text(self.capability_status(), encoding="utf-8")
            result = self.run_bash(
                'source "$1"; aether_require_no_sys_admin "$2"',
                str(PROFILE_HELPER), str(status),
            )
        self.assertEqual(0, result.returncode, result.stderr)

    @staticmethod
    def capability_status(**overrides: str) -> str:
        values = {
            "CapEff": "0000000000000000",
            "CapPrm": "0000000000000000",
            "CapInh": "0000000000000000",
            "CapBnd": "0000000000000000",
            "CapAmb": "0000000000000000",
        }
        values.update(overrides)
        return "Name:\tbash\n" + "".join(f"{key}:\t{value}\n" for key, value in values.items())

    def test_namespace_probe_fails_when_unshare_is_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "containerenv"
            marker.touch()
            command_dir = root / "bin"
            command_dir.mkdir()
            for command in ("mount",):
                located = shutil.which(command)
                if located:
                    (command_dir / command).symlink_to(located)
            env = os.environ.copy()
            env["PATH"] = str(command_dir)
            result = self.run_bash(
                'source "$1"; aether_check_nested_namespace_prerequisites "$2"',
                str(PROFILE_HELPER), str(marker), env=env,
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("prerequisite is unavailable: unshare", result.stderr)

    def test_namespace_probe_failure_is_not_silently_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "containerenv"
            marker.touch()
            bin_dir = root / "bin"
            bin_dir.mkdir()
            unshare = bin_dir / "unshare"
            unshare.write_text("#!/bin/sh\nexit 42\n", encoding="utf-8")
            unshare.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = str(bin_dir) + os.pathsep + env["PATH"]
            result = self.run_bash(
                'source "$1"; aether_probe_nested_namespaces "$2"',
                str(PROFILE_HELPER), str(marker), env=env,
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("nested user/mount namespace or private tmpfs probe failed", result.stderr)

    def make_mock_podman(self, directory: Path) -> None:
        podman = directory / "podman"
        podman.write_text(
            "#!/bin/sh\n"
            'if [ "$1" = "--version" ]; then echo "podman version test"; exit 0; fi\n'
            'if [ "$1" = "unshare" ]; then exit "${MOCK_PODMAN_UNSHARE_STATUS:-0}"; fi\n'
            'if [ "$1" = "info" ]; then\n'
            '  case "$3" in\n'
            '    *Security.Rootless*) echo "${MOCK_PODMAN_ROOTLESS:-true}" ;;\n'
            '    *ServiceIsRemote*) echo "${MOCK_PODMAN_REMOTE:-false}" ;;\n'
            '    *Host.Os*) echo Linux ;;\n'
            '    *Host.Arch*) echo amd64 ;;\n'
            '    *OCIRuntime.Name*) echo crun ;;\n'
            '    *NetworkBackend*) echo netavark ;;\n'
            '    *GraphDriverName*) echo overlay ;;\n'
            '    *GraphRoot*) echo /tmp ;;\n'
            '    *) echo "<no value>" ;;\n'
            '  esac\n'
            '  exit 0\n'
            'fi\n'
            'exit 2\n',
            encoding="utf-8",
        )
        podman.chmod(0o755)

    def runtime_env(self, directory: Path, **overrides: str) -> dict[str, str]:
        env = os.environ.copy()
        env["PATH"] = str(directory) + os.pathsep + env["PATH"]
        env.pop("CONTAINER_HOST", None)
        env.pop("CONTAINER_CONNECTION", None)
        env.update(overrides)
        return env

    def run_runtime_check(self, directory: Path, *args: str, **overrides: str):
        return subprocess.run(
            [str(LINUX_BASH), str(RUNTIME_CHECK), *args],
            capture_output=True,
            text=True,
            check=False,
            env=self.runtime_env(directory, **overrides),
        )

    def test_runtime_check_rejects_remote_podman(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            bin_dir = Path(directory)
            self.make_mock_podman(bin_dir)
            result = self.run_runtime_check(
                bin_dir, "--require-local-rootless", MOCK_PODMAN_REMOTE="true"
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Podman target: remote service", result.stdout)
        self.assertIn(
            "Storage filesystem: unavailable (remote graph root cannot be inspected locally)",
            result.stdout,
        )
        self.assertIn("remote Podman is not accepted", result.stderr)

    def test_runtime_check_rejects_remote_environment_override(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            bin_dir = Path(directory)
            self.make_mock_podman(bin_dir)
            result = self.run_runtime_check(
                bin_dir, "--require-local-rootless", CONTAINER_HOST="tcp://remote.invalid"
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("remote override detected", result.stdout)

    def test_runtime_check_rejects_rootful_podman(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            bin_dir = Path(directory)
            self.make_mock_podman(bin_dir)
            result = self.run_runtime_check(
                bin_dir, "--require-local-rootless", MOCK_PODMAN_ROOTLESS="false"
            )
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Execution privilege: rootful", result.stdout)
        self.assertIn("rootful Podman is not accepted", result.stderr)

    def test_runtime_check_reports_missing_subordinate_ranges(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_mock_podman(root)
            awk = root / "awk"
            awk.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            awk.chmod(0o755)
            result = self.run_runtime_check(root, "--require-local-rootless")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("/etc/subuid: MISSING or unreadable", result.stdout)
        self.assertIn("/etc/subgid: MISSING or unreadable", result.stdout)

    def test_runtime_check_reports_host_user_namespace_failure(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_mock_podman(root)
            unshare = root / "unshare"
            unshare.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            unshare.chmod(0o755)
            result = self.run_runtime_check(root, "--require-local-rootless")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("host user namespace support unavailable or blocked", result.stderr)

    def test_runtime_check_labels_nested_namespace_as_separate_test(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.make_mock_podman(root)
            result = self.run_runtime_check(root)
        self.assertIn("Podman target: local service", result.stdout)
        self.assertIn("Execution privilege: rootless", result.stdout)
        self.assertIn("OCI runtime: crun", result.stdout)
        self.assertIn("Network backend: netavark", result.stdout)
        self.assertIn("Storage driver: overlay", result.stdout)
        self.assertIn("Root mount propagation:", result.stdout)
        self.assertIn("Nested-container namespace operation: NOT TESTED", result.stdout)


if __name__ == "__main__":
    unittest.main()
