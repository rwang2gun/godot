#!/usr/bin/env python3
"""
Harness Executor — Phase 순차 실행 + 상태 관리 + 자동 커밋

Usage:
    python scripts/execute.py <task-name>                  # 상태 표시
    python scripts/execute.py <task-name> next             # 다음 pending Phase 내용 출력
    python scripts/execute.py <task-name> complete <N>     # Phase N 완료 + 자동 커밋
    python scripts/execute.py <task-name> reset            # status.json 리셋
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
PHASES_DIR = ROOT / "phases"


def task_dir(task: str) -> Path:
    return PHASES_DIR / task


def status_file(task: str) -> Path:
    return task_dir(task) / "status.json"


def discover_phase_files(task: str) -> list[Path]:
    d = task_dir(task)
    if not d.exists():
        return []
    return sorted(p for p in d.glob("phase*.md"))


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return {}
    fm = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            fm[key.strip()] = value.strip()
    return fm


def derive_phase_name(path: Path, fm: dict) -> str:
    if "name" in fm:
        return fm["name"]
    stem = path.stem  # phaseNN-slug
    parts = stem.split("-", 1)
    return parts[1] if len(parts) > 1 else stem


def init_status(task: str) -> dict:
    files = discover_phase_files(task)
    if not files:
        sys.exit(f"No phase files in {task_dir(task)}")
    phases = []
    for i, f in enumerate(files):
        fm = parse_frontmatter(f)
        phases.append({
            "id": i + 1,
            "file": f.name,
            "name": derive_phase_name(f, fm),
            "duration_estimate": int(fm.get("duration_estimate", "0") or 0),
            "verify": fm.get("verify", ""),
            "state": "pending",
            "started_at": None,
            "completed_at": None,
            "duration_seconds": None,
        })
    status = {
        "task": task,
        "started_at": datetime.now().isoformat(timespec="seconds"),
        "completed_at": None,
        "phases": phases,
    }
    save_status(task, status)
    return status


def load_status(task: str) -> dict:
    sf = status_file(task)
    if not sf.exists():
        return init_status(task)
    return json.loads(sf.read_text(encoding="utf-8"))


def save_status(task: str, status: dict) -> None:
    status_file(task).write_text(
        json.dumps(status, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def cmd_status(task: str) -> None:
    status = load_status(task)
    pending = [p for p in status["phases"] if p["state"] != "completed"]

    print("=" * 60)
    print("Harness Executor")
    print(f"Task: {task} | Phases: {len(status['phases'])} | Pending: {len(pending)}")
    print("=" * 60)
    print()

    for p in status["phases"]:
        if p["state"] == "completed":
            mark = "✓"
            dur = f"[{p['duration_seconds']}s]" if p["duration_seconds"] else ""
        elif p["state"] == "in_progress":
            mark = "→"
            dur = "[in progress]"
        else:
            mark = " "
            dur = f"[~{p['duration_estimate']}s]" if p["duration_estimate"] else ""
        print(f"  {mark} Phase {p['id']}: {p['name']} {dur}")

    print()
    print("=" * 60)
    if not pending:
        total = sum(p["duration_seconds"] or 0 for p in status["phases"])
        print(f"Task '{task}' completed!")
        print(f"Total duration: {total // 60}m {total % 60}s")
    else:
        nxt = pending[0]
        print(f"Next: Phase {nxt['id']} — {nxt['name']}")
        print(f"Run: python scripts/execute.py {task} next")
    print("=" * 60)


def cmd_next(task: str) -> None:
    status = load_status(task)
    pending = [p for p in status["phases"] if p["state"] != "completed"]
    if not pending:
        print(f"Task '{task}' already completed.")
        return
    p = pending[0]
    p["state"] = "in_progress"
    p["started_at"] = datetime.now().isoformat(timespec="seconds")
    save_status(task, status)

    fp = task_dir(task) / p["file"]
    print(f"=== Phase {p['id']}: {p['name']} ===")
    print()
    print(fp.read_text(encoding="utf-8"))
    print()
    print(f"After completion, run: python scripts/execute.py {task} complete {p['id']}")


def cmd_complete(task: str, phase_id: int) -> None:
    status = load_status(task)
    target = next((p for p in status["phases"] if p["id"] == phase_id), None)
    if not target:
        sys.exit(f"Phase {phase_id} not found")
    if target["state"] == "completed":
        print(f"Phase {phase_id} already completed.")
        return

    if target.get("verify"):
        print(f"Running verify: {target['verify']}")
        result = subprocess.run(target["verify"], shell=True, cwd=ROOT)
        if result.returncode != 0:
            sys.exit(f"Verify failed for Phase {phase_id} (exit {result.returncode})")

    target["state"] = "completed"
    target["completed_at"] = datetime.now().isoformat(timespec="seconds")
    if target["started_at"]:
        delta = datetime.fromisoformat(target["completed_at"]) - datetime.fromisoformat(target["started_at"])
        target["duration_seconds"] = int(delta.total_seconds())
    save_status(task, status)

    print(f"✓ Phase {phase_id}: {target['name']} completed")

    subprocess.run(["git", "add", "-A"], cwd=ROOT, check=False)
    msg = f"phase {phase_id}: {target['name']}"
    result = subprocess.run(
        ["git", "commit", "-m", msg],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        print(f"  → committed: {msg}")
    else:
        stdout = (result.stdout or "").strip()
        if "nothing to commit" in stdout:
            print("  → no changes to commit")
        else:
            print(f"  ! commit skipped: {stdout or result.stderr.strip()}")

    pending = [p for p in status["phases"] if p["state"] != "completed"]
    if not pending:
        status["completed_at"] = datetime.now().isoformat(timespec="seconds")
        save_status(task, status)
        total = sum(p["duration_seconds"] or 0 for p in status["phases"])
        print()
        print("=" * 60)
        print(f"Task '{task}' completed!")
        print(f"Total duration: {total // 60}m {total % 60}s")
        print("=" * 60)


def cmd_reset(task: str) -> None:
    sf = status_file(task)
    if sf.exists():
        sf.unlink()
        print(f"Reset status for task '{task}'")
    else:
        print(f"No status to reset for task '{task}'")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__.strip())
    task = sys.argv[1]
    if not task_dir(task).exists():
        sys.exit(f"Task directory not found: {task_dir(task)}")

    cmd = sys.argv[2] if len(sys.argv) > 2 else "status"
    if cmd == "status":
        cmd_status(task)
    elif cmd == "next":
        cmd_next(task)
    elif cmd == "complete":
        if len(sys.argv) < 4:
            sys.exit("Usage: python scripts/execute.py <task> complete <phase-id>")
        cmd_complete(task, int(sys.argv[3]))
    elif cmd == "reset":
        cmd_reset(task)
    else:
        sys.exit(f"Unknown command: {cmd}")


if __name__ == "__main__":
    main()
