#!/usr/bin/env python3
"""
Harness Executor v3 — Phase orchestration with metadata + safe staging.

Usage:
    python scripts/execute.py <task>                              # show status
    python scripts/execute.py <task> next                         # show next pending phase
    python scripts/execute.py <task> validate                     # validate metadata + frontmatter + status
    python scripts/execute.py <task> sync-status [opts]           # reconcile status.json with phase files
    python scripts/execute.py <task> complete <N>                 # safely stage + commit + mark phase complete
    python scripts/execute.py <task> reset                        # delete status.json

sync-status options:
    --prune-missing             remove pending entries whose phase file is missing
    --force-prune-completed     also remove completed entries whose phase file is missing
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


def _git_project_prefix() -> str:
    """Path of ROOT relative to git toplevel as POSIX, with trailing '/'. Empty when ROOT is repo root."""
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=ROOT, capture_output=True, check=True, text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""
    top = Path(res.stdout.strip())
    try:
        rel = ROOT.resolve().relative_to(top.resolve())
    except ValueError:
        return ""
    s = str(rel).replace("\\", "/")
    return "" if s in ("", ".") else s + "/"


_PROJECT_PREFIX_CACHE: str | None = None


def project_prefix() -> str:
    global _PROJECT_PREFIX_CACHE
    if _PROJECT_PREFIX_CACHE is None:
        _PROJECT_PREFIX_CACHE = _git_project_prefix()
    return _PROJECT_PREFIX_CACHE


def _strip_prefix(path: str) -> str | None:
    """Strip project prefix; return None if path is outside the project subtree."""
    pp = project_prefix()
    if not pp:
        return path
    if path.startswith(pp):
        return path[len(pp):]
    return None

# ---------------------------------------------------------------------------
# Known task defaults — the v3 implementation hardcodes only `mvp`.
# Other tasks must ship their own phases/<task>/metadata.json.
# ---------------------------------------------------------------------------
KNOWN_TASK_DEFAULTS: dict[str, dict] = {
    "mvp": {
        "schema_version": 1,
        "task": "mvp",
        "active_revision": "phases/mvp/REVISION_2026-05-09.md",
        "post_mvp_phase_range": [21, 23],
        "notes": [
            "status.json is runtime state only.",
            "local phase files are discovered dynamically from phases/<task>/phase*.md.",
        ],
    },
}


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def task_dir(task: str) -> Path:
    return PHASES_DIR / task


def status_file(task: str) -> Path:
    return task_dir(task) / "status.json"


def metadata_file(task: str) -> Path:
    return task_dir(task) / "metadata.json"


def discover_phase_files(task: str) -> list[Path]:
    d = task_dir(task)
    if not d.exists():
        return []
    # Exclude `phaseNN-deferred.md` — CLAUDE.md allows that naming for impl-review
    # MEDIUM/LOW deferral notes; they are sibling documentation, not phases.
    return sorted(p for p in d.glob("phase*.md") if not p.stem.endswith("-deferred"))


def to_posix(path: str) -> str:
    return path.replace("\\", "/")


_NOTIFY_ENABLED: bool = False  # Opt-in gate. Set by --notify CLI flag in main().


def _notify(message: str) -> None:
    """Best-effort Discord notification via scripts/notify.py.

    Gated behind explicit `--notify` CLI flag (codex impl-review HIGH 2026-05-10):
    do NOT auto-fire just because DISCORD_WEBHOOK_URL is set in the environment.
    Phase task names, commit SHAs, durations, and verify command output are sent
    to the configured webhook only when the operator opts in at the call site.
    """
    if not _NOTIFY_ENABLED:
        return
    try:
        notify_script = ROOT / "scripts" / "notify.py"
        if not notify_script.exists():
            return
        subprocess.run(
            [sys.executable, str(notify_script), message],
            cwd=ROOT, capture_output=True, timeout=15,
        )
    except Exception:
        pass


def _short_head() -> str:
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        return res.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "?"


# ---------------------------------------------------------------------------
# Frontmatter parser — Plan v3 §5
# ---------------------------------------------------------------------------

class FrontmatterError(ValueError):
    pass


_PATH_OK = re.compile(r"^[^\s,\[\]'\"]+$")  # POSIX-style path, no spaces/commas/brackets/quotes


def _check_path(raw: str, *, key: str, src: str, lineno: int) -> str:
    if raw != raw.strip():
        raise FrontmatterError(f"{src}:{lineno} {key!r} has leading/trailing whitespace")
    if not raw:
        raise FrontmatterError(f"{src}:{lineno} {key!r} is empty")
    if not _PATH_OK.match(raw):
        raise FrontmatterError(f"{src}:{lineno} {key!r} contains forbidden characters: {raw!r}")
    return raw


def _parse_inline_array(raw: str, *, key: str, src: str, lineno: int) -> list[str]:
    s = raw.strip()
    if s == "" or s == "[]":
        return []
    if not (s.startswith("[") and s.endswith("]")):
        raise FrontmatterError(
            f"{src}:{lineno} {key!r} must be inline array '[a, b]' or empty (got {s!r})"
        )
    inner = s[1:-1]
    if not inner.strip():
        return []
    paths: list[str] = []
    for chunk in inner.split(","):
        item = chunk.strip()
        if item.startswith("'") or item.startswith('"'):
            raise FrontmatterError(f"{src}:{lineno} {key!r} array items must not be quoted")
        paths.append(_check_path(item, key=key, src=src, lineno=lineno))
    return paths


def parse_frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\r?\n(.*?)\r?\n---", text, re.DOTALL)
    if not m:
        raise FrontmatterError(f"{path.name}: missing YAML frontmatter")
    fm: dict = {"sot_aux": [], "verify": "", "large_change_ok": False}
    src = path.name
    for i, raw in enumerate(m.group(1).splitlines(), start=1):
        line = raw.rstrip()
        if not line.strip():
            continue
        if ":" not in line:
            raise FrontmatterError(f"{src}:{i} no colon in {line!r}")
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if key == "name":
            if not value:
                raise FrontmatterError(f"{src}:{i} 'name' is empty")
            fm["name"] = value
        elif key == "duration_estimate":
            try:
                fm["duration_estimate"] = int(value or "0")
            except ValueError:
                raise FrontmatterError(f"{src}:{i} 'duration_estimate' not int: {value!r}")
        elif key == "verify":
            fm["verify"] = value
        elif key == "large_change_ok":
            v = value.lower()
            if v in ("", "false"):
                fm["large_change_ok"] = False
            elif v == "true":
                fm["large_change_ok"] = True
            else:
                raise FrontmatterError(f"{src}:{i} 'large_change_ok' must be true/false/empty: {value!r}")
        elif key == "sot":
            if value == "self":
                raise FrontmatterError(f"{src}:{i} 'sot: self' is forbidden (Plan v3 §3.2)")
            fm["sot"] = _check_path(value, key="sot", src=src, lineno=i)
        elif key == "sot_aux":
            fm["sot_aux"] = _parse_inline_array(value, key="sot_aux", src=src, lineno=i)
        else:
            fm[key] = value
    if "name" not in fm:
        raise FrontmatterError(f"{src}: missing 'name'")
    if "duration_estimate" not in fm:
        raise FrontmatterError(f"{src}: missing 'duration_estimate'")
    if "sot" not in fm:
        raise FrontmatterError(f"{src}: missing 'sot'")
    return fm


# ---------------------------------------------------------------------------
# Glob → regex matcher (POSIX-style paths)
# ---------------------------------------------------------------------------

def _glob_to_regex(pattern: str) -> re.Pattern:
    out: list[str] = []
    i = 0
    while i < len(pattern):
        c = pattern[i]
        if c == "*":
            if i + 1 < len(pattern) and pattern[i + 1] == "*":
                if i + 2 < len(pattern) and pattern[i + 2] == "/":
                    out.append("(?:.*/)?")
                    i += 3
                    continue
                out.append(".*")
                i += 2
                continue
            out.append("[^/]*")
            i += 1
        elif c == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(c))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def _expand_task(pattern: str, task: str) -> str:
    return pattern.replace("{task}", task)


# ---------------------------------------------------------------------------
# Stage policy — Plan v3 §7
# ---------------------------------------------------------------------------

DENY_PATTERNS = [
    ".git/**",
    ".godot/**",
    ".import/**",
    "node_modules/**",
    "**/node_modules/**",
    ".venv/**",
    "venv/**",
    "__pycache__/**",
    "**/__pycache__/**",
    "**/*.pyc",
    "**/.DS_Store",
    "**/Thumbs.db",
    "**/*.tmp",
    "**/*.temp",
    "**/*.log",
    "**/*.bak",
    "export/**",
    "build/**",
    "dist/**",
    "docs/design_handoff/**",
    ".claude/settings.local.json",
]

WHITELIST_PATTERNS = [
    # Godot runtime
    "project.godot",
    "scenes/**",
    "scripts/**",
    "data/**",
    "assets/**",
    "art/**",
    "audio/**",
    "theme/**",
    "themes/**",
    "fonts/**",
    "addons/**",
    # Tests
    "tests/**",
    # Godot metadata
    "**/*.uid",
    "**/*.import",
    # Harness/docs
    ".gitignore",
    ".claude/commands/**",
    ".claude/agents/**",
    ".claude/hooks/**",
    ".claude/settings.json",
    "CLAUDE.md",
    "docs/**/*.md",
    "phases/{task}/phase*.md",
    "phases/{task}/plans/*.md",
    "phases/{task}/reviews/*.md",
    "phases/{task}/status.json",
    "phases/{task}/metadata.json",
    "phases/{task}/notion-phase-ids.json",
    "phases/{task}/README.md",
    "phases/{task}/REVISION_*.md",
]

LARGE_FILE_BYTES = 5 * 1024 * 1024
LARGE_TOTAL_BYTES = 25 * 1024 * 1024
LARGE_COUNT = 100


def _compile_patterns(patterns: list[str], task: str) -> list[re.Pattern]:
    return [_glob_to_regex(_expand_task(p, task)) for p in patterns]


def _matches_any(path: str, regexes: list[re.Pattern]) -> bool:
    return any(rx.match(path) for rx in regexes)


# ---------------------------------------------------------------------------
# git status --porcelain=v2 -z parsing
# ---------------------------------------------------------------------------

def _git_status_v2() -> tuple[list[tuple[str, str]], list[str], list[str]]:
    """Return (changes, renames_or_copies, untracked) using porcelain=v2 -z.

    changes: list of (status_letter, posix_path) for ordinary tracked changes.
    renames_or_copies: posix paths that triggered R/C/U entries.
    untracked: posix paths from `?` records.
    """
    res = subprocess.run(
        ["git", "status", "--porcelain=v2", "-z", "--untracked-files=all"],
        cwd=ROOT, capture_output=True, check=True,
    )
    parts = res.stdout.split(b"\x00")
    changes: list[tuple[str, str]] = []
    renames: list[str] = []
    untracked: list[str] = []

    i = 0
    while i < len(parts):
        rec = parts[i]
        if not rec:
            i += 1
            continue
        try:
            line = rec.decode("utf-8")
        except UnicodeDecodeError:
            line = rec.decode("utf-8", errors="replace")
        kind = line[:1]
        if kind == "1":
            tokens = line.split(" ", 8)
            if len(tokens) < 9:
                i += 1
                continue
            xy = tokens[1]
            raw_path = tokens[8]
            sx, sy = xy[0], xy[1]
            status = sx if sx != "." else sy
            stripped = _strip_prefix(to_posix(raw_path))
            if stripped is not None:
                changes.append((status, stripped))
            i += 1
        elif kind == "2":
            tokens = line.split(" ", 9)
            if len(tokens) < 10:
                i += 1
                continue
            new_path = tokens[9]
            stripped = _strip_prefix(to_posix(new_path))
            if stripped is not None:
                renames.append(stripped)
            # next NUL-separated chunk is original path; consume it
            i += 2
        elif kind == "?":
            stripped = _strip_prefix(to_posix(line[2:]))
            if stripped is not None:
                untracked.append(stripped)
            i += 1
        elif kind == "u":
            tokens = line.split(" ")
            if tokens:
                stripped = _strip_prefix(to_posix(tokens[-1]))
                if stripped is not None:
                    renames.append(stripped)
            i += 1
        else:
            i += 1

    return changes, renames, untracked


# ---------------------------------------------------------------------------
# Metadata bootstrap — Plan v3 §4
# ---------------------------------------------------------------------------

def load_or_bootstrap_metadata(task: str, *, allow_create: bool) -> dict:
    mf = metadata_file(task)
    if mf.exists():
        return json.loads(mf.read_text(encoding="utf-8"))
    if not allow_create:
        sys.exit(f"metadata.json not found at {mf}. Run 'validate' first.")
    if task not in KNOWN_TASK_DEFAULTS:
        sys.exit(
            f"metadata.json missing for task {task!r} and no built-in default exists.\n"
            f"Create {mf} manually with at minimum: schema_version, task, active_revision."
        )
    data = json.loads(json.dumps(KNOWN_TASK_DEFAULTS[task]))  # deep copy
    mf.parent.mkdir(parents=True, exist_ok=True)
    mf.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[validate] created default metadata at {mf.relative_to(ROOT)}")
    return data


# ---------------------------------------------------------------------------
# status.json
# ---------------------------------------------------------------------------

def derive_phase_name(path: Path, fm: dict) -> str:
    if fm.get("name"):
        return fm["name"]
    stem = path.stem
    parts = stem.split("-", 1)
    return parts[1] if len(parts) > 1 else stem


def _entry_for(path: Path, fm: dict, phase_id: int) -> dict:
    return {
        "id": phase_id,
        "file": path.name,
        "name": derive_phase_name(path, fm),
        "duration_estimate": int(fm.get("duration_estimate") or 0),
        "verify": fm.get("verify", ""),
        "state": "pending",
        "started_at": None,
        "completed_at": None,
        "duration_seconds": None,
    }


def init_status(task: str) -> dict:
    files = discover_phase_files(task)
    if not files:
        sys.exit(f"No phase files in {task_dir(task)}")
    phases = []
    for i, f in enumerate(files):
        try:
            fm = parse_frontmatter(f)
        except FrontmatterError as e:
            sys.exit(f"Frontmatter error: {e}")
        phases.append(_entry_for(f, fm, i + 1))
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
        json.dumps(status, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

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
    if p["state"] != "in_progress":
        p["state"] = "in_progress"
        p["started_at"] = datetime.now().isoformat(timespec="seconds")
        save_status(task, status)

    fp = task_dir(task) / p["file"]
    fm = parse_frontmatter(fp)
    print(f"=== Phase {p['id']}: {p['name']} ===")
    print()
    print(f"SoT       : {fm['sot']}")
    if fm["sot_aux"]:
        print(f"SoT-aux   : {', '.join(fm['sot_aux'])}")
    print(f"large_change_ok: {fm['large_change_ok']}")
    print()
    print(fp.read_text(encoding="utf-8"))
    print()
    print(f"After completion, run: python scripts/execute.py {task} complete {p['id']}")


def cmd_validate(task: str) -> None:
    metadata = load_or_bootstrap_metadata(task, allow_create=True)
    if metadata.get("task") != task:
        sys.exit(f"metadata.task ({metadata.get('task')!r}) != cli task ({task!r})")
    active = metadata.get("active_revision")
    if not active:
        sys.exit("metadata.active_revision is missing/empty")
    if not (ROOT / active).exists():
        sys.exit(f"metadata.active_revision points to missing file: {active}")

    files = discover_phase_files(task)
    if not files:
        sys.exit(f"No phase files in {task_dir(task)}")

    errors: list[str] = []
    for f in files:
        try:
            fm = parse_frontmatter(f)
        except FrontmatterError as e:
            errors.append(str(e))
            continue
        if not (ROOT / fm["sot"]).exists():
            errors.append(f"{f.name}: sot path does not exist: {fm['sot']}")
        for aux in fm["sot_aux"]:
            if not (ROOT / aux).exists():
                errors.append(f"{f.name}: sot_aux path does not exist: {aux}")

    sf = status_file(task)
    if sf.exists():
        try:
            status = json.loads(sf.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"status.json: invalid JSON: {e}")
        else:
            status_files = {p["file"] for p in status.get("phases", [])}
            disk_files = {f.name for f in files}
            only_status = status_files - disk_files
            only_disk = disk_files - status_files
            if only_status:
                errors.append(
                    f"status.json references missing phase files: {sorted(only_status)} "
                    f"(run sync-status)"
                )
            if only_disk:
                errors.append(
                    f"phase files not tracked in status.json: {sorted(only_disk)} "
                    f"(run sync-status)"
                )

    if errors:
        for e in errors:
            print(f"  ✗ {e}", file=sys.stderr)
        sys.exit(f"validate failed with {len(errors)} error(s)")
    print(f"✓ validate ok — {len(files)} phase files; metadata + frontmatter clean")


def cmd_sync_status(task: str, *, prune_missing: bool, force_prune_completed: bool) -> None:
    sf = status_file(task)
    if not sf.exists():
        init_status(task)
        print(f"[sync-status] initialized {sf.relative_to(ROOT)}")
        return

    status = json.loads(sf.read_text(encoding="utf-8"))
    files = discover_phase_files(task)
    disk_names = [f.name for f in files]
    by_file = {p["file"]: p for p in status.get("phases", [])}

    new_phases: list[dict] = []
    next_id = 1
    for fname in disk_names:
        path = task_dir(task) / fname
        try:
            fm = parse_frontmatter(path)
        except FrontmatterError as e:
            sys.exit(f"sync-status: {e}")
        if fname in by_file:
            entry = dict(by_file[fname])
            entry["id"] = next_id
            entry["name"] = derive_phase_name(path, fm)
            entry["duration_estimate"] = int(fm.get("duration_estimate") or 0)
            entry["verify"] = fm.get("verify", "")
        else:
            entry = _entry_for(path, fm, next_id)
            print(f"  + added pending: {fname}")
        new_phases.append(entry)
        next_id += 1

    disk_set = set(disk_names)
    missing_pending: list[dict] = []
    missing_completed: list[dict] = []
    for p in status.get("phases", []):
        if p["file"] not in disk_set:
            (missing_completed if p.get("state") == "completed" else missing_pending).append(p)

    if missing_pending or missing_completed:
        print("[sync-status] Missing phase files referenced by status.json:")
        for p in missing_pending:
            print(f"  - pending  : {p['file']}")
        for p in missing_completed:
            print(f"  - completed: {p['file']}")

    will_prune = (prune_missing and missing_pending) or (force_prune_completed and missing_completed)
    if will_prune:
        backup = sf.with_suffix(sf.suffix + ".bak")
        backup.write_text(sf.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"  [backup] wrote {backup.relative_to(ROOT)}")

    if prune_missing:
        for p in missing_pending:
            print(f"  - pruned pending  : {p['file']}")
    else:
        for p in missing_pending:
            new_phases.append(dict(p, id=next_id))
            next_id += 1

    if force_prune_completed:
        for p in missing_completed:
            print(f"  - pruned completed: {p['file']}")
    else:
        for p in missing_completed:
            new_phases.append(dict(p, id=next_id))
            next_id += 1

    status["phases"] = new_phases
    save_status(task, status)
    print(f"✓ sync-status complete — {len(new_phases)} phases tracked")


# ---- complete ----

def _staged_paths() -> list[str]:
    res = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "-z"],
        cwd=ROOT, capture_output=True, check=True,
    )
    out: list[str] = []
    for x in res.stdout.decode("utf-8", errors="replace").split("\x00"):
        if not x:
            continue
        stripped = _strip_prefix(to_posix(x))
        if stripped is not None:
            out.append(stripped)
    return out


def _file_size(rel: str) -> int:
    p = ROOT / rel
    try:
        return p.stat().st_size
    except FileNotFoundError:
        return 0  # deletions or staged-only entries


def _classify_changes(task: str) -> tuple[list[str], list[str], list[str]]:
    """Return (candidates, denied, outside) for stage policy.

    `candidates` are unique POSIX paths to auto-stage.
    `denied` are deny-list matches (Plan v3 §6.3 step 8 → reject).
    `outside` are paths not matching whitelist nor deny-list (step 10 → reject).
    """
    deny_re = _compile_patterns(DENY_PATTERNS, task)
    allow_re = _compile_patterns(WHITELIST_PATTERNS, task)

    changes, renames, untracked = _git_status_v2()

    if renames:
        # Plan §6.3 step 9 + §7.4: hard reject and let user resolve.
        sys.exit(
            "Rename/copy detected by `git status --porcelain=v2` (Plan v3 §7.4 blocks auto-stage):\n"
            + "\n".join(f"  R/C: {r}" for r in renames)
            + "\nResolve manually (revert, commit, or split) and retry."
        )

    seen: set[str] = set()
    candidates: list[str] = []
    denied: list[str] = []
    outside: list[str] = []

    def consider(path: str) -> None:
        if path in seen:
            return
        seen.add(path)
        if _matches_any(path, deny_re):
            denied.append(path)
            return
        if _matches_any(path, allow_re):
            candidates.append(path)
        else:
            outside.append(path)

    for _status, path in changes:
        consider(path)
    for path in untracked:
        consider(path)

    return candidates, denied, outside


def _apply_size_guard(candidates: list[str], *, large_change_ok: bool) -> list[str]:
    errors: list[str] = []
    total = 0
    for c in candidates:
        sz = _file_size(c)
        total += sz
        if sz > LARGE_FILE_BYTES:
            errors.append(f"single file >5MB: {c} ({sz} bytes)")
    if total > LARGE_TOTAL_BYTES:
        errors.append(f"total candidate size >25MB: {total} bytes")
    if not large_change_ok and len(candidates) > LARGE_COUNT:
        errors.append(f"candidate count >{LARGE_COUNT}: {len(candidates)}")
    return errors


def cmd_complete(task: str, phase_id: int) -> None:
    status = load_status(task)
    target = next((p for p in status["phases"] if p["id"] == phase_id), None)
    if not target:
        sys.exit(f"Phase {phase_id} not found")
    if target["state"] == "completed":
        print(f"Phase {phase_id} already completed.")
        return

    phase_path = task_dir(task) / target["file"]
    try:
        fm = parse_frontmatter(phase_path)
    except FrontmatterError as e:
        sys.exit(f"complete: {e}")

    # Step 3: verify
    verify = (fm.get("verify") or "").strip()
    if verify:
        print(f"Running verify: {verify}")
        rc = subprocess.run(verify, shell=True, cwd=ROOT)
        if rc.returncode != 0:
            _notify(
                f"🚧 **Phase {phase_id} verify 실패** ({task})\n"
                f"phase: `{target['name']}`\n"
                f"cmd: `{verify}`\n"
                f"exit: {rc.returncode}"
            )
            sys.exit(f"Verify failed for Phase {phase_id} (exit {rc.returncode})")

    # Step 4: review gate
    review_path = task_dir(task) / "reviews" / f"phase{phase_id:02d}-impl-review.md"
    if not review_path.exists() or review_path.stat().st_size == 0:
        sys.exit(
            f"Missing or empty review: {review_path.relative_to(ROOT)}\n"
            f"Plan v3 §6.3 step 4 — adversarial-review must be saved before complete."
        )

    # Steps 5–6: clean-index requirement
    pre_staged = _staged_paths()
    if pre_staged:
        print("Aborting: pre-existing staged files detected (Plan v3 §6.3 step 6 — clean index required).")
        for p in pre_staged:
            print(f"  staged: {p}")
        sys.exit(1)

    # Steps 7–11: classify changes
    candidates, denied, outside = _classify_changes(task)

    if denied:
        print("Deny-listed changes present — clean these up before complete:")
        for p in denied:
            print(f"  ✗ deny: {p}")
        sys.exit("Plan v3 §6.3 step 8 — reject deny-listed changes.")

    if outside:
        print("Untracked/changed files outside the whitelist — investigate and resolve:")
        for p in outside:
            print(f"  ✗ outside whitelist: {p}")
        sys.exit("Plan v3 §6.3 step 10 — reject whitelist-outside changes.")

    if not candidates:
        sys.exit("No stage candidates after filtering. Phase commit must include at least one change.")

    # Step 12: large-change guard
    size_errors = _apply_size_guard(candidates, large_change_ok=fm["large_change_ok"])
    if size_errors:
        print("Large-change guard blocked complete:")
        for e in size_errors:
            print(f"  ✗ {e}")
        sys.exit("Adjust scope or split the phase before retrying.")

    # Step 13: stage in batches
    BATCH = 50
    print(f"Staging {len(candidates)} file(s):")
    for c in candidates:
        print(f"  + {c}")
    staged_by_us: list[str] = []
    for i in range(0, len(candidates), BATCH):
        chunk = candidates[i : i + BATCH]
        rc = subprocess.run(["git", "add", "--", *chunk], cwd=ROOT)
        if rc.returncode != 0:
            print(f"git add failed for batch starting at index {i}; rolling back.", file=sys.stderr)
            if staged_by_us:
                _unstage(staged_by_us)
            sys.exit(1)
        staged_by_us.extend(chunk)

    # Step 15: sanity
    diff_check = subprocess.run(
        ["git", "diff", "--cached", "--name-only"], cwd=ROOT, capture_output=True, text=True,
    )
    if not diff_check.stdout.strip():
        sys.exit("Staged diff is empty after `git add`. Aborting.")

    # Step 16: update status entry
    prev_status_text = status_file(task).read_text(encoding="utf-8")
    target["state"] = "completed"
    target["completed_at"] = datetime.now().isoformat(timespec="seconds")
    if target["started_at"]:
        delta = datetime.fromisoformat(target["completed_at"]) - datetime.fromisoformat(target["started_at"])
        target["duration_seconds"] = int(delta.total_seconds())
    pending = [p for p in status["phases"] if p["state"] != "completed"]
    if not pending:
        status["completed_at"] = datetime.now().isoformat(timespec="seconds")
    save_status(task, status)

    # Step 17: stage status.json
    sf_rel = to_posix(str(status_file(task).relative_to(ROOT)))
    subprocess.run(["git", "add", "--", sf_rel], cwd=ROOT, check=False)
    if sf_rel not in staged_by_us:
        staged_by_us.append(sf_rel)

    # Step 18: commit
    msg = f"phase {phase_id}: {target['name']}"
    commit = subprocess.run(["git", "commit", "-m", msg], cwd=ROOT, capture_output=True, text=True)
    if commit.returncode == 0:
        print(f"✓ Phase {phase_id}: {target['name']} committed")
        print(f"  → {msg}")
        sha = _short_head()
        dur_s = target.get("duration_seconds") or 0
        dur_str = f"{dur_s // 60}m {dur_s % 60}s" if dur_s else "—"
        if not pending:
            total = sum(p["duration_seconds"] or 0 for p in status["phases"])
            print()
            print("=" * 60)
            print(f"Task '{task}' completed!")
            print(f"Total duration: {total // 60}m {total % 60}s")
            print("=" * 60)
            _notify(
                f"🏁 **Task `{task}` 완료** — Phase {phase_id} (`{target['name']}`)\n"
                f"commit: `{sha}` · phase 소요: {dur_str} · 전체: {total // 60}m {total % 60}s"
            )
        else:
            nxt = pending[0]
            _notify(
                f"✅ **Phase {phase_id} 완료** ({task}) — `{target['name']}`\n"
                f"commit: `{sha}` · 소요: {dur_str}\n"
                f"다음: Phase {nxt['id']} `{nxt['name']}`"
            )
        return

    # Step 19: rollback on commit failure
    print("Commit failed — rolling back staged paths and status.json:", file=sys.stderr)
    if commit.stdout:
        print(commit.stdout.strip(), file=sys.stderr)
    if commit.stderr:
        print(commit.stderr.strip(), file=sys.stderr)
    status_file(task).write_text(prev_status_text, encoding="utf-8")
    if not _unstage(staged_by_us):
        print("CRITICAL: cleanup failed. Do NOT proceed to the next phase.", file=sys.stderr)
        _notify(
            f"🚨 **CRITICAL: Phase {phase_id} rollback 실패** ({task})\n"
            f"commit 실패 후 index 정리 실패. 다음 phase 진행 금지, 수동 개입 필요."
        )
        sys.exit(2)
    _notify(
        f"⚠️ **Phase {phase_id} commit 실패** ({task}) — `{target['name']}`\n"
        f"index는 pre-call 상태로 롤백됨. 원인 확인 후 재시도 필요."
    )
    sys.exit("complete failed — index rolled back to pre-call state")


def _unstage(paths: list[str], batch: int = 50) -> bool:
    unique = list(dict.fromkeys(paths))
    ok = True
    for i in range(0, len(unique), batch):
        chunk = unique[i : i + batch]
        res = subprocess.run(["git", "reset", "HEAD", "--", *chunk], cwd=ROOT, capture_output=True)
        if res.returncode != 0:
            ok = False
    return ok


def cmd_reset(task: str) -> None:
    sf = status_file(task)
    if sf.exists():
        sf.unlink()
        print(f"Reset status for task '{task}'")
    else:
        print(f"No status to reset for task '{task}'")


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__.strip())

    # `--notify` opt-in gate (codex impl-review HIGH 2026-05-10):
    # External webhook side effects only when explicitly requested at the call site.
    # Filter the flag out of argv before positional parsing.
    global _NOTIFY_ENABLED
    if "--notify" in sys.argv:
        _NOTIFY_ENABLED = True
        sys.argv = [a for a in sys.argv if a != "--notify"]

    task = sys.argv[1]
    if not task_dir(task).exists():
        sys.exit(f"Task directory not found: {task_dir(task)}")

    cmd = sys.argv[2] if len(sys.argv) > 2 else "status"
    if cmd == "status":
        cmd_status(task)
    elif cmd == "next":
        cmd_next(task)
    elif cmd == "validate":
        cmd_validate(task)
    elif cmd == "sync-status":
        rest = sys.argv[3:]
        cmd_sync_status(
            task,
            prune_missing="--prune-missing" in rest,
            force_prune_completed="--force-prune-completed" in rest,
        )
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
