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
재실행 시 sweep_out/sweep_state.json의 성공 스테이지만 스킵(중단-재개) — done 플래그를 그대로
믿지 않고 ① 저장된 rc/summary를 run_ok로 **재검증**(구버전 false-done 엔트리도 재시도) ②
**캠페인 지문**(정규화 seeds+RECIPE+의존 매니페스트 소스 sha+스키마) 일치 ③ 해당 스테이지 **레벨
digest** 일치까지 요구 — seeds/레시피/트레이너/레벨이 바뀐 완료는 스킵 자격 없음(지문 없는
레거시 엔트리 포함 재시도).
성공 판정 = train.py 집계줄("=== 집계") 존재 AND rc∈{0,1} — rc=1은 '완주했으나 무클리어'로
정당한 발견 결과(train.py 계약: 0=클리어 통과 / 1=무클리어 / 2=설정 오류). 크래시·집계줄
부재·rc=2는 done=false로 남아 재실행 시 자동 재시도되고, 실패 스테이지가 하나라도 있으면
러너 exit=1 + 말미 성공/실패 요약을 출력한다(codex R1: 실패를 완료로 위장 금지).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
TRAIN = HERE.parent / "train.py"
OUT = HERE / "sweep_out"
sys.path.insert(0, str(HERE.parent.parent))             # tools/solver — solution_registry
import solution_registry                                # noqa: E402 (level digest 결속)

# §14~16 확정 레시피(stall) — **--shaping trace --train-deadline 4500 필수**(§11 S12 커맨드 원형).
# 첫 스윕(2026-07-11)에서 이 둘을 빠뜨려 다단 스테이지가 terminal-only 기울기 0(bestR -0.020 평탄)
# 으로 전멸한 실측 교훈. trap_v2_test stall arm도 shaping="trace"+sil.
RECIPE = ["--grammar", "r2.1", "--envs", "4", "--sil",
          "--shaping", "trace", "--train-deadline", "4500",
          "--blocker-coef", "1.0", "--knowledge-coef", "1.0",
          "--knowledge-mode", "stall", "--stall-batches", "30", "--stall-share", "0.5",
          "--max-batches", "150", "--max-wall", "1800", "--no-save"]


STATE_SCHEMA = 2   # state 엔트리 의미 변경 시 증가(지문에 포함 → 옛 엔트리 전량 재시도)


def run_ok(rc: int, tail: str) -> bool:
    """스테이지 런 성공 판정 — 완주 증거(집계줄) AND rc∈{0,1}(1=무클리어 완주, 2=설정오류)."""
    return tail.startswith("=== 집계") and rc in (0, 1)


# 트레이너 파이썬측 의미론 의존 매니페스트(codex R4-M1·R5-M1 — train.py 하나로는 불충분).
# 검토 근거: train→mdp/env/model, mdp→model/solve/landmarks, env→run_test/solve import 체인 실사
# + solution_registry(기록 의미론). Godot 엔진측(드라이버+스테이지가 전이 로드하는 게임플레이
# 스크립트/엔티티 씬)은 solution_registry.runtime_digest가 coarse 과대포함으로 담당(codex R6).
FINGERPRINT_MANIFEST = [
    "tools/solver/rl/train.py", "tools/solver/rl/mdp.py", "tools/solver/rl/landmarks.py",
    "tools/solver/env.py", "tools/solver/model.py", "tools/solver/solve.py",
    "tools/solver/solution_registry.py", "scripts/run_test.py",
]


def campaign_fingerprint(seeds: str) -> str:
    """스킵 자격의 결속 지문 — 정규화 seeds + RECIPE 전체 + **파이썬 의존 매니페스트 소스 sha**
    + **엔진 runtime digest** + state 스키마(codex R3-M2: seeds/레시피가 다른 완료는 스킵 자격
    없음 / R4-M1·R5-M1·R6: CLI 인자가 같아도 트레이너·롤아웃·게임플레이 의미론이 바뀌면 옛
    완료가 살아남으면 안 됨. 매니페스트 파일 부재는 None으로 지문에 반영(삭제도 변경). 과잉
    무효화 비용은 무해 — 스윕 재실행은 레지스트리 dup 처리)."""
    norm_seeds = ",".join(str(s) for s in sorted({int(x) for x in seeds.split(",")}))
    root = solution_registry.REPO
    srcs = {rel: (hashlib.sha256((root / rel).read_bytes()).hexdigest()[:16]
                  if (root / rel).exists() else None)
            for rel in FINGERPRINT_MANIFEST}
    payload = json.dumps({"schema": STATE_SCHEMA, "seeds": norm_seeds, "recipe": RECIPE,
                          "sources": srcs,
                          "runtime": solution_registry.runtime_digest()},
                         sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def state_entry_ok(entry, fingerprint: str, level_digest: str | None) -> bool:
    """저장된 state 엔트리 재검증 — done=true라도 ① 기록된 rc/summary가 run_ok 통과(codex
    R2-M1: 구버전 러너는 크래시에도 done=true) ② 캠페인 지문 일치(codex R3-M2, 지문 없는
    레거시 엔트리 포함 재시도) ③ **해당 스테이지 레벨 digest 일치**(codex R4-M1: 성공 후
    레벨이 바뀐 스테이지는 새 레벨에서 재발견해야 함 — digest 산출 불가(None)도 스킵 불가)
    셋 다 만족해야 스킵. 비-dict 등 구조 위반 엔트리 = 재시도 가능(False — codex R16:
    {"stage01": null} 같은 parse-valid 손상이 기동을 죽이면 안 됨)."""
    if not isinstance(entry, dict):
        return False
    if not entry.get("done") or entry.get("fingerprint") != fingerprint:
        return False
    if level_digest is None or entry.get("level_digest") != level_digest:
        return False
    try:
        return run_ok(int(entry.get("rc")), str(entry.get("summary") or ""))
    except (TypeError, ValueError):
        return False


def _prev_attempts(entry) -> int:
    """엔트리의 attempts 회수(구조 위반·비수치 = 0 — codex R16 관용 파싱)."""
    if not isinstance(entry, dict):
        return 0
    try:
        return int(entry.get("attempts") or 0)
    except (TypeError, ValueError):
        return 0


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


def _load_state(state_p: Path) -> dict:
    """state 로드 — 손상(중단된 쓰기 등)은 quarantine 보존 후 빈 state로 재시작(codex R15-M2:
    손상 파일이 러너 기동 자체를 막아 캠페인이 수동 복구 전까지 좌초하는 것 차단).
    엔트리 유실은 무해(재시도=dup 처리)."""
    if not state_p.exists():
        return {}
    try:
        state = json.loads(state_p.read_text(encoding="utf-8"))
        return state if isinstance(state, dict) else {}
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:   # 비-UTF8도 손상(R16)
        base = f"sweep_state.corrupt-{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}"
        dst = state_p.with_name(f"{base}.json")
        i = 0
        while dst.exists():                    # 같은 초 재격리 시 선행 격리본 보존(레지스트리 동일 패턴)
            i += 1
            dst = state_p.with_name(f"{base}-{i}.json")
        try:
            os.replace(state_p, dst)
            print(f"[sweep] WARN state 손상({exc}) — {dst.name} 보존 후 빈 state로 재시작",
                  flush=True)
        except OSError:
            print(f"[sweep] WARN state 손상({exc}) — 이동 실패, 빈 state로 진행", flush=True)
        return {}


def _save_state(state_p: Path, state: dict) -> None:
    """원자적 교체(codex R15-M2: 스테이지당 수십 분 런 도중 중단돼도 부분쓰기 잔존 금지)."""
    tmp = state_p.with_name(f"{state_p.name}.tmp{os.getpid()}")
    tmp.write_text(json.dumps(state, indent=1, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, state_p)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--stages", default="1-25")
    ap.add_argument("--seeds", default="0,1,2")
    args = ap.parse_args()
    OUT.mkdir(exist_ok=True)
    # 단일-러너 강제(codex R15-M2): 동시 스윕 2개가 state를 서로 덮어쓰는 것 차단 —
    # 레지스트리와 동일 OS-수준 락(프로세스 사망 시 자동 해제), 러너 수명 전체 보유
    lock_f = open(OUT / "sweep.lock", "a+b")
    lock_f.seek(0)
    if not solution_registry._try_lock(lock_f):
        print("[sweep] 다른 스윕 러너가 실행 중(sweep.lock 점유) — 동시 실행 거부", flush=True)
        return 1
    state_p = OUT / "sweep_state.json"
    state: dict = _load_state(state_p)
    stages = parse_stages(args.stages)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    fp = campaign_fingerprint(args.seeds)
    t0 = time.monotonic()
    failed: list[str] = []
    for sid in stages:
        key = f"stage{sid:02d}"
        cur_ld = solution_registry.level_digest(sid)
        if state_entry_ok(state.get(key, {}), fp, cur_ld):
            print(f"[sweep] {key} 완료 기록 있음(재검증·지문·레벨 digest 일치) — 스킵", flush=True)
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
        ok = run_ok(rc, tail)                  # 실패는 done=false로 남겨 자동 재시도
        if not ok:
            failed.append(key)
        state[key] = {"done": ok, "rc": rc, "wall_s": wall, "summary": tail,
                      "attempts": _prev_attempts(state.get(key)) + 1, "fingerprint": fp,
                      "level_digest": cur_ld,
                      "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        _save_state(state_p, state)
        print(f"[sweep] {key} {'OK' if ok else 'FAIL(재시도 대상)'} rc={rc} wall={wall}s | {tail}",
              flush=True)
    print(f"[sweep] 전체 종료 total_wall={round(time.monotonic() - t0, 1)}s "
          f"실패 {len(failed)}건{': ' + ', '.join(failed) if failed else ''}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
