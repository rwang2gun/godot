#!/usr/bin/env python3
"""
Phase R (RL 솔버) R0 — REINFORCE 학습 루프 + 병렬 GodotEnv + acceptance 검증.

plan SoT = auto-solver-plan.md §Phase R. 무힌트(model.propose 미사용 — 이 모듈은 propose를 import하지
않는다), 엔진/PlanRunner/게이트 무변경(로컬 RL 게이트 = --verify-r0).

고정 acceptance 커맨드 (plan §R0):
    python tools/solver/rl/train.py --stage 11 --seeds 0,1,2 --envs 4 --max-episodes 20000 --max-wall 7200
고정 acceptance 커맨드 (plan §R1 — trace-shaped 보상+SIL, S12 다단; max_wall=사용자 지시 2026-07-04):
    python tools/solver/rl/train.py --stage 12 --seeds 0,1,2 --envs 4 --max-episodes 20000 --max-wall 1800 \
        --shaping trace --train-deadline 4500 --sil
R1-스윕 (S13~S25 탐사, plan §R1-스윕 — 비게이트, 단일 seed 30분 cap):
    python tools/solver/rl/train.py --stage NN --seeds 0 --envs 4 --max-episodes 20000 --max-wall 1800 \
        --shaping trace --train-deadline 4500 --sil --max-len 8
검증:
    python tools/solver/rl/train.py --verify-r0            # manifest + predicate + replay ×2 fail-closed
    python tools/solver/rl/train.py --verify-r1 --stage 12 # R1_PIN(shaping 포함) fail-closed
    python tools/solver/rl/train.py --coverage             # 문법 커버리지(known S11·S12 해 → 격자 → 엔진 클리어)
    python tools/solver/rl/train.py --preflight-only --envs 4   # 병렬 결정론 preflight만
"""
from __future__ import annotations

import argparse
import json
import sys
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

from mdp import StageMDP, GRAMMAR_VERSION, REWARD, SHAPING  # noqa: E402
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
                sil=False, sil_buffer=8, sil_coef=0.1)

# R0 고정 acceptance 계약(plan §R0) — verify-r0가 manifest에 강제(impl-R1 HIGH: pinned 계약 미검증 차단).
# replay_deadline도 pin(impl-R2 HIGH: manifest 자기-일관성만 보면 느슨한 deadline 재생성이 통과) —
# 판정 replay가 인증의 실체이므로 그 deadline은 상수 고정. 학습-전용 knob(train_deadline 등)은 pin 비대상.
R0_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=7200,
              replay_deadline=REPLAY_DEADLINE, max_len=DEFAULTS["max_len"])

# R1 고정 acceptance 계약(plan §R1) — R0_PIN + shaping 상수(plan-R1-H1: 계수까지 fail-closed;
# 계수 튜닝은 fallback 1에서만, 그때 이 pin도 같은 커밋에서 갱신). train_deadline=4500은 "학습-전용
# knob 비대상" 원칙의 명시 예외(plan-R2-H) — 3000f cap이 최적점 근방을 굶긴다고 plan이 입증한 material knob.
# max_wall=1800: 사용자 지시 2026-07-04("최대 30분 기준") — R0의 7200에서 하향.
# sil(+buffer/coef): fallback 2 채택(2026-07-04 — fallback 1 FAIL 후 SIL probe가 S12 클리어 실증,
# 세션 로그 F6·F7). fallback 계약대로 채택 시 pin 동일-커밋 갱신.
R1_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=1800,
              replay_deadline=REPLAY_DEADLINE, shaping="trace", shaping_coeffs=dict(SHAPING),
              train_deadline=4500, sil=True, sil_buffer=8, sil_coef=0.1,
              max_len=DEFAULTS["max_len"])   # post-commit codex R1 HIGH: 문법 길이도 인증 실체 — pin


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
    if with_trace and ok:
        traces = [r.get("trace") for r in results]
        ok = all(t == traces[0] for t in traces)
    print(f"[preflight] envs={pool.n} runs={len(digests)} trace={with_trace} "
          f"parallel identical={ok} wall={wall:.2f}s base={digests[0]}")
    return {"ok": ok, "wall_s": round(wall, 2), "runs": len(digests)}


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

def train_seed(mdp: StageMDP, pool: EnvPool, seed: int, cfg: dict) -> dict:
    torch, _ = _torch()
    torch.manual_seed(seed)
    policy = make_policy(mdp, cfg["hidden"])
    opt = torch.optim.Adam(policy.parameters(), lr=cfg["lr"])
    baseline, baseline_init = 0.0, False
    episodes, batch_i = 0, 0
    t0 = time.monotonic()
    curve: list[float] = []
    result = {"seed": seed, "cleared": False, "episodes": 0, "wall_s": 0.0,
              "best_reward": float("-inf"), "greedy_plan": None, "curve": curve}

    def _budget_left() -> bool:
        return episodes < cfg["max_episodes"] and (time.monotonic() - t0) < cfg["max_wall"]

    use_trace = cfg["shaping"] == "trace"                 # plan §R1 — trace-shaped 보상
    # self-imitation buffer (plan §R1 fallback 2): top-K (reward, partial), plan-sig 중복 제거.
    # 희소한 고보상 에피소드가 배치 평균에 희석돼 정책을 못 끌어올리는 병목(S12 bestR 0.447 정체 실측)
    # 을 (R−baseline)+ 가중 재모방으로 해소.
    sil_buf: list[tuple[float, list[dict[str, int]]]] = []
    sil_sigs: set[str] = set()
    while _budget_left():
        batch_i += 1
        eps = [_sample_episode(mdp, policy) for _ in range(cfg["batch"])]
        plans = [{"stage": mdp.stage_scene, "deadline_frames": cfg["train_deadline"],
                  **({"trace": True} if use_trace else {}),
                  "actions": mdp.decode_plan(p)} for p, _, _ in eps]
        rollouts = pool.evaluate(plans)
        episodes += len(eps)
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
            used = [(rew, p) for rew, p in sil_buf if rew > baseline]
            if used:
                sil_term = torch.tensor(0.0)
                for rew, p in used:
                    sil_term = sil_term + (rew - baseline) * (-_episode_logp(mdp, policy, p))
                loss = loss + cfg["sil_coef"] * sil_term / len(used)
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
                gp, _, _ = _sample_episode(mdp, policy, greedy=True)
            plan = mdp.decode_plan(gp)
            res = pool.envs[0].step({"stage": mdp.stage_scene,
                                     "deadline_frames": cfg["replay_deadline"], "actions": plan})
            if res.get("cleared") and int(res.get("saved") or 0) == mdp.hp:
                result.update(cleared=True, greedy_plan=plan)
                print(f"  [seed {seed}] GREEDY CLEAR saved={res.get('saved')}/{mdp.hp} "
                      f"frame={res.get('frame')} eps={episodes}")
                break
    result["episodes"] = episodes
    result["wall_s"] = round(time.monotonic() - t0, 1)
    if not result["cleared"] and result.get("best_episode") is not None:
        print(f"  [seed {seed}] FAIL bestR={result['best_reward']:.3f} best plan: "
              f"{json.dumps(result['best_episode'])}")
    return result


# ---------- acceptance 오케스트레이션 (--seeds 집계, R2-H) ----------

def rl_json_path(stage_id: int) -> Path:
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl.json"


def run_training(args) -> int:
    mdp = StageMDP(args.stage, max_len=args.max_len)
    seeds = [int(s) for s in args.seeds.split(",")]
    cfg = dict(DEFAULTS, max_episodes=args.max_episodes, max_wall=args.max_wall,
               shaping=args.shaping, train_deadline=args.train_deadline, max_len=args.max_len,
               sil=bool(args.sil))
    print(f"=== Phase R 학습: stage {args.stage} (hp={mdp.hp}, inv={mdp.inventory}, "
          f"max_len={mdp.max_len}, obs_dim={mdp.obs_dim}) seeds={seeds} "
          f"shaping={cfg['shaping']} train_deadline={cfg['train_deadline']} ===")
    pool, envs_effective, pf_info = build_pool(
        args.envs, mdp.stage_scene, with_trace=(cfg["shaping"] == "trace"))
    try:
        seed_results = [train_seed(mdp, pool, s, cfg) for s in seeds]
    finally:
        pool.close()
    n_clear = sum(1 for r in seed_results if r["cleared"])
    passed = n_clear * 2 >= len(seeds) + (len(seeds) % 2)   # ≥2/3 (일반화: 과반)
    print(f"=== 집계: {n_clear}/{len(seeds)} seed 클리어 → {'PASS' if passed else 'FAIL'} ===")
    # 산출물: 최소 에피소드 성공 seed의 greedy plan + manifest(effective config 전량, R2-M1)
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
                "pass": passed, "pass_rule": ">=2/3 seeds greedy clear within per-seed budget",
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


# ---------- --verify-r0/--verify-r1 (fail-closed 로컬 게이트, R1-M2·R2-M3 / plan §R1) ----------

_BASE_CFG_KEYS = ("batch", "lr", "entropy", "entropy_min", "entropy_decay", "hidden",
                  "max_episodes", "max_wall", "train_deadline", "replay_deadline", "reward")
_PIN_STD_KEYS = ("seeds", "envs", "max_episodes", "max_wall", "replay_deadline")


def _verify_pinned(stage_id: int, pin: dict, label: str) -> int:
    fails: list[str] = []
    path = rl_json_path(stage_id)
    if not path.exists():
        print(f"[{label}] FAIL: {path} 없음")
        return 1
    d = json.loads(path.read_text(encoding="utf-8"))
    meta = d.get("rl_meta") or {}
    cfg = meta.get("config") or {}
    mdp = StageMDP(stage_id, max_len=pin["max_len"])   # pinned 문법(길이 포함)이 검증 기준
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
    if meta.get("grammar_version") != GRAMMAR_VERSION:
        fails.append(f"grammar_version {meta.get('grammar_version')} != {GRAMMAR_VERSION}")
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


# ---------- --coverage (문법 커버리지: known 해 → 격자 인코딩 → 엔진 클리어, R1-H2) ----------

def coverage(stage_ids: list[int]) -> int:
    fails = []
    for sid in stage_ids:
        src = ROOT / "data" / "solutions" / f"stage{sid:02d}.solve.json"
        known = json.loads(src.read_text(encoding="utf-8"))
        mdp = StageMDP(sid)
        encoded = [mdp.encode_action(a) for a in known["actions"]]
        plan = mdp.decode_plan(encoded)
        res = solve.run_plan(known["stage"], plan, known["deadline_frames"], trace=False)
        ok = bool(res.get("cleared")) and int(res.get("saved") or 0) == mdp.hp
        print(f"[coverage] S{sid}: encoded={json.dumps(plan)}")
        print(f"[coverage] S{sid}: cleared={res.get('cleared')} saved={res.get('saved')}/{mdp.hp} "
              f"frame={res.get('frame')} → {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append(sid)
    if fails:
        print(f"[coverage] FAIL: {fails} — 문법이 known 해를 엔진-등가로 표현 못 함")
        return 1
    print("[coverage] PASS — 문법이 known 해 전부 커버")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Phase R R0 — RL plan-구성 학습(무힌트)")
    ap.add_argument("--stage", type=int, default=11)
    ap.add_argument("--seeds", type=str, default="0,1,2")
    ap.add_argument("--envs", type=int, default=4)
    ap.add_argument("--max-episodes", type=int, default=20000, help="seed당 에피소드 예산")
    ap.add_argument("--max-wall", type=int, default=7200, help="seed당 wall 예산(초)")
    ap.add_argument("--shaping", choices=("none", "trace"), default="none",
                    help="R1 trace-shaped 보상(기본 none = R0 커맨드 의미 불변)")
    ap.add_argument("--train-deadline", type=int, default=TRAIN_DEADLINE,
                    help="학습 롤아웃 deadline cap(R1 pinned 커맨드=4500; 판정 replay는 7000 고정)")
    ap.add_argument("--no-save", action="store_true",
                    help="산출물(rl.json) 미저장 — plan §R1 S11 스모크 격리용")
    ap.add_argument("--max-len", type=int, default=DEFAULTS["max_len"],
                    help="plan 슬롯 상한(R1-스윕: 인벤토리 큰 스테이지용; 실효값=min(ant-target 인벤토리 합, 이 값))")
    ap.add_argument("--sil", action="store_true",
                    help="self-imitation(plan §R1 fallback 2): top-K 에피소드 (R−baseline)+ 가중 재모방")
    ap.add_argument("--verify-r0", action="store_true")
    ap.add_argument("--verify-r1", action="store_true")
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--preflight-only", action="store_true")
    args = ap.parse_args()
    if args.verify_r0:
        return verify_r0(args.stage)
    if args.verify_r1:
        return verify_r1(args.stage)
    if args.coverage:
        return coverage([11, 12])
    if args.preflight_only:
        mdp = StageMDP(args.stage)
        pool, n, _ = build_pool(args.envs, mdp.stage_scene)
        pool.close()
        return 0 if n == args.envs else 1
    return run_training(args)


if __name__ == "__main__":
    raise SystemExit(main())
