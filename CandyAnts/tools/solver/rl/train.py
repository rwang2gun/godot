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
    python tools/solver/rl/train.py --verify-r2 --stage 13 # R2_PIN + ckpt/chain 무결 + curriculum 정합
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

from mdp import (StageMDP, GRAMMAR_VERSION, GRAMMAR_R2, REWARD, SHAPING,  # noqa: E402
                 global_vocab, manifest_stage_ids)
from env import GodotEnv                           # noqa: E402  (tools/solver/env.py)
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
R0_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=7200,
              replay_deadline=REPLAY_DEADLINE, max_len=DEFAULTS["max_len"],
              grammar="r1.1")

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
              grammar="r1.1")                # §R2 선결 계약: 리터럴 동결

# R2 고정 acceptance 계약(plan §R2 acceptance 2/3ⓑ — 공통 구간 예산, plan-R3 MED: 사슬 전 구간 동일 pin).
# grammar=r2.1(전역 어휘+마스킹+cell-target). 예산 회계는 **구간별**(plan-R2 MED-4) — verify-r2가
# chain의 각 세그먼트에 이 예산을 독립 적용한다(사슬 합산 아님).
R2_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=1800,
              replay_deadline=REPLAY_DEADLINE, shaping="trace", shaping_coeffs=dict(SHAPING),
              train_deadline=4500, sil=True, sil_buffer=8, sil_coef=0.1,
              max_len=DEFAULTS["max_len"], grammar=GRAMMAR_R2)
# pinned 사슬(체크포인트 출처 pin, plan-R2 HIGH-1): stage → 기대 chain 스테이지 열.
# S11=from-scratch 시점 / S12·S13=transfer 사슬 / S19=from-scratch 단독(어휘 증명 ⓑ, curriculum 불요 가정).
R2_CHAINS = {11: [11], 12: [11, 12], 13: [11, 12, 13], 19: [19]}
# pinned 커맨드에 --save-ckpt가 포함된 스테이지(헤더 독스트링 SoT) — 이들의 산출물에서 ckpt_saved
# **부재 = verify FAIL**(codex §R2-R2 HIGH-1: 항목 생략으로 byte-backed 검증 전체를 우회하는
# 부재-fail-open 차단). S19는 pinned 커맨드에 저장이 없어 비대상(기록돼 있으면 검증은 한다).
R2_SAVE_CKPT_STAGES = frozenset({11, 12, 13})

# ---------- r2 체크포인트 (P1 — plan §R2: 영속화 = 사용자 필수 요건) ----------
CKPT_FORMAT = "candyants-rl2-ckpt-v1"
CKPT_DIR = ROOT / "data" / "solutions" / "rl_ckpt"
# 직렬화 전수 계약(plan-R1 MED-1) — train_seed의 state 구성과 verify의 필드-완전성 검사가 이 목록을
# 공유(계약 드리프트 차단). 메타데이터-온리 위조 .pt 거부의 근거(codex §R2-R3 HIGH).
CKPT_REQUIRED_KEYS = (
    "format", "grammar_version", "vocab_digest", "stage_id", "layout_digest", "mask_digest",
    "model_cfg", "dtype", "seed", "seg_mode", "batch_i", "episodes_seg", "wall_seg",
    "cleared_seg", "baseline", "baseline_init", "curve_seg", "episodes_prior", "batches_prior",
    "sil_buf", "torch_rng", "policy", "optimizer", "chain")


def ckpt_path(stage_id: int, seed: int) -> Path:
    return CKPT_DIR / f"stage{stage_id:02d}_seed{seed}.r2.pt"


def _file_sha(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _model_cfg(mdp: StageMDP, cfg: dict) -> dict:
    """모델 shape 계약(ckpt 호환 검사 대상) — 전역 어휘라 스테이지 무관 동일해야 transfer 가능."""
    return {"hidden": cfg["hidden"], "conv_channels": cfg["conv_channels"],
            "max_len": mdp.max_len, "flat_dim": mdp.flat_dim,
            "heads": dict(mdp.heads)}


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
    if ckpt.get("format") != CKPT_FORMAT:
        fails.append(f"format {ckpt.get('format')!r} != {CKPT_FORMAT!r}")
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
    """로드한 ckpt의 현재-세그먼트를 chain 항목으로 접는다(transfer 시 완결 세그먼트로 편입)."""
    return {"stage_id": ckpt["stage_id"], "seed": ckpt["seed"], "mode": ckpt["seg_mode"],
            "episodes": ckpt["episodes_seg"], "batches": ckpt["batch_i"],
            "wall_s": ckpt["wall_seg"], "cleared": bool(ckpt["cleared_seg"]),
            "ckpt_sha": ckpt.get("_file_sha"), "ckpt_path": ckpt.get("_file_path")}


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


def _grid_tensor(mdp: StageMDP):
    """스테이지 상수 그리드 → CNN 입력 텐서(1×5×H×W). mdp._grid 레이아웃 = (r*W+c)*5+ch."""
    torch, _ = _torch()
    return (torch.tensor(mdp._grid, dtype=torch.float32)
            .view(1, mdp.H, mdp.W, 5).permute(0, 3, 1, 2).contiguous())


def _masked(lg, allowed: list[int], size: int):
    """허용 인덱스 밖 logits = -inf (무효 조합은 페널티가 아니라 표현 불가, plan §R2 P3).
    Categorical.entropy는 -inf logits를 finfo.min으로 clamp해 p=0 항이 0이 됨 — NaN 없음."""
    if len(allowed) >= size:
        return lg
    torch, _ = _torch()
    m = torch.full_like(lg, float("-inf"))
    m[allowed] = 0.0
    return lg + m


def _sample_episode_r2(mdp: StageMDP, policy, grid_t, greedy: bool = False):
    """r2 조건부 factored 샘플링: skill → (SUBMIT면 종료) → kind(스킬 메타로 단일 유효) → trigger →
    트리거-의존 head → kind-의존 head. 활성 head만 logp/entropy에 기여(비활성 head는 미샘플).
    스텝 0 SUBMIT 마스킹·인벤토리 동적 마스크는 mdp.head_mask가 담당."""
    torch, _ = _torch()
    partial: list[dict[str, int]] = []
    used: dict[str, int] = {}
    logps, ents = [], []
    for _t in range(mdp.max_len):
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


def _episode_logp_r2(mdp: StageMDP, policy, grid_t, partial: list[dict[str, int]]):
    """저장 에피소드의 현행-정책 log-prob 재계산(SIL) — 샘플링 경로와 동일한 조건부 head·마스킹."""
    torch, _ = _torch()
    total = torch.tensor(0.0)
    used: dict[str, int] = {}
    for t, a in enumerate(partial):
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


# ---------- 학습 (seed 1개) ----------

def train_seed(mdp: StageMDP, pool: EnvPool, seed: int, cfg: dict,
               ckpt_in: dict | None = None, ckpt_mode: str | None = None):
    """학습 1 seed. 반환 = (result, state) — state는 r2 체크포인트-가능 전체 상태(r1.1은 None).

    체크포인트 로드 2모드(plan §R2 P1): resume = 전 상태 복원(같은 세그먼트 계속, RNG·SIL·entropy
    카운터·baseline·curve까지 — 재개 등가성의 대상) / transfer = policy+optimizer 가중치만 이월,
    스테이지-파생 상태(entropy 스케줄·SIL buffer·baseline)는 리셋, RNG는 새 seed."""
    torch, _ = _torch()
    r2 = mdp.grammar_version == GRAMMAR_R2
    torch.manual_seed(seed)
    policy = make_policy_r2(mdp, cfg) if r2 else make_policy(mdp, cfg["hidden"])
    opt = torch.optim.Adam(policy.parameters(), lr=cfg["lr"])
    grid_t = _grid_tensor(mdp) if r2 else None
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

    def _sample(greedy: bool = False):
        return (_sample_episode_r2(mdp, policy, grid_t, greedy) if r2
                else _sample_episode(mdp, policy, greedy))

    def _ep_logp(p):
        return (_episode_logp_r2(mdp, policy, grid_t, p) if r2
                else _episode_logp(mdp, policy, p))

    use_trace = cfg["shaping"] == "trace"                 # plan §R1 — trace-shaped 보상
    while not result["cleared"] and _budget_left():
        batch_i += 1
        ran_batches += 1
        eps = [_sample() for _ in range(cfg["batch"])]
        plans = [{"stage": mdp.stage_scene, "deadline_frames": cfg["train_deadline"],
                  **({"trace": True} if use_trace else {}),
                  "actions": mdp.decode_plan(p)} for p, _, _ in eps]
        rollouts = pool.evaluate(plans)
        episodes += len(eps)
        if use_trace:
            # post-commit codex R4 MEDIUM: 빈-plan preflight만으론 "액션 발화 시 trace 소실" 회귀를 못
            # 잡고, shaped_bonus의 {} fail-safe가 무력화를 침묵시킴 → **액션 롤아웃별 trace 검증**.
            # 위반 = 학습 run 전체 fail(정직 크래시 — silent shaping 격하로 'trace' 라벨 산출물 금지).
            for r in rollouts:
                if not _trace_valid(r.get("trace")):
                    raise RuntimeError(
                        f"trace-shaped 학습 롤아웃에 유효 trace 부재 — 엔진/Env trace 수집 회귀 "
                        f"(fail-closed): digest={_digest(r)}")
        bonuses = [mdp.shaped_bonus(r) if use_trace else 0.0 for r in rollouts]
        rewards = [mdp.reward(r, len(p)) + b
                   for (p, _, _), r, b in zip(eps, rollouts, bonuses)]
        bi = max(range(len(rewards)), key=lambda i: rewards[i])
        if rewards[bi] > result["best_reward"]:
            result["best_episode"] = mdp.decode_plan(eps[bi][0])   # FAIL 사후 진단용(스윕 로그)
        result["best_reward"] = max(result["best_reward"], max(rewards))
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
            for (p, _lp, _e), rew in zip(eps, rewards):
                sig = json.dumps(p, sort_keys=True)
                if sig not in sil_sigs:
                    sil_buf.append((rew, p))
                    sil_sigs.add(sig)
            sil_buf.sort(key=lambda t: -t[0])
            for rew, p in sil_buf[cfg["sil_buffer"]:]:
                sil_sigs.discard(json.dumps(p, sort_keys=True))
            del sil_buf[cfg["sil_buffer"]:]
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
            print(f"  [seed {seed}] batch {batch_i} eps={episodes} meanR={mean_r:.3f}{shape_note} "
                  f"bestR={result['best_reward']:.3f} wall={time.monotonic() - t0:.0f}s")
        # greedy 평가(성공 판정 = 표준 deadline에서 saved==hp_stage)
        if batch_i % cfg["greedy_every"] == 0:
            with torch.no_grad():
                gp, _, _ = _sample(greedy=True)
            plan = mdp.decode_plan(gp)
            res = pool.envs[0].step({"stage": mdp.stage_scene,
                                     "deadline_frames": cfg["replay_deadline"], "actions": plan})
            if res.get("cleared") and int(res.get("saved") or 0) == mdp.hp:
                result.update(cleared=True, greedy_plan=plan)
                print(f"  [seed {seed}] GREEDY CLEAR saved={res.get('saved')}/{mdp.hp} "
                      f"frame={res.get('frame')} eps={episodes}")
                break
    result["episodes"] = episodes
    result["batches"] = batch_i
    result["wall_s"] = round(wall_prev + (time.monotonic() - t0), 1)
    if not result["cleared"] and result.get("best_episode") is not None:
        print(f"  [seed {seed}] FAIL bestR={result['best_reward']:.3f} best plan: "
              f"{json.dumps(result['best_episode'])}")
    state = None
    if r2:
        # 직렬화 대상 전수(plan-R1 MED-1): policy+optimizer + entropy 카운터(batch_i) + 사용 RNG 전수
        # (현 구현 = torch 단일; python random/numpy 미사용) + SIL 내용·순서 + 누적 카운터 + 문법/
        # digest/모델 config·dtype + 재개 사슬.
        state = {
            "format": CKPT_FORMAT, "grammar_version": mdp.grammar_version,
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
    return result, state


# ---------- acceptance 오케스트레이션 (--seeds 집계, R2-H) ----------

def rl_json_path(stage_id: int) -> Path:
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl.json"


def rl2_json_path(stage_id: int) -> Path:
    """r2 산출물은 별도 파일 — r0/r1 pinned 산출물(stageNN.rl.json)은 영구 보존(§R2 선결 계약)."""
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl2.json"


def run_training(args) -> int:
    r2 = args.grammar == GRAMMAR_R2
    seeds = [int(s) for s in args.seeds.split(",")]
    if (args.save_ckpt or args.resume_ckpt or args.transfer_ckpt) and not r2:
        print("체크포인트 플래그는 --grammar r2.1 전용(plan §R2 P1)")
        return 2
    if args.resume_ckpt and args.transfer_ckpt:
        print("--resume-ckpt와 --transfer-ckpt는 배타(로드 2모드 분리, plan-R2 HIGH-2)")
        return 2
    if (args.resume_ckpt or args.transfer_ckpt) and len(seeds) != 1:
        print("ckpt 로드는 seed 1개 커맨드 전용(per-seed 사슬 계약, plan-R3 HIGH-2)")
        return 2
    mdp = StageMDP(args.stage, max_len=args.max_len, grammar=args.grammar,
                   at_frame_cap=args.train_deadline)
    cfg = dict(DEFAULTS, max_episodes=args.max_episodes, max_wall=args.max_wall,
               shaping=args.shaping, train_deadline=args.train_deadline, max_len=args.max_len,
               sil=bool(args.sil), max_batches=args.max_batches)
    ckpt_in, ckpt_mode = None, None
    if args.resume_ckpt:
        ckpt_in, ckpt_mode = load_ckpt(args.resume_ckpt), "resume"
    elif args.transfer_ckpt:
        ckpt_in, ckpt_mode = load_ckpt(args.transfer_ckpt), "transfer"
    dim_note = f"obs_dim={mdp.obs_dim}" if not r2 else f"flat_dim={mdp.flat_dim} grid={mdp.H}x{mdp.W}"
    print(f"=== Phase R 학습: stage {args.stage} (hp={mdp.hp}, inv={mdp.inventory}, "
          f"max_len={mdp.max_len}, {dim_note}) grammar={args.grammar} seeds={seeds} "
          f"shaping={cfg['shaping']} train_deadline={cfg['train_deadline']} "
          f"ckpt={ckpt_mode or 'none'} ===")
    pool, envs_effective, pf_info = build_pool(
        args.envs, mdp.stage_scene, with_trace=(cfg["shaping"] == "trace"))
    try:
        outs = [train_seed(mdp, pool, s, cfg, ckpt_in, ckpt_mode) for s in seeds]
    finally:
        pool.close()
    seed_results = [r for r, _ in outs]
    n_clear = sum(1 for r in seed_results if r["cleared"])
    need = (len(seeds) + (len(seeds) % 2) + 1) // 2         # ≥2/3 (일반화: 과반) — verify와 동일식
    passed = n_clear >= need
    print(f"=== 집계: {n_clear}/{len(seeds)} seed 클리어 (필요 ≥{need}) → {'PASS' if passed else 'FAIL'} ===")
    if r2:
        # 체크포인트 저장(P1 — 영속화). 클리어 여부 무관 저장(FAIL 세그먼트도 exact resume 대상;
        # transfer는 _ckpt_compat이 미클리어 ckpt를 거부).
        saved: dict[int, dict] = {}
        if args.save_ckpt:
            for (res, state), s in zip(outs, seeds):
                p = ckpt_path(args.stage, s)
                sha = save_ckpt(p, state)
                saved[s] = {"path": str(p.relative_to(ROOT)).replace("\\", "/"), "sha256": sha}
                print(f"ckpt 저장: {p} sha256={sha[:16]}…")
        if not args.no_save:
            _write_r2_artifact(mdp, args, cfg, outs, seeds, envs_effective, pf_info,
                               saved, ckpt_in, ckpt_mode)
        else:
            print("--no-save: 산출물 미저장(판정은 위 집계줄)")
        return 0 if passed else 1
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
    return 0 if passed else 1


# ---------- r2 산출물 (seed-단위 병합 — per-seed 사슬 커맨드 계약, plan-R3 HIGH-2) ----------

def _rel(p: str | Path) -> str:
    try:
        return str(Path(p).resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(p).replace("\\", "/")


def _write_r2_artifact(mdp: StageMDP, args, cfg: dict, outs, seeds, envs_effective: int,
                       pf_info: dict, saved: dict, ckpt_in: dict | None,
                       ckpt_mode: str | None) -> None:
    """stageNN.rl2.json — seed별 항목을 병합 누적(같은 stage·config·어휘일 때만). FAIL seed도 기록
    (predicate는 pinned seed 3개가 모이면 재계산 — 사슬 자체가 결과, plan §R2 acceptance 2)."""
    path = rl2_json_path(mdp.stage_id)
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
            "config": cfg_pub,
            "pass": passed,
            "pass_rule": f">={need}/{len(pinned)} pinned seeds greedy clear "
                         "within per-segment budget",
            "mode": "pinned-acceptance" if budget_pinned else "exploratory-sweep",
            "seeds": entries,
            "curves": curves,
            "best_seed": best["seed"] if best else None,
        },
    }
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
    for s in seeds:
        if s.get("episodes", 10**9) > cfg.get("max_episodes", 0) + cfg.get("batch", 0):
            fails.append(f"seed {s.get('seed')}: 에피소드 예산 초과")
        if s.get("wall_s", 10**9) > cfg.get("max_wall", 0) + 60:
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
    f = ROOT / str(rec.get("path"))
    if not f.exists():
        fails.append(f"{px}: ckpt 파일 {rec.get('path')} 없음")
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
    except Exception as ex:
        fails.append(f"{px}: ckpt state_dict 로드 계약 불이행({type(ex).__name__}: {ex}) — "
                     "재개/전이 불가능한 위조·손상 ckpt")
    tr = ck.get("torch_rng")
    if not (torch.is_tensor(tr) and tr.dtype == torch.uint8 and tr.numel() > 0):
        fails.append(f"{px}: ckpt torch_rng가 유효한 RNG 상태 텐서 아님")


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
    for k in ("max_episodes", "max_wall", "shaping", "shaping_coeffs", "train_deadline",
              "sil", "sil_buffer", "sil_coef", "max_len", "replay_deadline"):
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
            # 구간별 예산 회계(plan-R2 MED-4) — 오버슛 허용은 r0/r1과 동일(배치 1개 / +60s)
            if seg.get("episodes", 10**9) > pin["max_episodes"] + cfg.get("batch", 0):
                fails.append(f"{spx}: 구간 에피소드 예산 초과")
            if seg.get("wall_s", 10**9) > pin["max_wall"] + 60:
                fails.append(f"{spx}: 구간 wall 예산 초과(+60s 오버슛 허용 밖)")
            if i < len(chain) - 1 and not seg.get("cleared"):
                fails.append(f"{spx}: 미클리어인데 후속 세그먼트 존재 — transfer 게이트 위반")
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
    if args.grammar != GRAMMAR_R2:
        print("--accept-resume-equiv는 --grammar r2.1 전용")
        return 2
    n = args.max_batches
    if not n:
        print("--max-batches N 필수(등가성 기준 배치 수)")
        return 2
    seed = int(args.seeds.split(",")[0])
    mdp = StageMDP(args.stage, max_len=args.max_len, grammar=args.grammar,
                   at_frame_cap=args.train_deadline)
    base = dict(DEFAULTS, max_episodes=10**9, max_wall=10**9, shaping=args.shaping,
                train_deadline=args.train_deadline, max_len=args.max_len, sil=bool(args.sil))
    print(f"=== P1 재개 등가성: stage {args.stage} seed {seed} N={n} "
          f"(A: 2N 무중단 / B: N→ckpt→resume→N) ===")
    pool, _eff, _pf = build_pool(args.envs, mdp.stage_scene,
                                 with_trace=(args.shaping == "trace"))
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
    ap.add_argument("--grammar", choices=(GRAMMAR_VERSION, GRAMMAR_R2), default=GRAMMAR_VERSION,
                    help="문법 버전(기본 r1.1 = 기존 커맨드 의미 불변; R2 커맨드는 r2.1 명시)")
    ap.add_argument("--save-ckpt", action="store_true",
                    help="r2: 학습 종료 시 체크포인트 저장(data/solutions/rl_ckpt/, P1 영속화)")
    ap.add_argument("--resume-ckpt", type=str, default=None,
                    help="r2: exact resume(동일 스테이지 — stage/레이아웃/마스크/seed digest 일치 요구)")
    ap.add_argument("--transfer-ckpt", type=str, default=None,
                    help="r2: curriculum 전이(타 스테이지 — 가중치만 이월, 전역 어휘 digest fail-closed)")
    ap.add_argument("--max-batches", type=int, default=0,
                    help="이 invocation의 배치-수 종료 조건(등가성 시험 전용; wall/에피소드 예산 비활성)")
    ap.add_argument("--verify-r0", action="store_true")
    ap.add_argument("--verify-r1", action="store_true")
    ap.add_argument("--verify-r2", action="store_true")
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
