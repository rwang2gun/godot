#!/usr/bin/env python3
"""
Check tone-policy compliance — scan files for forbidden vocabulary.

Forbidden tokens (per `docs/PHASE_14_OPTION_B_PROPOSAL.md` §0.2):
    die(), Dead, 사망, 죽

Exemption: `docs/PHASE_14_OPTION_B_PROPOSAL.md` §0.2 definition section
           — between `### 0.2 톤 폴리시` heading and the next `### ` heading.
The exemption is structural (section boundary), not line-number-based, so it
remains valid through frontmatter bumps and version history additions.

Usage:
    python scripts/check_tone_policy.py --commit1
        Scans PROPOSAL.md only. Use during Commit 1 self-review, before new
        phase files exist.
    python scripts/check_tone_policy.py --commit3
        Scans PROPOSAL.md + 7 new phase files. Use after Commit 3 phase file
        creation step, before sync-status.

Exit codes:
    0  pass (zero hits outside exemption)
    1  fail (forbidden token hits found — replace with §0.2 vocabulary)
    2  missing target file (terminating error)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PROPOSAL_PATH = Path("docs/PHASE_14_OPTION_B_PROPOSAL.md")

NEW_PHASE_FILES = [
    Path("phases/mvp/phase14-mechanic-adaptation-traits.md"),
    Path("phases/mvp/phase15-mechanic-adaptation-settlement.md"),
    Path("phases/mvp/phase16-mechanic-creation.md"),
    Path("phases/mvp/phase17-mechanic-hazard.md"),
    Path("phases/mvp/phase18-mechanic-destruction-earth.md"),
    Path("phases/mvp/phase19-mechanic-destruction-plant.md"),
    Path("phases/mvp/phase20-polish.md"),
]

FORBIDDEN_RE = re.compile(r"die\(\)|Dead|사망|죽")
EXEMPTION_START_RE = re.compile(r"^###\s+0\.2(\s|$)")
ANY_LEVEL3_HEADING_RE = re.compile(r"^###\s")


def scan_file(path: Path) -> list[tuple[int, str]]:
    """Return [(line_number, line_text)] for forbidden hits outside exemption."""
    if not path.exists():
        raise FileNotFoundError(f"Missing target file: {path}")

    lines = path.read_text(encoding="utf-8").splitlines()
    hits: list[tuple[int, str]] = []
    in_exemption = False

    for lineno, line in enumerate(lines, start=1):
        if path == PROPOSAL_PATH:
            if EXEMPTION_START_RE.match(line):
                in_exemption = True
                continue
            if in_exemption and ANY_LEVEL3_HEADING_RE.match(line):
                in_exemption = False
                # fall through — check this non-exempt heading line for hits
            if in_exemption:
                continue
        if FORBIDDEN_RE.search(line):
            hits.append((lineno, line))
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify tone-policy compliance for Option B docs.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--commit1",
        action="store_true",
        help="Scan PROPOSAL.md only (Commit 1 self-review timing).",
    )
    mode.add_argument(
        "--commit3",
        action="store_true",
        help="Scan PROPOSAL.md + 7 new phase files (Commit 3 post-write timing).",
    )
    args = parser.parse_args()

    targets: list[Path] = [PROPOSAL_PATH]
    if args.commit3:
        targets.extend(NEW_PHASE_FILES)

    total_hits = 0
    for target in targets:
        try:
            hits = scan_file(target)
        except FileNotFoundError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 2
        if hits:
            print(f"\n=== {target} ===")
            for lineno, text in hits:
                print(f"  {target}:{lineno}: {text.rstrip()}")
            total_hits += len(hits)

    if total_hits:
        print(
            f"\nFAIL: {total_hits} forbidden token hit(s) outside exemption "
            f"across {len(targets)} file(s). Replace with §0.2 policy vocabulary.",
            file=sys.stderr,
        )
        return 1

    print(f"PASS: 0 forbidden token hits across {len(targets)} file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
