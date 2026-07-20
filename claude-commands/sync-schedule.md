---
description: Save the Career Command Center local Claude CLI schedule
argument-hint: "[workspace path]"
---

Use the `career-command-center` skill and `scripts/sync_local_schedule.py` to register or remove the app-owned macOS schedule for `$ARGUMENTS`, or the active workspace when omitted. Use provider `claude`. Do not create a Claude Code `/schedule` job. Verify that the signed runner is loaded, report the next saved cadence, and identify any older assistant-managed schedule that must be disabled to prevent duplicates.
