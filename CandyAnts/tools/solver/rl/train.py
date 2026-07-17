#!/usr/bin/env python3
"""
Phase R (RL 솔버) R0/R1/R2 — REINFORCE 학습 루프 + 병렬 GodotEnv + acceptance 검증.

plan SoT = auto-solver-plan.md §Phase R. 무힌트(model.propose 미사용 — 이 모듈은 propose를 import하지
않는다), 엔진/PlanRunner/게이트 무변경(로컬 RL 게이트 = --verify-r0/r1/r2).

고정 acceptance 커맨드 (plan §R0):
    python tools/solver/rl/train.py --stage 11 --seeds 0,1,2 --envs 4 --max-episodes 20000 --max-wall 7200
고정 acceptance 커맨드 (plan §R1 — trace-shaped 보상+SIL, S12 다단; max_wall=사용자 지시 2026-07-04):
    python tools/solver/rl/train.py --stage 12 --seeds 0,1,2 --envs 4 --max-episodes 20000 --max-wall 1800 \
        --shaping trace --train-deadline 4500 --sil
R1-스윕 (S13~S25 탐사, plan §R1-스윕 — 비게이트, 단일 seed 30분 cap):
    python tools/solver/rl/train.py --stage NN --seeds 0 --envs 4 --max-episodes 20000 --max-wall 1800 \
        --shaping trace --train-deadline 4500 --sil --max-len 8
R2 (plan §R2 — 영속 학습: r2 문법 + 체크포인트 2모드 + curriculum. per-seed 사슬 커맨드, seed s∈{0,1,2}):
    python tools/solver/rl/train.py --grammar r2.1 --stage 11 --seeds s --envs 4 --max-episodes 20000 \
        --max-wall 1800 --shaping trace --train-deadline 4500 --sil --save-ckpt
    python tools/solver/rl/train.py --grammar r2.1 --stage 12 --seeds s <공통 예산> --sil \
        --transfer-ckpt data/solutions/rl_ckpt/stage11_seed{s}.r2.pt --save-ckpt
    python tools/solver/rl/train.py --grammar r2.1 --stage 13 --seeds s <공통 예산> --sil \
        --transfer-ckpt data/solutions/rl_ckpt/stage12_seed{s}.r2.pt --save-ckpt      # acceptance ③
    python tools/solver/rl/train.py --grammar r2.1 --stage 19 --seeds 0,1,2 <공통 예산> --sil  # 어휘 증명 ⓑ
검증:
    python tools/solver/rl/train.py --verify-r0            # manifest + predicate + replay ×2 fail-closed
    python tools/solver/rl/train.py --verify-r1 --stage 12 # R1_PIN(shaping 포함) fail-closed
    python tools/solver/rl/train.py --verify-r2 --stage 11 # R2_PIN + ckpt/chain 무결 + curriculum 정합
    python tools/solver/rl/train.py --verify-r2 --stage 19 # (인증 산출물 게이트 — stage12/13 rl2.json은
        # acceptance 2 FAIL의 정직 박제 기록이라 verify-r2가 거부하는 것이 기대 동작, plan §R2 실측 결과)
    python tools/solver/rl/train.py --coverage             # r1.1 커버리지(known S11·S12 → 격자 → 클리어)
    python tools/solver/rl/train.py --coverage-r2          # r2 커버리지(S11·S12 ant + S19 cell)
    python tools/solver/rl/train.py --accept-resume-equiv --grammar r2.1 --stage 11 --seeds 0 --envs 4 \
        --max-batches 6 --shaping trace --train-deadline 4500 --sil   # P1 재개 등가성(acceptance 1)
    python tools/solver/rl/train.py --preflight-only --envs 4   # 병렬 결정론 preflight만
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent            # tools/solver/rl
SOLVER = HERE.parent                              # tools/solver
ROOT = SOLVER.parents[1]                          # .../CandyAnts
for p in (str(SOLVER), str(ROOT / "scripts")):
    if p not in sys.path:
        sys.path.insert(0, p)

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

from mdp import (StageMDP, GRAMMAR_VERSION, GRAMMAR_R2, GRAMMAR_R4, REWARD, SHAPING,  # noqa: E402
                 global_vocab, manifest_stage_ids, skill_metas,
                 OBS_SCHEMA_DIGEST, obs_schema, C_TRACE, N_TRACE_SCALAR)
from env import GodotEnv                           # noqa: E402  (tools/solver/env.py)
import model                                       # noqa: E402  (frontier_dists — §14.3 지식-축적 보상)
from run_test import find_godot                    # noqa: E402  (실제 롤아웃 godot 해석 — exec digest 바인딩)
import solve                                       # noqa: E402  (run_plan 단발 리플레이 — 권위 경로)

REPLAY_DEADLINE = 7000       # acceptance 판정·리플레이 표준 deadline(축소 cap 거짓음성 차단, plan §R0)
TRAIN_DEADLINE = 3000        # 학습 중 롤아웃 cap(낭비 절감; S11 clear=1562f)
DIGEST_KEYS = ("cleared", "saved", "lost", "hp", "frame", "actions_fired", "picked_total")

# effective config 기본값 — manifest에 전량 박제(R2-M1: 기본값 drift가 산출물로 추적됨).
# entropy_min 0.005→0.02 (2026-07-04, S12 FAIL 진단): 감쇠 바닥 0.005에서 "1액션+SUBMIT" 길이-1
# 국소최적에 갇혀 2번째 슬롯 탐험이 죽는 것을 실측(20k 샘플에서 b1+b2 도달 0회) — 지속 탐험 바닥 상향.
DEFAULTS = dict(batch=16, lr=3e-3, entropy=0.03, entropy_min=0.02, entropy_decay=0.997,
                hidden=128, greedy_every=5,
                baseline_decay=0.9, max_len=6, train_deadline=TRAIN_DEADLINE,
                replay_deadline=REPLAY_DEADLINE, shaping="none",
                sil=False, sil_buffer=8, sil_coef=0.1,
                conv_channels=32, max_batches=0)   # r2: CNN 채널 / 등가성 시험용 배치-수 종료(0=비활성)

# R0 고정 acceptance 계약(plan §R0) — verify-r0가 manifest에 강제(impl-R1 HIGH: pinned 계약 미검증 차단).
# replay_deadline도 pin(impl-R2 HIGH: manifest 자기-일관성만 보면 느슨한 deadline 재생성이 통과) —
# 판정 replay가 인증의 실체이므로 그 deadline은 상수 고정. 학습-전용 knob(train_deadline 등)은 pin 비대상.
# grammar: §R2 선결 계약 — verify-r0/r1의 문법 pin은 모듈 상수가 아니라 **리터럴 "r1.1" 동결**
# (r2 승격과 무관하게 stage11/12 pinned 산출물은 r1.1 문법으로 영원히 검증).
# 실효 학습 knob 값-pin(codex §R2-R6 HIGH — 자기-보고 config 신뢰 금지; 예산 오버슛 상수의 출처):
# batch/lr/entropy 스케줄/hidden/greedy_every/baseline_decay/reward. r0/r1/r2 공통 편입 —
# stage11/12 pinned 산출물은 DEFAULTS와 일치하므로 PASS 불변.
_KNOB_PIN = dict(batch=DEFAULTS["batch"], lr=DEFAULTS["lr"], entropy=DEFAULTS["entropy"],
                 entropy_min=DEFAULTS["entropy_min"], entropy_decay=DEFAULTS["entropy_decay"],
                 hidden=DEFAULTS["hidden"], greedy_every=DEFAULTS["greedy_every"],
                 baseline_decay=DEFAULTS["baseline_decay"], reward=dict(REWARD))

R0_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=7200,
              replay_deadline=REPLAY_DEADLINE, max_len=DEFAULTS["max_len"],
              grammar="r1.1", **_KNOB_PIN)

# R1 고정 acceptance 계약(plan §R1) — R0_PIN + shaping 상수(plan-R1-H1: 계수까지 fail-closed;
# 계수 튜닝은 fallback 1에서만, 그때 이 pin도 같은 커밋에서 갱신). train_deadline=4500은 "학습-전용
# knob 비대상" 원칙의 명시 예외(plan-R2-H) — 3000f cap이 최적점 근방을 굶긴다고 plan이 입증한 material knob.
# max_wall=1800: 사용자 지시 2026-07-04("최대 30분 기준") — R0의 7200에서 하향.
# sil(+buffer/coef): fallback 2 채택(2026-07-04 — fallback 1 FAIL 후 SIL probe가 S12 클리어 실증,
# 세션 로그 F6·F7). fallback 계약대로 채택 시 pin 동일-커밋 갱신.
R1_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=1800,
              replay_deadline=REPLAY_DEADLINE, shaping="trace", shaping_coeffs=dict(SHAPING),
              train_deadline=4500, sil=True, sil_buffer=8, sil_coef=0.1,
              max_len=DEFAULTS["max_len"],   # post-commit codex R1 HIGH: 문법 길이도 인증 실체 — pin
              grammar="r1.1", **_KNOB_PIN)   # §R2 선결 계약: 리터럴 동결 / knob=§R2-R6

# R2 고정 acceptance 계약(plan §R2 acceptance 2/3ⓑ — 공통 구간 예산, plan-R3 MED: 사슬 전 구간 동일 pin).
# grammar=r2.1(전역 어휘+마스킹+cell-target). 예산 회계는 **구간별**(plan-R2 MED-4) — verify-r2가
# chain의 각 세그먼트에 이 예산을 독립 적용한다(사슬 합산 아님).
R2_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=1800,
              replay_deadline=REPLAY_DEADLINE, shaping="trace", shaping_coeffs=dict(SHAPING),
              train_deadline=4500, sil=True, sil_buffer=8, sil_coef=0.1,
              max_len=DEFAULTS["max_len"], grammar=GRAMMAR_R2,
              conv_channels=DEFAULTS["conv_channels"], **_KNOB_PIN)
# pinned 사슬(체크포인트 출처 pin, plan-R2 HIGH-1): stage → 기대 chain 스테이지 열.
# S11=from-scratch 시점 / S12·S13=transfer 사슬 / S19=from-scratch 단독(어휘 증명 ⓑ, curriculum 불요 가정).
R2_CHAINS = {11: [11], 12: [11, 12], 13: [11, 12, 13], 19: [19]}
# pinned 커맨드에 --save-ckpt가 포함된 스테이지(헤더 독스트링 SoT) — 이들의 산출물에서 ckpt_saved
# **부재 = verify FAIL**(codex §R2-R2 HIGH-1: 항목 생략으로 byte-backed 검증 전체를 우회하는
# 부재-fail-open 차단). S19는 pinned 커맨드에 저장이 없어 비대상(기록돼 있으면 검증은 한다).
R2_SAVE_CKPT_STAGES = frozenset({11, 12, 13})

# ---------- R3 (trace-refinement MDP — plan §R3, --refine opt-in) ----------
# 관측 확장 = 신규 ckpt 포맷(model_cfg에 trace-채널/obs-schema digest 포함 → r2 정책과 shape 비호환).
CKPT_FORMAT_R3 = "candyants-rl3-ckpt-v1"
# 처리량 floor(R1-high1/R2-high3 — wall-bound vacuous FAIL 차단). impl-pin 금지: verify-r3가 다른 값이면
# 리뷰된 plan 개정 없이 FAIL. MIN_DISTINCT=S13 known 해 공간 격자 하한 실측 기준 pin.
THROUGHPUT_FLOOR = {"MIN_EPISODES": 3000, "MIN_DISTINCT": 1500}
R3_PROTOCOL_VERSION = "rl3-tcp-ndjson-v1"   # exec_config_digest 멤버(memo_key stale hit 차단)


def _floor_reached(tp: dict) -> bool:
    """THROUGHPUT_FLOOR 도달 여부 = raw 카운터 파생(자기-보고 bool 신뢰 금지, codex §R3 HIGH-2).
    verify-r3가 이 함수로 재계산해 산출물의 floor_reached와 대조 + outcome 재판정.
    **AND**(codex §R3 R6-MED, 사용자 결정 2026-07-05 → plan §R3 개정): model_fail 인증에는 학습량
    (≥MIN_EPISODES) **그리고** 탐색 커버리지(≥MIN_DISTINCT)를 **둘 다** 요구 — MIN_DISTINCT의 pin 근거
    ("해 공간 격자 하한")와 정합. 한 축만 넘고 다른 축 미달 = 탐색/학습 부족 → throughput-pin-invalid(인프라)."""
    return (int(tp.get("episodes_completed") or 0) >= THROUGHPUT_FLOOR["MIN_EPISODES"]
            and int(tp.get("distinct_prefix_rollouts") or 0) >= THROUGHPUT_FLOOR["MIN_DISTINCT"])
# R3_PRIMARY_PIN(acceptance 1·2·3·5) = R2_PIN 계승 + refine 계약. shaping="trace"(=R_d4+R1_terminal_shaping,
# 계상 1회)·grammar r2.1·obs_schema_digest·memo 기본 on·max_len(S13=6). dense가 이 pin을 갱신 금지.
R3_PRIMARY_PIN = dict(R2_PIN, refine=True, dense_shaping=False,
                      obs_schema_digest=OBS_SCHEMA_DIGEST,
                      throughput_floor=dict(THROUGHPUT_FLOOR))
# R3_DENSE_PIN(acceptance 6, fallback) — 독립 정의(R3-med3): shaping="none"(terminal trace shaping off,
# 이중계상 차단)·dense_shaping·γ=1.0·terminal φ=0·φ 계수 {0.5,0.1}(SHAPING 계승) + primary 공유 나머지.
R3_DENSE_PIN = dict(R2_PIN, refine=True, dense_shaping=True, shaping="none",
                    obs_schema_digest=OBS_SCHEMA_DIGEST, gamma=1.0, terminal_potential=0,
                    dense_coeffs=dict(SHAPING), throughput_floor=dict(THROUGHPUT_FLOOR))


def _sha_obj(o) -> str:
    return hashlib.sha256(json.dumps(o, sort_keys=True).encode("utf-8")).hexdigest()


# ---------- R4 (랜드마크-상대 표현 — plan §R4, --grammar r4.0 opt-in) ----------
# R4_PIN(plan §R4 v3 + 2026-07-10 개정: 어휘 v11·cap128): 학습 레시피 = §14 최신(blocker/knowledge
# coef 1.0 공통) + max_len 8. grammar는 리터럴 "r4.0"(§R2 선결 계약 계승 — 승격과 무관하게 동결).
R4_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=1800,
              replay_deadline=REPLAY_DEADLINE, shaping="trace", shaping_coeffs=dict(SHAPING),
              train_deadline=4500, sil=True, sil_buffer=8, sil_coef=0.1,
              max_len=8, grammar="r4.0", conv_channels=DEFAULTS["conv_channels"],
              blocker_coef=1.0, knowledge_coef=1.0, **_KNOB_PIN)
# KNOWLEDGE 상수 pin 리터럴(plan §R4 R2-H6 — coefficient만으론 미결정): 코드 상수가 이와 다르면
# verify-r4 FAIL(pin 개정 리뷰 없이 내부 상수 변경 차단).
R4_KNOWLEDGE_PIN = {"new_token": 0.05, "repeat": 0.02, "repeat_cap": 50}


def _knowledge_contract_digest() -> str:
    """§14.3 v3 지식-보상 내부 계약 전량(R2-H6): 상수 + 토큰화 입도 + 시행착오 정의 + SIL 재평가 +
    ledger 이월 규칙. 산출물 동승, verify-r4 fail-closed 대조."""
    return _sha_obj({"KNOWLEDGE": KNOWLEDGE, "token_granularity": "field_value",
                     "trial_error": "uncleared_and_both_frontiers_unimproved",
                     "sil_reeval": "use_time", "ledger": {"resume": "carry", "transfer": "reset"}})


def _blocker_contract_digest() -> str:
    """§10 blocker-coef 내부 계약(R2-H6): redirect 귀속 + 정규화."""
    return _sha_obj({"attribution": "chebyshev<=1_horizontal_reversal_x_goal_dist_progress",
                     "normalization": "D0*ants"})


def _exec_config_digest(mdp: StageMDP, cfg: dict) -> tuple[str, dict]:
    """rollout(P)가 의존하는 exec config 전량(숨은 의존 0, plan §R3 memo_key 계약). 멤버 하나라도
    바뀌면 memo 무효(cross-config stale hit 차단). stage_resource_digest = subset 금지(R3-high1) —
    스테이지 .tres + 참조 layout + scene의 full content hash(spawn/timeout/per-entity 등 전 runtime 필드)."""
    def fh(rel: str):
        p = ROOT / rel
        return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
    sid = mdp.stage_id
    stage_files = [f"data/stages/stage{sid:02d}.tres",
                   f"data/stage_layouts/stage{sid:02d}_layout.tres",
                   f"scenes/stages/Stage{sid:02d}.tscn"]
    # 스테이지 리소스는 rollout 결정론의 실체 — 하나라도 없으면 memo_key가 content-blind가 됨.
    # fail-closed(codex §R3 HIGH-1 인접: 누락 시 silent None 금지).
    for rel in stage_files:
        if not (ROOT / rel).exists():
            raise FileNotFoundError(
                f"exec_config_digest: 스테이지 리소스 {rel} 없음 — memo_key content-bind 불가(fail-closed)")
    driver_files = ["scripts/core/PlanRunner.gd", "scripts/core/SimConfig.gd",
                    "tests/PlanServerHarness.gd", "tests/PlanServerHarness.tscn",
                    "tools/solver/env.py", "project.godot", "data/solver/capabilities.tres"]
    # 실제 롤아웃에 쓰이는 godot = find_godot()(GODOT_BIN 미설정 시 PATH/후보 폴백) — env var raw는
    # 미설정 시 빈 문자열로 두 바이너리를 구별 못 함(codex §R3 R3-MED). resolved 경로로 바인딩·fail-closed.
    try:
        godot_binary = str(Path(find_godot()).resolve())
    except Exception as e:
        raise RuntimeError(f"exec_config_digest: godot 실행파일 해석 불가 — {e} (fail-closed)")
    members = {
        "stage_resource_digest": _sha_obj({r: fh(r) for r in stage_files}),
        "skill_meta_digest": _sha_obj(skill_metas()),
        "vocab_digest": mdp.vocab_digest,
        "grammar": mdp.grammar_version,
        "fixed_fps": 60,
        "train_deadline": cfg["train_deadline"],
        "replay_deadline": cfg["replay_deadline"],
        "trace_schema_digest": OBS_SCHEMA_DIGEST,
        "trace_request": True,
        "godot_binary": godot_binary,
        "script_rev_digest": _sha_obj({r: fh(r) for r in driver_files}),
        "protocol_version": R3_PROTOCOL_VERSION,
    }
    return _sha_obj(members), members


# ---------- r2 체크포인트 (P1 — plan §R2: 영속화 = 사용자 필수 요건) ----------
CKPT_FORMAT = "candyants-rl2-ckpt-v1"
CKPT_FORMAT_R4 = "candyants-rl4-ckpt-v1"   # §R4 — 8ch 관측+pointer, r2/r3와 shape 비호환
CKPT_DIR = ROOT / "data" / "solutions" / "rl_ckpt"
# 직렬화 전수 계약(plan-R1 MED-1) — train_seed의 state 구성과 verify의 필드-완전성 검사가 이 목록을
# 공유(계약 드리프트 차단). 메타데이터-온리 위조 .pt 거부의 근거(codex §R2-R3 HIGH).
CKPT_REQUIRED_KEYS = (
    "format", "grammar_version", "vocab_digest", "stage_id", "layout_digest", "mask_digest",
    "model_cfg", "dtype", "seed", "seg_mode", "batch_i", "episodes_seg", "wall_seg",
    "cleared_seg", "baseline", "baseline_init", "curve_seg", "episodes_prior", "batches_prior",
    "sil_buf", "torch_rng", "policy", "optimizer", "chain")


def ckpt_path(stage_id: int, seed: int, refine: bool = False, grammar: str = GRAMMAR_R2) -> Path:
    # r3(refine)=.r3.pt / r4=.r4.pt — 별도 확장자로 r2 byte-backed ckpt 덮어쓰기 차단
    # (codex §R3 MED-4 / §R4 SOP §12.1).
    ext = "r3" if refine else ("r4" if grammar == GRAMMAR_R4 else "r2")
    return CKPT_DIR / f"stage{stage_id:02d}_seed{seed}.{ext}.pt"


# ---------- 해 발견 즉시 기록 (부작용 전용 — 게이트 산출물 rlN.json과 직교) ----------
# 목적(사용자 요건): RL이 클리어 해를 찾는 순간 durable하게 남긴다. run 종료 시 1회만 쓰는 gated
# 산출물과 달리, 뒤 seed 크래시·wall-timeout에도 발견 해가 유실되지 않게 append 로그 + 최신 sidecar를
# 쓴다. verify-r2/r3 계약(출처 결속·digest·merge lock)과 완전 무관 — 기록 실패가 학습을 죽이지 않는다.
FOUND_DIR = ROOT / "data" / "solutions" / "found"


def _append_jsonl(path: Path, rec: dict) -> None:
    """프로세스간 인터리브 방지용 짧은 파일락(_flush_write_r2와 동일 spin 패턴) 아래 1줄 append."""
    line = json.dumps(rec, ensure_ascii=False) + "\n"
    lock = path.with_suffix(path.suffix + ".lock")
    fd = None
    for _ in range(200):                       # ~2s (append는 짧아 경합 미미)
        try:
            fd = os.open(str(lock), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except FileExistsError:
            time.sleep(0.01)
    try:
        with open(path, "a", encoding="utf-8") as f:
            f.write(line)                      # 락 실패해도 유실보다 인터리브 위험 감수하고 append
    finally:
        if fd is not None:
            os.close(fd)
            try:
                os.unlink(str(lock))
            except OSError:
                pass


# 발견 기록 영속화 실패 회계(codex §17-R5 H1): _record_found/_record_partial은 예외를 삼켜
# 학습을 지속하지만(기록은 보조), 완주 후 rc를 3으로 격상해 스윕이 done으로 박제하지 못하게
# 한다(rc=3은 sweep run_ok({0,1}) 거부 → 자동 재시도). run_training 시작 시 리셋.
_PERSIST_FAILURES: list[str] = []


def _final_rc(passed: bool) -> int:
    """run_training 종료 코드: 0=클리어 통과 / 1=무클리어 완주 / **3=발견 기록 영속화 실패**
    (quarantine·락 타임아웃·FS 오류 등으로 durable 기록이 유실된 채 정상 종료하는 것 차단)."""
    if _PERSIST_FAILURES:
        print(f"=== 영속화 실패 {len(_PERSIST_FAILURES)}건(rc=3): "
              f"{'; '.join(_PERSIST_FAILURES)} ===")
        return 3
    return 0 if passed else 1


def _record_found(mdp: "StageMDP", seed: int, plan: list, res: dict,
                  cfg: dict, refine: bool, episodes: int) -> None:
    """train_seed의 greedy-clear 지점에서 호출. 발견 해를 **solution_registry 경유**로 기록
    (2026-07-11 사용자 계약): 실행-동치(trace digest) 중복이면 레지스트리 카운트만 갱신하고
    사이드카/log 미기록, 레벨 digest가 바뀌었으면 기존 해 파기 후 재등록, 신규 해만 durable 기록.
    부작용 전용(반환 없음) — 예외는 삼켜 학습 지속(기록은 보조, 학습이 1차)."""
    try:
        import solution_registry               # tools/solver (sys.path 선등록) — 기록 경로 한정 의존
        FOUND_DIR.mkdir(parents=True, exist_ok=True)
        rec = {
            "event": uuid.uuid4().hex[:16],    # 발견 이벤트 고유 ID(codex §17-R22: migrate
            #                                    멱등 원장의 무충돌 SoT — 같은 초 별개 발견 구별)
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "stage_id": mdp.stage_id,
            "stage": mdp.stage_scene,
            "seed": seed,
            "grammar": mdp.grammar_version,
            "refine": bool(refine),
            "saved": int(res.get("saved") or 0),
            "hp": mdp.hp,
            "frame": res.get("frame"),
            "episodes": episodes,
            "deadline_frames": cfg.get("replay_deadline"),
            "inventory": mdp.inventory,
            "actions": plan,                   # 디코딩된 플랜 — 무수정 replay/시각화용
            # witness-prefix curriculum 출처(opt-in에서만 키 존재 — 무힌트 발견 rec은 종전과
            # 구성 동일). 힌트-유래 해를 '순수 RL 발견'으로 과대표시하는 것 차단(정직 provenance).
            **({"hint": dict(cfg["prefix_hint"])} if cfg.get("prefix_hint") else {}),
        }
        outcome = solution_registry.record_clear(rec, res, FOUND_DIR)
        reg_rel = _rel(solution_registry.registry_path(mdp.stage_id, FOUND_DIR))
        if outcome == "dup":
            print(f"  [seed {seed}] 중복 해(실행-동치 기존 등재) → {reg_rel} 카운트만 갱신")
            return
        if outcome == "reset":
            print(f"  [seed {seed}] 레벨 변경 감지 → stage{mdp.stage_id:02d} 기존 해 파기 후 재등록")
        _append_jsonl(FOUND_DIR / "log.jsonl", rec)
        side = FOUND_DIR / f"stage{mdp.stage_id:02d}_seed{seed}.found.json"
        tmp = side.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(rec, indent=1, ensure_ascii=False), encoding="utf-8")
        os.replace(tmp, side)                  # 원자적 교체(부분쓰기 sidecar 차단)
        print(f"  [seed {seed}] 신규 해 기록 → {reg_rel} + {_rel(side)}")
    except Exception as e:                     # noqa: BLE001 — 기록 실패가 학습을 죽이면 안 됨
        _PERSIST_FAILURES.append(f"found stage{mdp.stage_id:02d} seed{seed}: {e}")
        print(f"  [seed {seed}] WARN 해 기록 실패(무시하고 학습 지속, 종료 rc=3 격상): {e}")


def _record_partial(mdp: "StageMDP", seed: int, plan: list, cfg: dict,
                    episodes: int, batches: int, best_reward: float, refine: bool) -> None:
    """train_seed FAIL 종료 지점에서 호출(정규 학습 front-door 한정 — record_partial kwarg 게이트,
    verify/accept 경로는 기본 False라 미기록). 미클리어 seed의 최고-보상(base) 플랜을 durable 기록 —
    '가장 멀리 도달' 보고용. 사이드카(.partial.json)는 **최신 런 스냅샷**(무조건 교체)이고,
    최고-진척 권위는 partials.jsonl **전 이력** + found_viewer의 스테이지별 리플레이-best 선정
    (codex R1-M3: 나중의 약한 런이 이전 최고를 못 가림). 리플레이 메트릭(saved/frame/trace)은
    보고 파이프라인이 결정론 리플레이로 산출(여기선 플랜+출처만). 부작용 전용·예외 삼킴
    (_record_found와 동일 계약)."""
    try:
        import solution_registry               # 레벨 digest 스탬프(뷰어 stale-체크용)
        FOUND_DIR.mkdir(parents=True, exist_ok=True)
        rec = {
            "event": uuid.uuid4().hex[:16],    # 발견 이벤트 고유 ID(codex §17-R22: migrate
            #                                    멱등 원장의 무충돌 SoT — 같은 초 별개 발견 구별)
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "stage_id": mdp.stage_id,
            "stage": mdp.stage_scene,
            "seed": seed,
            "grammar": mdp.grammar_version,
            "refine": bool(refine),
            "cleared": False,
            "level_digest": solution_registry.level_digest(mdp.stage_id),
            "best_reward": (float(best_reward) if best_reward != float("-inf") else None),
            "hp": mdp.hp,
            "episodes": episodes,
            "batches": batches,
            "deadline_frames": cfg.get("replay_deadline"),
            "inventory": mdp.inventory,
            "actions": plan,                   # 디코딩된 최고-보상 플랜 — 무수정 replay/시각화용
            **({"hint": dict(cfg["prefix_hint"])} if cfg.get("prefix_hint") else {}),  # provenance
        }
        _append_jsonl(FOUND_DIR / "partials.jsonl", rec)
        side = FOUND_DIR / f"stage{mdp.stage_id:02d}_seed{seed}.partial.json"
        tmp = side.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(rec, indent=1, ensure_ascii=False), encoding="utf-8")
        os.replace(tmp, side)                  # 원자적 교체(found sidecar와 동일 패턴)
        print(f"  [seed {seed}] 부분-진척 기록 → {_rel(side)} + found/partials.jsonl")
    except Exception as e:                     # noqa: BLE001 — 기록 실패가 학습을 죽이면 안 됨
        _PERSIST_FAILURES.append(f"partial stage{mdp.stage_id:02d} seed{seed}: {e}")
        print(f"  [seed {seed}] WARN 부분-진척 기록 실패(무시, 종료 rc=3 격상): {e}")


def _file_sha(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _model_cfg(mdp: StageMDP, cfg: dict) -> dict:
    """모델 shape 계약(ckpt 호환 검사 대상) — 전역 어휘라 스테이지 무관 동일해야 transfer 가능.
    r3(refine)은 관측 확장분(trace 채널/스칼라/obs-schema digest)까지 포함 → r2 ckpt와 shape 비호환."""
    mc = {"hidden": cfg["hidden"], "conv_channels": cfg["conv_channels"],
          "max_len": mdp.max_len, "flat_dim": mdp.flat_dim,
          "heads": dict(mdp.heads)}
    if cfg.get("refine"):
        mc.update(refine=True, flat_dim=mdp.flat_dim_r3, in_channels=5 + C_TRACE,
                  obs_schema_digest=OBS_SCHEMA_DIGEST)
    if mdp.grammar_version == GRAMMAR_R4:
        # §R4: 8ch 레이아웃 관측 + landmark pointer(피처-점수화 — per-index 임베딩 금지 계약).
        mc.update(in_channels=8, landmark_schema_digest=mdp.landmark_digest,
                  landmark_feature_dim=len(mdp.landmark_instances[0]["features"]),
                  pointer="feature_mlp")
    return mc


def save_ckpt(path: Path, state: dict) -> str:
    torch, _ = _torch()
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(state, path)
    return _file_sha(path)


def load_ckpt(path: str | Path) -> dict:
    torch, _ = _torch()
    p = Path(path)
    ckpt = torch.load(p, map_location="cpu", weights_only=True)
    ckpt["_file_sha"] = _file_sha(p)          # 사슬 provenance(manifest 기록·verify 대조)
    ckpt["_file_path"] = str(p)
    return ckpt


def _ckpt_compat(ckpt: dict, mdp: StageMDP, seed: int, mode: str, cfg: dict) -> None:
    """로드 2모드 fail-closed 계약(plan-R2 HIGH-2 / plan-R3 HIGH-1):
    - resume(동일 스테이지 exact): stage/레이아웃/마스크 digest + seed까지 전부 일치.
    - transfer(타 스테이지 curriculum): 레이아웃/마스크 **면제**(불일치가 전이의 정의)하되
      전역 어휘/head-시맨틱 digest + 모델 shape는 일치 — silent 오매핑 차단."""
    fails: list[str] = []
    want_fmt = (CKPT_FORMAT_R3 if cfg.get("refine")
                else CKPT_FORMAT_R4 if mdp.grammar_version == GRAMMAR_R4 else CKPT_FORMAT)
    if ckpt.get("format") != want_fmt:
        fails.append(f"format {ckpt.get('format')!r} != {want_fmt!r}")
    if ckpt.get("grammar_version") != mdp.grammar_version:
        fails.append(f"grammar {ckpt.get('grammar_version')!r} != {mdp.grammar_version!r}")
    if ckpt.get("vocab_digest") != mdp.vocab_digest:
        fails.append("전역 어휘/head-시맨틱 digest 불일치 — shape만 같은 가중치의 silent 오매핑 차단")
    if ckpt.get("dtype") != "float32":
        fails.append(f"dtype {ckpt.get('dtype')!r} != 'float32'")
    mc = _model_cfg(mdp, cfg)
    if ckpt.get("model_cfg") != mc:
        fails.append(f"model_cfg 불일치: ckpt={ckpt.get('model_cfg')} != now={mc}")
    if mode == "resume":
        if ckpt.get("stage_id") != mdp.stage_id:
            fails.append(f"exact resume stage 불일치: {ckpt.get('stage_id')} != {mdp.stage_id}")
        if ckpt.get("layout_digest") != mdp.layout_digest():
            fails.append("exact resume 레이아웃 digest 불일치")
        if ckpt.get("mask_digest") != mdp.mask_digest():
            fails.append("exact resume 마스크 digest 불일치")
        if ckpt.get("seed") != seed:
            fails.append(f"exact resume seed 불일치: {ckpt.get('seed')} != {seed}")
    elif mode == "transfer":
        if ckpt.get("stage_id") == mdp.stage_id:
            fails.append("transfer인데 동일 스테이지 — exact resume(--resume-ckpt)을 쓸 것")
        if not ckpt.get("cleared_seg"):
            fails.append("미클리어 세그먼트 ckpt에서 transfer 금지 — curriculum은 클리어한 "
                         "스테이지의 ckpt에서만 이어서 학습(plan §R2 P4)")
    else:
        fails.append(f"unknown ckpt mode {mode!r}")
    if fails:
        raise RuntimeError("ckpt 비호환(fail-closed):\n  - " + "\n  - ".join(fails))


def _ckpt_segment(ckpt: dict) -> dict:
    """로드한 ckpt의 현재-세그먼트를 chain 항목으로 접는다(transfer 시 완결 세그먼트로 편입).
    경로는 repo-상대 정규화(codex §R2-R7 HIGH — 절대경로 메타 = 비이식·비정본)."""
    return {"stage_id": ckpt["stage_id"], "seed": ckpt["seed"], "mode": ckpt["seg_mode"],
            "episodes": ckpt["episodes_seg"], "batches": ckpt["batch_i"],
            "wall_s": ckpt["wall_seg"], "cleared": bool(ckpt["cleared_seg"]),
            "ckpt_sha": ckpt.get("_file_sha"),
            "ckpt_path": _rel(ckpt.get("_file_path") or "")}


def _digest(r: dict) -> dict:
    return {k: r.get(k) for k in DIGEST_KEYS}


# ---------- 병렬 env 풀 (R1-M3: preflight + bind-실패 재시도, env.py 무변경) ----------

def _make_env(retries: int = 3) -> GodotEnv:
    last: Exception | None = None
    for _ in range(retries):
        try:
            return GodotEnv()                      # 실패(포트 race 등) 시 재호출 = 새 free port
        except RuntimeError as e:
            last = e
    raise RuntimeError(f"GodotEnv boot failed after {retries} retries: {last}")


class EnvPool:
    def __init__(self, n: int):
        # 부분 실패 시 이미 부팅된 Godot 프로세스 누수 방지(R1-M2) — 만든 것까지 닫고 재던짐.
        self.envs: list[GodotEnv] = []
        try:
            for _ in range(n):
                self.envs.append(_make_env())
        except Exception:
            self.close()
            raise

    @property
    def n(self) -> int:
        return len(self.envs)

    def evaluate(self, plans: list[dict]) -> list[dict]:
        """plans를 env별 스트라이드 분할로 병렬 평가, 입력 순서대로 결과 반환(결정론 수집)."""
        results: list[dict | None] = [None] * len(plans)

        def _work(ei: int) -> None:
            for i in range(ei, len(plans), self.n):
                results[i] = self.envs[ei].step(plans[i])
        if self.n == 1:
            _work(0)
        else:
            with ThreadPoolExecutor(max_workers=self.n) as ex:
                list(ex.map(_work, range(self.n)))
        return results  # type: ignore[return-value]

    def close(self) -> None:
        for e in self.envs:
            try:
                e.close()
            except Exception:
                pass


def _trace_valid(t) -> bool:
    """trace 페이로드 형태 검증(공용 — preflight/학습 롤아웃/verify replay, codex R3·R4):
    비어있지 않은 dict + 개미별 비어있지 않은 샘플 리스트 + 첫 샘플 len>=4(소비자 s[3] 접근 정합)."""
    return (isinstance(t, dict) and len(t) > 0
            and all(isinstance(v, list) and len(v) > 0
                    and isinstance(v[0], (list, tuple)) and len(v[0]) >= 4
                    for v in t.values()))


def preflight(pool: EnvPool, stage_scene: str, with_trace: bool = False) -> dict:
    """N env × 빈 plan 2회 = 전 digest identical — **학습과 동일한 병렬 경로(pool.evaluate,
    ThreadPoolExecutor)로 실행**해 동시성 자체를 검증한다(R1-M1: 순차 preflight는 병렬 미검증).
    with_trace(plan §R1): trace:true로 돌려 **trace 필드까지 identical** 요구(shaping 신호 결정론 게이트)
    + wall 측정. 반환 {ok, wall_s, runs} — shaping=trace면 manifest `preflight_trace`로 박제."""
    plan = {"stage": stage_scene, "deadline_frames": 600, "actions": []}
    if with_trace:
        plan = dict(plan, trace=True)
    t0 = time.monotonic()
    results = pool.evaluate([plan] * (2 * pool.n))   # 스트라이드 분배로 env당 정확히 2회
    wall = time.monotonic() - t0
    digests = [_digest(r) for r in results]
    ok = all(d == digests[0] for d in digests)
    trace_present = None
    if with_trace:
        # post-commit codex R3 MEDIUM: trace 수집이 조용히 사라지면(전부 None) 동등성 비교가 공허하게
        # 통과 → "trace 결정론 증거"가 빈-plan 결정론으로 격하됨. **부재/공백/기형 trace = fail-closed**
        # (형태 계약 = 모듈 공용 _trace_valid).
        traces = [r.get("trace") for r in results]
        trace_present = all(_trace_valid(t) for t in traces)
        if not trace_present:
            ok = False
        elif ok:
            ok = all(t == traces[0] for t in traces)
    print(f"[preflight] envs={pool.n} runs={len(digests)} trace={with_trace} "
          f"trace_present={trace_present} parallel identical={ok} wall={wall:.2f}s base={digests[0]}")
    info = {"ok": ok, "wall_s": round(wall, 2), "runs": len(digests)}
    if with_trace:
        info["trace_present"] = trace_present
    return info


def build_pool(envs_requested: int, stage_scene: str,
               with_trace: bool = False) -> tuple[EnvPool, int, dict]:
    """요청 N으로 풀 구성 → preflight 실패 시 N=1 강등(plan §R0 N 폴백 계약). 반환에 preflight 정보 동봉."""
    pool = EnvPool(envs_requested)
    info = {"ok": True, "wall_s": 0.0, "runs": 0}     # N=1 요청 = preflight 비대상(단일 env 결정론 기확립)
    if pool.n > 1:
        info = preflight(pool, stage_scene, with_trace)
        if not info["ok"]:
            print("[preflight] FAIL → N=1 강등(정직 보고: manifest envs_effective=1)")
            pool.close()
            pool = EnvPool(1)
    return pool, pool.n, info


# ---------- 정책 (torch는 여기서만 lazy import — 미설치 환경 기존 도구 무영향) ----------

def _torch():
    import torch
    import torch.nn as nn
    # CPU 스레드 1 고정: 모델이 작아 멀티스레드 이득 0인데, 기본값(코어 수)은 병렬 env/사슬과
    # OpenMP busy-wait 오버서브스크립션으로 롤아웃 처리량을 붕괴시킴(2026-07-04 S12 사슬 실측 —
    # 12 env 경합에서 배치 처리량 ~20x 저하). 단일 스레드는 reduction 순서도 고정(결정론 강화).
    if torch.get_num_threads() != 1:
        torch.set_num_threads(1)
    return torch, nn


def make_policy(mdp: StageMDP, hidden: int):
    torch, nn = _torch()

    class Policy(nn.Module):
        def __init__(self):
            super().__init__()
            self.torso = nn.Sequential(
                nn.Linear(mdp.obs_dim, hidden), nn.Tanh(),
                nn.Linear(hidden, hidden), nn.Tanh())
            self.heads = nn.ModuleDict(
                {h: nn.Linear(hidden, n) for h, n in mdp.heads.items()})

        def forward(self, obs):
            z = self.torso(obs)
            return {h: self.heads[h](z) for h in mdp.head_names}

    return Policy()


def make_policy_r2(mdp: StageMDP, cfg: dict):
    """r2 스테이지-불변 정책(plan §R2 P2): 공유 CNN 인코더(가변 H×W×5 그리드 → adaptive pool 고정
    임베딩) + 전역-어휘 head. 모든 파라미터 shape가 스테이지 무관 — 같은 가중치 파일이 임의 등재
    스테이지에 로드 가능(P1의 전제)."""
    torch, nn = _torch()
    ch = cfg["conv_channels"]

    class PolicyR2(nn.Module):
        def __init__(self):
            super().__init__()
            self.conv = nn.Sequential(
                nn.Conv2d(5, ch, 3, padding=1), nn.ReLU(),
                nn.Conv2d(ch, ch, 3, padding=1), nn.ReLU(),
                nn.AdaptiveMaxPool2d((4, 4)))
            self.torso = nn.Sequential(
                nn.Linear(ch * 16 + mdp.flat_dim, cfg["hidden"]), nn.Tanh(),
                nn.Linear(cfg["hidden"], cfg["hidden"]), nn.Tanh())
            self.heads = nn.ModuleDict(
                {h: nn.Linear(cfg["hidden"], n) for h, n in mdp.heads.items()})

        def forward(self, grid, flat):
            z = self.conv(grid).flatten(1)
            z = self.torso(torch.cat([z, flat], dim=1))
            return {h: self.heads[h](z) for h in mdp.head_names}

    return PolicyR2()


def make_policy_r4(mdp: StageMDP, cfg: dict):
    """r4.0 정책(plan §R4): r2 스테이지-불변 CNN(8ch)+torso를 계승하되, **landmark head만
    피처-점수화 pointer** — 후보별 logit = 공유 MLP(concat[torso z, 후보 피처(19dim)]).
    per-index nn.Linear/임베딩 **금지**(인덱스가 새 절대좌표가 되는 것 차단 — R4_PIN 핵심 계약).
    후보 피처 행렬은 스테이지-파생 **상수 buffer**(파라미터 아님 — transfer 시 타깃 스테이지
    피처로 자연 교체 = 스테이지-파생 상태 리셋 계약과 정합). 파라미터 shape 전부 스테이지-불변."""
    torch, nn = _torch()
    ch = cfg["conv_channels"]
    feat_dim = len(mdp.landmark_instances[0]["features"])
    cap = mdp.heads["landmark"]
    feats = torch.tensor([i["features"] for i in mdp.landmark_instances],
                         dtype=torch.float32)                    # N×F (N ≤ cap)

    class PolicyR4(nn.Module):
        def __init__(self):
            super().__init__()
            self.conv = nn.Sequential(
                nn.Conv2d(8, ch, 3, padding=1), nn.ReLU(),
                nn.Conv2d(ch, ch, 3, padding=1), nn.ReLU(),
                nn.AdaptiveMaxPool2d((4, 4)))
            self.torso = nn.Sequential(
                nn.Linear(ch * 16 + mdp.flat_dim, cfg["hidden"]), nn.Tanh(),
                nn.Linear(cfg["hidden"], cfg["hidden"]), nn.Tanh())
            self.heads = nn.ModuleDict(
                {h: nn.Linear(cfg["hidden"], n) for h, n in mdp.heads.items()
                 if h != "landmark"})
            self.pointer = nn.Sequential(                        # 공유 점수기 — 후보 수 무관
                nn.Linear(cfg["hidden"] + feat_dim, cfg["hidden"] // 2), nn.Tanh(),
                nn.Linear(cfg["hidden"] // 2, 1))
            # persistent=False — state_dict 제외(스테이지-파생 상수: transfer 시 소스 N≠타깃 N
            # shape 충돌 방지 + "가중치만 이월" 계약과 정합. 재구성 = mdp.landmark_instances).
            self.register_buffer("landmark_feats", feats, persistent=False)

        def forward(self, grid, flat):
            z = self.conv(grid).flatten(1)
            z = self.torso(torch.cat([z, flat], dim=1))
            out = {h: self.heads[h](z) for h in mdp.head_names if h != "landmark"}
            n = self.landmark_feats.shape[0]
            zi = z.unsqueeze(1).expand(-1, n, -1)                # B×N×hidden
            fi = self.landmark_feats.unsqueeze(0).expand(z.shape[0], -1, -1)
            scores = self.pointer(torch.cat([zi, fi], dim=2)).squeeze(-1)   # B×N
            pad = torch.full((z.shape[0], cap - n), float("-inf"),
                             device=scores.device, dtype=scores.dtype)
            out["landmark"] = torch.cat([scores, pad], dim=1)    # B×cap (실존 후보 밖 = -inf)
            return out

    return PolicyR4()


def _grid_tensor(mdp: StageMDP):
    """스테이지 상수 그리드 → CNN 입력 텐서(1×C×H×W). mdp._grid 레이아웃 = (r*W+c)*C+ch.
    C = 채널 수(r1/r2/r3 레이아웃 5ch, r4 8ch — §R4a) 파생(그리드 길이/HW, 하드코딩 0)."""
    torch, _ = _torch()
    C = len(mdp._grid) // (mdp.H * mdp.W)
    return (torch.tensor(mdp._grid, dtype=torch.float32)
            .view(1, mdp.H, mdp.W, C).permute(0, 3, 1, 2).contiguous())


def _masked(lg, allowed: list[int], size: int):
    """허용 인덱스 밖 logits = -inf (무효 조합은 페널티가 아니라 표현 불가, plan §R2 P3).
    Categorical.entropy는 -inf logits를 finfo.min으로 clamp해 p=0 항이 0이 됨 — NaN 없음."""
    if len(allowed) >= size:
        return lg
    torch, _ = _torch()
    m = torch.full_like(lg, float("-inf"))
    m[allowed] = 0.0
    return lg + m


def _sample_episode_r2(mdp: StageMDP, policy, grid_t, greedy: bool = False,
                       prefix: list[dict[str, int]] | None = None):
    """r2 조건부 factored 샘플링: skill → (SUBMIT면 종료) → kind(스킬 메타로 단일 유효) → trigger →
    트리거-의존 head → kind-의존 head. 활성 head만 logp/entropy에 기여(비활성 head는 미샘플).
    스텝 0 SUBMIT 마스킹·인벤토리 동적 마스크는 mdp.head_mask가 담당.

    prefix(opt-in, witness-guided curriculum — 2026-07-13 스윕 실패 분석): 앞 k스텝을 인코딩된
    강제 액션으로 고정하고 정책은 그 이후만 샘플. 강제 스텝은 **결정이 아니므로** logp/entropy
    비기여(SIL replay도 _episode_logp_r2(start=k)로 동일 규약 — 마스크 밖 강제 idx의 -inf
    log_prob NaN 오염 차단). prefix=None(기본) = 기존 경로 byte-identical."""
    torch, _ = _torch()
    partial: list[dict[str, int]] = [dict(a) for a in (prefix or [])]
    used: dict[str, int] = {}
    for a in partial:                             # 강제 스텝의 인벤토리 소비를 마스크 문맥에 반영
        sid = mdp.skills[a["skill"]]
        used[sid] = used.get(sid, 0) + 1
    logps, ents = [], []
    for _t in range(len(partial), mdp.max_len):
        flat = torch.tensor(mdp.obs_flat_r2(partial), dtype=torch.float32).unsqueeze(0)
        logits = policy(grid_t, flat)
        idx: dict[str, int] = {}
        step_logp, step_ent = [], []

        def _pick(h: str) -> None:
            lg = _masked(logits[h][0], mdp.head_mask(h, _t, used, idx), mdp.heads[h])
            dist = torch.distributions.Categorical(logits=lg)
            a = torch.argmax(lg) if greedy else dist.sample()
            idx[h] = int(a)
            step_logp.append(dist.log_prob(a))
            step_ent.append(dist.entropy())

        _pick("skill")
        if idx["skill"] == mdp.SUBMIT:
            logps.append(step_logp[0])
            ents.append(step_ent[0])
            break
        _pick("kind")
        _pick("trigger")
        for h in mdp.active_heads(idx)[2:]:       # kind·trigger 이후 의존 head
            _pick(h)
        sid = mdp.skills[idx["skill"]]
        used[sid] = used.get(sid, 0) + 1
        logps.append(sum(step_logp))
        ents.append(sum(step_ent))
        partial.append(idx)
    zero = torch.tensor(0.0)
    return partial, (sum(logps) if logps else zero), (sum(ents) if ents else zero)


def _episode_logp_r2(mdp: StageMDP, policy, grid_t, partial: list[dict[str, int]],
                     start: int = 0):
    """저장 에피소드의 현행-정책 log-prob 재계산(SIL) — 샘플링 경로와 동일한 조건부 head·마스킹.
    start>0 = prefix curriculum의 강제 스텝 수: t<start는 logp 비기여(인벤토리 문맥만 반영) —
    강제 idx가 마스크 밖이면 log_prob=-inf로 loss가 NaN 오염되는 것 차단. start=0(기본) 무변경."""
    torch, _ = _torch()
    total = torch.tensor(0.0)
    used: dict[str, int] = {}
    for t, a in enumerate(partial):
        if t < start:                             # 강제 스텝 — 결정 아님(샘플링 경로와 동일 규약)
            sid = mdp.skills[a["skill"]]
            used[sid] = used.get(sid, 0) + 1
            continue
        flat = torch.tensor(mdp.obs_flat_r2(partial[:t]), dtype=torch.float32).unsqueeze(0)
        logits = policy(grid_t, flat)
        for h in ["skill"] + mdp.active_heads(a):
            lg = _masked(logits[h][0], mdp.head_mask(h, t, used, a), mdp.heads[h])
            total = total + torch.distributions.Categorical(logits=lg).log_prob(
                torch.tensor(a[h]))
        sid = mdp.skills[a["skill"]]
        used[sid] = used.get(sid, 0) + 1
    if len(partial) < mdp.max_len:                # 종료 SUBMIT 선택까지 포함(샘플링과 동일 마스킹)
        flat = torch.tensor(mdp.obs_flat_r2(partial), dtype=torch.float32).unsqueeze(0)
        lg = _masked(policy(grid_t, flat)["skill"][0],
                     mdp.head_mask("skill", len(partial), used, {}), mdp.heads["skill"])
        total = total + torch.distributions.Categorical(logits=lg).log_prob(
            torch.tensor(mdp.SUBMIT))
    return total


def _sample_episode(mdp: StageMDP, policy, greedy: bool = False):
    """정책에서 plan 1개 샘플. 반환 = (partial[head-idx dict...], logp 합, entropy 합).

    스텝 0의 SUBMIT은 마스킹(최소 plan 길이 1) — 빈 plan은 어떤 스테이지에서도 유효 해가 아니며,
    보상 0의 빈 plan이 음수-보상 탐험을 이기는 collapse attractor가 되는 걸 원천 차단(스모크 실측).
    """
    torch, _ = _torch()
    partial: list[dict[str, int]] = []
    logps, ents = [], []
    for _t in range(mdp.max_len):
        obs = torch.tensor(mdp.obs(partial), dtype=torch.float32).unsqueeze(0)
        logits = policy(obs)
        idx: dict[str, int] = {}
        step_logp, step_ent = [], []
        for h in mdp.head_names:
            lg = logits[h][0]
            if h == "skill" and _t == 0:
                lg = lg.clone()
                lg[mdp.SUBMIT] = float("-inf")
            dist = torch.distributions.Categorical(logits=lg)
            a = torch.argmax(lg) if greedy else dist.sample()
            idx[h] = int(a)
            step_logp.append(dist.log_prob(a))
            step_ent.append(dist.entropy())
        if idx["skill"] == mdp.SUBMIT:
            logps.append(step_logp[0])            # SUBMIT = skill head만 유효(다른 head 미사용)
            ents.append(step_ent[0])
            break
        logps.append(sum(step_logp))
        ents.append(sum(step_ent))
        partial.append(idx)
    zero = torch.tensor(0.0)
    return partial, (sum(logps) if logps else zero), (sum(ents) if ents else zero)


def _episode_logp(mdp: StageMDP, policy, partial: list[dict[str, int]]):
    """저장 에피소드의 현행-정책 log-prob 재계산(self-imitation, plan §R1 fallback 2).
    len<max_len이면 종료 SUBMIT 선택까지 포함(샘플링 경로와 동일 마스킹)."""
    torch, _ = _torch()
    total = torch.tensor(0.0)
    for t, a in enumerate(partial):
        logits = policy(torch.tensor(mdp.obs(partial[:t]), dtype=torch.float32).unsqueeze(0))
        for h in mdp.head_names:
            lg = logits[h][0]
            if h == "skill" and t == 0:
                lg = lg.clone()
                lg[mdp.SUBMIT] = float("-inf")
            total = total + torch.distributions.Categorical(logits=lg).log_prob(
                torch.tensor(a[h]))
    if len(partial) < mdp.max_len:
        lg = policy(torch.tensor(mdp.obs(partial), dtype=torch.float32).unsqueeze(0))["skill"][0]
        total = total + torch.distributions.Categorical(logits=lg).log_prob(
            torch.tensor(mdp.SUBMIT))
    return total


# ---------- R3 refine (trace-refinement — plan §R3, --refine opt-in) ----------

def make_policy_r3(mdp: StageMDP, cfg: dict):
    """r3 정책 = r2 CNN + trace 공간 채널 concat(5→5+C_TRACE) + trace 집계 스칼라(flat append).
    파라미터 shape는 여전히 스테이지-무관(전역 어휘) — from-scratch 학습(R3 primary는 transfer 미사용)."""
    torch, nn = _torch()
    ch = cfg["conv_channels"]
    in_ch = 5 + C_TRACE

    class PolicyR3(nn.Module):
        def __init__(self):
            super().__init__()
            self.conv = nn.Sequential(
                nn.Conv2d(in_ch, ch, 3, padding=1), nn.ReLU(),
                nn.Conv2d(ch, ch, 3, padding=1), nn.ReLU(),
                nn.AdaptiveMaxPool2d((4, 4)))
            self.torso = nn.Sequential(
                nn.Linear(ch * 16 + mdp.flat_dim_r3, cfg["hidden"]), nn.Tanh(),
                nn.Linear(cfg["hidden"], cfg["hidden"]), nn.Tanh())
            self.heads = nn.ModuleDict(
                {h: nn.Linear(cfg["hidden"], n) for h, n in mdp.heads.items()})

        def forward(self, grid, flat):
            z = self.conv(grid).flatten(1)
            z = self.torso(torch.cat([z, flat], dim=1))
            return {h: self.heads[h](z) for h in mdp.head_names}

    return PolicyR3()


def _trace_grid_tensor(mdp: StageMDP, res: dict, blind: bool = False):
    """trace 공간 채널 → CNN 입력 텐서(1×C_TRACE×H×W). blind = 전부 0(trace-blind 대조)."""
    torch, _ = _torch()
    tc = [0.0] * (mdp.H * mdp.W * C_TRACE) if blind else mdp.trace_channels(res)
    return (torch.tensor(tc, dtype=torch.float32)
            .view(1, mdp.H, mdp.W, C_TRACE).permute(0, 3, 1, 2).contiguous())


def _r3_grid(mdp: StageMDP, grid_t, res: dict, blind: bool = False):
    """layout 5ch(상수 grid_t) + trace C_TRACE ch(per-obs) concat → 1×(5+C_TRACE)×H×W."""
    torch, _ = _torch()
    return torch.cat([grid_t, _trace_grid_tensor(mdp, res, blind)], dim=1)


class Rollouter:
    """refine 롤아웃 캐시(plan §R3 memo). memo_key = sha256(exec_config_digest, 정규화 lowered plan).
    캐시는 처리량만 — verdict/보상/샘플링 불변(acceptance 3이 memo-on==--no-memo byte-identical 실증).
    use_memo=False면 매 롤아웃 실행(결정론 대조). 회계: requests/total_rollouts/distinct/hit_rate."""

    def __init__(self, pool: EnvPool, mdp: StageMDP, cfg: dict, exec_digest: str,
                 use_memo: bool = True):
        self.pool, self.mdp, self.cfg = pool, mdp, cfg
        self.exec_digest, self.use_memo = exec_digest, use_memo
        self.cache: dict[str, dict] = {}
        self.seen: set[str] = set()
        self.requests = 0
        self.total_rollouts = 0

    def _key(self, lowered: list) -> str:
        return _sha_obj([self.exec_digest, lowered])

    def _plan(self, lowered: list) -> dict:
        return {"stage": self.mdp.stage_scene, "deadline_frames": self.cfg["train_deadline"],
                "trace": True, "actions": lowered}

    def _run(self, k: str, lowered: list) -> dict:
        r = self.pool.envs[0].step(self._plan(lowered))
        if not _trace_valid(r.get("trace")):
            raise RuntimeError(
                f"refine 롤아웃 유효 trace 부재(fail-closed): digest={_digest(r)}")
        self.total_rollouts += 1
        self.seen.add(k)
        if self.use_memo:
            self.cache[k] = r
        return r

    def get(self, partial: list) -> dict:
        self.requests += 1
        lowered = self.mdp.decode_plan(partial)
        k = self._key(lowered)
        if self.use_memo and k in self.cache:
            return self.cache[k]
        return self._run(k, lowered)

    def batch(self, partials: list) -> list[dict]:
        """distinct un-cached prefix를 pool 병렬 평가(입력 순서대로 반환) — refine 처리량 유지."""
        self.requests += len(partials)
        lowereds = [self.mdp.decode_plan(p) for p in partials]
        keys = [self._key(l) for l in lowereds]
        local: dict[str, dict] = {}
        need: dict[str, list] = {}
        for k, l in zip(keys, lowereds):
            if self.use_memo and k in self.cache:
                local[k] = self.cache[k]
            elif k not in need:
                need[k] = l
        if need:
            nk = list(need)
            res = self.pool.evaluate([self._plan(need[k]) for k in nk])
            for k, r in zip(nk, res):
                if not _trace_valid(r.get("trace")):
                    raise RuntimeError(
                        f"refine 배치 롤아웃 유효 trace 부재(fail-closed): digest={_digest(r)}")
                self.total_rollouts += 1
                self.seen.add(k)
                local[k] = r
                if self.use_memo:
                    self.cache[k] = r
        return [local[k] for k in keys]

    @property
    def distinct(self) -> int:
        return len(self.seen)

    @property
    def memo_hit_rate(self) -> float:
        return round(1.0 - self.total_rollouts / self.requests, 4) if self.requests else 0.0


def _sample_batch_refine(mdp: StageMDP, policy, grid_t, roll: Rollouter, cfg: dict,
                         greedy: bool = False, blind: bool = False, n: int | None = None):
    """refine 에피소드 배치를 depth-lockstep으로 전진(N-env 병렬 + memo 유지): 스텝 t에서 각 활성
    에피소드의 P_t를 롤아웃(배치)→trace 관측→액션 샘플. append면 P_{t+1}, SUBMIT/max_len이면 terminal.
    반환 = [(partial, logp, ent, final_result)] — final_result = rollout(최종 plan)(중간 obs 롤아웃 재사용).
    RNG: torch 스트림을 depth×episode 순으로 소비(refine 전용 경로 — 재개 등가성은 동일 경로 재사용으로 성립)."""
    torch, _ = _torch()
    B = n if n is not None else cfg["batch"]
    eps = [{"partial": [], "used": {}, "logps": [], "ents": [], "done": False,
            "result": None} for _ in range(B)]
    for t in range(mdp.max_len + 1):
        active = [e for e in eps if not e["done"]]
        if not active:
            break
        results = roll.batch([e["partial"] for e in active])   # rollout(P_t) 관측(baseline=빈 plan)
        for e, r in zip(active, results):
            e["cur"] = r
        if t == mdp.max_len:                                   # 인벤토리/슬롯 소진 → 최종 롤아웃 확정
            for e in active:
                e["done"], e["result"] = True, e["cur"]
            break
        for e in active:
            flat = torch.tensor(mdp.obs_flat_r3(e["partial"], e["cur"], blind=blind),
                                dtype=torch.float32).unsqueeze(0)
            gin = _r3_grid(mdp, grid_t, e["cur"], blind)
            logits = policy(gin, flat)
            idx: dict[str, int] = {}
            step_logp, step_ent = [], []

            def _pick(h: str) -> None:
                lg = _masked(logits[h][0], mdp.head_mask(h, t, e["used"], idx), mdp.heads[h])
                dist = torch.distributions.Categorical(logits=lg)
                a = torch.argmax(lg) if greedy else dist.sample()
                idx[h] = int(a)
                step_logp.append(dist.log_prob(a))
                step_ent.append(dist.entropy())

            _pick("skill")
            if idx["skill"] == mdp.SUBMIT:                     # terminal — 최종 plan = P_t(rollout 재사용)
                e["logps"].append(step_logp[0])
                e["ents"].append(step_ent[0])
                e["done"], e["result"] = True, e["cur"]
                continue
            _pick("kind")
            _pick("trigger")
            for h in mdp.active_heads(idx)[2:]:
                _pick(h)
            sid = mdp.skills[idx["skill"]]
            e["used"][sid] = e["used"].get(sid, 0) + 1
            e["logps"].append(sum(step_logp))
            e["ents"].append(sum(step_ent))
            e["partial"].append(idx)
    zero = torch.tensor(0.0)
    out = []
    for e in eps:
        if e["result"] is None:                               # 방어(도달 불가 경로)
            e["result"] = roll.get(e["partial"])
        out.append((e["partial"], sum(e["logps"]) if e["logps"] else zero,
                    sum(e["ents"]) if e["ents"] else zero, e["result"]))
    return out


def _episode_logp_r3(mdp: StageMDP, policy, grid_t, partial: list[dict[str, int]],
                     roll: Rollouter, blind: bool = False):
    """저장 에피소드의 현행-정책 log-prob 재계산(SIL) — 각 prefix의 trace obs 필요(memo 재사용)."""
    torch, _ = _torch()
    total = torch.tensor(0.0)
    used: dict[str, int] = {}
    for t, a in enumerate(partial):
        res = roll.get(partial[:t])
        flat = torch.tensor(mdp.obs_flat_r3(partial[:t], res, blind=blind),
                            dtype=torch.float32).unsqueeze(0)
        logits = policy(_r3_grid(mdp, grid_t, res, blind), flat)
        for h in ["skill"] + mdp.active_heads(a):
            lg = _masked(logits[h][0], mdp.head_mask(h, t, used, a), mdp.heads[h])
            total = total + torch.distributions.Categorical(logits=lg).log_prob(
                torch.tensor(a[h]))
        sid = mdp.skills[a["skill"]]
        used[sid] = used.get(sid, 0) + 1
    if len(partial) < mdp.max_len:
        res = roll.get(partial)
        flat = torch.tensor(mdp.obs_flat_r3(partial, res, blind=blind),
                            dtype=torch.float32).unsqueeze(0)
        lg = _masked(policy(_r3_grid(mdp, grid_t, res, blind), flat)["skill"][0],
                     mdp.head_mask("skill", len(partial), used, {}), mdp.heads["skill"])
        total = total + torch.distributions.Categorical(logits=lg).log_prob(
            torch.tensor(mdp.SUBMIT))
    return total


def _dense_terms(mdp: StageMDP, partial: list, roll: Rollouter) -> tuple[float, list]:
    """dense PBRS(plan §R3 acceptance 6): F_t = γ·φ(P_{t+1}) − φ(P_t), γ=1.0, terminal φ=0(모든 종료
    원인). φ = R1 trace potential = mdp.shaped_bonus(rollout(P)). Σ F_t = γ^L·φ(term) − φ(P_0) =
    −φ(P_0)(정책-불변, Ng 1999) — telescoping 단위검증 대상. 반환 (Σ F_t, φ[P_0..P_L])."""
    L = len(partial)
    phis = [mdp.shaped_bonus(roll.get(partial[:t])) for t in range(L + 1)]
    total = 0.0
    for t in range(L):
        total += 1.0 * phis[t + 1] - phis[t]        # γ=1.0
    total += 0.0 - phis[L]                           # P_L → terminal, φ(terminal)=0
    return total, phis


def _dense_reward(mdp: StageMDP, partial: list, final_res: dict, roll: Rollouter) -> float:
    """dense 모드 보상 = R_d4(terminal verdict) + Σ_t F_t (R1 terminal trace-shaping off — 이중계상 차단)."""
    dense, _ = _dense_terms(mdp, partial, roll)
    return mdp.reward(final_res, len(partial)) + dense


# ---------- 지식-축적 보상 (워크로그 §14.3 v3, 사용자 설계 2026-07-10 — opt-in) ----------

# 계수(전체 스케일 = knowledge_coef): new_token=토큰 첫 사용(유한 vocab → 소진=자연 감쇠),
# repeat=미개선 동일-plan 반복 1회당 누진 페널티, repeat_cap=페널티 상한(repeat×cap이 최대 절대값).
KNOWLEDGE = {"new_token": 0.05, "repeat": 0.02, "repeat_cap": 50}


class KnowledgeLedger:
    """"지식으로 쌓이는 모든 행위 보상 + 같은 시행착오 반복 누진 페널티" 원장(§14.3 v3).

    시행착오(사용자 정의 2026-07-10) = **미클리어 & 두 프런티어 모두 미갱신**
    (빈손→candy 최소거리 / 운반→home 최소거리 — model.frontier_dists, 원시 물리 진척이라 shaping 순환 없음).
    - 신규-보상은 유한 **토큰** 단위만(plan 단위 신규-보상 금지 = 조합공간 novelty 파밍 방지).
    - 페널티는 **동일 plan의 미개선 반복**에만, 첫 시행착오는 0(사용 주저 방지) → 이후 누진(cap 클립).
    - 성공/개선 에피소드는 페널티 면제(수렴·SIL 재모방 보호).
    결정론(배치 내 에피소드 순서 고정)·RNG 미사용. ckpt 동승: resume=이월(재도전 가속),
    transfer=리셋(스테이지-국소 토큰이라 무의미). 불사용 인벤토리는 어떤 항에도 등장하지 않음(중립)."""

    def __init__(self, coef: float, data: dict | None = None):
        d = data or {}
        self.coef = float(coef)
        self.token_seen: set[str] = set(d.get("token_seen") or [])
        self.plan_fail_n: dict[str, int] = {k: int(v) for k, v in (d.get("plan_fail_n") or {}).items()}
        self.best_w = int(d.get("best_w", 1 << 30))
        self.best_c = int(d.get("best_c", 1 << 30))

    def repeat_term(self, sig: str) -> float:
        """현재 누진 페널티(≤0) — 관측만(미갱신). SIL 사용-시점 재평가용(수집-시점 박제 방지)."""
        n = self.plan_fail_n.get(sig, 0)
        if n <= 0:
            return 0.0
        return -self.coef * KNOWLEDGE["repeat"] * min(n, KNOWLEDGE["repeat_cap"])

    def observe(self, p: list, res: dict, layout: dict) -> float:
        """에피소드 1건 관측 → knowledge bonus(부호 포함) 반환 + 원장 갱신.
        ⚠토큰 = 액션의 **필드 값 단위**(skill=3, y_row=6, …) — 액션-조합 단위는 공간이 수만+라
        novelty 파밍 가능(§14.3 패치 위반). 조합 신규성은 '반복 페널티 부재'가 암묵 보상."""
        b = 0.0
        for tok in p:
            fields = (sorted(tok.items()) if isinstance(tok, dict)
                      else [("tok", json.dumps(tok, sort_keys=True))])
            for f, v in fields:
                ts = f"{f}={v}"
                if ts not in self.token_seen:
                    self.token_seen.add(ts)
                    b += self.coef * KNOWLEDGE["new_token"]
        w, c = model.frontier_dists(res.get("trace"), layout)
        improved = bool(res.get("cleared")) or w < self.best_w or c < self.best_c
        self.best_w = min(self.best_w, w)
        self.best_c = min(self.best_c, c)
        if improved:
            return b
        sig = json.dumps(p, sort_keys=True)
        b += self.repeat_term(sig)               # 첫 시행착오(n=0)=0 — 페널티는 반복부터
        self.plan_fail_n[sig] = self.plan_fail_n.get(sig, 0) + 1
        return b

    def to_dict(self) -> dict:
        return {"token_seen": sorted(self.token_seen),
                "plan_fail_n": dict(self.plan_fail_n),
                "best_w": self.best_w, "best_c": self.best_c}


# ---------- 정체-진단 검출기 (워크로그 §16, 사용자 결정 2026-07-11 — opt-in) ----------

class StallGovernor:
    """정체-진단 검출기(§16.6 최종형) — **격발 = 재시작 신호**(mid-run 게이트 아님).

    격발 = 미개선(bestR base) 연속 ≥ stall_batches **AND** 최근 stall_batches 창의
    **dup 점유율(1 − unique/total plan sig)** ≥ stall_share. 격발 시 train_seed가 즉시 중단하고
    오케스트레이터(train_seed_escalate)가 **같은 seed를 knowledge=always로 재시작**(§14.4가
    구출을 실증한 정확한 레짐 — 결정론 재현).
    보조 격발(opt-in, 2026-07-13 스윕 실패 분석): any_batches>0이면 **미개선 연속 ≥ any_batches
    단독**으로도 격발(dup 무관). 근거 = 2차 스윕 FAIL 12 중 10개가 '다양-고원'(dup 0.02~0.08 —
    여러 plan을 시도하며 전부 실패)이라 dup 조건이 격발을 영구 차단, blocked_n ~120으로 검출
    런이 예산을 전소(S6·S10·S18·S23·S24 실측). any_batches=0(기본) = 기존 동작 byte-identical.
    지연-투입(게이트/램프/해제/latch)은 3판 실측 반증으로 폐기(§16.4~16.6): bestR-틱/프런티어-틱
    해제 = 미세-진척 깜빡임으로 압력 누적 실패, latch(끝까지 유지)도 구출 실패 — knowledge의
    구출력은 batch 0부터의 경로 의존(α 신규-토큰 초기 지급 + β 페널티 점진 성장 + baseline
    공적응)이라 mid-run 투입으로 재현 불가.
    보정 실측(§16.4, dup max): 격발해야 = S12s1 0.756·S17s2 0.915 / 격발 금지 = S17s0 0.371 →
    기본 문턱 0.5. v2.1 꼬리(s4 0.452·s5 0.327)는 반복-병리가 아니라 초기-탐험(α) 수혜라
    **의도적 비격발**(α는 건강-런 교란과 동전의 양면 — 정직 트레이드오프). 실측 오격발 0.
    순수·RNG 미사용 — 검출 런의 보상 경로에 일절 불개입."""

    def __init__(self, stall_batches: int, stall_share: float, data: dict | None = None,
                 any_batches: int = 0):
        d = data or {}
        self.stall_batches = int(stall_batches)
        self.stall_share = float(stall_share)
        self.any_batches = int(any_batches)      # 0=off(기존 동작) — 보조 격발 문턱(dup 무관)
        self.window: list[list[str]] = [list(x) for x in (d.get("window") or [])]
        self.since_improve = int(d.get("since_improve", 0))
        self.fired = bool(d.get("fired", False))
        self.events: list[dict] = [dict(e) for e in (d.get("events") or [])]
        # 진단 계측(격발-차단 상태 관측 — §16.4 acceptance가 트리거 불발을 드러내 추가)
        self.blocked_n = int(d.get("blocked_n", 0))
        self.blocked_max_top = float(d.get("blocked_max_top", 0.0))
        self.blocked_max_dup = float(d.get("blocked_max_dup", 0.0))

    def _top_share(self) -> tuple[float, float, int]:
        """(최빈 sig 점유율, dup 점유율 = 1 − unique/total, 창 에피소드 수).
        dup 점유율 = '창 안에서 반복된 plan의 비율' — 격발 메트릭(§16.4 보정)."""
        n = sum(len(b) for b in self.window)
        if not n:
            return 0.0, 0.0, 0
        cnt: dict[str, int] = {}
        for b in self.window:
            for s in b:
                cnt[s] = cnt.get(s, 0) + 1
        return max(cnt.values()) / n, 1.0 - len(cnt) / n, n

    def observe_batch(self, batch_i: int, best_improved: bool, sigs: list[str]) -> None:
        """best_improved = bestR(base) 갱신(정체 카운터 리셋 — 민감한 검출이 의도:
        오검출은 dup 조건이 막고, 격발 후엔 train_seed가 중단하므로 과검출 비용 없음)."""
        if self.fired:
            return
        self.window.append(list(sigs))
        del self.window[:-self.stall_batches]
        if best_improved:
            self.since_improve = 0
            return
        self.since_improve += 1
        if self.since_improve >= self.stall_batches:
            share, dup, n = self._top_share()
            if dup >= self.stall_share:
                self.fired = True
                self.events.append({"batch": batch_i, "event": "on",
                                    "dup_share": round(dup, 4),
                                    "top_share": round(share, 4), "window_eps": n})
            elif self.any_batches and self.since_improve >= self.any_batches:
                # 보조 격발(다양-고원): dup 문턱 미달이어도 미개선이 any_batches까지 누적되면 격발.
                # rule 키로 주-격발(dup)과 구별 — 회계/사후분석에서 격발 사유 추적 가능.
                self.fired = True
                self.events.append({"batch": batch_i, "event": "on", "rule": "any_batches",
                                    "dup_share": round(dup, 4),
                                    "top_share": round(share, 4), "window_eps": n})
            else:
                # 진단 계측: 정체인데 반복-지배 문턱 미달로 격발이 막힌 상태(최초 1회 + 최대값 갱신 기록)
                if not self.blocked_n:
                    self.events.append({"batch": batch_i, "event": "blocked_first",
                                        "top_share": round(share, 4), "dup_share": round(dup, 4)})
                self.blocked_n += 1
                if share > self.blocked_max_top or dup > self.blocked_max_dup:
                    self.blocked_max_top = max(self.blocked_max_top, share)
                    self.blocked_max_dup = max(self.blocked_max_dup, dup)

    def summary(self) -> dict:
        return {"events": list(self.events), "blocked_n": self.blocked_n,
                "blocked_max_top": round(self.blocked_max_top, 4),
                "blocked_max_dup": round(self.blocked_max_dup, 4)}

    def to_dict(self) -> dict:
        return {"window": [list(x) for x in self.window],
                "since_improve": self.since_improve,
                "fired": self.fired, "events": list(self.events),
                "blocked_n": self.blocked_n,
                "blocked_max_top": self.blocked_max_top,
                "blocked_max_dup": self.blocked_max_dup}


# ---------- 학습 (seed 1개) ----------

def train_seed(mdp: StageMDP, pool: EnvPool, seed: int, cfg: dict,
               ckpt_in: dict | None = None, ckpt_mode: str | None = None,
               record_partial: bool = False):
    """학습 1 seed. 반환 = (result, state) — state는 r2 체크포인트-가능 전체 상태(r1.1은 None).

    체크포인트 로드 2모드(plan §R2 P1): resume = 전 상태 복원(같은 세그먼트 계속, RNG·SIL·entropy
    카운터·baseline·curve까지 — 재개 등가성의 대상) / transfer = policy+optimizer 가중치만 이월,
    스테이지-파생 상태(entropy 스케줄·SIL buffer·baseline)는 리셋, RNG는 새 seed."""
    torch, _ = _torch()
    # r2 플래그 = "r2-계열 기계"(샘플링/obs/ckpt 경로 공유) — r4.0 포함(§R4: head-제네릭 재사용).
    r4 = mdp.grammar_version == GRAMMAR_R4
    r2 = mdp.grammar_version == GRAMMAR_R2 or r4
    refine = bool(cfg.get("refine"))          # plan §R3 — trace-refinement(opt-in)
    dense = bool(cfg.get("dense_shaping"))    # plan §R3 acceptance 6 — dense PBRS fallback
    blind = bool(cfg.get("trace_blind"))      # plan §R3 acceptance 1 (ii) — trace 정보 격리 대조
    if refine and mdp.grammar_version != GRAMMAR_R2:
        raise RuntimeError("--refine는 --grammar r2.1 전용(plan §R3 — r2.1 문법 무변경, 관측만 확장)")
    torch.manual_seed(seed)
    policy = (make_policy_r4(mdp, cfg) if r4
              else (make_policy_r3(mdp, cfg) if refine
                    else make_policy_r2(mdp, cfg)) if r2 else make_policy(mdp, cfg["hidden"]))
    opt = torch.optim.Adam(policy.parameters(), lr=cfg["lr"])
    grid_t = _grid_tensor(mdp) if r2 else None
    roll = None
    if refine:
        exec_digest, _ = _exec_config_digest(mdp, cfg)
        roll = Rollouter(pool, mdp, cfg, exec_digest, use_memo=cfg.get("memo", True))
    baseline, baseline_init = 0.0, False
    episodes, batch_i = 0, 0                  # 세그먼트 카운터 — 예산 회계는 구간별(plan-R2 MED-4)
    wall_prev = 0.0                           # exact resume 시 같은 세그먼트의 이전 invocation 누적 wall
    seg_mode = "transfer" if ckpt_mode == "transfer" else "scratch"
    chain: list[dict] = []                    # 이전 스테이지의 완결 세그먼트들(재개 사슬, plan-R1 MED-1)
    ep_prior = bat_prior = 0                  # 사슬 누적 카운터(현 세그먼트 이전)
    curve: list[float] = []
    # self-imitation buffer (plan §R1 fallback 2): top-K (reward, partial), plan-sig 중복 제거.
    # 희소한 고보상 에피소드가 배치 평균에 희석돼 정책을 못 끌어올리는 병목(S12 bestR 0.447 정체 실측)
    # 을 (R−baseline)+ 가중 재모방으로 해소.
    sil_buf: list[tuple[float, list[dict[str, int]]]] = []
    sil_sigs: set[str] = set()
    result = {"seed": seed, "cleared": False, "episodes": 0, "wall_s": 0.0, "batches": 0,
              "best_reward": float("-inf"), "greedy_plan": None, "curve": curve}
    if ckpt_in is not None:
        if not r2:
            raise RuntimeError("체크포인트는 r2 문법 전용(plan §R2)")
        _ckpt_compat(ckpt_in, mdp, seed, ckpt_mode, cfg)     # fail-closed 비호환 거부
        policy.load_state_dict(ckpt_in["policy"])
        opt.load_state_dict(ckpt_in["optimizer"])
        if ckpt_mode == "resume":
            torch.set_rng_state(ckpt_in["torch_rng"])
            batch_i = int(ckpt_in["batch_i"])
            episodes = int(ckpt_in["episodes_seg"])
            wall_prev = float(ckpt_in["wall_seg"])
            baseline = float(ckpt_in["baseline"])
            baseline_init = bool(ckpt_in["baseline_init"])
            curve.extend(ckpt_in["curve_seg"])
            sil_buf = [(float(r), list(p)) for r, p in ckpt_in["sil_buf"]]
            sil_sigs = {json.dumps(p, sort_keys=True) for _, p in sil_buf}
            seg_mode = ckpt_in["seg_mode"]
            chain = list(ckpt_in["chain"])
            ep_prior, bat_prior = int(ckpt_in["episodes_prior"]), int(ckpt_in["batches_prior"])
            if bool(ckpt_in["cleared_seg"]):     # 클리어로 끝난 세그먼트의 resume = no-op(터미널)
                result.update(cleared=True, greedy_plan=ckpt_in.get("greedy_plan"))
        else:                                    # transfer: 스테이지-파생 상태 리셋(plan §R2 P1/P4)
            chain = list(ckpt_in["chain"]) + [_ckpt_segment(ckpt_in)]
            ep_prior = int(ckpt_in["episodes_prior"]) + int(ckpt_in["episodes_seg"])
            bat_prior = int(ckpt_in["batches_prior"]) + int(ckpt_in["batch_i"])
    t0 = time.monotonic()
    ran_batches = 0

    def _budget_left() -> bool:
        if cfg.get("max_batches"):               # 등가성 시험 모드: 배치 수만 종료 조건(plan-R2 MED-3 ⓓ)
            return ran_batches < cfg["max_batches"]
        return (episodes < cfg["max_episodes"]
                and wall_prev + (time.monotonic() - t0) < cfg["max_wall"])

    # witness-prefix curriculum(opt-in — run_training이 r2.1·non-refine·scratch로 게이트).
    # prefix 부재(기본) = 기존 경로 byte-identical(빈 리스트 → 샘플러/logp 인자 기본값과 동일 동작).
    prefix = [dict(a) for a in (cfg.get("prefix_actions") or [])]
    if prefix and (not r2 or r4 or refine):
        raise RuntimeError("prefix curriculum은 --grammar r2.1 non-refine 경로 전용(방어 가드)")

    def _sample(greedy: bool = False):
        return (_sample_episode_r2(mdp, policy, grid_t, greedy, prefix=prefix or None) if r2
                else _sample_episode(mdp, policy, greedy))

    def _ep_logp(p):
        if refine:
            return _episode_logp_r3(mdp, policy, grid_t, p, roll, blind=blind)
        return (_episode_logp_r2(mdp, policy, grid_t, p, start=len(prefix)) if r2
                else _episode_logp(mdp, policy, p))

    use_trace = cfg["shaping"] == "trace"                 # plan §R1 — trace-shaped 보상
    # 생산적 blocker 활용도 보너스(opt-in, plan §6.4 첫 수 — 2026-07-06). coef=0이면 완전 no-op(pinned
    # 경로 byte-identical). >0이면 롤아웃에 report_fired 부착(blocker 정착 셀) + reward에 blocker_bonus 가산.
    blocker_coef = float(cfg.get("blocker_coef", 0.0) or 0.0)
    if blocker_coef and refine:
        raise RuntimeError("--blocker-coef는 현재 non-refine(r2 primary) 경로 전용 — refine 미배선")
    # 지식-축적 보상(opt-in, §14.3 v3). coef=0이면 완전 no-op(pinned 경로 byte-identical).
    k_coef = float(cfg.get("knowledge_coef", 0.0) or 0.0)
    if k_coef and refine:
        raise RuntimeError("--knowledge-coef는 현재 non-refine(r2 primary) 경로 전용 — refine 미배선")
    # §16: knowledge_mode. always(기본) = §14.4 원행동(아래 ledger 경로 원문 그대로) /
    # stall = 검출 런(knowledge 미적용·governor만) → 격발 시 중단(train_seed_escalate가 재시작).
    k_mode = str(cfg.get("knowledge_mode", "always"))
    if k_mode not in ("always", "stall"):
        raise RuntimeError(f"knowledge_mode 미지원: {k_mode}")
    if k_mode == "stall" and not k_coef:
        raise RuntimeError("knowledge_mode=stall은 knowledge_coef>0 필요(재시작 시 적용할 크기)")
    ledger = None
    if k_coef and k_mode == "always":
        ledger = KnowledgeLedger(k_coef, (ckpt_in or {}).get("knowledge_ledger")
                                 if ckpt_mode == "resume" else None)
    governor = None
    if k_coef and k_mode == "stall":
        governor = StallGovernor(cfg.get("stall_batches", 30), cfg.get("stall_share", 0.5),
                                 (ckpt_in or {}).get("knowledge_governor")
                                 if ckpt_mode == "resume" else None,
                                 any_batches=int(cfg.get("stall_any_batches", 0) or 0))
    # §16 codex R1-H1 fail-closed: resume는 ckpt의 **유효 knowledge 모드**와 일치해야 한다.
    # escalate 재시작 ckpt = always-포맷(ledger 동승) — stall CLI로 재개하면 ledger 무시 + fresh
    # governor = 결정론 resume 계약 위반(침묵 오염). 레거시 ckpt(키 부재)는 동승 상태로 추론.
    k_eff = ("stall_detect" if governor is not None
             else "always" if ledger is not None else "none")
    if ckpt_in is not None and ckpt_mode == "resume":
        ck_eff = ckpt_in.get("knowledge_mode_effective",
                             "always" if "knowledge_ledger" in ckpt_in
                             else "stall_detect" if "knowledge_governor" in ckpt_in else "none")
        if k_eff != ck_eff:
            raise RuntimeError(
                f"resume knowledge-모드 불일치(fail-closed): ckpt={ck_eff} vs cfg={k_eff} — "
                "escalate 재시작(always-포맷) ckpt는 --knowledge-mode always(기본)로 재개할 것")
    while not result["cleared"] and _budget_left():
        batch_i += 1
        ran_batches += 1
        if refine:
            # closed-loop: 배치 각 에피소드가 P_0..P_L을 롤아웃하며 trace 관측(memo + N-env 병렬).
            # 최종 롤아웃(final_res)만 보상에 쓰임(중간 obs 롤아웃 보상 0 — 이중계상 차단).
            samp = _sample_batch_refine(mdp, policy, grid_t, roll, cfg, blind=blind)
            eps = [(p, lp, en) for (p, lp, en, _r) in samp]
            rollouts = [r for (_p, _lp, _en, r) in samp]
            episodes += len(eps)
            if dense:                                     # dense PBRS(acceptance 6): R_d4 + Σ F_t
                bonuses = [0.0] * len(eps)                # 로깅용(terminal shaping off)
                rewards = [_dense_reward(mdp, p, r, roll)
                           for (p, _, _), r in zip(eps, rollouts)]
            else:                                         # primary: R_d4 + R1_terminal_shaping(계상 1회)
                bonuses = [mdp.shaped_bonus(r) for r in rollouts]
                rewards = [mdp.reward(r, len(p)) + b
                           for (p, _, _), r, b in zip(eps, rollouts, bonuses)]
        else:
            eps = [_sample() for _ in range(cfg["batch"])]
            plans = [{"stage": mdp.stage_scene, "deadline_frames": cfg["train_deadline"],
                      **({"trace": True} if (use_trace or ledger is not None) else {}),
                      **({"report_fired": True} if blocker_coef else {}),
                      "actions": mdp.decode_plan(p)} for p, _, _ in eps]
            rollouts = pool.evaluate(plans)
            episodes += len(eps)
            if use_trace or ledger is not None:
                # post-commit codex R4 MEDIUM: 빈-plan preflight만으론 "액션 발화 시 trace 소실" 회귀를 못
                # 잡고, shaped_bonus의 {} fail-safe가 무력화를 침묵시킴 → **액션 롤아웃별 trace 검증**.
                # 위반 = 학습 run 전체 fail(정직 크래시 — silent shaping 격하로 'trace' 라벨 산출물 금지).
                for r in rollouts:
                    if not _trace_valid(r.get("trace")):
                        raise RuntimeError(
                            f"trace-shaped 학습 롤아웃에 유효 trace 부재 — 엔진/Env trace 수집 회귀 "
                            f"(fail-closed): digest={_digest(r)}")
            bonuses = [mdp.shaped_bonus(r) if use_trace else 0.0 for r in rollouts]
            rewards = [mdp.reward(r, len(p)) + b + mdp.blocker_bonus(r, blocker_coef)
                       for (p, _, _), r, b in zip(eps, rollouts, bonuses)]
        # 지식 항(§14.3): PG 보상에만 가산. bestR/SIL은 base 보상 기준(시간-가변 항 섞이면 비교 불능 +
        # SIL 수집-시점 고보상 박제가 collapse를 되레 지속시키는 역효과 — 사용-시점 repeat_term 재평가로 대체).
        br = rewards
        if ledger is not None and not refine:
            br = list(rewards)
            rewards = [rw + ledger.observe(p, r, mdp.layout)
                       for (p, _, _), r, rw in zip(eps, rollouts, br)]
        prev_best = result["best_reward"]
        bi = max(range(len(br)), key=lambda i: br[i])
        if br[bi] > result["best_reward"]:
            result["best_episode"] = mdp.decode_plan(eps[bi][0])   # FAIL 사후 진단용(스윕 로그)
        result["best_reward"] = max(result["best_reward"], max(br))
        if governor is not None:
            # §16.6 검출 런: 보상 경로 불개입(위 ledger 분기 미진입) — 관측만. 격발 = 즉시 중단
            # (지연-투입 3판 반증 — 구출은 train_seed_escalate의 always 재시작이 담당).
            governor.observe_batch(batch_i, max(br) > prev_best,
                                   [json.dumps(p, sort_keys=True) for p, _, _ in eps])
            if governor.fired:
                result["stall_escalate"] = dict(governor.events[-1])
                ev = governor.events[-1]
                rule_note = f", rule={ev['rule']}" if ev.get("rule") else ""
                print(f"  [seed {seed}] stall 격발(batch {batch_i}, "
                      f"dup {ev.get('dup_share')}{rule_note}) → 검출 런 중단")
                break
        mean_r = sum(rewards) / len(rewards)
        mean_shape = sum(bonuses) / len(bonuses)
        curve.append(round(mean_r, 4))
        if not baseline_init:
            baseline, baseline_init = mean_r, True
        ent_coef = max(cfg["entropy_min"], cfg["entropy"] * cfg["entropy_decay"] ** batch_i)
        loss = torch.tensor(0.0)
        for (p, logp, ent), rew in zip(eps, rewards):
            loss = loss + (-(rew - baseline) * logp - ent_coef * ent)
        loss = loss / len(eps)
        if cfg["sil"]:
            # buffer 갱신(top-K, sig 중복 제거) 후 (R−baseline)+ 가중 모방 항 가산.
            # k_coef>0이면 buffer엔 base 보상(br) 저장 + 사용 시점에 현재 repeat_term으로 재평가 —
            # 수집-시점 지식 항을 박제하면 baseline 하락과 함께 collapse plan 모방이 되레 강화되는 역효과.
            for (p, _lp, _e), rew in zip(eps, br):
                sig = json.dumps(p, sort_keys=True)
                if sig not in sil_sigs:
                    sil_buf.append((rew, p))
                    sil_sigs.add(sig)
            sil_buf.sort(key=lambda t: -t[0])
            for rew, p in sil_buf[cfg["sil_buffer"]:]:
                sil_sigs.discard(json.dumps(p, sort_keys=True))
            del sil_buf[cfg["sil_buffer"]:]
            if ledger is not None:
                used_sil = []
                for rew, p in sil_buf:
                    eff = rew + ledger.repeat_term(json.dumps(p, sort_keys=True))
                    if eff > baseline:
                        used_sil.append((eff, p))
            else:
                used_sil = [(rew, p) for rew, p in sil_buf if rew > baseline]
            if used_sil:
                sil_term = torch.tensor(0.0)
                for rew, p in used_sil:
                    sil_term = sil_term + (rew - baseline) * (-_ep_logp(p))
                loss = loss + cfg["sil_coef"] * sil_term / len(used_sil)
        opt.zero_grad()
        loss.backward()
        opt.step()
        baseline = cfg["baseline_decay"] * baseline + (1 - cfg["baseline_decay"]) * mean_r
        if batch_i % 10 == 0:
            shape_note = f" meanShape={mean_shape:.3f}" if use_trace else ""
            gov_note = (f" gov=si{governor.since_improve}"
                        if governor is not None else "")
            print(f"  [seed {seed}] batch {batch_i} eps={episodes} meanR={mean_r:.3f}{shape_note} "
                  f"bestR={result['best_reward']:.3f}{gov_note} wall={time.monotonic() - t0:.0f}s")
        # greedy 평가(성공 판정 = 표준 deadline에서 saved==hp_stage)
        if batch_i % cfg["greedy_every"] == 0:
            with torch.no_grad():
                if refine:
                    gp = _sample_batch_refine(mdp, policy, grid_t, roll, cfg,
                                              greedy=True, blind=blind, n=1)[0][0]
                else:
                    gp, _, _ = _sample(greedy=True)
            plan = mdp.decode_plan(gp)
            # trace:true = 실행-동치 dedup 키(solution_registry.exec_digest) 원료 — 가산적·판정 불변
            # (Phase 2 실증: trace byte-identical·verdict 불변). 클리어 시 res가 그대로 기록에 쓰임.
            res = pool.envs[0].step({"stage": mdp.stage_scene, "trace": True,
                                     "deadline_frames": cfg["replay_deadline"], "actions": plan})
            if res.get("cleared") and int(res.get("saved") or 0) == mdp.hp:
                result.update(cleared=True, greedy_plan=plan)
                print(f"  [seed {seed}] GREEDY CLEAR saved={res.get('saved')}/{mdp.hp} "
                      f"frame={res.get('frame')} eps={episodes}")
                _record_found(mdp, seed, plan, res, cfg, refine, episodes)  # 발견 즉시 durable 기록
                break
    result["episodes"] = episodes
    result["batches"] = batch_i
    result["wall_s"] = round(wall_prev + (time.monotonic() - t0), 1)
    if refine:
        # 처리량 회계(plan §R3 THROUGHPUT_FLOOR — wall-bound vacuous FAIL 진단·binding 축 판별).
        if result["cleared"]:
            binding = "clear"
        elif cfg.get("max_batches"):
            binding = "batches"
        elif episodes >= cfg["max_episodes"]:
            binding = "episode"
        else:
            binding = "wall"
        tp = {
            "episodes_completed": episodes,
            "distinct_prefix_rollouts": roll.distinct,
            "total_rollouts": roll.total_rollouts,
            "memo_hit_rate": roll.memo_hit_rate,
            "wall_s": result["wall_s"], "binding_axis": binding,
            "throughput_floor": dict(THROUGHPUT_FLOOR)}
        tp["floor_reached"] = _floor_reached(tp)   # raw 카운터 파생(verify가 재계산·대조)
        result["throughput"] = tp
    if not result["cleared"] and result.get("best_episode") is not None:
        print(f"  [seed {seed}] FAIL bestR={result['best_reward']:.3f} best plan: "
              f"{json.dumps(result['best_episode'])}")
        if record_partial:                     # kwarg 게이트(cfg 비참여 = exec-digest/pin 불변)
            _record_partial(mdp, seed, result["best_episode"], cfg,
                            result["episodes"], result["batches"],
                            result["best_reward"], refine)
    state = None
    if r2:
        # 직렬화 대상 전수(plan-R1 MED-1): policy+optimizer + entropy 카운터(batch_i) + 사용 RNG 전수
        # (현 구현 = torch 단일; python random/numpy 미사용) + SIL 내용·순서 + 누적 카운터 + 문법/
        # digest/모델 config·dtype + 재개 사슬. r3(refine)은 별도 포맷(관측 확장 → r2 정책과 비호환).
        state = {
            "format": (CKPT_FORMAT_R3 if refine
                       else CKPT_FORMAT_R4 if r4 else CKPT_FORMAT),
            "grammar_version": mdp.grammar_version,
            "vocab_digest": mdp.vocab_digest, "stage_id": mdp.stage_id,
            "layout_digest": mdp.layout_digest(), "mask_digest": mdp.mask_digest(),
            "model_cfg": _model_cfg(mdp, cfg), "dtype": "float32",
            "seed": seed, "seg_mode": seg_mode,
            "batch_i": batch_i, "episodes_seg": episodes,
            "wall_seg": result["wall_s"], "cleared_seg": bool(result["cleared"]),
            "baseline": baseline, "baseline_init": baseline_init,
            "curve_seg": list(curve),
            "episodes_prior": ep_prior, "batches_prior": bat_prior,
            "sil_buf": [[r, p] for r, p in sil_buf],
            "torch_rng": torch.get_rng_state(),
            "policy": policy.state_dict(), "optimizer": opt.state_dict(),
            "chain": chain, "greedy_plan": result["greedy_plan"],
        }
        if ledger is not None:      # §14.3 opt-in에서만 동승 — coef=0 ckpt는 기존과 키 구성 동일
            state["knowledge_ledger"] = ledger.to_dict()
        if governor is not None:    # §16 stall 모드에서만 동승(resume 복원 + 격발 계측 박제)
            state["knowledge_governor"] = governor.to_dict()
        if k_eff != "none":         # §16 codex R1-H1: 유효 모드 박제(resume 라우팅 fail-closed 대조 키).
            state["knowledge_mode_effective"] = k_eff   # coef=0 ckpt는 키 부재 = 기존과 구성 동일
    if governor is not None:
        result["knowledge_governor"] = {"mode": "stall",
                                        "stall_batches": governor.stall_batches,
                                        "stall_share": governor.stall_share,
                                        # 보조 격발 문턱은 opt-in일 때만 표기(기존 로그/회계 포맷 보존)
                                        **({"stall_any_batches": governor.any_batches}
                                           if governor.any_batches else {}),
                                        **governor.summary()}
        print(f"  [seed {seed}] governor: {result['knowledge_governor']}")
    return result, state


def train_seed_escalate(mdp: StageMDP, pool: EnvPool, seed: int, cfg: dict,
                        ckpt_in: dict | None = None, ckpt_mode: str | None = None,
                        record_partial: bool = False):
    """§16.6 stall 모드 front-door — 검출 런 → 격발 시 **같은 seed × knowledge=always 재시작**.

    근거: 지연-투입(게이트/latch)은 3판 실측 반증(§16.4~16.6) — knowledge의 구출력은 batch 0부터의
    경로 의존이라 mid-run 투입으로 재현 불가. 재시작 레짐은 §14.4가 해당 병리(S12 s1 collapse·
    S17 s2 고원) 구출을 실증한 **정확한 커맨드**(결정론 재현). §11.4 reseed(새 seed × 같은 레짐 =
    같은 함정 반복)와 달리 같은 seed × 다른 레짐. 비용 = 검출 배치(stall_batches+α)가 격발 seed에
    한해 추가 — 무격발(건강) seed는 검출 런이 곧 결과(보상 경로 불개입 = knowledge-무 런과 동일).
    비-stall cfg는 무변경 통과(위임만). 반환 = 최종 (result, state); 격발 시 result에
    stall_escalation(검출 회계) 동승."""
    res, st = train_seed(mdp, pool, seed, cfg, ckpt_in, ckpt_mode,
                         record_partial=record_partial)
    if not res.get("stall_escalate"):
        return res, st
    always_cfg = {k: v for k, v in cfg.items()
                  if k not in ("knowledge_mode", "stall_batches", "stall_share",
                               "stall_any_batches")}
    # 구출 런 ckpt 라우팅(§16 codex R2-H1): resume-모드 검출 ckpt(stall_detect)를 always_cfg에
    # 그대로 넘기면 R1 fail-closed 가드가 격발 시점에 거부 → **resume이면 무-ckpt 재시작**(문서화된
    # escalate 의미론 = 같은 seed × 처음부터 always). transfer는 보존(가중치 warm-start가 사용자
    # 의도이고 §12 SOP상 ledger/governor 리셋이라 모드-가드 비대상).
    # §16 codex R3-H1(하이브리드 4경로): **transfer-유래 검출 런이 '재개' 사슬로 격발**하면 재개
    # ckpt엔 transfer 원본 경로가 없어 구출 레짐(transfer×always)을 재구성할 수 없다 — silent
    # scratch 강등은 사용자 의도(warm-start) 파기이므로 fail-closed(명시 재실행 안내).
    if ckpt_mode == "resume" and (ckpt_in or {}).get("seg_mode") == "transfer":
        raise RuntimeError(
            "stall-escalate: transfer-유래 검출 런(재개 사슬)이 격발 — 재개 ckpt엔 transfer 원본이 "
            "없어 구출 레짐을 재구성할 수 없음(fail-closed). --knowledge-mode stall "
            "--transfer-ckpt <원본 소스>로 처음부터 재실행할 것")
    r_ckpt, r_mode = (None, None) if ckpt_mode == "resume" else (ckpt_in, ckpt_mode)
    print(f"  [seed {seed}] stall-escalate → knowledge=always 재시작(§14.4 레짐"
          f"{', 검출 resume-ckpt 미승계=scratch' if ckpt_mode == 'resume' else ''})")
    res2, st2 = train_seed(mdp, pool, seed, always_cfg, r_ckpt, r_mode,
                           record_partial=record_partial)
    res2["stall_escalation"] = {"fire": res["stall_escalate"],
                                "detect_batches": res["batches"],
                                "detect_episodes": res["episodes"],
                                "detect_wall_s": res["wall_s"]}
    return res2, st2


# ---------- acceptance 오케스트레이션 (--seeds 집계, R2-H) ----------

def rl_json_path(stage_id: int) -> Path:
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl.json"


def rl4_json_path(stage_id: int) -> Path:
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl4.json"


def rl2_json_path(stage_id: int) -> Path:
    """r2 산출물은 별도 파일 — r0/r1 pinned 산출물(stageNN.rl.json)은 영구 보존(§R2 선결 계약)."""
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl2.json"


def _r3_variant(cfg: dict) -> str:
    if cfg.get("trace_blind"):
        return "trace_blind"
    if cfg.get("dense_shaping"):
        return "dense_fallback"
    return "primary"


def rl3_json_path(stage_id: int, variant: str = "primary") -> Path:
    """r3 산출물 — variant별 분리 파일(primary/dense/blind가 서로 clobber 방지, 세 런 전부 박제)."""
    suffix = "" if variant == "primary" else f".{variant}"
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl3{suffix}.json"


def _r3_outcome(entries: list[dict], passed: bool) -> str:
    """outcome enum(plan §R3 R3-med2): pass / model_fail / throughput-pin-invalid.
    (throughput-infeasible는 예산 개정 ≤1회 후 수동 escalate 산출물 — 자동 분류 대상 아님.)"""
    if passed:
        return "pass"
    non_cleared = [e for e in entries if not e["cleared"]]
    if non_cleared and all((e.get("throughput") or {}).get("floor_reached")
                           for e in non_cleared):
        return "model_fail"                   # floor 도달 후 미클리어 = 정당한 model FAIL
    return "throughput-pin-invalid"           # wall이 floor 전에 걸림 = infra(≠ model FAIL)


def _write_r3_artifact(mdp: StageMDP, args, cfg: dict, outs, seeds,
                       envs_effective: int, pf_info: dict, saved: dict) -> None:
    """stageNN.rl3[.variant].json — variant(primary/dense_fallback/trace_blind)·outcome·처리량 회계·
    인과 라벨(r3_mechanical_pass) 박제. mode↔pin 정합은 verify-r3가 강제."""
    variant = _r3_variant(cfg)
    mode = "dense_fallback" if cfg.get("dense_shaping") else "primary"
    cfg_pub = {**cfg, "reward": REWARD, "shaping_coeffs": dict(SHAPING),
               "obs_schema_digest": OBS_SCHEMA_DIGEST}
    exec_digest, exec_members = _exec_config_digest(mdp, cfg)
    entries = []
    for (res, _state), s in zip(outs, seeds):
        br = res["best_reward"]
        entries.append({
            "seed": s, "cleared": bool(res["cleared"]), "episodes": res["episodes"],
            "batches": res["batches"], "wall_s": res["wall_s"],
            "best_reward": (br if br != float("-inf") else None),
            "greedy_plan": res["greedy_plan"],
            "envs_requested": args.envs, "envs_effective": envs_effective,
            "throughput": res.get("throughput"),
            "preflight_trace": pf_info, "ckpt_saved": saved.get(s)})
    pinned = R3_PRIMARY_PIN["seeds"]
    need = (len(pinned) + (len(pinned) % 2) + 1) // 2
    n_clear = sum(1 for e in entries if e["seed"] in pinned and e["cleared"])
    passed = (n_clear >= need) and not cfg.get("max_batches")
    outcome = _r3_outcome([e for e in entries if e["seed"] in pinned], passed)
    cleared_entries = [e for e in entries if e["cleared"] and e.get("greedy_plan")]
    best = min(cleared_entries, key=lambda e: e["episodes"]) if cleared_entries else None
    out = {
        "stage": mdp.stage_scene, "stage_id": mdp.stage_id,
        "deadline_frames": cfg["replay_deadline"],
        "inventory": mdp.inventory,
        "actions": best["greedy_plan"] if best else None,
        "expect": {"cleared": True, "saved": mdp.hp},
        "rl_meta": {
            "grammar_version": mdp.grammar_version, "no_hint": True,
            "refine": True, "mode": mode, "variant": variant,
            "save_ckpt": bool(args.save_ckpt),   # ckpt 부재를 비-silent화(codex §R3 R4-MED)
            "obs_schema_digest": OBS_SCHEMA_DIGEST,
            "trace_channels": list(obs_schema()["trace_channels"]),
            "trace_scalars": list(obs_schema()["trace_scalars"]),
            "memo_key_members": sorted(exec_members.keys()),
            "exec_config_digest": exec_digest,
            "vocab_digest": mdp.vocab_digest, "layout_digest": mdp.layout_digest(),
            "config": cfg_pub,
            # r3_mechanical_pass = --refine(trace-full)이 ≥need 클리어(그것만 — trace 인과 주장 아님).
            # trace_causal_pass는 세 런(trace-full/terminal-only/trace-blind) 조합으로만 결정(verify-r3/report).
            "r3_mechanical_pass": passed,
            "outcome": outcome, "budget_revisions": 0,
            "pass_rule": f">={need}/{len(pinned)} pinned seeds greedy clear within per-seed budget",
            "run_mode": "pinned-acceptance" if (seeds == pinned and args.envs == R3_PRIMARY_PIN["envs"]
                                                and not cfg.get("max_batches")) else "exploratory",
            "seeds": entries, "envs_effective": envs_effective,
            "best_seed": best["seed"] if best else None,
        },
    }
    path = rl3_json_path(mdp.stage_id, variant)
    path.write_text(json.dumps(out, indent=1), encoding="utf-8")
    print(f"산출물 저장: {path} — variant={variant} mode={mode} outcome={outcome} "
          f"mech_pass={passed}")


def run_training(args) -> int:
    _PERSIST_FAILURES.clear()                 # 영속화 실패 회계 리셋(in-process 재호출 안전)
    r2 = args.grammar in (GRAMMAR_R2, GRAMMAR_R4)     # r2-계열(ckpt/산출물 기계 공유 — §R4)
    seeds = [int(s) for s in args.seeds.split(",")]
    if (args.save_ckpt or args.resume_ckpt or args.transfer_ckpt) and not r2:
        print("체크포인트 플래그는 --grammar r2.1/r4.0 전용(plan §R2 P1/§R4)")
        return 2
    if args.resume_ckpt and args.transfer_ckpt:
        print("--resume-ckpt와 --transfer-ckpt는 배타(로드 2모드 분리, plan-R2 HIGH-2)")
        return 2
    if (args.resume_ckpt or args.transfer_ckpt) and len(seeds) != 1:
        print("ckpt 로드는 seed 1개 커맨드 전용(per-seed 사슬 계약, plan-R3 HIGH-2)")
        return 2
    refine = bool(getattr(args, "refine", False))
    if refine and not r2:
        print("--refine는 --grammar r2.1 전용(plan §R3)")
        return 2
    # witness-prefix curriculum 검증(opt-in — 2026-07-13 스윕 실패 분석 액션 5).
    # 계약: r2.1 전용·non-refine·scratch 전용(ckpt 플래그 배타 — mask_digest가 prefix를 모름)·
    # --no-save 필수(pinned 산출물 rl*.json 완전 불가침 — 발견 기록은 레지스트리가 담당하고
    # hint 출처가 rec에 동승). k < max_len(자유 슬롯 ≥1 없으면 학습 대상이 없음).
    prefix_k = int(getattr(args, "prefix_k", 0) or 0)
    prefix_plan = getattr(args, "prefix_plan", None)
    if prefix_k < 0:
        print(f"--prefix-k는 음수 불가: {prefix_k}")
        return 2
    if bool(prefix_k) != bool(prefix_plan):
        print("--prefix-plan과 --prefix-k(>0)는 함께 지정(witness-prefix curriculum)")
        return 2
    if prefix_k:
        if args.grammar != GRAMMAR_R2:
            print("--prefix-plan은 --grammar r2.1 전용(r2 인코더/샘플러 경로)")
            return 2
        if refine:
            print("--prefix-plan은 non-refine 경로 전용(refine 샘플러 미배선)")
            return 2
        if args.save_ckpt or args.resume_ckpt or args.transfer_ckpt:
            print("--prefix-plan은 scratch 전용(ckpt 계약이 prefix를 모름 — resume/transfer 오염 차단)")
            return 2
        if not args.no_save:
            print("--prefix-plan은 --no-save 필수(pinned 산출물 보호 — 발견 기록은 레지스트리 담당)")
            return 2
        if prefix_k >= args.max_len:
            print(f"--prefix-k {prefix_k} >= --max-len {args.max_len} — 자유 슬롯 0(학습 대상 없음)")
            return 2
    mdp = StageMDP(args.stage, max_len=args.max_len, grammar=args.grammar,
                   at_frame_cap=args.train_deadline)
    cfg = dict(DEFAULTS, max_episodes=args.max_episodes, max_wall=args.max_wall,
               shaping=args.shaping, train_deadline=args.train_deadline, max_len=args.max_len,
               sil=bool(args.sil), max_batches=args.max_batches,
               blocker_coef=float(getattr(args, "blocker_coef", 0.0) or 0.0),  # opt-in(§6.4)
               knowledge_coef=float(getattr(args, "knowledge_coef", 0.0) or 0.0))  # opt-in(§14.3)
    # §16 정체-격발(opt-in): cfg 키는 stall일 때만 주입 — always/off 런의 cfg_pub(산출물 config·
    # 병합 동일성 비교)을 종전과 바이트 단위로 보존.
    if getattr(args, "knowledge_mode", "always") == "stall":
        if not cfg["knowledge_coef"]:
            print("--knowledge-mode stall은 --knowledge-coef>0 필요(격발 시 적용할 크기)")
            return 2
        cfg.update(knowledge_mode="stall",
                   stall_batches=int(getattr(args, "stall_batches", 30)),
                   stall_share=float(getattr(args, "stall_share", 0.5)))
        # 보조 격발(다양-고원, opt-in): 키는 >0일 때만 주입 — 기존 stall 런의 cfg_pub/산출물
        # config를 바이트 단위로 보존(§16 주입 규약과 동일).
        any_b = int(getattr(args, "stall_any_batches", 0) or 0)
        if any_b:
            if any_b < cfg["stall_batches"]:
                print(f"--stall-any-batches {any_b} < --stall-batches {cfg['stall_batches']} — "
                      "보조 문턱은 주 문턱 이상이어야 함(주-격발이 항상 선평가)")
                return 2
            cfg["stall_any_batches"] = any_b
    if prefix_k:
        # prefix 로드·인코딩(fail-closed): 어휘 밖 스킬/형식 오류 = 즉시 거부. encode는 witness
        # 값을 가장 가까운 격자로 스냅(x→셀센터, frame→양자화 bin) — 정확 재현이 아니라 유도가 목적.
        try:
            pp = Path(prefix_plan)
            pdata = json.loads(pp.read_text(encoding="utf-8"))
            pacts = pdata.get("actions") or pdata.get("plan") or []
            if prefix_k > len(pacts):
                print(f"--prefix-k {prefix_k} > 플랜 액션 수 {len(pacts)}")
                return 2
            # witness **전체** 인코딩(codex 07-16 R2 HIGH-1): 잔여 액션도 r2.1 격자로 표현 가능해야
            # "학습 표현 안에 클리어 completion 존재"가 성립한다. prefix만 인코딩하면 잔여가 문법 밖인
            # witness가 거짓 통과.
            encoded_all = [mdp.encode_action(a) for a in pacts]
            encoded = encoded_all[:prefix_k]
        except (OSError, ValueError, KeyError, json.JSONDecodeError,
                AttributeError, TypeError, IndexError) as e:
            # AttributeError/TypeError/IndexError: 기형 witness 형상(최상위 배열, null actions,
            # 빈 cell 배열 등)도 traceback(rc=1)이 아니라 rc=2 정규 거부(codex R5 MEDIUM).
            print(f"--prefix-plan 로드/인코딩 실패(fail-closed): {type(e).__name__}: {e}")
            return 2
        if len(pacts) > mdp.max_len:              # 총 길이도 학습 슬롯 수 안(codex R2 HIGH-1)
            print(f"--prefix-plan 액션 수 {len(pacts)} > 학습 max_len {mdp.max_len} — "
                  "clear completion이 학습 표현 밖(fail-closed)")
            return 2
        # 마스크-표현 가능성(codex R4 HIGH, _grammar_canon과 동일 워크): 인코딩이 되더라도 per-stage
        # head 마스크 밖이면(예: cell-전용 sand_mound를 mode:"ant"로) 정책 샘플러가 그 액션을 영원히
        # 생성할 수 없다 — 리플레이는 명시 mode를 존중해 클리어할 수 있으므로 리플레이 전에 거부.
        # 인벤토리 초과도 skill head 동적 마스크가 함께 잡는다(used 추적).
        used_mask: dict[str, int] = {}
        for i, enc_a in enumerate(encoded_all):
            for h in ["skill"] + mdp.active_heads(enc_a):
                if enc_a[h] not in mdp.head_mask(h, i, used_mask, enc_a):
                    print(f"--prefix-plan 마스크-표현 불가(fail-closed): actions[{i}] head "
                          f"{h}={enc_a[h]} — 정책이 산출할 수 없는 액션(스킬-대상 종류/인벤토리/"
                          "row·frame 도메인 위반). witness를 문법 안으로 재구성 후 재시도")
                    return 2
            sid_s = mdp.skills[enc_a["skill"]]
            used_mask[sid_s] = used_mask.get(sid_s, 0) + 1
        # 의미론 fail-closed(2026-07-16 §1 후속 1): 격자 스냅은 "가장 가까운" 표현일 뿐 의미 보존을
        # 보증하지 않는다 — S23 사례: 넓은 y밴드 witness가 1셀 밴드로 붕괴해 액션 미발화, 매 에피소드가
        # 오염 prefix로 시작 → 클리어 방향 기울기 원천 0(수 시간 낭비). **전체 왕복 플랜**(잔여도 왕복 —
        # codex R2 HIGH-1)을 엔진 리플레이 1회(권위 경로)로 확인, cleared 아니면 즉시 거부.
        joined = mdp.decode_plan(encoded_all)
        # deadline = 학습 롤아웃과 동일한 train_deadline(codex 07-16 R1 HIGH): witness 자체 deadline
        # (예: 12000)으로 리플레이하면 학습 지평(4500) 밖에서 클리어되는 witness가 거짓 통과 —
        # 어떤 학습 에피소드도 그 클리어에 도달할 수 없는데 게이트만 초록이 되는 조건을 차단.
        sem_deadline = int(args.train_deadline)
        # wall-clock 600s(codex R6 MEDIUM): deadline_frames는 시뮬 한도라 엔진 행에 무력 —
        # 행 시 run_plan이 자식을 죽이고 error dict 반환 → 아래 cleared 검사에서 rc=2 정규 거부.
        sem = solve.run_plan(mdp.stage_scene, joined, sem_deadline, trace=False,
                             report_fired=True, timeout=600.0)
        # 성공 기준 = cleared AND saved==hp_stage(codex R3 HIGH): 게임 cleared=true는 부분 회수
        # (saved<hp, 예: S18 니어-해 cleared=true saved=4/5)에서도 성립하지만 RL 학습 판정은
        # saved==hp라, cleared만 보면 학습이 도달할 수 없는 부분-클리어 witness가 거짓 통과한다.
        if not (sem.get("cleared") and int(sem.get("saved") or 0) == mdp.hp):
            err = f" error={sem.get('error')!r}" if sem.get("error") else ""
            print(f"--prefix-plan 의미론 검증 실패(fail-closed): 전체 왕복 플랜({len(joined)}액션) "
                  f"리플레이(deadline={sem_deadline}) cleared={sem.get('cleared')} "
                  f"saved={sem.get('saved')}/{mdp.hp}(요구=전량) reason={sem.get('reason')!r} "
                  f"frame={sem.get('frame')}{err} — witness가 격자 인코딩에서 의미를 잃었거나(밴드 "
                  "붕괴/트리거 스냅 등) 학습 지평(--train-deadline) 안에 전량-회수 클리어하지 못함. "
                  "grid-정렬 재구성 또는 deadline 재검토 후 재시도")
            return 2
        # prefix 발화 검사(codex R2 HIGH-2): cleared만 보면 prefix가 한 번도 발화하지 않아도(죽은
        # prefix) 잔여만으로 클리어되는 witness가 통과한다. 학습은 매 에피소드에 prefix를 강제해
        # 인벤토리·마스킹만 소모하므로 fail-closed 거부. (fired_actions.index = 플랜 배열 위치)
        fired_idx = {int(e.get("index", -1)) for e in (sem.get("fired_actions") or [])}
        unfired_prefix = [i for i in range(prefix_k) if i not in fired_idx]
        if unfired_prefix:
            print(f"--prefix-plan 의미론 검증 실패(fail-closed): prefix 액션 {unfired_prefix} 미발화 — "
                  "잔여만으로 클리어되는 죽은 prefix. witness에서 불필요 액션 제거 후 재시도")
            return 2
        unfired_rest = [i for i in range(prefix_k, len(joined)) if i not in fired_idx]
        if unfired_rest:
            print(f"[prefix] 경고: 잔여 액션 {unfired_rest} 미발화(클리어에는 무영향) — witness 정리 권장")
        print(f"[prefix] 의미론 검증 PASS: 전체 왕복 플랜({len(joined)}액션, prefix {prefix_k} 전부 발화) "
              f"리플레이(deadline={sem_deadline}) cleared saved={sem.get('saved')} frame={sem.get('frame')}")
        cfg["prefix_actions"] = encoded
        cfg["prefix_hint"] = {                    # 발견 기록 provenance(무힌트 발견과 명시 구별)
            "k": prefix_k, "source": _rel(pp),
            "sha256_16": hashlib.sha256(pp.read_bytes()).hexdigest()[:16]}
    if refine:                                    # plan §R3 — trace-refinement 계약(opt-in)
        cfg.update(refine=True, dense_shaping=bool(getattr(args, "dense_shaping", False)),
                   trace_blind=bool(getattr(args, "trace_blind", False)),
                   memo=not bool(getattr(args, "no_memo", False)),
                   obs_schema_digest=OBS_SCHEMA_DIGEST,
                   throughput_floor=dict(THROUGHPUT_FLOOR))
    ckpt_in, ckpt_mode = None, None
    if args.resume_ckpt:
        ckpt_in, ckpt_mode = load_ckpt(args.resume_ckpt), "resume"
    elif args.transfer_ckpt:
        ckpt_in, ckpt_mode = load_ckpt(args.transfer_ckpt), "transfer"
    dim_note = f"obs_dim={mdp.obs_dim}" if not r2 else f"flat_dim={mdp.flat_dim} grid={mdp.H}x{mdp.W}"
    prefix_note = (f" prefix={cfg['prefix_hint']['k']}@{cfg['prefix_hint']['source']}"
                   if cfg.get("prefix_hint") else "")
    print(f"=== Phase R 학습: stage {args.stage} (hp={mdp.hp}, inv={mdp.inventory}, "
          f"max_len={mdp.max_len}, {dim_note}) grammar={args.grammar} seeds={seeds} "
          f"shaping={cfg['shaping']} train_deadline={cfg['train_deadline']} "
          f"ckpt={ckpt_mode or 'none'}{prefix_note} ===")
    pool, envs_effective, pf_info = build_pool(
        args.envs, mdp.stage_scene,
        with_trace=(cfg["shaping"] == "trace" or refine or cfg["blocker_coef"] > 0
                    or cfg["knowledge_coef"] > 0))
    reseed_k = int(getattr(args, "reseed_on_fail", 0) or 0)
    if reseed_k and ckpt_in is not None:
        print("--reseed-on-fail은 scratch 학습 전용(ckpt 로드 모드=per-seed 사슬 계약과 배타)")
        return 2
    if reseed_k and cfg.get("knowledge_mode") == "stall":
        print("--reseed-on-fail과 --knowledge-mode stall은 배타(둘 다 재시도 오케스트레이션 — 조합 의미 미정의)")
        return 2
    try:
        if reseed_k:
            # collapse 회피(§11): 요청 seed가 FAIL이면 대체 seed로 재시도. 실제 학습된 seed로
            # seeds를 재바인딩(이후 zip/산출물 회계가 실 seed 기준). train_seed 무변경.
            outs, eff_seeds = [], []
            for slot_seed in seeds:
                rs = train_seed(mdp, pool, slot_seed, cfg, ckpt_in, ckpt_mode,
                                record_partial=True)
                attempt = 0
                while not rs[0]["cleared"] and attempt < reseed_k:
                    attempt += 1
                    alt = slot_seed + 1000 * attempt
                    print(f"  [reseed] slot {slot_seed} FAIL(collapse) → 대체 seed {alt} "
                          f"재시도 ({attempt}/{reseed_k})")
                    rs = train_seed(mdp, pool, alt, cfg, ckpt_in, ckpt_mode,
                                    record_partial=True)
                outs.append(rs)
                eff_seeds.append(rs[0]["seed"])
            seeds = eff_seeds
        else:
            outs = [train_seed_escalate(mdp, pool, s, cfg, ckpt_in, ckpt_mode,
                                        record_partial=True) for s in seeds]
    finally:
        pool.close()
    seed_results = [r for r, _ in outs]
    n_clear = sum(1 for r in seed_results if r["cleared"])
    need = (len(seeds) + (len(seeds) % 2) + 1) // 2         # ≥2/3 (일반화: 과반) — verify와 동일식
    passed = n_clear >= need
    print(f"=== 집계: {n_clear}/{len(seeds)} seed 클리어 (필요 ≥{need}) → {'PASS' if passed else 'FAIL'} ===")
    if refine:
        saved_r3: dict[int, dict] = {}
        if args.save_ckpt:
            for (res, state), s in zip(outs, seeds):
                p = ckpt_path(args.stage, s, refine=True)   # .r3.pt (R2 ckpt 미덮어쓰기)
                sha = save_ckpt(p, state)
                saved_r3[s] = {"path": _rel(p), "sha256": sha}
                print(f"ckpt 저장(r3): {p} sha256={sha[:16]}…")
        if not args.no_save:
            _write_r3_artifact(mdp, args, cfg, outs, seeds, envs_effective, pf_info, saved_r3)
        else:
            print("--no-save: 산출물 미저장(판정은 위 집계줄 — plan §R3 스모크 격리)")
        return _final_rc(passed)
    if r2:
        # 체크포인트 저장(P1 — 영속화). 클리어 여부 무관 저장(FAIL 세그먼트도 exact resume 대상;
        # transfer는 _ckpt_compat이 미클리어 ckpt를 거부).
        saved: dict[int, dict] = {}
        if args.save_ckpt:
            for (res, state), s in zip(outs, seeds):
                p = ckpt_path(args.stage, s, grammar=args.grammar)
                sha = save_ckpt(p, state)
                saved[s] = {"path": str(p.relative_to(ROOT)).replace("\\", "/"), "sha256": sha}
                print(f"ckpt 저장: {p} sha256={sha[:16]}…")
        if not args.no_save:
            _write_r2_artifact(mdp, args, cfg, outs, seeds, envs_effective, pf_info,
                               saved, ckpt_in, ckpt_mode)
        else:
            print("--no-save: 산출물 미저장(판정은 위 집계줄)")
        return _final_rc(passed)
    # ---- r1.1 산출물 경로(기존 그대로) ----
    ok = [r for r in seed_results if r["cleared"]]
    if ok and not args.no_save:
        best = min(ok, key=lambda r: r["episodes"])
        out = {
            "stage": mdp.stage_scene, "stage_id": args.stage,
            "deadline_frames": cfg["replay_deadline"],
            "inventory": mdp.inventory,
            "actions": best["greedy_plan"],
            "expect": {"cleared": True, "saved": mdp.hp},
            "rl_meta": {
                "grammar_version": GRAMMAR_VERSION, "no_hint": True,
                "envs_requested": args.envs, "envs_effective": envs_effective,
                "config": {**cfg, "reward": REWARD, "shaping_coeffs": dict(SHAPING)},
                # post-commit codex R5: pass_rule은 실제 seed 수 기반 — 단일-seed 스윕이 ">=2/3" 라벨로
                # 증거 과대표시하던 fail-open 차단. mode가 pinned acceptance와 탐사 스윕을 명시 구별
                # (pinned seed set = R0/R1 공통 [0,1,2]; verify는 어차피 seeds pin으로 스윕 산출물 거부).
                "pass": passed,
                "pass_rule": f">={need}/{len(seeds)} seeds greedy clear within per-seed budget",
                "mode": ("pinned-acceptance" if seeds == R0_PIN["seeds"]
                         else "exploratory-sweep"),
                "seeds": [{k: r[k] for k in ("seed", "cleared", "episodes", "wall_s", "best_reward")}
                          for r in seed_results],
                "curves": {str(r["seed"]): r["curve"] for r in seed_results},
                "best_seed": best["seed"],
            },
        }
        if cfg["shaping"] == "trace":
            out["rl_meta"]["preflight_trace"] = pf_info   # plan §R1 R2-M — verify-r1 fail-closed 증거
        path = rl_json_path(args.stage)
        path.write_text(json.dumps(out, indent=1), encoding="utf-8")
        print(f"산출물 저장: {path}")
    elif ok and args.no_save:
        print("--no-save: 산출물 미저장(판정은 위 집계줄 — plan §R1 S11 스모크 격리)")
    return _final_rc(passed)


# ---------- r2 산출물 (seed-단위 병합 — per-seed 사슬 커맨드 계약, plan-R3 HIGH-2) ----------

def _rel(p: str | Path) -> str:
    try:
        return str(Path(p).resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(p).replace("\\", "/")


def _write_r2_artifact(mdp: StageMDP, args, cfg: dict, outs, seeds, envs_effective: int,
                       pf_info: dict, saved: dict, ckpt_in: dict | None,
                       ckpt_mode: str | None) -> None:
    """stageNN.rl2.json(r4는 stageNN.rl4.json) — seed별 항목을 병합 누적(같은 stage·config·어휘일
    때만). FAIL seed도 기록(predicate는 pinned seed 3개가 모이면 재계산, plan §R2 acceptance 2)."""
    path = (rl4_json_path(mdp.stage_id) if mdp.grammar_version == GRAMMAR_R4
            else rl2_json_path(mdp.stage_id))
    # 병렬 per-seed 사슬이 같은 파일을 병합-쓰기 — read-merge-write를 lockfile로 직렬화(유실 차단).
    lock = path.with_suffix(".lock")
    fd = None
    for _ in range(600):
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except FileExistsError:
            time.sleep(0.1)
    if fd is None:
        raise RuntimeError(f"artifact lock 획득 실패(60s): {lock} — stale lock이면 수동 삭제")
    try:
        _merge_write_r2(path, mdp, args, cfg, outs, seeds, envs_effective, pf_info,
                        saved, ckpt_in, ckpt_mode)
    finally:
        os.close(fd)
        os.unlink(lock)


def _merge_write_r2(path: Path, mdp: StageMDP, args, cfg: dict, outs, seeds,
                    envs_effective: int, pf_info: dict, saved: dict,
                    ckpt_in: dict | None, ckpt_mode: str | None) -> None:
    cfg_pub = {**cfg, "reward": REWARD, "shaping_coeffs": dict(SHAPING)}
    prev_seeds: dict[int, dict] = {}
    curves: dict[str, list] = {}
    if path.exists():
        try:
            old = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            old = None
        om = (old or {}).get("rl_meta") or {}
        if (old and old.get("stage_id") == mdp.stage_id
                and om.get("grammar_version") == mdp.grammar_version
                and om.get("vocab_digest") == mdp.vocab_digest
                and om.get("config") == cfg_pub):
            prev_seeds = {e["seed"]: e for e in om.get("seeds", [])}
            curves = dict(om.get("curves", {}))
        elif old is not None:
            print(f"[r2 artifact] 기존 {path.name}와 stage/config/어휘 불일치 — "
                  "seed 병합 없이 새로 시작(혼합-config 집계 차단, fail-closed)")
    loaded = None
    if ckpt_in is not None:
        loaded = {"path": _rel(ckpt_in["_file_path"]), "sha256": ckpt_in["_file_sha"],
                  "mode": ckpt_mode}
    for (res, state), s in zip(outs, seeds):
        seg = {"stage_id": mdp.stage_id, "seed": s, "mode": state["seg_mode"],
               "episodes": res["episodes"], "batches": res["batches"],
               "wall_s": res["wall_s"], "cleared": bool(res["cleared"]),
               "ckpt_sha": (saved.get(s) or {}).get("sha256"),
               "ckpt_path": (saved.get(s) or {}).get("path")}
        br = res["best_reward"]
        prev_seeds[s] = {
            "seed": s, "cleared": bool(res["cleared"]), "episodes": res["episodes"],
            "batches": res["batches"], "wall_s": res["wall_s"],
            "best_reward": (br if br != float("-inf") else None),
            "greedy_plan": res["greedy_plan"],
            "envs_requested": args.envs, "envs_effective": envs_effective,
            "chain": state["chain"] + [seg],
            "ckpt_saved": saved.get(s), "ckpt_loaded": loaded,
        }
        if cfg["shaping"] == "trace":
            prev_seeds[s]["preflight_trace"] = pf_info
        # §16 stall 회계 동승(있을 때만 — 비-stall 런 entry는 종전과 키 구성 동일): escalate 여부·
        # 검출 오버헤드가 산출물에서 식별 가능해야 정직(클리어가 검출 런인지 always-구출인지).
        if res.get("stall_escalation"):
            prev_seeds[s]["stall_escalation"] = res["stall_escalation"]
        if res.get("knowledge_governor"):
            prev_seeds[s]["knowledge_governor"] = res["knowledge_governor"]
        curves[str(s)] = res["curve"]
    entries = [prev_seeds[k] for k in sorted(prev_seeds)]
    pinned = R2_PIN["seeds"]
    need = (len(pinned) + (len(pinned) % 2) + 1) // 2
    # 사슬 앞단 미클리어로 이 스테이지에 미도달한 seed = FAIL 집계(plan §R2 acceptance 2 —
    # 결측 seed는 not-cleared와 동치이므로 predicate는 기록된 클리어 수만으로 판정).
    n_clear = sum(1 for s in pinned if s in prev_seeds and prev_seeds[s]["cleared"])
    passed = n_clear >= need
    budget_pinned = (args.envs == R2_PIN["envs"] and not cfg.get("max_batches")
                     and all(cfg_pub.get(k) == R2_PIN[k]
                             for k in ("max_episodes", "max_wall", "shaping", "shaping_coeffs",
                                       "train_deadline", "sil", "sil_buffer", "sil_coef",
                                       "max_len", "replay_deadline")))
    cleared_entries = [e for e in entries if e["cleared"] and e.get("greedy_plan")]
    best = min(cleared_entries, key=lambda e: e["episodes"]) if cleared_entries else None
    out = {
        "stage": mdp.stage_scene, "stage_id": mdp.stage_id,
        "deadline_frames": cfg["replay_deadline"],
        "inventory": mdp.inventory,
        "actions": best["greedy_plan"] if best else None,
        "expect": {"cleared": True, "saved": mdp.hp},
        "rl_meta": {
            "grammar_version": mdp.grammar_version, "no_hint": True,
            "vocab_digest": mdp.vocab_digest, "layout_digest": mdp.layout_digest(),
            "config": cfg_pub, "envs_requested": args.envs,
            "pass": passed,
            "pass_rule": f">={need}/{len(pinned)} pinned seeds greedy clear "
                         "within per-segment budget",
            "mode": "pinned-acceptance" if budget_pinned else "exploratory-sweep",
            "seeds": entries,
            "curves": curves,
            "best_seed": best["seed"] if best else None,
        },
    }
    if mdp.grammar_version == GRAMMAR_R4:      # §R4 — 표현/계약 digest 동승(verify-r4 대조 키)
        out["rl_meta"].update(
            landmark_schema_digest=mdp.landmark_digest,
            landmark_count=len(mdp.landmark_instances),
            mask_digest=mdp.mask_digest(),
            knowledge_contract_digest=_knowledge_contract_digest(),
            blocker_contract_digest=_blocker_contract_digest())
    path.write_text(json.dumps(out, indent=1), encoding="utf-8")
    state_note = ("전 seed 집계" if all(s in prev_seeds for s in pinned)
                  else f"부분 집계({sorted(prev_seeds)})")
    print(f"산출물 저장: {path} — {state_note}, pinned pass={passed}")


# ---------- --verify-r0/--verify-r1 (fail-closed 로컬 게이트, R1-M2·R2-M3 / plan §R1) ----------

_BASE_CFG_KEYS = ("batch", "lr", "entropy", "entropy_min", "entropy_decay", "hidden",
                  "max_episodes", "max_wall", "train_deadline", "replay_deadline", "reward")
# grammar는 config 키가 아니라 rl_meta.grammar_version pin(§R2 선결 계약: 리터럴 동결) — std로 분류.
_PIN_STD_KEYS = ("seeds", "envs", "max_episodes", "max_wall", "replay_deadline", "grammar")


def _verify_pinned(stage_id: int, pin: dict, label: str) -> int:
    fails: list[str] = []
    path = rl_json_path(stage_id)
    if not path.exists():
        print(f"[{label}] FAIL: {path} 없음")
        return 1
    d = json.loads(path.read_text(encoding="utf-8"))
    meta = d.get("rl_meta") or {}
    cfg = meta.get("config") or {}
    # pinned 문법(리터럴 grammar + 길이)이 검증 기준 — §R2 선결 계약: r0/r1은 r1.1로 영원히 검증.
    mdp = StageMDP(stage_id, max_len=pin["max_len"], grammar=pin["grammar"])
    # ① manifest 완전성 + 스테이지 바인딩 + pinned 계약(impl-R1 HIGH: 다른 config/스테이지 산출물 차단)
    if d.get("stage_id") != stage_id:
        fails.append(f"stage_id {d.get('stage_id')} != {stage_id}")
    if d.get("stage") != mdp.stage_scene:
        fails.append(f"stage {d.get('stage')} != {mdp.stage_scene}")
    if cfg.get("replay_deadline") != pin["replay_deadline"]:
        fails.append(f"config.replay_deadline != pinned {pin['replay_deadline']}")
    if d.get("deadline_frames") != pin["replay_deadline"]:
        fails.append(f"deadline_frames != pinned {pin['replay_deadline']}")
    if (d.get("expect") or {}).get("saved") != mdp.hp:
        fails.append(f"expect.saved != hp_stage {mdp.hp}")
    if meta.get("no_hint") is not True:
        fails.append("no_hint != true")
    if meta.get("grammar_version") != pin["grammar"]:
        fails.append(f"grammar_version {meta.get('grammar_version')} != pinned {pin['grammar']}")
    if meta.get("pass") is not True:
        fails.append("rl_meta.pass != true")
    if meta.get("envs_requested") != pin["envs"]:
        fails.append(f"envs_requested != {pin['envs']} (pinned)")
    if cfg.get("max_episodes") != pin["max_episodes"] or cfg.get("max_wall") != pin["max_wall"]:
        fails.append("max_episodes/max_wall이 pinned 예산과 다름")
    for k in ("envs_effective", "seeds"):
        if k not in meta:
            fails.append(f"rl_meta.{k} 누락")
    extra_cfg = tuple(k for k in pin if k not in _PIN_STD_KEYS)   # R1: shaping/shaping_coeffs/train_deadline
    for k in _BASE_CFG_KEYS + extra_cfg:
        if k not in cfg:
            fails.append(f"config.{k} 누락")
    # pin 추가 상수는 값까지 강제(plan-R1-H1·R2-H — 계수·train_deadline stale 산출물 차단)
    for k in extra_cfg:
        if cfg.get(k) != pin[k]:
            fails.append(f"config.{k} {cfg.get(k)!r} != pinned {pin[k]!r}")
    # trace preflight 증거(plan §R1 R2-M): shaping=trace pin일 때 {ok,wall_s,runs} 필수,
    # envs_effective>1 → ok=true 강제(ok=false는 N=1 강등 계약 하에서만 허용).
    if pin.get("shaping") == "trace":
        pf = meta.get("preflight_trace")
        if not isinstance(pf, dict) or any(k not in pf for k in ("ok", "wall_s", "runs")):
            fails.append("rl_meta.preflight_trace {ok,wall_s,runs} 누락")
        else:
            # post-commit codex R1 MEDIUM: 값의 구조까지 강제 — runs는 preflight 계약(env당 정확히
            # 2회 = 2*envs_requested; pin envs>1이라 preflight 항상 실행), wall>0. runs=0/wall=0
            # 같은 무의미 자기-보고 증거를 fail-closed로 차단.
            eff = int(meta.get("envs_effective") or 0)
            if pf.get("runs") != 2 * pin["envs"]:
                fails.append(f"preflight_trace.runs {pf.get('runs')!r} != 2*envs_requested "
                             f"{2 * pin['envs']} (preflight 계약 위반 — 위조/무의미 증거)")
            w = pf.get("wall_s")
            if not (isinstance(w, (int, float)) and not isinstance(w, bool) and w > 0):
                fails.append(f"preflight_trace.wall_s {w!r} — 양수 실측치 아님")
            if eff > 1 and pf.get("ok") is not True:
                fails.append("envs_effective>1인데 preflight_trace.ok != true")
            if eff <= 1 and pf.get("ok") is True:
                fails.append("envs_effective<=1(N=1 강등)인데 preflight_trace.ok == true — 모순 manifest")
        # post-commit codex R2 MEDIUM: manifest의 preflight_trace는 자기-보고라 증거가 아니라 참고 —
        # **검증자 측 실행이 권위**. verify가 pinned env 수로 trace preflight를 직접 재실행해 병렬
        # trace 결정론을 실측한다(preflight/build_pool/EnvPool.evaluate 회귀를 JSON 편집으로 은폐 불가).
        # wall_s는 진단 출력일 뿐 신뢰 증거 아님.
        live_pool = None
        try:
            live_pool = EnvPool(pin["envs"])
            live = preflight(live_pool, mdp.stage_scene, with_trace=True)
            if (live["ok"] is not True or live["runs"] != 2 * pin["envs"]
                    or live.get("trace_present") is not True):   # R3: trace 부재도 명시 거부
                fails.append(f"검증자 측 trace preflight 실측 FAIL: {live}")
        except Exception as e:
            fails.append(f"검증자 측 trace preflight 실행 불가({type(e).__name__}: {e}) — fail-closed")
        finally:
            if live_pool is not None:
                live_pool.close()
    seeds = meta.get("seeds") or []
    if [s.get("seed") for s in seeds] != pin["seeds"]:
        fails.append(f"seeds {[s.get('seed') for s in seeds]} != pinned {pin['seeds']}")
    # 예산 게이트 시맨틱: _budget_left()는 배치 **시작 전** 검사 → 마지막 배치/greedy 평가가 경계를
    # 넘길 수 있다(S12 실측: wall 1804/1800). 허용 오버슛 = 배치 1개(에피소드 +batch) / wall +60s —
    # 이 밖은 진짜 예산 위반(fail-closed 유지).
    # 오버슛 허용치는 **pinned 상수**에서(codex §R2-R6 — 자기-보고 config.batch 신뢰 금지)
    for s in seeds:
        if s.get("episodes", 10**9) > pin["max_episodes"] + pin["batch"]:
            fails.append(f"seed {s.get('seed')}: 에피소드 예산 초과")
        if s.get("wall_s", 10**9) > pin["max_wall"] + 60:
            fails.append(f"seed {s.get('seed')}: wall 예산 초과(+60s 오버슛 허용 밖)")
    # ② predicate 재판정
    n_seeds = len(pin["seeds"])
    # run_training 집계식(n_clear*2 >= n+(n%2))과 동일 경계 — 판정 이원화 금지(3 seed → 2)
    need = (n_seeds + (n_seeds % 2) + 1) // 2
    n_clear = sum(1 for s in seeds if s.get("cleared"))
    if n_clear < need:
        fails.append(f"{n_seeds}-seed predicate 미달: cleared {n_clear}/{n_seeds} (≥{need} 필요)")
    # ③ 문법 인코딩 가능성 (post-commit codex R1 HIGH): grammar_version 문자열 신뢰 금지 — 각 액션이
    # encode→decode 라운드트립으로 **자기 자신을 재생산**해야 현행 문법의 표현 가능 액션이다(문법 밖
    # 액션은 격자 투영이 값을 바꾸거나 어휘 .index가 예외 → fail-closed). 길이도 pinned 실효 max_len
    # (min(ant-target 인벤토리 합, pin.max_len)) 이내여야 정책이 산출 가능했던 plan.
    actions = d.get("actions") or []
    canon: list[dict] = []
    grammar_fails = 0
    if len(actions) > mdp.max_len:
        fails.append(f"actions {len(actions)}개 > pinned 실효 max_len {mdp.max_len} — 문법 밖 길이")
        grammar_fails += 1
    if not actions:
        fails.append("actions 비어 있음 — 유효 해 아님(스텝0 SUBMIT 마스킹 계약)")
        grammar_fails += 1
    for i, a in enumerate(actions):
        try:
            rt = mdp.decode(mdp.encode_action(a))
        except Exception as e:
            fails.append(f"action[{i}] 문법 인코딩 불가({type(e).__name__}: {e}) — grammar 밖 액션")
            grammar_fails += 1
            continue
        if rt != a:
            fails.append(f"action[{i}] encode→decode 라운드트립 불일치(문법 밖 액션): {a} != {rt}")
            grammar_fails += 1
        canon.append(rt)
    # ④ 독립 replay ×2 (단발 run_plan = 권위 경로) + saved==hp_stage — **replay 대상은 라운드트립
    # canonical plan**(문법 산출이 replay 권위; ③ 통과 시 원본과 값 동일). ③ 실패면 replay 무의미 — 생략.
    digests = []
    for i in range(2 if grammar_fails == 0 else 0):
        res = solve.run_plan(d["stage"], canon, d["deadline_frames"], trace=False)
        if "error" in res:
            fails.append(f"replay {i + 1} 에러: {res['error']}")
            break
        digests.append(_digest(res))
    if len(digests) == 2:
        if digests[0] != digests[1]:
            fails.append(f"replay ×2 불일치: {digests[0]} != {digests[1]}")
        if not digests[0].get("cleared"):
            fails.append("replay 미클리어")
        if int(digests[0].get("saved") or 0) != mdp.hp:
            fails.append(f"saved {digests[0].get('saved')} != hp_stage {mdp.hp}")
        # ⑤ trace 재생 replay (post-commit codex R4): 빈-plan preflight는 "액션 발화 시 trace 소실"
        # 회귀를 못 잡는다 — **pinned actions 자체를 trace=True로 재생**해 ⓐ trace 유효 ⓑ trace 관측이
        # 시뮬레이션을 교란하지 않음(digest 동일)을 실측.
        if pin.get("shaping") == "trace":
            res_t = solve.run_plan(d["stage"], canon, d["deadline_frames"], trace=True)
            if "error" in res_t:
                fails.append(f"trace replay 에러: {res_t['error']}")
            else:
                if _digest(res_t) != digests[0]:
                    fails.append(f"trace replay digest 불일치: {_digest(res_t)} != {digests[0]}")
                if not _trace_valid(res_t.get("trace")):
                    fails.append("pinned actions의 trace replay에서 trace 부재/기형 — 수집 회귀")
    if fails:
        print(f"[{label}] FAIL:")
        for f in fails:
            print("  -", f)
        return 1
    print(f"[{label}] PASS — manifest 완전 · predicate {n_clear}/{n_seeds} · replay ×2 identical "
          f"{digests[0]}")
    return 0


def verify_r0(stage_id: int) -> int:
    return _verify_pinned(stage_id, R0_PIN, "verify-r0")


def verify_r1(stage_id: int) -> int:
    return _verify_pinned(stage_id, R1_PIN, "verify-r1")


# ---------- --verify-r2 (plan §R2 acceptance 4 — R1 게이트 계승 + ckpt/사슬/curriculum) ----------

def _check_preflight_evidence(pf, envs_req: int, envs_eff: int, fails: list[str], px: str) -> None:
    """preflight_trace 증거 구조 검사(r1 로직 계승 — runs=2*envs_req, wall>0, ok↔effective 정합)."""
    if not isinstance(pf, dict) or any(k not in pf for k in ("ok", "wall_s", "runs")):
        fails.append(f"{px}: preflight_trace {{ok,wall_s,runs}} 누락")
        return
    if pf.get("runs") != 2 * envs_req:
        fails.append(f"{px}: preflight_trace.runs {pf.get('runs')!r} != 2*envs_requested "
                     f"{2 * envs_req} (위조/무의미 증거)")
    w = pf.get("wall_s")
    if not (isinstance(w, (int, float)) and not isinstance(w, bool) and w > 0):
        fails.append(f"{px}: preflight_trace.wall_s {w!r} — 양수 실측치 아님")
    if envs_eff > 1 and pf.get("ok") is not True:
        fails.append(f"{px}: envs_effective>1인데 preflight_trace.ok != true")
    if envs_eff <= 1 and pf.get("ok") is True:
        fails.append(f"{px}: envs_effective<=1(N=1 강등)인데 ok == true — 모순 manifest")


# 사슬 세그먼트 contract 키(codex §R2-R4 HIGH — stage-id 축약 비교 금지, 전체 메타데이터 대조)
_SEG_KEYS = ("stage_id", "seed", "mode", "episodes", "batches", "wall_s", "cleared",
             "ckpt_sha", "ckpt_path")


def _grammar_canon(mdp: StageMDP, actions: list, max_repr: int, fails: list[str],
                   px: str) -> list[dict]:
    """plan의 r2 문법 검사(공용 — top-level actions와 seed별 greedy_plan 동일 계약): 길이 +
    encode→decode 라운드트립 자기재생산 + **마스크-표현 가능성**(인벤토리 초과·at_frame cap 초과·
    비-surface ant row 등 정책이 산출 불가능한 plan 거부). 반환 = canonical plan(replay 권위)."""
    canon: list[dict] = []
    if len(actions) > max_repr:
        fails.append(f"{px}: {len(actions)}개 > 표현 가능 길이 {max_repr} — 문법 밖")
    used: dict[str, int] = {}
    for i, a in enumerate(actions):
        try:
            enc = mdp.encode_action(a)
            rt = mdp.decode(enc)
        except Exception as ex:
            fails.append(f"{px}[{i}] r2 인코딩 불가({type(ex).__name__}: {ex}) — grammar 밖 액션")
            continue
        if rt != a:
            fails.append(f"{px}[{i}] encode→decode 라운드트립 불일치(문법 밖 액션): {a} != {rt}")
        for h in ["skill"] + mdp.active_heads(enc):
            if enc[h] not in mdp.head_mask(h, i, used, enc):
                fails.append(f"{px}[{i}] head {h}={enc[h]} — per-stage 마스크 밖(정책 산출 불가 plan)")
        sid_used = mdp.skills[enc["skill"]]
        used[sid_used] = used.get(sid_used, 0) + 1
        canon.append(rt)
    return canon


def _validate_ckpt_file(rec: dict, sid: int, seed, expect_cleared, expect_chain,
                        pin: dict, vocab_digest: str, fails: list[str], px: str,
                        expect_sha: str | None = None) -> None:
    """ckpt 기록({path,sha256})의 **byte-backed** 검증 — 파일 실존 + sha 실측(기록·대조 sha 양쪽) +
    load 후 내용 계약(grammar/전역 어휘·stage·seed·layout/mask digest·cleared_seg) + **내부 사슬을
    신뢰-검증된 세그먼트 레코드와 전체 메타데이터로 대조**(expect_chain = 이 ckpt의 자기-세그먼트를
    말단으로 포함한 사슬; codex §R2-R4 HIGH — id 축약 비교 금지) + 학습 로드 계약 실행.
    현-스테이지 저장분 / transfer 로드 출처 / 결측-seed 상류 근거 3경로가 **동일 계약**을 공유
    (codex §R2-R1 HIGH-2·R2 HIGH-1/2 — JSON-only 신뢰·부재-우회 제거)."""
    # 저장소-정본 경로 pin(codex §R2-R7 HIGH): 경로는 (stage, seed)에서 파생된 정본만 —
    # 절대경로·../ 이탈·임의 로컬 파일로 유효 바이트를 공급하는 우회 차단(hermetic provenance).
    want = str(ckpt_path(sid, seed).relative_to(ROOT)).replace("\\", "/")
    if str(rec.get("path")).replace("\\", "/") != want:
        fails.append(f"{px}: ckpt path {rec.get('path')!r} != 저장소-정본 {want!r} — "
                     "repo-비귀속 경로 거부(fail-closed)")
        return
    f = ROOT / want
    if not f.exists():
        fails.append(f"{px}: ckpt 파일 {want} 없음")
        return
    actual = _file_sha(f)
    if actual != rec.get("sha256"):
        fails.append(f"{px}: ckpt 파일 sha 실측 불일치 — byte-backed provenance 위반(스테일/변조)")
        return
    if expect_sha is not None and actual != expect_sha:
        fails.append(f"{px}: ckpt 파일 sha != 대조 sha(사슬 기록과 불일치)")
        return
    try:
        ck = load_ckpt(f)
        m = StageMDP(sid, max_len=pin["max_len"], grammar=pin["grammar"],
                     at_frame_cap=pin["train_deadline"])
    except Exception as ex:
        fails.append(f"{px}: ckpt/mdp 검증 불가({type(ex).__name__}: {ex}) — fail-closed")
        return
    if ck.get("format") != CKPT_FORMAT:
        fails.append(f"{px}: ckpt format {ck.get('format')!r} != {CKPT_FORMAT!r}")
    missing_keys = [k for k in CKPT_REQUIRED_KEYS if k not in ck]
    if missing_keys:
        fails.append(f"{px}: ckpt 직렬화 전수 필드 누락 {missing_keys} — 메타-온리/부분 위조 거부")
        return
    if ck.get("grammar_version") != pin["grammar"]:
        fails.append(f"{px}: ckpt grammar {ck.get('grammar_version')!r} != pinned")
    if ck.get("vocab_digest") != vocab_digest:
        fails.append(f"{px}: ckpt 전역 어휘 digest 불일치")
    if ck.get("stage_id") != sid:
        fails.append(f"{px}: ckpt stage_id {ck.get('stage_id')} != {sid}")
    if ck.get("seed") != seed:
        fails.append(f"{px}: ckpt seed {ck.get('seed')} != {seed}")
    if ck.get("layout_digest") != m.layout_digest():
        fails.append(f"{px}: ckpt layout_digest 불일치")
    # exact-resume 계약 이행 가능성(codex §R2-R1 MED-3): 마스크 시맨틱 드리프트 거부.
    if ck.get("mask_digest") != m.mask_digest():
        fails.append(f"{px}: ckpt mask_digest 불일치(exact-resume 계약 비이행)")
    if expect_cleared is not None and bool(ck.get("cleared_seg")) != bool(expect_cleared):
        fails.append(f"{px}: ckpt cleared_seg {ck.get('cleared_seg')} != 기대 {expect_cleared}")
    if expect_chain is not None:
        # 내부 사슬 = 자기-세그먼트 이전의 완결 세그먼트들. 신뢰 사슬(expect_chain[:-1])과
        # **contract 키 전체**로 세그먼트별 대조(codex §R2-R4 HIGH — seed/mode/cleared/sha/카운터
        # 위조가 stage-id 열 뒤에 숨는 것 차단).
        internal = ck.get("chain") or []
        expect_prior = list(expect_chain[:-1])
        if len(internal) != len(expect_prior):
            fails.append(f"{px}: ckpt 내부 사슬 길이 {len(internal)} != 기대 {len(expect_prior)}")
        else:
            for i, (a, b) in enumerate(zip(internal, expect_prior)):
                bad = [k for k in _SEG_KEYS if a.get(k) != b.get(k)]
                if bad:
                    fails.append(f"{px}: ckpt 내부 사슬[{i}] 세그먼트 메타 불일치 {bad}: "
                                 f"{ {k: a.get(k) for k in bad} } != { {k: b.get(k) for k in bad} }")
        # 자기-세그먼트 결속: ckpt의 세그먼트 카운터/모드가 신뢰 사슬 말단 레코드와 일치해야
        # 내부 카운터 위조로 구간 예산 회계(plan-R2 MED-4)를 우회할 수 없다.
        last = expect_chain[-1]
        for ck_k, seg_k in (("seg_mode", "mode"), ("batch_i", "batches"),
                            ("episodes_seg", "episodes"), ("wall_seg", "wall_s"),
                            ("cleared_seg", "cleared"), ("stage_id", "stage_id"),
                            ("seed", "seed")):
            if ck.get(ck_k) != last.get(seg_k):
                fails.append(f"{px}: ckpt.{ck_k} {ck.get(ck_k)!r} != 사슬 말단.{seg_k} "
                             f"{last.get(seg_k)!r} — 자기-세그먼트 결속 위반")
    # 학습 로드 계약 실행(codex §R2-R3 HIGH — 검증자와 로더의 계약 동일화): dtype·model_cfg 대조 +
    # pinned 정책/옵티마이저 인스턴스에 state_dict **실로드**(shape/key 불일치 = 예외 = FAIL).
    # 메타데이터만 갖춘 위조 .pt는 여기서 반드시 죽는다. torch_rng는 uint8 상태 텐서여야 함
    # (전역 RNG는 오염시키지 않음 — set_rng_state 미호출).
    torch, _ = _torch()
    cfg_v = dict(DEFAULTS)               # hidden/conv_channels는 CLI 비노출 = DEFAULTS가 pin의 실체
    if ck.get("dtype") != "float32":
        fails.append(f"{px}: ckpt dtype {ck.get('dtype')!r} != 'float32'")
    mc = _model_cfg(m, cfg_v)
    if ck.get("model_cfg") != mc:
        fails.append(f"{px}: ckpt model_cfg 불일치: {ck.get('model_cfg')} != pinned {mc}")
        return
    try:
        pol = make_policy_r2(m, cfg_v)
        pol.load_state_dict(ck["policy"])
        opt = torch.optim.Adam(pol.parameters(), lr=cfg_v["lr"])
        opt.load_state_dict(ck["optimizer"])
        # optimizer 슬롯 검증(codex §R2-R8 HIGH): attach는 shape를 안 본다 — **존재하는 슬롯**의
        # Adam 모멘트 텐서가 대응 파라미터와 shape/dtype 일치 + step 존재 + lr pinned여야 첫 재개
        # opt.step()이 실행 가능하다(오염-슬롯 = 재개 크래시 = fail-closed). 슬롯 "부재"는 결함이
        # 아님: Adam은 lazy 초기화라 스테이지에서 활성 불가능한 head(예: ant-전용 스테이지의 col)는
        # 그래프에 못 들어가 슬롯이 없는 게 정상이고, 그 상태의 resume은 lazy 재초기화로 기능한다
        # (실측: stage11 ckpt들 — cell 스킬 無 인벤토리 → col head 슬롯 없음). 학습 여부 자체는
        # batch_i/에피소드 카운터·사슬 결속이 별도 강제.
        ost = opt.state_dict()
        if any(g.get("lr") != cfg_v["lr"] for g in ost.get("param_groups", [])):
            fails.append(f"{px}: optimizer lr != pinned {cfg_v['lr']}")
        params = list(pol.parameters())
        for pi, sl in (ost.get("state") or {}).items():
            if not isinstance(sl, dict) or "step" not in sl or not (0 <= int(pi) < len(params)):
                fails.append(f"{px}: optimizer state[{pi}] 슬롯 구조 불량(step 부재/파라미터 밖)")
                break
            prm = params[int(pi)]
            bad = [k for k in ("exp_avg", "exp_avg_sq")
                   if not (torch.is_tensor(sl.get(k)) and sl[k].shape == prm.shape
                           and sl[k].dtype == prm.dtype)]
            if bad:
                fails.append(f"{px}: optimizer 슬롯 {bad}[param {pi}] shape/dtype != 파라미터 — "
                             "재개-불능 ckpt(fail-closed)")
                break
    except Exception as ex:
        fails.append(f"{px}: ckpt state_dict 로드 계약 불이행({type(ex).__name__}: {ex}) — "
                     "재개/전이 불가능한 위조·손상 ckpt")
    tr = ck.get("torch_rng")
    if not (torch.is_tensor(tr) and tr.dtype == torch.uint8 and tr.numel() > 0):
        fails.append(f"{px}: ckpt torch_rng가 유효한 RNG 상태 텐서 아님")
    else:
        # RNG 로드 계약 실왕복(codex §R2-R9 HIGH): resume은 set_rng_state를 호출한다 — 타입만 맞는
        # 위조 상태(잘못된 길이 등)는 여기서 거부. 전역 RNG는 finally 복원으로 무오염.
        _old_rng = torch.get_rng_state()
        try:
            torch.set_rng_state(tr)
        except Exception as ex:
            fails.append(f"{px}: torch_rng set 계약 불이행({type(ex).__name__}: {ex}) — "
                         "재개-불능 RNG 상태(fail-closed)")
        finally:
            torch.set_rng_state(_old_rng)


def verify_r2(stage_id: int) -> int:
    """r2 산출물 fail-closed 게이트: R1 게이트 전체 계승(pinned 예산·문법 라운드트립·live preflight·
    trace 재생·pass 시맨틱) + 체크포인트 메타(mode별 digest 계약·재개 사슬 무결) + curriculum
    manifest 정합(plan §R2 acceptance 4)."""
    label, pin = "verify-r2", R2_PIN
    fails: list[str] = []
    path = rl2_json_path(stage_id)
    if not path.exists():
        print(f"[{label}] FAIL: {path} 없음")
        return 1
    d = json.loads(path.read_text(encoding="utf-8"))
    meta = d.get("rl_meta") or {}
    cfg = meta.get("config") or {}
    mdp = StageMDP(stage_id, max_len=pin["max_len"], grammar=pin["grammar"],
                   at_frame_cap=pin["train_deadline"])
    # ① 바인딩 + manifest 완전성 + pinned 계약
    if d.get("stage_id") != stage_id:
        fails.append(f"stage_id {d.get('stage_id')} != {stage_id}")
    if d.get("stage") != mdp.stage_scene:
        fails.append(f"stage {d.get('stage')} != {mdp.stage_scene}")
    if d.get("deadline_frames") != pin["replay_deadline"]:
        fails.append(f"deadline_frames != pinned {pin['replay_deadline']}")
    if (d.get("expect") or {}).get("saved") != mdp.hp:
        fails.append(f"expect.saved != hp_stage {mdp.hp}")
    if meta.get("no_hint") is not True:
        fails.append("no_hint != true")
    if meta.get("grammar_version") != pin["grammar"]:
        fails.append(f"grammar_version {meta.get('grammar_version')} != pinned {pin['grammar']}")
    if meta.get("vocab_digest") != mdp.vocab_digest:
        fails.append("전역 어휘/head-시맨틱 digest 불일치 — 어휘 드리프트 산출물(재생성 필요)")
    if meta.get("layout_digest") != mdp.layout_digest():
        fails.append("layout_digest 불일치 — 레이아웃 변경 후 stale 산출물")
    if meta.get("pass") is not True:
        fails.append("rl_meta.pass != true")
    if cfg.get("max_batches"):
        fails.append("config.max_batches 사용 — 배치-수 종료는 등가성 시험 전용(pinned 예산 위장 차단)")
    for k in _BASE_CFG_KEYS:
        if k not in cfg:
            fails.append(f"config.{k} 누락")
    # pin의 config 키 전량 값-대조(codex §R2-R6 — 실효 knob 자기-보고 금지; seeds/envs/grammar는
    # config가 아닌 별도 필드로 검증)
    for k in pin:
        if k in ("seeds", "envs", "grammar"):
            continue
        if cfg.get(k) != pin[k]:
            fails.append(f"config.{k} {cfg.get(k)!r} != pinned {pin[k]!r}")
    # ② per-seed 항목 + predicate + 사슬/curriculum/ckpt (plan §R2 P1/P4)
    # 결측 seed = 사슬 앞단 미클리어(FAIL 집계, plan acceptance 2). 단 "결측"은 근거가 있어야 한다
    # (codex §R2-R1 HIGH-1 — 나쁜 seed 생략 cherry-pick 차단): 상류 산출물에 그 seed의 미클리어가
    # 실증된 경우에만 허용, from-scratch 사슬(상류 없음)은 전원 기록 필수. pinned 밖 seed·중복 거부.
    entries = meta.get("seeds") or []
    entry_seeds = [e.get("seed") for e in entries]
    if len(set(entry_seeds)) != len(entry_seeds) or not set(entry_seeds) <= set(pin["seeds"]):
        fails.append(f"seeds {entry_seeds} ⊄ pinned {pin['seeds']} (중복/비-pinned seed)")
    man_pos = {sid: i for i, sid in enumerate(manifest_stage_ids())}
    expected_chain = R2_CHAINS.get(stage_id)
    for s in [x for x in pin["seeds"] if x not in entry_seeds]:
        if not expected_chain or len(expected_chain) <= 1:
            fails.append(f"결측 pinned seed {s}: from-scratch 스테이지는 전원 기록 필수(cherry-pick 차단)")
            continue
        # 결측 근거 = raw JSON 신뢰 금지(codex §R2-R2 HIGH-2): 상류 산출물의 stage 바인딩·grammar·
        # 어휘 digest·config가 이 산출물과 정합하고(전이적 pin), seed 중복이 없으며, 해당 seed의
        # 미클리어 기록이 **byte-backed ckpt 증거**(cleared_seg==False 실측)로 뒷받침될 때만 인정.
        excuse = False
        for up_sid in expected_chain[:-1]:
            up_p = rl2_json_path(up_sid)
            if not up_p.exists():
                break
            up_doc = json.loads(up_p.read_text(encoding="utf-8"))
            um = up_doc.get("rl_meta") or {}
            up_entries = um.get("seeds") or []
            up_seed_ids = [x.get("seed") for x in up_entries]
            if (up_doc.get("stage_id") != up_sid
                    or um.get("grammar_version") != pin["grammar"]
                    or um.get("vocab_digest") != mdp.vocab_digest
                    or um.get("config") != cfg
                    or len(set(up_seed_ids)) != len(up_seed_ids)):
                fails.append(f"결측 pinned seed {s}: 상류 S{up_sid} 산출물이 pin 비정합/중복 seed — "
                             "근거로 사용 불가(fail-closed)")
                break
            ue = next((x for x in up_entries if x.get("seed") == s), None)
            if ue is None:
                break                                  # 이 상류에도 기록 없음 → 근거 없음
            if not ue.get("cleared"):
                if not isinstance(ue.get("ckpt_saved"), dict):
                    fails.append(f"결측 pinned seed {s}: 상류 S{up_sid} 실패 기록에 byte-backed "
                                 "ckpt 증거 없음(fail-closed)")
                else:
                    pre = len(fails)
                    _validate_ckpt_file(ue["ckpt_saved"], up_sid, s, False,
                                        list(ue.get("chain") or []),
                                        pin, mdp.vocab_digest, fails,
                                        f"결측 seed {s} 근거(S{up_sid})")
                    excuse = len(fails) == pre         # 증거 검증 전부 통과 시에만 근거 인정
                break
        if not excuse:
            fails.append(f"결측 pinned seed {s}: 검증된 상류 미클리어 근거 없음 — "
                         "cherry-pick 의심(fail-closed)")
    n_seeds = len(pin["seeds"])
    need = (n_seeds + (n_seeds % 2) + 1) // 2
    max_repr = min(sum(mdp.inventory.get(s, 0) for s in mdp.skills), pin["max_len"])
    verified_clear: set[int] = set()      # predicate는 replay-실증된 클리어만(codex §R2-R5 HIGH)
    for e in entries:
        sd = e.get("seed")
        px = f"seed {sd}"
        if e.get("envs_requested") != pin["envs"]:
            fails.append(f"{px}: envs_requested != {pin['envs']} (pinned)")
        _check_preflight_evidence(e.get("preflight_trace"), pin["envs"],
                                  int(e.get("envs_effective") or 0), fails, px)
        chain = e.get("chain") or []
        if not chain:
            fails.append(f"{px}: 재개 사슬(chain) 기록 없음")
            continue
        stages = [seg.get("stage_id") for seg in chain]
        if expected_chain is not None and stages != expected_chain:
            fails.append(f"{px}: chain {stages} != pinned {expected_chain} "
                         "(체크포인트 출처 pin, plan-R2 HIGH-1)")
        unknown = [s for s in stages if s not in man_pos]
        if unknown:
            fails.append(f"{px}: chain 스테이지 {unknown}가 campaign_manifest에 없음")
        elif any(man_pos[a] >= man_pos[b] for a, b in zip(stages, stages[1:])):
            fails.append(f"{px}: chain {stages}가 manifest 순서와 모순(curriculum 정합 위반)")
        for i, seg in enumerate(chain):
            spx = f"{px} chain[{i}](S{seg.get('stage_id')})"
            if seg.get("seed") != sd:
                fails.append(f"{spx}: 세그먼트 seed {seg.get('seed')} != {sd} — per-seed 사슬 위반")
            want = "scratch" if i == 0 else "transfer"
            if seg.get("mode") != want:
                fails.append(f"{spx}: mode {seg.get('mode')!r} != {want!r}")
            # 구간별 예산 회계(plan-R2 MED-4) — 오버슛 허용 = **pinned batch**(codex §R2-R6:
            # 자기-보고 config.batch 부풀림으로 예산 우회 차단)
            if seg.get("episodes", 10**9) > pin["max_episodes"] + pin["batch"]:
                fails.append(f"{spx}: 구간 에피소드 예산 초과")
            if seg.get("wall_s", 10**9) > pin["max_wall"] + 60:
                fails.append(f"{spx}: 구간 wall 예산 초과(+60s 오버슛 허용 밖)")
            if i < len(chain) - 1 and not seg.get("cleared"):
                fails.append(f"{spx}: 미클리어인데 후속 세그먼트 존재 — transfer 게이트 위반")
            # 세그먼트 ckpt 경로도 저장소-정본만(codex §R2-R7 HIGH — 절대경로/이탈 메타 거부)
            if seg.get("ckpt_sha") is not None:
                want_p = str(ckpt_path(int(seg.get("stage_id") or -1),
                                       seg.get("seed")).relative_to(ROOT)).replace("\\", "/")
                if str(seg.get("ckpt_path")).replace("\\", "/") != want_p:
                    fails.append(f"{spx}: 세그먼트 ckpt_path {seg.get('ckpt_path')!r} 비정본 "
                                 f"(정본 {want_p!r})")
        if chain[-1].get("stage_id") != stage_id:
            fails.append(f"{px}: chain 말단 {chain[-1].get('stage_id')} != {stage_id}")
        if bool(chain[-1].get("cleared")) != bool(e.get("cleared")):
            fails.append(f"{px}: 말단 세그먼트/엔트리 cleared 모순")
        # ckpt 무결 — 로드 출처(사슬 len>1이면 필수: transfer의 증거) + 저장 파일(기록 시 검증)
        if len(chain) > 1:
            cl = e.get("ckpt_loaded")
            if not isinstance(cl, dict):
                fails.append(f"{px}: transfer 사슬인데 ckpt_loaded 기록 없음")
            else:
                if cl.get("mode") != "transfer":
                    fails.append(f"{px}: ckpt_loaded.mode {cl.get('mode')!r} != 'transfer'")
                if cl.get("sha256") != chain[-2].get("ckpt_sha"):
                    fails.append(f"{px}: 로드 ckpt sha != 직전 세그먼트 ckpt_sha (사슬 무결 위반)")
                want_lp = str(ckpt_path(int(chain[-2].get("stage_id") or -1),
                                        sd).relative_to(ROOT)).replace("\\", "/")
                if str(cl.get("path")).replace("\\", "/") != want_lp:
                    fails.append(f"{px}: ckpt_loaded.path {cl.get('path')!r} 비정본 (정본 {want_lp!r})")
                up_sid = chain[-2].get("stage_id") or -1
                up_path = rl2_json_path(up_sid)
                if not up_path.exists():
                    fails.append(f"{px}: 직전 스테이지 산출물 {up_path.name} 없음 — 출처 검증 불가")
                else:
                    up = json.loads(up_path.read_text(encoding="utf-8"))
                    ue = next((x for x in (up.get("rl_meta") or {}).get("seeds", [])
                               if x.get("seed") == sd), None)
                    if not ue or not isinstance(ue.get("ckpt_saved"), dict):
                        fails.append(f"{px}: 직전 산출물에 seed {sd} ckpt_saved 기록 없음")
                    elif ue["ckpt_saved"].get("sha256") != cl.get("sha256"):
                        fails.append(f"{px}: 출처 ckpt sha 불일치 — cherry-pick 차단(plan §R2 acceptance 2)")
                    else:
                        # byte-backed provenance(codex §R2-R1 HIGH-2): 상류 ckpt "파일"을 실측하고
                        # 내용 계약까지 검증(공용 helper) — 위조/스테일 manifest로 출처 위장 불가.
                        # 기대 사슬 = 검증된 외부 사슬의 상류 구간(세그먼트 레코드, §R2-R4).
                        _validate_ckpt_file(ue["ckpt_saved"], up_sid, sd, True, chain[:-1],
                                            pin, mdp.vocab_digest, fails,
                                            f"{px} transfer 출처(S{up_sid})",
                                            expect_sha=cl.get("sha256"))
        cs = e.get("ckpt_saved")
        if not isinstance(cs, dict):
            # 부재-fail-open 차단(codex §R2-R2 HIGH-1): pinned 계약이 --save-ckpt인 스테이지는
            # ckpt_saved 생략 = byte-backed 검증 우회이므로 부재 자체가 FAIL.
            if stage_id in R2_SAVE_CKPT_STAGES:
                fails.append(f"{px}: ckpt_saved 기록 없음 — pinned 계약(--save-ckpt) 위반, "
                             "byte-backed 검증 우회 차단(fail-closed)")
        else:
            if cs.get("sha256") != chain[-1].get("ckpt_sha"):
                fails.append(f"{px}: ckpt_saved sha != 말단 세그먼트 ckpt_sha(사슬 기록 모순)")
            _validate_ckpt_file(cs, stage_id, sd, bool(e.get("cleared")), chain,
                                pin, mdp.vocab_digest, fails, px)
        # predicate 증거(codex §R2-R5 HIGH): cleared는 자기-보고 불리언으로 인정하지 않는다 —
        # seed별 greedy_plan의 문법 canon + **엔진 replay 실측**(pinned deadline, saved==hp)만
        # predicate에 가산. ckpt 비대상 스테이지(S19)에서도 클리어 위조 불가.
        if e.get("cleared"):
            gp = e.get("greedy_plan") or []
            if not gp:
                fails.append(f"{px}: cleared인데 greedy_plan 없음 — 증거 부재(fail-closed)")
            else:
                pre = len(fails)
                gcanon = _grammar_canon(mdp, gp, max_repr, fails, f"{px} greedy_plan")
                if len(fails) == pre:
                    gres = solve.run_plan(mdp.stage_scene, gcanon, pin["replay_deadline"],
                                          trace=False)
                    if "error" in gres:
                        fails.append(f"{px}: greedy_plan replay 에러: {gres['error']}")
                    elif not (gres.get("cleared") and int(gres.get("saved") or 0) == mdp.hp):
                        fails.append(f"{px}: greedy_plan replay 미클리어({_digest(gres)}) — "
                                     "cleared 자기-보고 위조(fail-closed)")
                    else:
                        verified_clear.add(sd)
    n_clear = len(verified_clear)
    if n_clear < need:
        fails.append(f"{n_seeds}-seed predicate 미달: 검증-클리어 {n_clear}/{n_seeds} "
                     f"(≥{need} 필요; 결측 seed {sorted(set(pin['seeds']) - set(entry_seeds))} = FAIL 집계)")
    # ③ 문법 라운드트립 + 표현 가능 길이 + 마스크-표현 가능성 (공용 helper — seed별 plan과 동일 계약)
    actions = d.get("actions") or []
    grammar_pre = len(fails)
    canon: list[dict] = []
    if not actions:
        fails.append("actions 비어 있음 — 유효 해 아님(스텝0 SUBMIT 마스킹 계약)")
    else:
        canon = _grammar_canon(mdp, actions, max_repr, fails, "action")
        # actions ↔ best_seed 결속(codex §R2-R5): top-level plan은 검증-클리어된 best_seed의
        # greedy_plan과 동일해야 한다 — 출처 불명 plan이 predicate와 무관하게 실리는 것 차단.
        bs = meta.get("best_seed")
        be = next((x for x in entries if x.get("seed") == bs), None)
        if be is None or bs not in verified_clear:
            fails.append(f"best_seed {bs!r}가 검증-클리어 seed 아님 — actions 출처 불명")
        elif actions != (be.get("greedy_plan") or []):
            fails.append("top-level actions != best_seed greedy_plan — 출처 결속 위반")
    grammar_fails = len(fails) - grammar_pre
    # ④ 독립 replay ×2 + ⑤ trace 재생 (r1 ④⑤ 계승 — canonical plan이 replay 권위)
    digests = []
    for i in range(2 if grammar_fails == 0 else 0):
        res = solve.run_plan(d["stage"], canon, d["deadline_frames"], trace=False)
        if "error" in res:
            fails.append(f"replay {i + 1} 에러: {res['error']}")
            break
        digests.append(_digest(res))
    if len(digests) == 2:
        if digests[0] != digests[1]:
            fails.append(f"replay ×2 불일치: {digests[0]} != {digests[1]}")
        if not digests[0].get("cleared"):
            fails.append("replay 미클리어")
        if int(digests[0].get("saved") or 0) != mdp.hp:
            fails.append(f"saved {digests[0].get('saved')} != hp_stage {mdp.hp}")
        res_t = solve.run_plan(d["stage"], canon, d["deadline_frames"], trace=True)
        if "error" in res_t:
            fails.append(f"trace replay 에러: {res_t['error']}")
        else:
            if _digest(res_t) != digests[0]:
                fails.append(f"trace replay digest 불일치: {_digest(res_t)} != {digests[0]}")
            if not _trace_valid(res_t.get("trace")):
                fails.append("actions의 trace replay에서 trace 부재/기형 — 수집 회귀")
    # ⑥ 검증자 측 live trace preflight (r1 계승 — 자기-보고 아닌 실측이 권위)
    live_pool = None
    try:
        live_pool = EnvPool(pin["envs"])
        live = preflight(live_pool, mdp.stage_scene, with_trace=True)
        if (live["ok"] is not True or live["runs"] != 2 * pin["envs"]
                or live.get("trace_present") is not True):
            fails.append(f"검증자 측 trace preflight 실측 FAIL: {live}")
    except Exception as ex:
        fails.append(f"검증자 측 trace preflight 실행 불가({type(ex).__name__}: {ex}) — fail-closed")
    finally:
        if live_pool is not None:
            live_pool.close()
    if fails:
        print(f"[{label}] FAIL:")
        for f in fails:
            print("  -", f)
        return 1
    print(f"[{label}] PASS — manifest 완전 · predicate {n_clear}/{n_seeds} · 사슬/ckpt 무결 · "
          f"replay ×2 identical {digests[0]}")
    return 0


# ---------- --coverage (문법 커버리지: known 해 → 격자 인코딩 → 엔진 클리어, R1-H2) ----------

def _dense_telescoping_ok() -> tuple[bool, str]:
    """dense PBRS 결정론 telescoping 단위검증(plan §R3 acceptance 6): 임의 φ 시퀀스에서
    Σ_t F_t == γ^L·φ(terminal) − φ(P_0) = −φ(P_0)(γ=1, terminal φ=0). 순수 함수 — 엔진 불요."""
    class _FakeMDP:
        def shaped_bonus(self, res):
            return res["_phi"]
    class _FakeRoll:
        def __init__(self, phis):
            self.phis = phis
        def get(self, partial):
            return {"_phi": self.phis[len(partial)]}
    for phis in ([0.3, -0.1, 0.5, 0.2], [0.0], [1.0, 1.0], [-0.4, 0.7, -0.2, 0.9, 0.1]):
        L = len(phis) - 1
        partial = [{"skill": 0}] * L
        total, got = _dense_terms(_FakeMDP(), partial, _FakeRoll(phis))
        if abs(total - (-phis[0])) > 1e-9:
            return False, f"telescoping 불일치: ΣF={total} != -φ(P0)={-phis[0]} (φ={phis})"
    return True, "telescoping OK (Σ F_t == -φ(P_0), 4 시퀀스)"


def verify_r3(stage_id: int) -> int:
    """r3(trace-refinement) primary 산출물 fail-closed 게이트(plan §R3 acceptance 4): R1/R2 게이트
    계승(pinned 예산·문법 라운드트립·live trace preflight·trace 재생 replay·pass 시맨틱) + obs 계약
    (obs_schema_digest·trace_channels/scalars 순서) + memo 계약(memo_key 스키마) + 처리량 회계
    (THROUGHPUT_FLOOR 판정) + outcome별 분기 + mode↔pin 정합 + ckpt 무결 + dense telescoping."""
    label = "verify-r3"
    # primary가 정본(gate) — 있으면 그것, 없고 dense_fallback만 있으면 그것(fallback rung 검증).
    # **선택 경로↔mode/variant 결속**(codex §R3 R4-MED): 어느 파일을 열었는지가 기대 mode/variant를
    # 결정한다 — self-report mode로 pin 고르면 dense 아티팩트를 primary 경로에 복사해 통과 가능.
    path = rl3_json_path(stage_id, "primary")
    selected = "primary"
    if not path.exists():
        dpath = rl3_json_path(stage_id, "dense_fallback")
        if dpath.exists():
            path, selected = dpath, "dense_fallback"
        else:
            print(f"[{label}] FAIL: {path} 없음")
            return 1
    d = json.loads(path.read_text(encoding="utf-8"))
    meta = d.get("rl_meta") or {}
    cfg = meta.get("config") or {}
    mode = meta.get("mode")
    fails: list[str] = []
    # 선택 경로가 mode/variant/pin을 강제 — self-report 신뢰 금지.
    want_mode = "dense_fallback" if selected == "dense_fallback" else "primary"
    pin = R3_DENSE_PIN if selected == "dense_fallback" else R3_PRIMARY_PIN
    if mode != want_mode:
        fails.append(f"선택 경로({selected})↔mode {mode!r} 불일치 — {want_mode!r} 기대(경로 위장 차단)")
    if meta.get("variant") != selected:
        fails.append(f"variant {meta.get('variant')!r} != 선택 경로 {selected!r} (A/B 경로 격리 위반)")
    if selected == "primary" and cfg.get("trace_blind"):
        fails.append("config.trace_blind == true — primary 게이트는 trace-full만(blind는 인과 대조 전용)")
    mdp = StageMDP(stage_id, max_len=pin["max_len"], grammar=pin["grammar"],
                   at_frame_cap=pin["train_deadline"])
    # ① 바인딩 + 관측/refine 계약
    if d.get("stage_id") != stage_id:
        fails.append(f"stage_id {d.get('stage_id')} != {stage_id}")
    if d.get("stage") != mdp.stage_scene:
        fails.append(f"stage {d.get('stage')} != {mdp.stage_scene}")
    if d.get("deadline_frames") != pin["replay_deadline"]:
        fails.append(f"deadline_frames != pinned {pin['replay_deadline']}")
    if (d.get("expect") or {}).get("saved") != mdp.hp:
        fails.append(f"expect.saved != hp_stage {mdp.hp}")
    if meta.get("no_hint") is not True:
        fails.append("no_hint != true")
    if meta.get("refine") is not True:
        fails.append("rl_meta.refine != true (refine=false 위장 차단)")
    if meta.get("grammar_version") != pin["grammar"]:
        fails.append(f"grammar_version != pinned {pin['grammar']}")
    if meta.get("vocab_digest") != mdp.vocab_digest:
        fails.append("vocab_digest 불일치")
    if meta.get("layout_digest") != mdp.layout_digest():
        fails.append("layout_digest 불일치")
    # obs 스키마 계약: digest + 채널/스칼라 이름·순서 = 모듈 상수(변조 fail-closed)
    schema = obs_schema()
    if meta.get("obs_schema_digest") != schema["digest"]:
        fails.append("obs_schema_digest 불일치 — 관측 스키마 드리프트/위조")
    if cfg.get("obs_schema_digest") != schema["digest"]:
        fails.append("config.obs_schema_digest 불일치")
    if meta.get("trace_channels") != schema["trace_channels"]:
        fails.append(f"trace_channels {meta.get('trace_channels')} != {schema['trace_channels']}")
    if meta.get("trace_scalars") != schema["trace_scalars"]:
        fails.append(f"trace_scalars 순서 불일치")
    # memo_key 계약: 멤버 집합 = _exec_config_digest 멤버(스키마) + **digest 값 대조**(codex §R3 R2-MED —
    # 멤버명만 보면 PlanRunner/env/godot/deadline/protocol drift가 통과). verify는 이미 로컬 godot로
    # replay하므로 same-config 대조가 정합. 재계산 config = pinned mode(training과 동일 digest-바인딩 키).
    exec_digest, exec_members = _exec_config_digest(
        mdp, dict(DEFAULTS, refine=True, train_deadline=pin["train_deadline"]))
    if meta.get("memo_key_members") != sorted(exec_members.keys()):
        fails.append(f"memo_key_members {meta.get('memo_key_members')} != "
                     f"{sorted(exec_members.keys())} (memo_key 스키마 위조)")
    if meta.get("exec_config_digest") != exec_digest:
        fails.append(f"exec_config_digest {str(meta.get('exec_config_digest'))[:16]}… != "
                     f"재계산 {exec_digest[:16]}… (rollout 의존 drift/위조 — memo/provenance 계약)")
    # ② config pin 값-대조(mode별 pin) — refine/dense/obs/floor 등 계약 상수
    if cfg.get("max_batches"):
        fails.append("config.max_batches 사용 — pinned 예산 위장 차단")
    if cfg.get("refine") is not True:
        fails.append("config.refine != true")
    if bool(cfg.get("dense_shaping")) != bool(pin.get("dense_shaping")):
        fails.append(f"config.dense_shaping != pinned {pin.get('dense_shaping')} (mode↔pin 불일치)")
    if cfg.get("shaping") != pin["shaping"]:
        fails.append(f"config.shaping {cfg.get('shaping')!r} != pinned {pin['shaping']!r} "
                     "(primary=trace / dense=none — 이중계상 차단)")
    if cfg.get("throughput_floor") != THROUGHPUT_FLOOR:
        fails.append(f"config.throughput_floor {cfg.get('throughput_floor')} != {THROUGHPUT_FLOOR} "
                     "(impl-pin 금지 — plan 개정 없이 다른 값이면 FAIL)")
    for k in _BASE_CFG_KEYS:
        if k not in cfg:
            fails.append(f"config.{k} 누락")
    for k in ("shaping_coeffs", "train_deadline", "sil", "sil_buffer", "sil_coef",
              "max_len", "replay_deadline", "max_episodes", "max_wall"):
        if cfg.get(k) != pin.get(k):
            fails.append(f"config.{k} {cfg.get(k)!r} != pinned {pin.get(k)!r}")
    # ③ per-seed 항목 + 처리량 회계 + outcome
    entries = meta.get("seeds") or []
    entry_seeds = [e.get("seed") for e in entries]
    if entry_seeds != pin["seeds"]:
        fails.append(f"seeds {entry_seeds} != pinned {pin['seeds']}")
    for e in entries:
        sd = e.get("seed")
        if e.get("envs_requested") != pin["envs"]:
            fails.append(f"seed {sd}: envs_requested != {pin['envs']}")
        _check_preflight_evidence(e.get("preflight_trace"), pin["envs"],
                                  int(e.get("envs_effective") or 0), fails, f"seed {sd}")
        tp = e.get("throughput") or {}
        for k in ("episodes_completed", "distinct_prefix_rollouts", "total_rollouts",
                  "memo_hit_rate", "binding_axis", "floor_reached"):
            if k not in tp:
                fails.append(f"seed {sd}: throughput.{k} 누락(회계 불완전)")
        # floor_reached는 자기-보고 신뢰 금지 — raw 카운터로 재계산해 대조(codex §R3 HIGH-2).
        if tp and bool(tp.get("floor_reached")) != _floor_reached(tp):
            fails.append(f"seed {sd}: floor_reached {tp.get('floor_reached')} != raw 카운터 재계산 "
                         f"{_floor_reached(tp)} (eps={tp.get('episodes_completed')}·"
                         f"distinct={tp.get('distinct_prefix_rollouts')}, 자기-보고 위조)")
        if e.get("episodes", 10**9) > pin["max_episodes"] + pin["batch"]:
            fails.append(f"seed {sd}: 에피소드 예산 초과")
        if e.get("wall_s", 10**9) > pin["max_wall"] + 60:
            fails.append(f"seed {sd}: wall 예산 초과(+60s 밖)")
    n_seeds = len(pin["seeds"])
    need = (n_seeds + (n_seeds % 2) + 1) // 2
    # predicate 증거(codex §R3 R7-MED — verify_r2 §R2-R5 패턴 계승): cleared 자기-보고 불리언 불인정.
    # seed별 greedy_plan을 문법 canon + 엔진 replay(pinned deadline, saved==hp)해 **실증된 것만** n_clear.
    max_repr = min(sum(mdp.inventory.get(s, 0) for s in mdp.skills), pin["max_len"])
    verified_clear: set = set()
    for e in entries:
        if not e.get("cleared"):
            continue
        sd = e.get("seed")
        gp = e.get("greedy_plan") or []
        if not gp:
            fails.append(f"seed {sd}: cleared인데 greedy_plan 없음 — 증거 부재(fail-closed)")
            continue
        pre = len(fails)
        gcanon = _grammar_canon(mdp, gp, max_repr, fails, f"seed {sd} greedy_plan")
        if len(fails) != pre:
            continue
        gres = solve.run_plan(mdp.stage_scene, gcanon, pin["replay_deadline"], trace=False)
        if "error" in gres:
            fails.append(f"seed {sd}: greedy_plan replay 에러: {gres['error']}")
        elif not (gres.get("cleared") and int(gres.get("saved") or 0) == mdp.hp):
            fails.append(f"seed {sd}: greedy_plan replay 미클리어({_digest(gres)}) — cleared 위조(fail-closed)")
        else:
            verified_clear.add(sd)
    n_clear = len(verified_clear)
    outcome = meta.get("outcome")
    # outcome 재판정 = **replay-실증 클리어 + 재계산 floor**(자기-보고 cleared/floor bool 불신, HIGH-2·R7-MED).
    recompute_entries = [{"cleared": (e.get("seed") in verified_clear),
                          "throughput": {"floor_reached": _floor_reached(e.get("throughput") or {})}}
                         for e in entries]
    recomputed = _r3_outcome(recompute_entries, n_clear >= need)
    if outcome != recomputed:
        fails.append(f"outcome {outcome!r} != 재계산 {recomputed!r} (raw 카운터 기반 재판정)")
    if meta.get("r3_mechanical_pass") != (n_clear >= need):
        fails.append(f"r3_mechanical_pass != (cleared {n_clear}/{n_seeds} ≥ {need})")
    # ④ outcome별 분기: pass = predicate ∧ best plan replay ×2 byte-identical ∧ saved==hp /
    #   model_fail = floor 도달 ∧ predicate 미달 / throughput-pin-invalid = replay 스킵 + 증거 보존.
    if outcome == "pass":
        if n_clear < need:
            fails.append(f"outcome=pass인데 검증-클리어 predicate 미달 {n_clear}/{n_seeds}")
        actions = d.get("actions") or []
        # actions ↔ best_seed 결속(codex §R3 R7-MED): top-level plan = 검증-클리어된 best_seed의
        # greedy_plan(출처 불명 plan이 predicate와 무관하게 실리는 것 차단).
        bs = meta.get("best_seed")
        be = next((x for x in entries if x.get("seed") == bs), None)
        if be is None or bs not in verified_clear:
            fails.append(f"best_seed {bs!r}가 검증-클리어 seed 아님 — actions 출처 불명")
        elif actions != (be.get("greedy_plan") or []):
            fails.append("top-level actions != best_seed greedy_plan — 출처 결속 위반")
        if not actions:
            fails.append("outcome=pass인데 actions 없음")
        else:
            gpre = len(fails)
            canon = _grammar_canon(mdp, actions, max_repr, fails, "action")
            gfail = len(fails) - gpre
            if gfail == 0:
                digs = []
                for _ in range(2):
                    res = solve.run_plan(d["stage"], canon, d["deadline_frames"], trace=False)
                    if "error" in res:
                        fails.append(f"replay 에러: {res['error']}")
                        break
                    digs.append(_digest(res))
                if len(digs) == 2:
                    if digs[0] != digs[1]:
                        fails.append(f"replay ×2 불일치: {digs[0]} != {digs[1]}")
                    if not digs[0].get("cleared"):
                        fails.append("replay 미클리어")
                    if int(digs[0].get("saved") or 0) != mdp.hp:
                        fails.append(f"saved {digs[0].get('saved')} != hp {mdp.hp}")
                    rt2 = solve.run_plan(d["stage"], canon, d["deadline_frames"], trace=True)
                    if "error" in rt2:      # trace 경로 회귀를 침묵 통과 금지(codex §R3 R5-MED)
                        fails.append(f"best plan trace replay 에러: {rt2['error']}")
                    elif not _trace_valid(rt2.get("trace")):
                        fails.append("best plan trace replay 부재/기형")
    elif outcome == "model_fail":
        non_cleared = [e for e in entries if not e.get("cleared")]
        if not all(_floor_reached(e.get("throughput") or {}) for e in non_cleared):
            fails.append("outcome=model_fail인데 미클리어 seed가 floor 미도달(재계산, → pin-invalid 이어야)")
    elif outcome in ("throughput-pin-invalid", "throughput-infeasible"):
        pass  # predicate/replay 스킵 — 보존된 처리량 증거는 위 ③에서 검사
    else:
        fails.append(f"outcome {outcome!r} ∉ enum")
    # ⑤ ckpt 무결(primary=from-scratch → resume-exact digest 계약만; transfer 미사용).
    # ckpt 부재를 비-silent화(codex §R3 R4-MED): save_ckpt 플래그가 계약 — true면 seed별 ckpt_saved 필수,
    # false면 부재 필수. 플래그로 "저장 안 함"과 "증거 탈취"를 구별(둘 다 침묵 스킵 차단).
    save_ckpt_flag = meta.get("save_ckpt")
    if not isinstance(save_ckpt_flag, bool):
        fails.append("rl_meta.save_ckpt 누락/비-bool — ckpt 계약 불명(fail-closed)")
    for e in entries:
        cs = e.get("ckpt_saved")
        if save_ckpt_flag is True and not isinstance(cs, dict):
            fails.append(f"seed {e.get('seed')}: save_ckpt=true인데 ckpt_saved 부재(증거 탈취 차단)")
        if save_ckpt_flag is False and cs is not None:
            fails.append(f"seed {e.get('seed')}: save_ckpt=false인데 ckpt_saved 존재(계약 모순)")
        if isinstance(cs, dict):
            sd_e = e.get("seed")
            p = ROOT / cs.get("path", "")
            # 경로 결속(codex §R3 R5-MED): 저장 경로 = 정확히 이 stage·seed의 정본 .r3.pt(cross-seed/
            # wrong-path 대체 차단).
            if cs.get("path") != _rel(ckpt_path(stage_id, sd_e, refine=True)):
                fails.append(f"seed {sd_e}: ckpt_saved.path {cs.get('path')} != 정본 "
                             f"{_rel(ckpt_path(stage_id, sd_e, refine=True))}(경로 위장)")
            if not p.exists():
                fails.append(f"seed {sd_e}: ckpt 파일 {cs.get('path')} 없음")
            elif _file_sha(p) != cs.get("sha256"):
                fails.append(f"seed {sd_e}: ckpt sha256 불일치(byte-backed 위조)")
            else:
                rec = load_ckpt(p)
                if rec.get("format") != CKPT_FORMAT_R3:
                    fails.append(f"seed {sd_e}: ckpt format != {CKPT_FORMAT_R3}")
                for rk in CKPT_REQUIRED_KEYS:
                    if rk not in rec:
                        fails.append(f"seed {sd_e}: ckpt 필드 {rk} 누락")
                mc = (rec.get("model_cfg") or {})
                if mc.get("obs_schema_digest") != schema["digest"] or not mc.get("refine"):
                    fails.append(f"seed {sd_e}: ckpt model_cfg obs/refine 계약 위반")
                # seed·stage·digest 결속(codex §R3 R5-MED): resume-exact 계약으로 record를 현 MDP에 대조
                # (seed/stage_id/grammar/vocab/layout/mask/model_cfg 전부) — 다른 유효 r3 ckpt 대체 차단.
                try:
                    _ckpt_compat(rec, mdp, sd_e, "resume", dict(DEFAULTS, refine=True,
                                                                max_len=pin["max_len"]))
                except RuntimeError as ce:
                    fails.append(f"seed {sd_e}: ckpt resume-exact 계약 위반 — {ce}")
    # ⑥ dense telescoping 단위검증(mode 무관 — dense fallback 정확성 상시 검증)
    ok, note = _dense_telescoping_ok()
    if not ok:
        fails.append(f"dense telescoping FAIL: {note}")
    # ⑦ 검증자 측 live trace preflight(자기-보고 아닌 실측 — R2 계승)
    live_pool = None
    try:
        live_pool = EnvPool(pin["envs"])
        live = preflight(live_pool, mdp.stage_scene, with_trace=True)
        if (live["ok"] is not True or live["runs"] != 2 * pin["envs"]
                or live.get("trace_present") is not True):
            fails.append(f"검증자 측 trace preflight 실측 FAIL: {live}")
    except Exception as e:
        fails.append(f"검증자 측 preflight 실행 불가({type(e).__name__}: {e}) — fail-closed")
    finally:
        if live_pool is not None:
            live_pool.close()
    if fails:
        print(f"[{label}] FAIL (mode={mode} outcome={outcome}):")
        for f in fails:
            print("  -", f)
        return 1
    print(f"[{label}] PASS — mode={mode} outcome={outcome} mech_pass={meta.get('r3_mechanical_pass')} "
          f"cleared {n_clear}/{n_seeds} · {note}")
    return 0


def verify_r4(stage_id: int) -> int:
    """fail-closed 로컬 게이트(plan §R4 acceptance 5): stageNN.rl4.json을 R4_PIN·표현 계약·엔진
    리플레이로 검증. 메인 게이트 비편입(RL 트랙 로컬)."""
    label = "verify-r4"
    fails: list[str] = []
    path = rl4_json_path(stage_id)
    if not path.exists():
        print(f"[{label}] FAIL: {path} 없음")
        return 1
    d = json.loads(path.read_text(encoding="utf-8"))
    meta = d.get("rl_meta") or {}
    cfg = meta.get("config") or {}
    if meta.get("grammar_version") != "r4.0":            # 리터럴 동결(§R2 선결 계약 계승)
        fails.append(f"grammar_version {meta.get('grammar_version')!r} != 'r4.0'")
    mdp = StageMDP(stage_id, max_len=R4_PIN["max_len"], grammar=GRAMMAR_R4,
                   at_frame_cap=R4_PIN["train_deadline"])
    # --- 표현 계약(랜드마크/관측/cap — 재계산 대조, 자기-보고 신뢰 금지) ---
    if meta.get("landmark_schema_digest") != mdp.landmark_digest:
        fails.append("landmark_schema_digest 불일치(어휘/정렬/피처/offset 개정 미반영 산출물)")
    if int(meta.get("landmark_count") or -1) != len(mdp.landmark_instances):
        fails.append(f"landmark_count {meta.get('landmark_count')} != 재열거 {len(mdp.landmark_instances)}")
    if meta.get("mask_digest") != mdp.mask_digest():
        fails.append("mask_digest 불일치(인스턴스 열거/마스크 drift)")
    if mdp._lm.LANDMARK_CANDIDATE_CAP != 128:
        fails.append(f"LANDMARK_CANDIDATE_CAP {mdp._lm.LANDMARK_CANDIDATE_CAP} != 128(pin)")
    c_layout = len(mdp._grid) // (mdp.H * mdp.W)
    if c_layout != 8:
        fails.append(f"C_layout {c_layout} != 8(R4_OBS_SCHEMA pin)")
    if meta.get("vocab_digest") != mdp.vocab_digest:
        fails.append("전역 어휘 digest 불일치")
    if meta.get("layout_digest") != mdp.layout_digest():
        fails.append("layout digest 불일치(레이아웃 변경 후 stale 산출물)")
    # --- shaping-항 내부 계약(R2-H6) ---
    if KNOWLEDGE != R4_KNOWLEDGE_PIN:
        fails.append(f"KNOWLEDGE 코드 상수 {KNOWLEDGE} != pin {R4_KNOWLEDGE_PIN}(개정 리뷰 필요)")
    if meta.get("knowledge_contract_digest") != _knowledge_contract_digest():
        fails.append("knowledge_contract_digest 불일치")
    if meta.get("blocker_contract_digest") != _blocker_contract_digest():
        fails.append("blocker_contract_digest 불일치")
    # --- config 값-대조(R4_PIN 전량 — 자기-보고 config를 pin과 대조) ---
    for k in ("max_episodes", "max_wall", "shaping", "shaping_coeffs", "train_deadline",
              "sil", "sil_buffer", "sil_coef", "max_len", "replay_deadline",
              "blocker_coef", "knowledge_coef", *_KNOB_PIN):
        if cfg.get(k) != R4_PIN[k]:
            fails.append(f"config.{k} {cfg.get(k)!r} != pin {R4_PIN[k]!r}")
    if int(meta.get("envs_requested") or -1) != R4_PIN["envs"]:
        fails.append(f"envs_requested {meta.get('envs_requested')} != {R4_PIN['envs']}")
    seed_entries = meta.get("seeds") or []
    if not seed_entries or any(int(e.get("seed", -1)) not in R4_PIN["seeds"] for e in seed_entries):
        fails.append(f"seed 집합 {[e.get('seed') for e in seed_entries]} not-subset pinned {R4_PIN['seeds']}")
    # --- 문법 자기재생산 + 엔진 리플레이 x2(D4 — 산출물 해의 실효 검증) ---
    actions = d.get("actions")
    if not actions:
        fails.append("actions=null — 클리어 해 없는 산출물(FAIL)")
    else:
        for i, a in enumerate(actions):
            try:
                enc = mdp.encode_action(a)
                dec = mdp.decode(enc)
                if mdp.encode_action(dec) != enc:
                    fails.append(f"action[{i}] encode-decode 비자기재생산(문법 밖/양자화 불안정)")
                # 문법-정확성(fail-closed): r4 산출물 액션은 decode 출력 그대로라 exact roundtrip이
                # 성립해야 한다. 최근접-매치 encode의 드리프트 관용은 커버리지 게이트(타 문법 해) 전용 —
                # 여기서 허용하면 문법 밖 액션(수작업/변조)이 replay만 통과해도 r4 산출물로 위장 가능.
                if json.dumps(dec, sort_keys=True) != json.dumps(a, sort_keys=True):
                    fails.append(f"action[{i}] 문법-정확 불일치(decode(encode(a)) != a — 비생성/변조 산출물)")
            except Exception as e:
                fails.append(f"action[{i}] r4 인코딩 불가({type(e).__name__}: {e})")
        if not fails:
            rr = [solve.run_plan(mdp.stage_scene, actions, deadline=R4_PIN["replay_deadline"],
                                 trace=False) for _ in range(2)]
            if json.dumps(rr[0], sort_keys=True) != json.dumps(rr[1], sort_keys=True):
                fails.append("replay x2 비동일(결정론 위반)")
            if not (rr[0].get("cleared") and int(rr[0].get("saved") or 0) >= mdp.hp):
                fails.append(f"replay 판정 실패: {rr[0]}")
    if fails:
        print(f"[{label}] FAIL:")
        for f in fails:
            print("  -", f)
        return 1
    print(f"[{label}] PASS — 표현/계약 digest·pin config·문법 자기재생산·replay x2 그린 "
          f"(landmarks={len(mdp.landmark_instances)})")
    return 0


def coverage(stage_ids: list[int], grammar: str = GRAMMAR_VERSION) -> int:
    label = f"coverage:{grammar}"
    fails = []
    for sid in stage_ids:
        src = ROOT / "data" / "solutions" / f"stage{sid:02d}.solve.json"
        known = json.loads(src.read_text(encoding="utf-8"))
        mdp = StageMDP(sid, grammar=grammar)
        encoded = [mdp.encode_action(a) for a in known["actions"]]
        plan = mdp.decode_plan(encoded)
        res = solve.run_plan(known["stage"], plan, known["deadline_frames"], trace=False)
        ok = bool(res.get("cleared")) and int(res.get("saved") or 0) == mdp.hp
        print(f"[{label}] S{sid}: encoded={json.dumps(plan)}")
        print(f"[{label}] S{sid}: cleared={res.get('cleared')} saved={res.get('saved')}/{mdp.hp} "
              f"frame={res.get('frame')} → {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append(sid)
    if fails:
        print(f"[{label}] FAIL: {fails} — 문법이 known 해를 엔진-등가로 표현 못 함")
        return 1
    print(f"[{label}] PASS — 문법이 known 해 전부 커버")
    return 0


# ---------- --accept-resume-equiv (P1 acceptance 1 — 재개 등가성, plan §R2) ----------

def accept_resume_equiv(args) -> int:
    """같은 seed·배치 수 기준(wall 아님): 2N 무중단 vs (N + ckpt 저장) 후 (resume + N)의
    최종 정책 파라미터(비트 동일)·학습 곡선(배치별 meanR 시퀀스) 일치. 결정론 배치 계약
    (plan-R2 MED-3): --max-batches 모드는 배치 수만 종료 조건(wall 조기중단 비활성)."""
    torch, _ = _torch()
    if args.grammar not in (GRAMMAR_R2, GRAMMAR_R4):
        print("--accept-resume-equiv는 --grammar r2.1/r4.0 전용")
        return 2
    n = args.max_batches
    if not n:
        print("--max-batches N 필수(등가성 기준 배치 수)")
        return 2
    seed = int(args.seeds.split(",")[0])
    refine = bool(getattr(args, "refine", False))
    if refine and args.grammar != GRAMMAR_R2:
        print("--refine 재개 등가성은 r2.1 전용(r4는 refine 미지원)")
        return 2
    mdp = StageMDP(args.stage, max_len=args.max_len, grammar=args.grammar,
                   at_frame_cap=args.train_deadline)
    base = dict(DEFAULTS, max_episodes=10**9, max_wall=10**9, shaping=args.shaping,
                train_deadline=args.train_deadline, max_len=args.max_len, sil=bool(args.sil))
    if refine:                                    # r3: refine 경로도 재개 등가성 대상(plan §R3 acceptance 2)
        base.update(refine=True, dense_shaping=bool(getattr(args, "dense_shaping", False)),
                    trace_blind=bool(getattr(args, "trace_blind", False)),
                    memo=not bool(getattr(args, "no_memo", False)),
                    obs_schema_digest=OBS_SCHEMA_DIGEST)
    print(f"=== P1 재개 등가성: stage {args.stage} seed {seed} N={n} refine={refine} "
          f"(A: 2N 무중단 / B: N→ckpt→resume→N) ===")
    pool, _eff, _pf = build_pool(args.envs, mdp.stage_scene,
                                 with_trace=(args.shaping == "trace" or refine))
    tmp = Path(tempfile.gettempdir()) / f"candyants_rl2_equiv_{os.getpid()}.pt"
    try:
        res_a, st_a = train_seed(mdp, pool, seed, dict(base, max_batches=2 * n))
        res_b1, st_b1 = train_seed(mdp, pool, seed, dict(base, max_batches=n))
        save_ckpt(tmp, st_b1)
        ck = load_ckpt(tmp)
        res_b2, st_b2 = train_seed(mdp, pool, seed, dict(base, max_batches=n), ck, "resume")
    finally:
        pool.close()
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
    fails: list[str] = []
    pa, pb = st_a["policy"], st_b2["policy"]
    if pa.keys() != pb.keys():
        fails.append("정책 파라미터 키 불일치")
    else:
        diff = [k for k in pa if not torch.equal(pa[k], pb[k])]
        if diff:
            fails.append(f"정책 파라미터 불일치({len(diff)}개 텐서): {diff[:4]}…")
    ca, cb1, cb2 = res_a["curve"], res_b1["curve"], res_b2["curve"]
    if cb2[:len(cb1)] != cb1:
        fails.append(f"B2 곡선 앞부분 != B1 곡선 (len {len(cb1)}/{len(cb2)})")
    if ca != cb2:
        fails.append(f"곡선 불일치: A(len {len(ca)}) != B(len {len(cb2)})")
    if res_a["episodes"] != res_b2["episodes"]:
        fails.append(f"에피소드 수 불일치: {res_a['episodes']} != {res_b2['episodes']}")
    if fails:
        print("[accept-resume-equiv] FAIL (부분 직렬화 은폐 금지 — P1 FAIL):")
        for f in fails:
            print("  -", f)
        return 1
    print(f"[accept-resume-equiv] PASS — 파라미터 비트동일 + 곡선 {len(ca)}개 배치 일치 "
          f"(eps {res_a['episodes']})")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Phase R — RL plan-구성 학습(무힌트, r0/r1/r2)")
    ap.add_argument("--stage", type=int, default=11)
    ap.add_argument("--seeds", type=str, default="0,1,2")
    ap.add_argument("--envs", type=int, default=4)
    ap.add_argument("--max-episodes", type=int, default=20000, help="seed당 에피소드 예산")
    ap.add_argument("--max-wall", type=int, default=7200, help="seed당 wall 예산(초)")
    ap.add_argument("--shaping", choices=("none", "trace"), default="none",
                    help="R1 trace-shaped 보상(기본 none = R0 커맨드 의미 불변)")
    ap.add_argument("--train-deadline", type=int, default=TRAIN_DEADLINE,
                    help="학습 롤아웃 deadline cap(R1/R2 pinned 커맨드=4500; 판정 replay는 7000 고정)")
    ap.add_argument("--no-save", action="store_true",
                    help="산출물(rl.json/rl2.json) 미저장 — plan §R1 S11 스모크 격리용")
    ap.add_argument("--max-len", type=int, default=DEFAULTS["max_len"],
                    help="plan 슬롯 상한(r1.1 실효값=min(ant-target 인벤토리 합, 이 값); r2=전역 고정 슬롯)")
    ap.add_argument("--sil", action="store_true",
                    help="self-imitation(plan §R1 fallback 2): top-K 에피소드 (R−baseline)+ 가중 재모방")
    ap.add_argument("--blocker-coef", type=float, default=0.0,
                    help="생산적 blocker 활용도 보너스 계수(opt-in, §6.4; 0=무효 = pinned 경로 byte-identical). "
                         ">0이면 롤아웃 report_fired + reward에 +coef·redirect_value/(D0·ants) 가산")
    ap.add_argument("--knowledge-coef", type=float, default=0.0,
                    help="지식-축적 보상 계수(opt-in, §14.3 v3; 0=무효 = pinned 경로 byte-identical). "
                         ">0이면 신규 토큰(필드 값) 첫 사용 +, '시행착오'(미클리어 & 빈손→candy/운반→home "
                         "프런티어 모두 미갱신) 동일 plan 반복 누진 −(cap 클립). 원장은 ckpt 동승"
                         "(resume 이월=재도전 가속 / transfer 리셋). SIL은 사용-시점 재평가")
    ap.add_argument("--knowledge-mode", choices=["always", "stall"], default="always",
                    help="§16 정체-격발(opt-in, 권장 레시피=stall): always=§14.4 원행동(knowledge-coef>0 "
                         "시 상시 적용) / stall=검출 런(knowledge 미적용)을 돌리다 격발 시 **같은 seed를 "
                         "knowledge=always로 재시작**(escalation-restart — §14.4 실증 레짐의 결정론 재현). "
                         "격발 = 미개선(bestR) 연속 ≥ --stall-batches AND 최근 창 dup 점유율 ≥ "
                         "--stall-share(반복-지배 정체 진단 — §16.4 5점 보정, 실측 오격발 0). "
                         "지연-투입(게이트/latch)은 3판 실측 반증으로 폐기(§16.4~16.6). "
                         "최종 acceptance 12/12(§16.7 — baseline·always 둘 다 엄격 우위). "
                         "stall은 --knowledge-coef>0 필요. cfg 키는 stall일 때만 주입(산출물 config 호환)")
    ap.add_argument("--stall-batches", type=int, default=30,
                    help="§16 격발 조건 ⓐ: bestR 미갱신 연속 배치 수 문턱(= 반복-지배 창 크기)")
    ap.add_argument("--stall-share", type=float, default=0.5,
                    help="§16 격발 조건 ⓑ: 최근 창 dup 점유율(1−unique/total) 문턱. 보정 실측(§16.4): "
                         "격발해야 = 0.756/0.915, 격발 금지 = 0.371 → 0.5")
    ap.add_argument("--stall-any-batches", type=int, default=0,
                    help="보조 격발(opt-in, 2026-07-13 스윕 실패 분석): bestR 미개선 연속 배치가 이 값에 "
                         "도달하면 dup 문턱과 무관하게 격발(다양-고원 구제 — 2차 스윕 FAIL 12 중 10개가 "
                         "dup 0.02~0.08로 주-격발 영구 차단 실측). 0=off(기존 동작 byte-identical), "
                         "--stall-batches 이상이어야 함. --knowledge-mode stall 전용")
    ap.add_argument("--reseed-on-fail", type=int, default=0,
                    help="collapse 회피(§11 안정화): FAIL로 끝난 seed를 대체 seed(base+1000·attempt)로 최대 "
                         "K회 재시도(opt-in, 0=기존 동작 불변). 오케스트레이션 전용 — train_seed 무변경이라 "
                         "pinned 경로 byte-identical. scratch 학습 전용(ckpt 로드 모드 비활성). "
                         "collapse seed가 빨리 잘리도록 --max-wall을 짧게(정상 seed clear wall 초과분) 줄 것")
    ap.add_argument("--grammar", choices=(GRAMMAR_VERSION, GRAMMAR_R2, GRAMMAR_R4), default=GRAMMAR_VERSION,
                    help="문법 버전(기본 r1.1 = 기존 커맨드 의미 불변; R2 커맨드는 r2.1 명시)")
    ap.add_argument("--save-ckpt", action="store_true",
                    help="r2: 학습 종료 시 체크포인트 저장(data/solutions/rl_ckpt/, P1 영속화)")
    ap.add_argument("--resume-ckpt", type=str, default=None,
                    help="r2: exact resume(동일 스테이지 — stage/레이아웃/마스크/seed digest 일치 요구)")
    ap.add_argument("--transfer-ckpt", type=str, default=None,
                    help="r2: curriculum 전이(타 스테이지 — 가중치만 이월, 전역 어휘 digest fail-closed)")
    ap.add_argument("--max-batches", type=int, default=0,
                    help="이 invocation의 배치-수 종료 조건(등가성 시험 전용; wall/에피소드 예산 비활성)")
    ap.add_argument("--prefix-plan", type=str, default=None,
                    help="witness-prefix curriculum(opt-in, 2026-07-13 스윕 실패 분석): 플랜 JSON"
                         "(witness/solve 포맷, actions 배열)의 앞 --prefix-k개 액션을 격자 인코딩해 "
                         "강제 prefix로 고정하고 정책은 이후 스텝만 학습. r2.1·non-refine·scratch 전용, "
                         "--no-save 필수(pinned 산출물 불가침 — 발견은 레지스트리에 hint provenance 동승). "
                         "encode가 witness 값을 격자로 스냅(정확 재현 아님 — 유도 목적)")
    ap.add_argument("--prefix-k", type=int, default=0,
                    help="--prefix-plan에서 강제할 앞 액션 수(0=off). k < --max-len(자유 슬롯 ≥1). "
                         "k를 줄여가며(예: 4→2→0) 자력 발견 비중을 확대하는 curriculum 용법")
    ap.add_argument("--refine", action="store_true",
                    help="r3 trace-refinement(plan §R3): 부분 plan 롤아웃 trace를 상태로 관측(closed-loop)")
    ap.add_argument("--dense-shaping", action="store_true",
                    help="r3 fallback: dense PBRS(F_t=γφ(P_{t+1})−φ(P_t), γ=1, terminal φ=0)")
    ap.add_argument("--trace-blind", action="store_true",
                    help="r3 인과 대조: trace 채널·스칼라 전부 0(롤아웃 수·비용은 --refine과 동일)")
    ap.add_argument("--no-memo", action="store_true",
                    help="r3 롤아웃 memo 캐시 끔(memo-결정론 대조 — memo-on과 byte-identical 실증)")
    ap.add_argument("--verify-r0", action="store_true")
    ap.add_argument("--verify-r1", action="store_true")
    ap.add_argument("--verify-r2", action="store_true")
    ap.add_argument("--verify-r3", action="store_true")
    ap.add_argument("--verify-r4", action="store_true")
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--coverage-r2", action="store_true",
                    help="r2 문법 커버리지: known S11·S12(ant)+S19(cell) 해 → 격자 → 엔진 클리어")
    ap.add_argument("--accept-resume-equiv", action="store_true",
                    help="P1 재개 등가성 acceptance(2N 무중단 vs N+ckpt+N — 파라미터·곡선 일치)")
    ap.add_argument("--preflight-only", action="store_true")
    args = ap.parse_args()
    if args.verify_r0:
        return verify_r0(args.stage)
    if args.verify_r1:
        return verify_r1(args.stage)
    if args.verify_r2:
        return verify_r2(args.stage)
    if args.verify_r3:
        return verify_r3(args.stage)
    if args.verify_r4:
        return verify_r4(args.stage)
    if args.coverage:
        return coverage([11, 12])
    if args.coverage_r2:
        return coverage([11, 12, 19], grammar=GRAMMAR_R2)
    if args.accept_resume_equiv:
        return accept_resume_equiv(args)
    if args.preflight_only:
        mdp = StageMDP(args.stage)
        pool, n, _ = build_pool(args.envs, mdp.stage_scene)
        pool.close()
        return 0 if n == args.envs else 1
    return run_training(args)


if __name__ == "__main__":
    raise SystemExit(main())
