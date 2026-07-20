#!/usr/bin/env python3
"""Exercise the signed CLI runner and isolated LaunchAgent registration flow."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import plistlib
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

def run(*args: object, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(value) for value in args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    args = parser.parse_args()
    runner = args.app / "Contents/Helpers/CareerCommandCenterRunner"
    if not runner.is_file() or not os.access(runner, os.X_OK):
        raise SystemExit(f"Background runner is missing at {runner}")

    with tempfile.TemporaryDirectory(prefix="career-command-center-scheduler-") as temporary:
        root = Path(temporary)
        workspace = root / "Workspace"
        automation = workspace / "Automation"
        logs = workspace / "Logs"
        automation.mkdir(parents=True)
        logs.mkdir()
        prompt = automation / "scheduled_search_prompt.txt"
        prompt.write_text("Run the isolated scheduler integration test.", encoding="utf-8")

        capture = root / "assistant-arguments.txt"
        assistant = root / "fake-codex"
        assistant.write_text(
            "#!/bin/sh\nprintf '%s\\n' \"$@\" > \"$FAKE_ASSISTANT_CAPTURE\"\n",
            encoding="utf-8",
        )
        assistant.chmod(0o755)
        environment = dict(os.environ)
        environment["FAKE_ASSISTANT_CAPTURE"] = str(capture)

        run(
            runner,
            "run",
            "--workspace", workspace,
            "--provider", "codex",
            "--assistant-executable", assistant,
            "--prompt-file", prompt,
            env=environment,
        )
        runtime = json.loads((automation / "scheduler_runtime.json").read_text(encoding="utf-8"))
        assert runtime["state"] == "completed"
        assert runtime["exit_code"] == 0
        assert Path(runtime["log_path"]).is_file()
        captured = capture.read_text(encoding="utf-8")
        assert "--search" in captured
        assert "--ask-for-approval" in captured
        assert "never" in captured
        assert str(workspace) in captured
        assert "isolated scheduler integration test" in captured

        lock_path = automation / "search-run.lock"
        with lock_path.open("a+") as lock_handle:
            fcntl.flock(lock_handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            run(
                runner,
                "run",
                "--workspace", workspace,
                "--provider", "codex",
                "--assistant-executable", assistant,
                "--prompt-file", prompt,
                env=environment,
            )
        skipped = json.loads((automation / "scheduler_runtime.json").read_text(encoding="utf-8"))
        assert skipped["state"] == "skipped"

        fake_home = root / "Home"
        fake_launchctl = root / "fake-launchctl"
        fake_launchctl.write_text(
            "#!/bin/sh\nif [ \"$1\" = \"print\" ]; then printf 'state = not running\\n'; fi\nexit 0\n",
            encoding="utf-8",
        )
        fake_launchctl.chmod(0o755)
        schedule_environment = dict(environment)
        schedule_environment["CAREER_COMMAND_CENTER_LAUNCH_AGENT_HOME"] = str(fake_home)
        schedule_environment["CAREER_COMMAND_CENTER_LAUNCHCTL_EXECUTABLE"] = str(fake_launchctl)
        label = "com.careercommandcenter.search.test"
        result = run(
            runner,
            "schedule", "install",
            "--label", label,
            "--workspace", workspace,
            "--provider", "codex",
            "--assistant-executable", assistant,
            "--prompt-file", prompt,
            "--frequency", "daily",
            "--weekdays-only",
            "--hour", "8",
            "--minute", "15",
            env=schedule_environment,
        )
        status = json.loads(result.stdout)
        assert status["installed"] is True
        assert status["loaded"] is True

        launch_agent = fake_home / "Library/LaunchAgents" / f"{label}.plist"
        with launch_agent.open("rb") as handle:
            payload = plistlib.load(handle)
        assert payload["Label"] == label
        assert payload["ProgramArguments"][0] == str(runner)
        intervals = payload["StartCalendarInterval"]
        assert [value["Weekday"] for value in intervals] == [1, 2, 3, 4, 5]
        assert all(value["Hour"] == 8 and value["Minute"] == 15 for value in intervals)

        removed = run(
            runner,
            "schedule", "remove",
            "--label", label,
            env=schedule_environment,
        )
        assert json.loads(removed.stdout)["installed"] is False
        assert not launch_agent.exists()

        config_directory = workspace / "Config"
        config_directory.mkdir()
        config_path = config_directory / "command_center_config.json"
        config_path.write_text(
            json.dumps(
                {
                    "version": 2,
                    "automation": {
                        "enabled": True,
                        "frequency": "weekly",
                        "weeklyDay": "Wednesday",
                        "weekdaysOnly": False,
                        "hour": 9,
                        "minute": 30,
                        "automationID": "legacy-assistant-task",
                        "schedulerBackend": "assistant",
                        "needsCodexSync": True,
                    },
                }
            ),
            encoding="utf-8",
        )
        schedule_environment["CAREER_COMMAND_CENTER_CODEX_EXECUTABLE"] = str(assistant)
        run(
            "python3",
            ROOT / "scripts/sync_local_schedule.py",
            workspace,
            "--provider", "codex",
            "--app", args.app,
            "--skip-readiness-check",
            env=schedule_environment,
        )
        synchronized = json.loads(config_path.read_text(encoding="utf-8"))["automation"]
        assert synchronized["schedulerBackend"] == "local"
        assert synchronized["automationID"] == "com.careercommandcenter.search"
        assert synchronized["legacyAssistantAutomationID"] == "legacy-assistant-task"
        assert synchronized["needsCodexSync"] is False
        with (
            fake_home / "Library/LaunchAgents/com.careercommandcenter.search.plist"
        ).open("rb") as handle:
            weekly_payload = plistlib.load(handle)
        assert weekly_payload["StartCalendarInterval"]["Weekday"] == 3
        assert weekly_payload["StartCalendarInterval"]["Hour"] == 9
        assert weekly_payload["StartCalendarInterval"]["Minute"] == 30

    print("Scheduled runner tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
