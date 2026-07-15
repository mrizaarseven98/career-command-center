#!/usr/bin/env python3
"""Install the bundled Career Command Center macOS app for the current user."""

from __future__ import annotations

import argparse
import json
import platform
import shutil
import subprocess
from pathlib import Path


PLUGIN_ROOT = Path(__file__).resolve().parent.parent
PREBUILT = PLUGIN_ROOT / "assets" / "macos-app" / "prebuilt" / "Career Command Center.app"
BUILD_SCRIPT = PLUGIN_ROOT / "scripts" / "build_app.sh"


def run_build() -> Path:
    result = subprocess.run(
        [str(BUILD_SCRIPT)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return Path(result.stdout.strip().splitlines()[-1])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--destination",
        type=Path,
        default=Path.home() / "Applications" / "Career Command Center.app",
    )
    parser.add_argument("--workspace", type=Path, default=None)
    parser.add_argument("--force-rebuild", action="store_true")
    parser.add_argument("--no-launch", action="store_true")
    args = parser.parse_args()

    if platform.system() != "Darwin":
        raise SystemExit("Career Command Center currently supports macOS 14 or later.")

    source = PREBUILT
    can_use_prebuilt = platform.machine().lower() in {"arm64", "aarch64"}
    if args.force_rebuild or not can_use_prebuilt or not (source / "Contents" / "MacOS" / "CareerCommandCenter").exists():
        source = run_build()

    args.destination.parent.mkdir(parents=True, exist_ok=True)
    if args.destination.exists():
        shutil.rmtree(args.destination)
    shutil.copytree(source, args.destination, symlinks=True)

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
                "launched": not args.no_launch,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
