#!/usr/bin/env python3
"""
Stop 훅 — 턴이 끝날 때마다 내 마지막 답변을 디스코드로 자동 발송.

자동으로 길게 진행할 때 놓치는 결정/완료/블로커를 사용자가 디스코드에서
바로 확인할 수 있도록 하는 안전망. 턴 중간의 즉시 알림은 기존
`scripts/notify.py` 수동 호출 컨벤션이 계속 담당한다.

입력: Stop 이벤트 JSON (stdin) — `transcript_path`에서 마지막 assistant
메시지의 text 블록을 추출한다.
전송: `scripts/notify.py`를 detached(fire-and-forget)로 띄워 webhook POST.
      턴 종료를 막지 않도록 동기 대기하지 않는다.

webhook 미설정/추출 실패/오류는 모두 조용히 통과(return 0) — 알림은
보조 기능이고 turn을 절대 막지 않는다.

테스트: STOP_NOTIFY_DEBUG=1 이면 발송 대신 메시지를 stdout에 출력.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HOOK_DIR = Path(__file__).resolve().parent          # scripts/hooks
NOTIFY = HOOK_DIR.parent / "notify.py"              # scripts/notify.py

HEADER = "🐜 CandyAnts · 턴 종료"
# notify.py가 2000자에서 최종 truncate. 헤더는 앞에 두어 항상 살아남는다.
BODY_MAX = 1800


def _extract_text(content) -> str:
    """assistant content(문자열 또는 블록 리스트)에서 text만 모아 합친다."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                parts.append(str(block.get("text", "")))
            elif isinstance(block, str):
                parts.append(block)
        return "\n".join(parts)
    return ""


def last_assistant_text(transcript_path: str) -> str:
    """transcript JSONL을 끝에서부터 훑어 마지막 assistant 텍스트를 찾는다."""
    if not transcript_path:
        return ""
    p = Path(transcript_path)
    if not p.exists():
        return ""
    try:
        lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return ""
    for raw in reversed(lines):
        raw = raw.strip()
        if not raw:
            continue
        try:
            rec = json.loads(raw)
        except Exception:
            continue
        if not isinstance(rec, dict):
            continue
        msg = rec.get("message") if isinstance(rec.get("message"), dict) else None
        role = (msg or {}).get("role") or rec.get("role") or rec.get("type")
        if role != "assistant":
            continue
        content = (msg or rec).get("content")
        text = _extract_text(content).strip()
        if text:
            return text
    return ""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    text = last_assistant_text(payload.get("transcript_path", ""))
    if not text:
        return 0

    if len(text) > BODY_MAX:
        text = text[: BODY_MAX - 12] + "\n…(생략)"
    message = f"{HEADER}\n{text}"

    if os.environ.get("STOP_NOTIFY_DEBUG"):
        print(message)
        return 0

    # fire-and-forget: notify.py를 detached로 띄우고 즉시 반환(턴 종료 비차단).
    try:
        flags = 0
        if os.name == "nt":
            flags = getattr(subprocess, "CREATE_NO_WINDOW", 0) | getattr(
                subprocess, "DETACHED_PROCESS", 0
            )
        subprocess.Popen(
            [sys.executable, str(NOTIFY), message],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=flags,
        )
    except Exception:
        pass  # 알림 실패는 turn을 막지 않는다
    return 0


if __name__ == "__main__":
    sys.exit(main())
