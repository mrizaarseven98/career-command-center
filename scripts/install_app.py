#!/usr/bin/env python3
"""Install the bundled Career Command Center macOS app for the current user."""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import stat
import subprocess
import uuid
from pathlib import Path


PLUGIN_ROOT = Path(__file__).resolve().parent.parent
PREBUILT = PLUGIN_ROOT / "assets" / "macos-app" / "prebuilt" / "Career Command Center.app"
BUILD_SCRIPT = PLUGIN_ROOT / "scripts" / "build_app.sh"
EXECUTABLE_RELATIVE_PATHS = (
    Path("Contents/MacOS/CareerCommandCenter"),
    Path("Contents/Helpers/CareerCommandCenterUpdater"),
)


def run_build() -> Path:
    result = subprocess.run(
        ["/bin/bash", str(BUILD_SCRIPT)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return Path(result.stdout.strip().splitlines()[-1])


def ensure_launchable(app_path: Path) -> bool:
    """Restore transfer-sensitive permissions and refresh the local app signature."""
    executables = [app_path / relative for relative in EXECUTABLE_RELATIVE_PATHS]
    executables.extend((app_path / "Contents/Resources/Support/scripts").glob("*.py"))
    missing = [path for path in executables[: len(EXECUTABLE_RELATIVE_PATHS)] if not path.is_file()]
    if missing:
        raise SystemExit(f"Bundled app executable is missing: {missing[0]}")

    repaired_permissions = any(not os.access(path, os.X_OK) for path in executables)
    for executable in executables:
        executable.chmod(
            executable.stat().st_mode
            | stat.S_IXUSR
            | stat.S_IXGRP
            | stat.S_IXOTH
        )

    try:
        subprocess.run(
            ["/usr/bin/codesign", "--force", "--deep", "--sign", "-", str(app_path)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        subprocess.run(
            ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app_path)],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or str(error)).strip()
        raise SystemExit(f"Could not prepare the app for launch: {detail}") from error

    return repaired_permissions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--destination",
        type=Path,
        default=Path.home() / "Applications" / "Career Command Center.app",
    )
    parser.add_argument("--workspace", type=Path, default=None)
    parser.add_argument(
        "--assistant-provider",
        choices=("codex", "claude"),
        default="codex",
        help="Assistant name used by the app's handoff controls.",
    )
    parser.add_argument("--force-rebuild", action="store_true")
    parser.add_argument("--no-launch", action="store_true")
    args = parser.parse_args()

    if platform.system() != "Darwin":
        raise SystemExit("Career Command Center currently supports macOS 14 or later.")

    source = PREBUILT
    if args.force_rebuild or not (source / EXECUTABLE_RELATIVE_PATHS[0]).is_file():
        source = run_build()

    args.destination.parent.mkdir(parents=True, exist_ok=True)
    staging = args.destination.parent / f".{args.destination.name}.install-{uuid.uuid4().hex}.app"
    backup = args.destination.parent / f".{args.destination.name}.backup-{uuid.uuid4().hex}.app"
    moved_existing = False
    try:
        shutil.copytree(source, staging, symlinks=True)
        repaired_permissions = ensure_launchable(staging)
        if args.destination.exists():
            args.destination.rename(backup)
            moved_existing = True
        staging.rename(args.destination)
    except BaseException:
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        if moved_existing and backup.exists() and not args.destination.exists():
            backup.rename(args.destination)
        raise
    if backup.exists():
        shutil.rmtree(backup, ignore_errors=True)

    preference_written = True
    preference_warning = None
    try:
        subprocess.run(
            [
                "/usr/bin/defaults",
                "write",
                "com.careercommandcenter.macos",
                "CareerCommandCenter.assistantProvider",
                args.assistant_provider,
            ],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except subprocess.CalledProcessError as error:
        preference_written = False
        preference_warning = (
            error.stderr or error.stdout or "macOS did not accept the assistant preference"
        ).strip()

    command = ["open", str(args.destination)]
    if args.workspace:
        command.extend(["--args", "--workspace", str(args.workspace)])
    if not args.no_launch:
        subprocess.run(command, check=True)

    print(
        json.dumps(
            {
                "installed_app": str(args.destination),
                "workspace_override": str(args.workspace) if args.workspace else None,
                "assistant_provider": args.assistant_provider,
                "assistant_preference_written": preference_written,
                "assistant_preference_warning": preference_warning,
                "launched": not args.no_launch,
                "executable_permission_repaired": repaired_permissions,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
