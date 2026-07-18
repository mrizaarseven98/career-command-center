#!/usr/bin/env python3
"""Exercise the macOS self-update helper, including rollback."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_APP = ROOT / "build/Career Command Center.app"


def run(*args: object, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(arg) for arg in args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )


def prepare_app(source: Path, destination: Path, version: str) -> None:
    shutil.copytree(source, destination, symlinks=True)
    info = destination / "Contents/Info.plist"
    run("/usr/bin/plutil", "-replace", "CFBundleShortVersionString", "-string", version, info)
    run("/usr/bin/plutil", "-replace", "CFBundleVersion", "-string", version.replace(".", ""), info)
    run("/usr/bin/codesign", "--force", "--deep", "--sign", "-", destination)
    run("/usr/bin/codesign", "--verify", "--deep", "--strict", destination)


def version(app: Path) -> str:
    return run(
        "/usr/bin/plutil",
        "-extract",
        "CFBundleShortVersionString",
        "raw",
        "-o",
        "-",
        app / "Contents/Info.plist",
    ).stdout.strip()


def exited_pid() -> int:
    process = subprocess.Popen(["/usr/bin/true"])
    process.wait(timeout=5)
    return process.pid


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=DEFAULT_APP)
    args = parser.parse_args()
    source = args.app.resolve()
    helper = source / "Contents/Helpers/CareerCommandCenterUpdater"
    if not helper.is_file() or not os.access(helper, os.X_OK):
        raise SystemExit(f"Build the app first; updater helper missing at {helper}")

    environment = dict(os.environ)
    environment["CAREER_COMMAND_CENTER_SKIP_RELAUNCH"] = "1"

    with tempfile.TemporaryDirectory(prefix="career-command-center-update-") as temporary:
        root = Path(temporary)
        destination = root / "Applications/Career Command Center.app"
        staged = root / "Staging/Career Command Center.app"
        destination.parent.mkdir(parents=True)
        staged.parent.mkdir(parents=True)
        prepare_app(source, destination, "3.9.9")
        prepare_app(source, staged, "4.0.0")

        run(helper, staged, destination, exited_pid(), env=environment)
        assert version(destination) == "4.0.0"
        assert not staged.parent.exists()
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", destination)

        shutil.rmtree(destination)
        staged.parent.mkdir(parents=True)
        prepare_app(source, destination, "3.9.9")
        prepare_app(source, staged, "4.0.1")
        executable = staged / "Contents/MacOS/CareerCommandCenter"
        executable.chmod(0o644)

        failed = run(helper, staged, destination, exited_pid(), check=False, env=environment)
        assert failed.returncode != 0
        assert version(destination) == "3.9.9"
        assert os.access(destination / "Contents/MacOS/CareerCommandCenter", os.X_OK)
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", destination)

    print("Update installer tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
