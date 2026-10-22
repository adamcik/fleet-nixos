"""Update one Orbit release, its Nix compiler, and both package artifacts together.

Release discovery is separate from artifact generation: Renovate supplies an exact
version, while manual runs may discover the latest stable Orbit tag. Compiler
selection happens before nix-update evaluates the new source's Go modules.
"""

import argparse
import base64
import dataclasses
import datetime
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.request


@dataclasses.dataclass(frozen=True)
class Release:
    version: str
    commit: str
    date: str
    required_go: str


class GitHub:
    """Read release metadata and requirements from the same immutable commit."""

    def __init__(self, base_url="https://api.github.com/repos/fleetdm/fleet"):
        self.base_url = base_url

    def release(self, version):
        if version is None:
            refs = self._get("/git/matching-refs/tags/orbit-v")
            versions = [
                ref["ref"].removeprefix("refs/tags/orbit-v")
                for ref in refs
                if re.fullmatch(
                    r"refs/tags/orbit-v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)",
                    ref["ref"],
                )
            ]
            if not versions:
                raise ValueError("No stable Orbit release tags found")
            version = max(versions, key=_version_tuple)

        _version_tuple(version)
        obj = self._get(f"/git/ref/tags/orbit-v{version}")["object"]
        for _ in range(10):
            if obj["type"] == "commit":
                break
            if obj["type"] != "tag":
                raise ValueError("Orbit tag does not refer to a commit")
            obj = self._get(f"/git/tags/{obj['sha']}")["object"]
        else:
            raise ValueError("Orbit tag has too many nested annotated tags")

        commit = obj["sha"]
        if not re.fullmatch(r"[0-9a-f]{40}", commit):
            raise ValueError("Orbit tag has an invalid commit SHA")
        date = self._get(f"/commits/{commit}")["commit"]["committer"]["date"]
        datetime.datetime.fromisoformat(date)
        source = self._get(f"/contents/go.mod?ref={commit}")
        if source["encoding"] != "base64":
            raise ValueError("Unsupported GitHub go.mod encoding")
        go_mod = base64.b64decode(source["content"]).decode()
        requirements = re.findall(
            r"^go[ \t]+(\S+)[ \t]*(?://[^\r\n]*)?\r?$", go_mod, re.MULTILINE
        )
        if len(requirements) != 1:
            raise ValueError("Expected exactly one go directive in upstream go.mod")
        _version_tuple(requirements[0], allow_family=True)
        return Release(version, commit, date, requirements[0])

    def _get(self, path):
        headers = {
            "Accept": "application/vnd.github+json",
            "User-Agent": "fleet-nixos-updater",
        }
        token = (
            os.environ.get("GH_TOKEN")
            or os.environ.get("GITHUB_TOKEN")
            or os.environ.get("RENOVATE_TOKEN")
        )
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(self.base_url + path, headers=headers)
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)


class Nix:
    """Artifact operations against this checkout and its locked nixpkgs input."""

    def __init__(self, root):
        self.root = root

    def select_go(self, required, current):
        expression = (
            "(import ./scripts/select-go.nix) { "
            "pkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; "
            f"requiredVersion = {json.dumps(required)}; currentVersion = {json.dumps(current)}; "
            "}"
        )
        return json.loads(
            self._run(
                "nix",
                "eval",
                "--impure",
                "--no-write-lock-file",
                "--json",
                "--expr",
                expression,
                capture=True,
            )
        )

    def refresh_nixpkgs(self):
        self._run("nix", "flake", "update", "nixpkgs")

    def refresh_hashes(self):
        self._run("nix-update", "orbit", "--flake", "--version=skip")

    def verify(self):
        # These packages share a large source tree; parallel builds can exhaust
        # ephemeral runners' scratch space even when the Nix store has room.
        system = self._system()
        self._run(
            "nix",
            "build",
            "--no-link",
            "--max-jobs",
            "1",
            ".#orbit",
            ".#fleet-desktop",
            f".#checks.{system}.orbit-go-version",
            f".#checks.{system}.orbit-release-version",
        )

    def _system(self):
        return self._run(
            "nix",
            "eval",
            "--impure",
            "--raw",
            "--expr",
            "builtins.currentSystem",
            capture=True,
        ).strip()

    def _run(self, *args, capture=False):
        result = subprocess.run(
            args,
            cwd=self.root,
            check=True,
            text=True,
            stdout=subprocess.PIPE if capture else None,
        )
        return result.stdout


def update(root, release, nix, *, dry_run=False):
    """Restore entry-state files on failure; a pending release stays visibly pending."""
    package_file = root / "pkgs/default.nix"
    lock_file = root / "flake.lock"
    release_file = root / "orbit.json"
    originals = {}
    for path in (package_file, lock_file, release_file):
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Expected a regular file: {path}")
        originals[path] = path.read_bytes()
    original_package = originals[package_file].decode()
    requested_release = json.loads(originals[release_file])
    if not isinstance(requested_release, dict) or not isinstance(
        requested_release.get("version"), str
    ):
        raise TypeError("Expected a version string in orbit.json")
    _version_tuple(requested_release["version"])
    current_go = _assignment(original_package, "goVersion")
    _version_tuple(current_go, allow_family=True)
    compiler = nix.select_go(release.required_go, current_go)
    if dry_run:
        return compiler

    try:
        if compiler is None:
            print(
                f"Locked nixpkgs has no compiler satisfying Go {release.required_go}; refreshing nixpkgs",
                flush=True,
            )
            nix.refresh_nixpkgs()
            compiler = nix.select_go(release.required_go, current_go)
        if compiler is None:
            raise ValueError(
                f"Updated nixpkgs still has no compiler satisfying Go {release.required_go}"
            )

        content = original_package
        for key, value in {
            "version": release.version,
            "commit": release.commit,
            "date": release.date,
            "goVersion": compiler["family"],
        }.items():
            content = _replace_assignment(content, key, value)
        package_file.write_text(content)
        requested_release["version"] = release.version
        release_file.write_text(json.dumps(requested_release, indent=2) + "\n")
        nix.refresh_hashes()
        nix.verify()
    except BaseException:
        for path, original in originals.items():
            path.write_bytes(original)
        raise
    return compiler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--version", help="Exact stable Orbit version, without the orbit-v prefix"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Resolve release and compiler without modifying files or building",
    )
    args = parser.parse_args()
    root = pathlib.Path.cwd()
    try:
        if args.version is not None:
            _version_tuple(args.version)
        release = GitHub().release(args.version)
        compiler = update(root, release, Nix(root), dry_run=args.dry_run)
        metadata = {
            "version": release.version,
            "commit": release.commit,
            "date": release.date,
            "required_go": release.required_go,
            "selected_go": compiler["version"]
            if compiler
            else "nixpkgs refresh required",
        }
        for key, value in metadata.items():
            print(f"{key}={value}")
        if not args.dry_run and os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a") as output:
                for key, value in metadata.items():
                    print(f"{key}={value}", file=output)
    except (
        ValueError,
        TypeError,
        KeyError,
        OSError,
        subprocess.CalledProcessError,
    ) as error:
        print(f"Orbit update failed: {error}", file=sys.stderr)
        return 1
    return 0


def _version_tuple(version, *, allow_family=False):
    components = r"(?:0|[1-9][0-9]*)"
    pattern = rf"{components}\.{components}(?:\.{components})" + (
        "?" if allow_family else ""
    )
    if not re.fullmatch(pattern, version):
        raise ValueError(
            f"Expected a stable numeric {'Go' if allow_family else 'Orbit'} version, got {version!r}"
        )
    return tuple(map(int, version.split(".")))


def _assignment(content, key):
    matches = re.findall(rf'^  {re.escape(key)} = "([^"\n]+)";$', content, re.MULTILINE)
    if len(matches) != 1:
        raise ValueError(f"Expected one literal {key} assignment in pkgs/default.nix")
    return matches[0]


def _replace_assignment(content, key, value):
    _assignment(content, key)
    return re.sub(
        rf'^  {re.escape(key)} = "[^"\n]+";$',
        lambda _: f"  {key} = {json.dumps(value)};",
        content,
        flags=re.MULTILINE,
    )


if __name__ == "__main__":
    sys.exit(main())
