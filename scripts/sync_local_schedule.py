#!/usr/bin/env python3
"""Register Career Command Center's local macOS CLI schedule."""

from __future__ import annotations

import argparse
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path


LABEL = "com.careercommandcenter.search"


def run(*args: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(value) for value in args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def installed_app(explicit: Path | None) -> Path:
    candidates = [
        explicit,
        Path.home() / "Applications/Career Command Center.app",
        Path("/Applications/Career Command Center.app"),
    ]
    for candidate in candidates:
        if candidate and (candidate / "Contents/Helpers/CareerCommandCenterRunner").is_file():
            return candidate.resolve()
    raise SystemExit("Career Command Center.app is not installed in an Applications folder.")


def selected_provider(explicit: str | None) -> str:
    if explicit:
        return explicit
    result = subprocess.run(
        [
            "/usr/bin/defaults",
            "read",
            "com.careercommandcenter.macos",
            "CareerCommandCenter.assistantProvider",
        ],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    value = result.stdout.strip()
    return value if value in {"codex", "claude"} else "codex"


def assistant_executable(provider: str) -> Path:
    home = Path.home()
    override_name = (
        "CAREER_COMMAND_CENTER_CODEX_EXECUTABLE"
        if provider == "codex"
        else "CAREER_COMMAND_CENTER_CLAUDE_EXECUTABLE"
    )
    override = os.environ.get(override_name)
    if provider == "codex":
        candidates = [
            Path(override) if override else None,
            Path("/Applications/ChatGPT.app/Contents/Resources/codex"),
            home / "Applications/ChatGPT.app/Contents/Resources/codex",
            Path("/Applications/Codex.app/Contents/Resources/codex"),
            home / "Applications/Codex.app/Contents/Resources/codex",
            home / ".local/bin/codex",
            Path("/opt/homebrew/bin/codex"),
            Path("/usr/local/bin/codex"),
        ]
        executable_name = "codex"
    else:
        candidates = [
            Path(override) if override else None,
            home / ".claude/local/claude",
            home / ".local/bin/claude",
            Path("/opt/homebrew/bin/claude"),
            Path("/usr/local/bin/claude"),
        ]
        executable_name = "claude"
    located = shutil.which(executable_name)
    if located:
        candidates.append(Path(located))
    nvm = home / ".nvm/versions/node"
    if nvm.is_dir():
        candidates.extend(path / "bin" / executable_name for path in nvm.iterdir() if path.is_dir())
    for candidate in candidates:
        if candidate is None:
            continue
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
    raise SystemExit(f"The {provider} CLI could not be found. Install or sign in to it first.")


def workflow_root(app: Path, workspace: Path) -> Path:
    with (app / "Contents/Info.plist").open("rb") as handle:
        version = str(plistlib.load(handle)["CFBundleShortVersionString"])
    managed = workspace / "System/CareerCommandCenter" / version
    if (managed / "WORKFLOW.md").is_file():
        return managed
    bundled = app / "Contents/Resources/Support"
    if (bundled / "WORKFLOW.md").is_file():
        return bundled
    raise SystemExit("The app workflow files are missing. Reinstall Career Command Center.")


def atomic_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--provider", choices=("codex", "claude"))
    parser.add_argument("--app", type=Path)
    parser.add_argument("--skip-readiness-check", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    workspace = args.workspace.expanduser().resolve()
    config_path = workspace / "Config/command_center_config.json"
    config = json.loads(config_path.read_text(encoding="utf-8"))
    automation = config.setdefault("automation", {})
    app = installed_app(args.app)
    runner = app / "Contents/Helpers/CareerCommandCenterRunner"
    provider = selected_provider(args.provider)

    if not args.skip_readiness_check:
        doctor = Path(__file__).resolve().parent / "doctor.py"
        run("python3", doctor, workspace, "--strict")

    if not automation.get("enabled") or automation.get("frequency") == "manual":
        result = run(runner, "schedule", "remove", "--label", LABEL)
    else:
        assistant = assistant_executable(provider)
        root = workflow_root(app, workspace)
        prompt_path = workspace / "Automation/scheduled_search_prompt.txt"
        prompt_path.parent.mkdir(parents=True, exist_ok=True)
        prompt_path.write_text(
            f"Run the Career Command Center job and PhD search for {workspace}. "
            f"Treat {root} as the workflow root, read WORKFLOW.md, and execute the specification "
            f"produced by scripts/render_automation_spec.py using {config_path}. Update app state "
            "only through scripts/state_cli.py and record the completed run.\n",
            encoding="utf-8",
        )
        command: list[object] = [
            runner,
            "schedule", "install",
            "--label", LABEL,
            "--workspace", workspace,
            "--provider", provider,
            "--assistant-executable", assistant,
            "--prompt-file", prompt_path,
            "--frequency", automation.get("frequency", "daily"),
            "--hour", int(automation.get("hour", 8)),
            "--minute", int(automation.get("minute", 0)),
            "--weekly-day", automation.get("weeklyDay", "Monday"),
        ]
        if automation.get("weekdaysOnly"):
            command.append("--weekdays-only")
        result = run(*command)

    if automation.get("schedulerBackend") == "assistant" and not automation.get("legacyAssistantAutomationID"):
        old_identifier = str(automation.get("automationID") or "")
        if old_identifier and old_identifier != LABEL:
            automation["legacyAssistantAutomationID"] = old_identifier
    automation["schedulerBackend"] = "local"
    automation["automationID"] = LABEL
    automation["needsCodexSync"] = False
    automation["lastSyncedAt"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    atomic_json(config_path, config)

    print(result.stdout.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
