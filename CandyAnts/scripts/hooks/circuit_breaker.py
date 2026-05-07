#!/usr/bin/env python3
"""
Circuit Breaker — 같은 에러가 60초 안에 5번 반복되면 "전략 변경" 경고.

PostToolUse 이벤트에서 실패한 도구 호출의 시그니처를 추적.
이미 도구가 실행된 시점이라 BLOCK은 못 함 — 경고(stderr) + return 0.

상태 파일: scripts/hooks/.circuit_breaker_state.json
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

WINDOW_SECONDS = 60
THRESHOLD = 5
SIGNATURE_LEN = 200

STATE_FILE = Path(__file__).resolve().parent / ".circuit_breaker_state.json"


def load_events() -> list[dict]:
    if not STATE_FILE.exists():
        return []
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:
        return []


def save_events(events: list[dict]) -> None:
    STATE_FILE.write_text(json.dumps(events, ensure_ascii=False), encoding="utf-8")


def extract_signature(payload: dict) -> str:
    response = payload.get("tool_response", {}) or {}
    err = response.get("error")
    if err:
        return str(err)[:SIGNATURE_LEN]
    if response.get("is_error"):
        content = response.get("content", "")
        if isinstance(content, list):
            content = " ".join(str(c) for c in content)
        return str(content)[:SIGNATURE_LEN]
    return ""


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    sig = extract_signature(payload)
    if not sig:
        return 0  # 에러 아님

    now = time.time()
    events = [e for e in load_events() if now - e["t"] <= WINDOW_SECONDS]
    events.append({"t": now, "sig": sig})

    same = [e for e in events if e["sig"] == sig]

    if len(same) >= THRESHOLD:
        sys.stderr.write(
            f"WARN: Circuit Breaker — 같은 에러가 {WINDOW_SECONDS}초 안에 {len(same)}번 반복됨.\n"
            f"  에러 시그니처: {sig[:120]}\n"
            f"  같은 시도를 반복하지 말고 접근 방식을 바꾸세요.\n"
            f"  (예: 다른 도구, 다른 파라미터, 사용자에게 도움 요청)\n"
        )
        # 알림 후 해당 시그니처 카운터 리셋 (반복 알림 방지)
        events = [e for e in events if e["sig"] != sig]

    save_events(events)
    return 0


if __name__ == "__main__":
    sys.exit(main())
