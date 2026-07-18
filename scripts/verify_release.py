#!/usr/bin/env python3
"""Verify that a Git tag matches the app and plugin release metadata."""

from __future__ import annotations

import argparse
import json
import plistlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()

    if not re.fullmatch(r"v\d+\.\d+\.\d+", args.tag):
        raise SystemExit("Release tag must use vMAJOR.MINOR.PATCH")
    version = args.tag.removeprefix("v")
    with (ROOT / "assets/macos-app/Info.plist").open("rb") as handle:
        app_info = plistlib.load(handle)
    if app_info.get("CFBundleShortVersionString") != version:
        raise SystemExit(
            f"Tag {args.tag} does not match app version "
            f"{app_info.get('CFBundleShortVersionString')}"
        )

    manifest = json.loads((ROOT / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))
    plugin_version = str(manifest.get("version", "")).split("+", 1)[0]
    if not re.fullmatch(r"\d+\.\d+\.\d+", plugin_version):
        raise SystemExit("Codex plugin version is not semantic")

    claude = json.loads((ROOT / ".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
    claude_version = str(claude["plugins"][0].get("version", ""))
    if claude_version != plugin_version:
        raise SystemExit("Codex and Claude plugin versions do not match")

    print(f"Release metadata valid: app {version}, plugins {plugin_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
