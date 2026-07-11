#!/usr/bin/env python3
"""RL 다중-seed 전 스테이지 스윕 (2026-07-11 사용자 지시 — 해 '발견' 목적, 검증 아님).

캠페인 스테이지 1~25를 §16 확정 stall 레시피(blocker 1.0 + knowledge 1.0 stall)로
seed 0,1,2 scratch 학습. 산출물은 train.py가 durable 기록:
  - 클리어 해        → data/solutions/found/stageNN_seed{s}.found.json (+ log.jsonl)
  - 미클리어 최고-진척 → data/solutions/found/stageNN_seed{s}.partial.json (+ partials.jsonl)
보고·시각화(중복 제거 + 궤적)는 후속 found_viewer 확장이 이 사이드카들을 소비한다.

의도적 SOP 이탈: --save-ckpt 미사용 — 스윕이 기존 cleared ckpt(rl_ckpt/stageNN_seed*.r2.pt,
§13 지식전이 자산)를 덮어쓰는 파괴적 부작용 차단. --no-save로 rl2.json 산출물도 미저장
(발견 기록은 found/ 사이드카가 담당, pinned 산출물 보호).

사용:
    PYTHONIOENCODING=utf-8 python tools/solver/rl/experiments/sweep_stages.py [--stages 1-25] [--seeds 0,1,2]
재실행 시 sweep_out/sweep_state.json에 완료 기록된 스테이지는 스킵(중단-재개).
크래시(rc!=0 + 집계줄 부재) 스테이지를 다시 돌리려면 state에서 해당 키를 지우고 재실행.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRAIN = HERE.parent / "train.py"
OUT = HERE / "sweep_out"

# §14~16 확정 레시피(stall) — **--shaping trace --train-deadline 4500 필수**(§11 S12 커맨드 원형).
# 첫 스윕(2026-07-11)에서 이 둘을 빠뜨려 다단 스테이지가 terminal-only 기울기 0(bestR -0.020 평탄)
# 으로 전멸한 실측 교훈. trap_v2_test stall arm도 shaping="trace"+sil.
RECIPE = ["--grammar", "r2.1", "--envs", "4", "--sil",
          "--shaping", "trace", "--train-deadline", "4500",
          "--blocker-coef", "1.0", "--knowledge-coef", "1.0",
          "--knowledge-mode", "stall", "--stall-batches", "30", "--stall-share", "0.5",
          "--max-batches", "150", "--max-wall", "1800", "--no-save"]


def parse_stages(spec: str) -> list[int]:
    """"1-25" / "3,7,20-25" 형태를 정수 리스트로."""
    out: list[int] = []
    for part in spec.split(","):
        part = part.strip()
        if "-" in part:
            a, b = part.split("-", 1)
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--stages", default="1-25")
    ap.add_argument("--seeds", default="0,1,2")
    args = ap.parse_args()
    OUT.mkdir(exist_ok=True)
    state_p = OUT / "sweep_state.json"
    state: dict = json.loads(state_p.read_text(encoding="utf-8")) if state_p.exists() else {}
    stages = parse_stages(args.stages)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    t0 = time.monotonic()
    for sid in stages:
        key = f"stage{sid:02d}"
        if state.get(key, {}).get("done"):
            print(f"[sweep] {key} 완료 기록 있음 — 스킵", flush=True)
            continue
        cmd = [sys.executable, str(TRAIN), "--stage", str(sid), "--seeds", args.seeds] + RECIPE
        log_p = OUT / f"{key}.log"
        print(f"[sweep] {key} 시작 → {log_p.name}", flush=True)
        t1 = time.monotonic()
        with open(log_p, "w", encoding="utf-8") as lf:
            rc = subprocess.call(cmd, stdout=lf, stderr=subprocess.STDOUT, env=env)
        wall = round(time.monotonic() - t1, 1)
        # train.py 집계줄 회수(로그 꼬리) — 크래시면 집계줄 부재로 마지막 줄이 남는다.
        tail = ""
        try:
            lines = log_p.read_text(encoding="utf-8", errors="replace").strip().splitlines()
            tail = next((ln for ln in reversed(lines) if ln.startswith("=== 집계")),
                        lines[-1] if lines else "")
        except Exception:
            pass
        state[key] = {"done": True, "rc": rc, "wall_s": wall, "summary": tail,
                      "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        state_p.write_text(json.dumps(state, indent=1, ensure_ascii=False), encoding="utf-8")
        print(f"[sweep] {key} rc={rc} wall={wall}s | {tail}", flush=True)
    print(f"[sweep] 전체 종료 total_wall={round(time.monotonic() - t0, 1)}s", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
