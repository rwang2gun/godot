#!/usr/bin/env python3
"""
Dangerous Cmd Guard — 위험한 셸 명령을 실행 전에 BLOCK.

대상: Bash 도구의 command 인자
패턴: rm -rf, force push, git reset --hard, --no-verify, fork bomb 등

Exit code:
  0 = 통과
  2 = block (Claude에 stderr 메시지 표시)
"""
from __future__ import annotations

import json
import re
import sys

if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

DANGEROUS_PATTERNS: list[tuple[str, str]] = [
    (r"\brm\s+-[rRfF]+\s+/(\s|$)", "rm -rf / (루트 삭제)"),
    (r"\brm\s+-[rRfF]+\s+\.[\\/]?(\s|$)", "rm -rf . (현재 디렉토리 삭제)"),
    (r"\brm\s+-[rRfF]+\s+\*", "rm -rf 와일드카드"),
    (r"\bgit\s+push\b.*--force(?!-with-lease)\b", "git push --force (--force-with-lease 권장)"),
    (r"\bgit\s+push\b.*\s-f(\s|$)", "git push -f"),
    (r"\bgit\s+reset\s+--hard\b", "git reset --hard"),
    (r"\bgit\s+clean\s+-[fdxFDX]+\b", "git clean -fdx (untracked 일괄 삭제)"),
    (r"\bgit\s+checkout\s+\.(\s|$)", "git checkout . (변경 일괄 폐기)"),
    (r"\bgit\s+restore\s+\.(\s|$)", "git restore . (변경 일괄 폐기)"),
    (r"\bgit\s+branch\s+-D\b", "git branch -D (강제 삭제)"),
    (r"--no-verify\b", "git hook 우회 (--no-verify)"),
    (r":\(\)\s*\{.*\}\s*;\s*:", "fork bomb"),
    (r"\bdd\s+if=.*of=/dev/", "dd to device (디스크 덮어쓰기)"),
    (r"\bmkfs\.", "mkfs (파일시스템 포맷)"),
]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    if payload.get("tool_name") != "Bash":
        return 0
    cmd = payload.get("tool_input", {}).get("command", "")
    if not cmd:
        return 0

    for pattern, label in DANGEROUS_PATTERNS:
        if re.search(pattern, cmd):
            sys.stderr.write(
                f"BLOCKED by Dangerous Cmd Guard\n"
                f"  패턴: {label}\n"
                f"  명령: {cmd}\n"
                f"  의도가 분명하면 사용자에게 확인 후 다른 안전한 방식으로 실행하세요.\n"
            )
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
