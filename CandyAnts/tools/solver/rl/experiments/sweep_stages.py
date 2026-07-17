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
시도별 분리 기록(2026-07-12 사용자 지시): 로그 = sweep_out/stageNN.attemptK.log(시도마다 새
파일, 실패 로그 보존) / 시도 결과 이력 = sweep_out/attempts.jsonl append 누적(이력 SoT) /
sweep_state.json = 스킵 판정용 최신 상태만.
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


def campaign_fingerprint(seeds: str, max_len: int | None = None,
                         max_batches: int | None = None,
                         stall_any: int | None = None,
                         prefix: dict | None = None,
                         train_deadline: int | None = None) -> str:
    """스킵 자격의 결속 지문 — 정규화 seeds + RECIPE 전체 + **파이썬 의존 매니페스트 소스 sha**
    + **엔진 runtime digest** + state 스키마(codex R3-M2: seeds/레시피가 다른 완료는 스킵 자격
    없음 / R4-M1·R5-M1·R6: CLI 인자가 같아도 트레이너·롤아웃·게임플레이 의미론이 바뀌면 옛
    완료가 살아남으면 안 됨. 매니페스트 파일 부재는 None으로 지문에 반영(삭제도 변경). 과잉
    무효화 비용은 무해 — 스윕 재실행은 레지스트리 dup 처리).
    max_len(2026-07-13 실패 분석)·max_batches(2026-07-15 니어클리어 예산 상향): per-stage
    오버라이드가 있는 스테이지만 지문에 키를 추가 — 오버라이드 없는 스테이지의 payload는
    종전과 byte-identical(기존 done 엔트리 스킵 자격 보존). 예산을 올린 재실행은 지문이
    갈라져 기존 '무클리어 완주(rc=1)' 기록을 스킵하지 않고 새 배치-예산으로 재도전한다."""
    norm_seeds = ",".join(str(s) for s in sorted({int(x) for x in seeds.split(",")}))
    root = solution_registry.REPO
    srcs = {rel: (hashlib.sha256((root / rel).read_bytes()).hexdigest()[:16]
                  if (root / rel).exists() else None)
            for rel in FINGERPRINT_MANIFEST}
    body = {"schema": STATE_SCHEMA, "seeds": norm_seeds, "recipe": RECIPE,
            "sources": srcs,
            "runtime": solution_registry.runtime_digest()}
    if max_len is not None:
        body["max_len"] = int(max_len)
    if max_batches is not None:
        body["max_batches"] = int(max_batches)
    if stall_any is not None:
        body["stall_any"] = int(stall_any)
    if prefix is not None:                     # 경로+k(어떤 witness의 앞 몇 액션을 고정했는가)를 결속
        body["prefix"] = {"path": str(prefix["path"]), "k": int(prefix["k"])}
    if train_deadline is not None:
        body["train_deadline"] = int(train_deadline)
    payload = json.dumps(body, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def parse_max_len_overrides(spec: str) -> dict[int, int]:
    """"14:8,15:7,20:7" → {14:8, 15:7, 20:7}. 형식 위반 = ValueError(fail-closed — 스테이지가
    의도한 문법 확장 없이 기본 max_len으로 돌아가 조용히 FAIL 반복하는 것 차단)."""
    out: dict[int, int] = {}
    for part in (spec or "").split(","):
        part = part.strip()
        if not part:
            continue
        sid_s, v_s = part.split(":", 1)
        sid, v = int(sid_s), int(v_s)
        if v < 1:
            raise ValueError(f"max_len 오버라이드는 ≥1: {part}")
        out[sid] = v
    return out


def parse_max_batches_overrides(spec: str) -> dict[int, int]:
    """"15:500,20:300" → {15:500, 20:300}. RECIPE 기본 --max-batches(150)를 스테이지별로 상향
    (2026-07-15 니어클리어 집중: batch 150에서 수렴 중 컷된 스테이지에 배치-예산 추가 부여).
    형식 위반 = ValueError(fail-closed — 조용히 기본 예산으로 돌아가 니어클리어를 못 넘는 것 차단)."""
    out: dict[int, int] = {}
    for part in (spec or "").split(","):
        part = part.strip()
        if not part:
            continue
        sid_s, v_s = part.split(":", 1)
        sid, v = int(sid_s), int(v_s)
        if v < 1:
            raise ValueError(f"max_batches 오버라이드는 ≥1: {part}")
        out[sid] = v
    return out


def parse_stall_any_overrides(spec: str) -> dict[int, int]:
    """"18:60,10:60" → {18:60, 10:60}. 보조 격발(§도구②, 2026-07-13 실패분석) per-stage 부여 —
    평평-고원(dup 0.02~0.08로 주-격발 영구차단) 스테이지에 dup-무관 격발 문턱. train.py가
    stall-any ≥ stall-batches(30)를 최종 강제(여기선 ≥1만, fail-closed는 트레이너 계약에 위임).
    형식 위반 = ValueError."""
    out: dict[int, int] = {}
    for part in (spec or "").split(","):
        part = part.strip()
        if not part:
            continue
        sid_s, v_s = part.split(":", 1)
        sid, v = int(sid_s), int(v_s)
        if v < 1:
            raise ValueError(f"stall_any 오버라이드는 ≥1: {part}")
        out[sid] = v
    return out


def parse_train_deadline_overrides(spec: str) -> dict[int, int]:
    """"10:9000" → {10: 9000}. RECIPE 기본 --train-deadline(4500)을 스테이지별로 상향 —
    witness 클리어가 학습 지평 밖인 스테이지용(2026-07-17: S10 witness f4746 > 4500이라 prefix
    의미론 게이트가 기본 지평에서 정당 거부 → 지평 자체를 witness에 맞춘다). 형식 위반 =
    ValueError(fail-closed — 조용히 기본 지평으로 돌아가 게이트 거부를 반복하는 것 차단)."""
    out: dict[int, int] = {}
    for part in (spec or "").split(","):
        part = part.strip()
        if not part:
            continue
        sid_s, v_s = part.split(":", 1)
        sid, v = int(sid_s), int(v_s)
        if v < 1:
            raise ValueError(f"train_deadline 오버라이드는 ≥1: {part}")
        out[sid] = v
    return out


def parse_prefix_overrides(spec: str) -> dict[int, dict]:
    """"23:data/solutions/stage23.witness.json:3,24:...:2" → {23:{"path":..,"k":3}, ...}.
    witness-prefix curriculum(§도구③) per-stage — 어려운 앞부분 k개 액션을 witness에서 고정.
    형식 = sid:경로:k (경로에 콜론 없음 가정; sid=첫 필드, k=끝 필드, 경로=사이). 경로는 러너
    CWD(=CandyAnts) 상대 해석. 형식 위반·k<1·빈 경로 = ValueError(fail-closed)."""
    out: dict[int, dict] = {}
    for part in (spec or "").split(","):
        part = part.strip()
        if not part:
            continue
        sid_s, rest = part.split(":", 1)
        path, k_s = rest.rsplit(":", 1)
        sid, k = int(sid_s), int(k_s)
        if k < 1:
            raise ValueError(f"prefix k는 ≥1: {part}")
        if not path.strip():
            raise ValueError(f"prefix 경로 비어있음: {part}")
        out[sid] = {"path": path.strip(), "k": k}
    return out


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
    ap.add_argument("--max-len-overrides", default="",
                    help="per-stage 문법 길이 오버라이드 \"14:8,15:7,20:7\" — 알려진 해가 기본 "
                         "max_len=6을 초과하는 스테이지용(2026-07-13 실패 분석 ①: S14=8·S15=7·"
                         "S20=7액션 해가 표현 공간 밖). 오버라이드 스테이지는 지문에 max_len이 "
                         "결속돼 기본-길이 완료 기록과 별개로 재시도된다")
    ap.add_argument("--max-batches-overrides", default="",
                    help="per-stage 배치-예산 상향 \"15:500,20:300\" — RECIPE 기본 --max-batches"
                         "(150)에서 수렴 중 컷된 니어클리어 스테이지에 예산 추가(2026-07-15). "
                         "오버라이드 스테이지는 지문에 max_batches가 결속돼 기본-예산 '무클리어 "
                         "완주' 기록을 스킵하지 않고 새 예산으로 재도전한다")
    ap.add_argument("--stall-any-overrides", default="",
                    help="per-stage 보조 격발 \"18:60,10:60\" — 평평-고원(dup 저점유로 주-격발 "
                         "영구차단) 스테이지에 stall-any 문턱 부여(§도구②). 지문에 결속")
    ap.add_argument("--prefix-overrides", default="",
                    help="per-stage witness-prefix \"23:data/solutions/stage23.witness.json:3\" "
                         "(sid:경로:k) — 어려운 앞 k액션을 witness에서 고정하고 이후만 학습(§도구③). "
                         "경로는 러너 CWD 상대. 지문에 (경로,k) 결속")
    ap.add_argument("--train-deadline-overrides", default="",
                    help="per-stage 학습 지평 오버라이드 \"10:9000\" — witness 클리어 프레임이 "
                         "RECIPE 기본 --train-deadline(4500) 밖인 스테이지용(prefix 의미론 게이트가 "
                         "기본 지평에서 정당 거부하는 케이스). 지문에 결속")
    args = ap.parse_args()
    overrides = parse_max_len_overrides(args.max_len_overrides)
    batch_overrides = parse_max_batches_overrides(args.max_batches_overrides)
    stall_any_overrides = parse_stall_any_overrides(args.stall_any_overrides)
    prefix_overrides = parse_prefix_overrides(args.prefix_overrides)
    deadline_overrides = parse_train_deadline_overrides(args.train_deadline_overrides)
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
        # per-stage 지문: max_len·max_batches·stall_any·prefix·train_deadline 오버라이드 스테이지만
        # 지문이 갈라짐(기본 스테이지 = 종전 fp 그대로 — byte-identical payload로 스킵 자격 보존)
        ml = overrides.get(sid)
        mb = batch_overrides.get(sid)
        sa = stall_any_overrides.get(sid)
        pfx = prefix_overrides.get(sid)
        td = deadline_overrides.get(sid)
        stage_fp = (campaign_fingerprint(args.seeds, max_len=ml, max_batches=mb,
                                         stall_any=sa, prefix=pfx, train_deadline=td)
                    if any(v is not None for v in (ml, mb, sa, pfx, td)) else fp)
        if state_entry_ok(state.get(key, {}), stage_fp, cur_ld):
            print(f"[sweep] {key} 완료 기록 있음(재검증·지문·레벨 digest 일치) — 스킵", flush=True)
            continue
        recipe = list(RECIPE)
        if mb is not None:                     # RECIPE의 --max-batches 값을 in-place 교체(중복 플래그 방지, argparse last-wins 비의존)
            if "--max-batches" in recipe:
                recipe[recipe.index("--max-batches") + 1] = str(mb)
            else:
                recipe += ["--max-batches", str(mb)]
        if td is not None:                     # RECIPE의 --train-deadline 값 in-place 교체(동일 패턴)
            if "--train-deadline" in recipe:
                recipe[recipe.index("--train-deadline") + 1] = str(td)
            else:
                recipe += ["--train-deadline", str(td)]
        cmd = [sys.executable, str(TRAIN), "--stage", str(sid), "--seeds", args.seeds] + recipe
        if ml is not None:
            cmd += ["--max-len", str(ml)]
        if sa is not None:                     # §도구② 보조 격발(train.py가 ≥stall-batches 최종 강제)
            cmd += ["--stall-any-batches", str(sa)]
        if pfx is not None:                    # §도구③ witness-prefix(경로는 CWD 상대; train.py fail-closed 검증)
            cmd += ["--prefix-plan", pfx["path"], "--prefix-k", str(pfx["k"])]
        # 시도별 분리 기록(2026-07-12 사용자 지시): 로그는 attempt 번호로 파일 분리(덮어쓰기
        # 없음 — 실패 시도의 로그도 보존), 결과 요약은 attempts.jsonl에 append 누적.
        attempt = _prev_attempts(state.get(key)) + 1
        log_p = OUT / f"{key}.attempt{attempt:02d}.log"
        print(f"[sweep] {key} 시작(attempt {attempt}) → {log_p.name}", flush=True)
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
        entry = {"done": ok, "rc": rc, "wall_s": wall, "summary": tail,
                 "attempts": attempt, "fingerprint": stage_fp,
                 **({"max_len": ml} if ml is not None else {}),
                 **({"max_batches": mb} if mb is not None else {}),
                 **({"stall_any": sa} if sa is not None else {}),
                 **({"prefix": pfx} if pfx is not None else {}),
                 "level_digest": cur_ld, "log": log_p.name,
                 "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        state[key] = entry
        _save_state(state_p, state)
        # 시도 이력 append(불변 누적 — state는 스킵 판정용 최신본, 이력의 SoT는 이 파일)
        with open(OUT / "attempts.jsonl", "a", encoding="utf-8") as af:
            af.write(json.dumps({"stage": key, "seeds": args.seeds, **entry},
                                ensure_ascii=False) + "\n")
        print(f"[sweep] {key} {'OK' if ok else 'FAIL(재시도 대상)'} rc={rc} wall={wall}s | {tail}",
              flush=True)
    print(f"[sweep] 전체 종료 total_wall={round(time.monotonic() - t0, 1)}s "
          f"실패 {len(failed)}건{': ' + ', '.join(failed) if failed else ''}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
