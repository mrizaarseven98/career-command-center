---
description: Synchronize Career Command Center scheduling with Claude
argument-hint: "[workspace path]"
---

Use the `career-command-center` skill to render the saved automation specification for `$ARGUMENTS`, or the active workspace when omitted. Create or update one matching Claude Code `/schedule` job only when it can access the selected local workspace. Never create a duplicate, and mark synchronization only after the real scheduled-job operation succeeds. If local workspace access is unavailable, leave the app unsynchronized and explain the exact blocker.
