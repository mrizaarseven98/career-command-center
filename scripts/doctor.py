#!/usr/bin/env python3
"""Diagnose workspace and app readiness for Career Command Center."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    workspace = args.workspace.expanduser().resolve()
    errors: list[str] = []
    warnings: list[str] = []

    required = [
        "Config/command_center_config.json",
        "State/cv_command_center_state.json",
        "Evidence_Bank/CV_GENERATION_STANDARD.md",
        "Evidence_Bank/WORKSPACE_CONTRACT.md",
        "Evidence_Bank/approved_evidence.json",
    ]
    for relative in required:
        if not (workspace / relative).exists():
            errors.append(f"Missing {relative}")

    config: dict = {}
    config_path = workspace / "Config/command_center_config.json"
    if config_path.exists():
        try:
            config = json.loads(config_path.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"Invalid config JSON: {exc}")
    if config and not config.get("onboarding_completed"):
        errors.append("First-use onboarding is not complete")
    if config and not (config.get("profile") or {}).get("fullName"):
        errors.append("Candidate full name is missing")
    if config and not (config.get("search") or {}).get("countries"):
        errors.append("No target countries are configured")

    state_path = workspace / "State/cv_command_center_state.json"
    if state_path.exists():
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            if not isinstance(state.get("leads"), list):
                errors.append("State leads is not an array")
        except Exception as exc:
            errors.append(f"Invalid state JSON: {exc}")

    evidence_path = workspace / "Evidence_Bank/approved_evidence.json"
    masters: list[str] = []
    has_evidence_blocks = False
    if evidence_path.exists():
        try:
            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            registered = evidence.get("approved_master_cvs") or {}
            masters = list(registered.values()) if isinstance(registered, dict) else list(registered)
            has_evidence_blocks = bool(evidence.get("evidence_blocks"))
            if not has_evidence_blocks:
                warnings.append("Evidence audit has not approved any evidence blocks")
        except Exception as exc:
            errors.append(f"Invalid evidence JSON: {exc}")
    if not masters:
        masters = list((config.get("cv") or {}).get("selectedMasterPaths") or [])
    missing_masters = [path for path in masters if not Path(path).expanduser().exists()]
    if not masters:
        warnings.append("No approved role-family master CVs are registered")
    elif missing_masters:
        warnings.append(f"{len(missing_masters)} registered master CV path(s) do not exist")

    ledger_path = workspace / "Evidence_Bank/Verified_Evidence_Ledger.md"
    if not ledger_path.exists() and not has_evidence_blocks:
        warnings.append("Narrative evidence ledger has not been created")

    document_count = sum(1 for path in (workspace / "Documents").rglob("*") if path.is_file())
    project_count = sum(1 for path in (workspace / "Projects").rglob("*") if path.is_file())
    if document_count == 0 and project_count == 0 and not has_evidence_blocks:
        warnings.append("No source documents or project files have been imported")

    ready = not errors and not any(
        text.startswith("Evidence audit") or text.startswith("No approved")
        for text in warnings
    )
    result = {
        "workspace": str(workspace),
        "ready_for_automation": ready,
        "errors": errors,
        "warnings": warnings,
        "documents": document_count,
        "project_files": project_count,
        "approved_masters": len(masters) - len(missing_masters),
    }
    print(json.dumps(result, indent=2))
    if errors:
        return 2
    if args.strict and warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
