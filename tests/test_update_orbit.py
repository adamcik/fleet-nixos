"""Release fixtures and artifact substitutes keep failure-path tests offline.

The real Nix compiler selector is checked by select-go.nix; a live release update
and package builds provide the integration check for nix-update itself.
"""

import base64
import json
import pathlib
import subprocess
import tempfile
import unittest

from scripts import update_orbit

COMMIT = "a" * 40
DATE = "2026-10-19T13:50:14Z"
RELEASE = update_orbit.Release("1.62.0", COMMIT, DATE, "1.27.1")
COMPILER = {"family": "1.27", "version": "1.27.1", "attribute": "go_1_27"}
PACKAGE = """{pkgs}: let
  goVersion = "1.26";
  version = "1.61.0";
  commit = "old";
  date = "old";
  vendorHash = "old-hash";
in {}
"""


class ReleaseTests(unittest.TestCase):
    def test_selected_release_uses_its_own_commit_and_go_requirement(self):
        github = FixtureGitHub()
        release = github.release("1.62.0")
        self.assertEqual(release, RELEASE)
        self.assertNotIn("/git/matching-refs/tags/orbit-v", github.requests)
        self.assertIn(f"/contents/go.mod?ref={COMMIT}", github.requests)

    def test_latest_discovery_sorts_versions_and_ignores_other_tag_families(self):
        github = FixtureGitHub()
        self.assertEqual(github.release(None).version, "1.62.0")

    def test_annotated_tag_is_peeled_to_commit(self):
        github = FixtureGitHub(annotated=True)
        self.assertEqual(github.release("1.62.0").commit, COMMIT)

    def test_toolchain_suggestion_is_not_the_minimum_requirement(self):
        github = FixtureGitHub(go_mod="module fleet\ngo 1.27.1\ntoolchain go1.28.0\n")
        self.assertEqual(github.release("1.62.0").required_go, "1.27.1")

    def test_go_directive_allows_a_trailing_comment(self):
        github = FixtureGitHub(go_mod="module fleet\ngo 1.27.1 // minimum compiler\n")
        self.assertEqual(github.release("1.62.0").required_go, "1.27.1")

    def test_rejects_invalid_or_ambiguous_go_requirement(self):
        for go_mod in ("module fleet\n", "go 1.27.1\ngo 1.28.0\n", "go 1.28rc1\n"):
            with self.subTest(go_mod=go_mod), self.assertRaises(ValueError):
                FixtureGitHub(go_mod=go_mod).release("1.62.0")

    def test_rejects_unsafe_or_nonstable_versions_before_any_request(self):
        for version in ("../main", "1.62.0; true", "1.62.0-rc1", "01.62.0", "1.62"):
            github = FixtureGitHub()
            with self.subTest(version=version), self.assertRaises(ValueError):
                github.release(version)
            self.assertEqual(github.requests, [])

    def test_missing_selected_release_never_falls_back_to_latest(self):
        with self.assertRaises(KeyError):
            FixtureGitHub().release("1.63.0")


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        (self.root / "pkgs").mkdir()
        self.package = self.root / "pkgs/default.nix"
        self.package.write_text(PACKAGE)
        self.lock = self.root / "flake.lock"
        self.lock.write_text("original lock\n")
        self.requested = self.root / "orbit.json"
        self.requested.write_text('{"version": "1.62.0"}\n')

    def test_selects_compiler_before_hashes_and_builds_both_outputs(self):
        nix = FixtureNix(self.root)
        update_orbit.update(self.root, RELEASE, nix)
        self.assertIn('goVersion = "1.27";', self.package.read_text())
        self.assertIn('version = "1.62.0";', self.package.read_text())
        self.assertEqual(nix.events, ["select", "hashes", "verify"])
        self.assertEqual(self.lock.read_text(), "original lock\n")
        self.assertEqual(json.loads(self.requested.read_text())["version"], "1.62.0")

    def test_refreshes_nixpkgs_only_when_locked_compilers_are_insufficient(self):
        nix = FixtureNix(self.root, needs_refresh=True)
        update_orbit.update(self.root, RELEASE, nix)
        self.assertEqual(
            nix.events, ["select", "refresh", "select", "hashes", "verify"]
        )
        self.assertEqual(self.lock.read_text(), "updated nixpkgs\n")

    def test_unavailable_compiler_restores_lock_and_preserves_entry_state(self):
        nix = FixtureNix(self.root, needs_refresh=True, unavailable=True)
        with self.assertRaisesRegex(ValueError, "still has no compiler"):
            update_orbit.update(self.root, RELEASE, nix)
        self.assertEqual(self.package.read_text(), PACKAGE)
        self.assertEqual(self.lock.read_text(), "original lock\n")
        self.assertNotIn("hashes", nix.events)

    def test_failed_artifacts_leave_renovates_requested_release_visibly_pending(self):
        original = PACKAGE
        for phase in ("hashes", "verify"):
            self.package.write_text(original)
            nix = FixtureNix(self.root, needs_refresh=True, failure=phase)
            with (
                self.subTest(phase=phase),
                self.assertRaises(subprocess.CalledProcessError),
            ):
                update_orbit.update(self.root, RELEASE, nix)
            self.assertEqual(self.package.read_text(), original)
            self.assertEqual(self.lock.read_text(), "original lock\n")
            self.assertEqual(
                json.loads(self.requested.read_text())["version"], "1.62.0"
            )
            self.assertIn('version = "1.61.0";', self.package.read_text())

    def test_successful_update_is_idempotent(self):
        nix = FixtureNix(self.root)
        update_orbit.update(self.root, RELEASE, nix)
        first = (
            self.package.read_bytes(),
            self.lock.read_bytes(),
            self.requested.read_bytes(),
        )
        update_orbit.update(self.root, RELEASE, nix)
        self.assertEqual(
            (
                self.package.read_bytes(),
                self.lock.read_bytes(),
                self.requested.read_bytes(),
            ),
            first,
        )

    def test_manual_update_advances_requested_release_only_on_success(self):
        self.requested.write_text('{"version": "1.61.0"}\n')
        with self.assertRaises(subprocess.CalledProcessError):
            update_orbit.update(
                self.root, RELEASE, FixtureNix(self.root, failure="verify")
            )
        self.assertEqual(json.loads(self.requested.read_text())["version"], "1.61.0")
        update_orbit.update(self.root, RELEASE, FixtureNix(self.root))
        self.assertEqual(json.loads(self.requested.read_text())["version"], "1.62.0")

    def test_dry_run_never_refreshes_writes_or_builds(self):
        nix = FixtureNix(self.root, needs_refresh=True)
        self.assertIsNone(update_orbit.update(self.root, RELEASE, nix, dry_run=True))
        self.assertEqual(nix.events, ["select"])
        self.assertEqual(self.package.read_text(), PACKAGE)
        self.assertEqual(self.lock.read_text(), "original lock\n")

    def test_ambiguous_assignments_fail_without_artifact_changes(self):
        original = PACKAGE + '  version = "1.62.0";\n'
        self.package.write_text(original)
        with self.assertRaisesRegex(ValueError, "one literal version"):
            update_orbit.update(self.root, RELEASE, FixtureNix(self.root))
        self.assertEqual(self.package.read_text(), original)

    def test_invalid_release_manifest_fails_before_artifact_work(self):
        for invalid in ("[]\n", '{"version": 1.62}\n'):
            self.requested.write_text(invalid)
            nix = FixtureNix(self.root)
            with self.subTest(manifest=invalid), self.assertRaises(TypeError):
                update_orbit.update(self.root, RELEASE, nix)
            self.assertEqual(nix.events, [])
            self.assertEqual(self.package.read_text(), PACKAGE)
            self.assertEqual(self.requested.read_text(), invalid)


class FixtureGitHub(update_orbit.GitHub):
    """Replace only the remote JSON transport with captured-shape API responses."""

    def __init__(self, *, annotated=False, go_mod="module fleet\ngo 1.27.1\n"):
        super().__init__()
        self.requests = []
        self.responses = {
            "/git/matching-refs/tags/orbit-v": [
                {"ref": f"refs/tags/{tag}"}
                for tag in (
                    "orbit-v1.9.0",
                    "orbit-v1.62.0",
                    "orbit-v1.63.0-rc1",
                    "v99.0.0",
                )
            ],
            "/git/ref/tags/orbit-v1.62.0": {
                "object": {"sha": COMMIT, "type": "tag" if annotated else "commit"}
            },
            f"/git/tags/{COMMIT}": {"object": {"sha": COMMIT, "type": "commit"}},
            f"/commits/{COMMIT}": {"commit": {"committer": {"date": DATE}}},
            f"/contents/go.mod?ref={COMMIT}": {
                "encoding": "base64",
                "content": base64.b64encode(go_mod.encode()).decode(),
            },
        }

    def _get(self, path):
        self.requests.append(path)
        return self.responses[path]


class FixtureNix:
    """Model external artifact work without network downloads or compiler builds."""

    def __init__(self, root, *, needs_refresh=False, unavailable=False, failure=None):
        self.root = root
        self.needs_refresh = needs_refresh
        self.unavailable = unavailable
        self.failure = failure
        self.events = []

    def select_go(self, required, current):
        self.events.append("select")
        return None if self.needs_refresh or self.unavailable else COMPILER

    def refresh_nixpkgs(self):
        self.events.append("refresh")
        (self.root / "flake.lock").write_text("updated nixpkgs\n")
        self.needs_refresh = False

    def refresh_hashes(self):
        self.events.append("hashes")
        content = (self.root / "pkgs/default.nix").read_text()
        if (
            'goVersion = "1.27";' not in content
            or f'commit = "{COMMIT}";' not in content
        ):
            raise AssertionError(
                "Compiler and exact source must be selected before fetching Go modules"
            )
        (self.root / "pkgs/default.nix").write_text(
            content.replace("old-hash", "new-hash")
        )
        if self.failure == "hashes":
            raise subprocess.CalledProcessError(1, ["nix-update"])

    def verify(self):
        self.events.append("verify")
        if self.failure == "verify":
            raise subprocess.CalledProcessError(1, ["nix", "build"])


if __name__ == "__main__":
    unittest.main()
