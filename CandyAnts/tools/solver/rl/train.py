#!/usr/bin/env python3
"""
Phase R (RL 솔버) R0 — REINFORCE 학습 루프 + 병렬 GodotEnv + acceptance 검증.

plan SoT = auto-solver-plan.md §Phase R. 무힌트(model.propose 미사용 — 이 모듈은 propose를 import하지
않는다), 엔진/PlanRunner/게이트 무변경(로컬 RL 게이트 = --verify-r0).

고정 acceptance 커맨드 (plan §R0):
    python tools/solver/rl/train.py --stage 11 --seeds 0,1,2 --envs 4 --max-episodes 20000 --max-wall 7200
검증:
    python tools/solver/rl/train.py --verify-r0            # manifest + predicate + replay ×2 fail-closed
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

from mdp import StageMDP, GRAMMAR_VERSION, REWARD  # noqa: E402
from env import GodotEnv                           # noqa: E402  (tools/solver/env.py)
import solve                                       # noqa: E402  (run_plan 단발 리플레이 — 권위 경로)

REPLAY_DEADLINE = 7000       # acceptance 판정·리플레이 표준 deadline(축소 cap 거짓음성 차단, plan §R0)
TRAIN_DEADLINE = 3000        # 학습 중 롤아웃 cap(낭비 절감; S11 clear=1562f)
DIGEST_KEYS = ("cleared", "saved", "lost", "hp", "frame", "actions_fired", "picked_total")

# effective config 기본값 — manifest에 전량 박제(R2-M1: 기본값 drift가 산출물로 추적됨).
DEFAULTS = dict(batch=16, lr=3e-3, entropy=0.03, entropy_min=0.005, entropy_decay=0.997,
                hidden=128, greedy_every=5,
                baseline_decay=0.9, max_len=6, train_deadline=TRAIN_DEADLINE,
                replay_deadline=REPLAY_DEADLINE)

# R0 고정 acceptance 계약(plan §R0) — verify-r0가 manifest에 강제(impl-R1 HIGH: pinned 계약 미검증 차단).
# replay_deadline도 pin(impl-R2 HIGH: manifest 자기-일관성만 보면 느슨한 deadline 재생성이 통과) —
# 판정 replay가 인증의 실체이므로 그 deadline은 상수 고정. 학습-전용 knob(train_deadline 등)은 pin 비대상.
R0_PIN = dict(seeds=[0, 1, 2], envs=4, max_episodes=20000, max_wall=7200,
              replay_deadline=REPLAY_DEADLINE)


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


def preflight(pool: EnvPool, stage_scene: str) -> bool:
    """N env × 빈 plan 2회 = 전 digest identical — **학습과 동일한 병렬 경로(pool.evaluate,
    ThreadPoolExecutor)로 실행**해 동시성 자체를 검증한다(R1-M1: 순차 preflight는 병렬 미검증)."""
    plan = {"stage": stage_scene, "deadline_frames": 600, "actions": []}
    results = pool.evaluate([plan] * (2 * pool.n))   # 스트라이드 분배로 env당 정확히 2회
    digests = [_digest(r) for r in results]
    ok = all(d == digests[0] for d in digests)
    print(f"[preflight] envs={pool.n} runs={len(digests)} parallel identical={ok} base={digests[0]}")
    return ok


def build_pool(envs_requested: int, stage_scene: str) -> tuple[EnvPool, int]:
    """요청 N으로 풀 구성 → preflight 실패 시 N=1 강등(plan §R0 N 폴백 계약)."""
    pool = EnvPool(envs_requested)
    if pool.n > 1 and not preflight(pool, stage_scene):
        print("[preflight] FAIL → N=1 강등(정직 보고: manifest envs_effective=1)")
        pool.close()
        pool = EnvPool(1)
    return pool, pool.n


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

    while _budget_left():
        batch_i += 1
        eps = [_sample_episode(mdp, policy) for _ in range(cfg["batch"])]
        plans = [{"stage": mdp.stage_scene, "deadline_frames": cfg["train_deadline"],
                  "actions": mdp.decode_plan(p)} for p, _, _ in eps]
        rollouts = pool.evaluate(plans)
        episodes += len(eps)
        rewards = [mdp.reward(r, len(p)) for (p, _, _), r in zip(eps, rollouts)]
        result["best_reward"] = max(result["best_reward"], max(rewards))
        mean_r = sum(rewards) / len(rewards)
        curve.append(round(mean_r, 4))
        if not baseline_init:
            baseline, baseline_init = mean_r, True
        ent_coef = max(cfg["entropy_min"], cfg["entropy"] * cfg["entropy_decay"] ** batch_i)
        loss = torch.tensor(0.0)
        for (p, logp, ent), rew in zip(eps, rewards):
            loss = loss + (-(rew - baseline) * logp - ent_coef * ent)
        loss = loss / len(eps)
        opt.zero_grad()
        loss.backward()
        opt.step()
        baseline = cfg["baseline_decay"] * baseline + (1 - cfg["baseline_decay"]) * mean_r
        if batch_i % 10 == 0:
            print(f"  [seed {seed}] batch {batch_i} eps={episodes} meanR={mean_r:.3f} "
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
    return result


# ---------- acceptance 오케스트레이션 (--seeds 집계, R2-H) ----------

def rl_json_path(stage_id: int) -> Path:
    return ROOT / "data" / "solutions" / f"stage{stage_id:02d}.rl.json"


def run_training(args) -> int:
    mdp = StageMDP(args.stage, max_len=DEFAULTS["max_len"])
    seeds = [int(s) for s in args.seeds.split(",")]
    cfg = dict(DEFAULTS, max_episodes=args.max_episodes, max_wall=args.max_wall)
    print(f"=== Phase R R0 학습: stage {args.stage} (hp={mdp.hp}, inv={mdp.inventory}, "
          f"max_len={mdp.max_len}, obs_dim={mdp.obs_dim}) seeds={seeds} ===")
    pool, envs_effective = build_pool(args.envs, mdp.stage_scene)
    try:
        seed_results = [train_seed(mdp, pool, s, cfg) for s in seeds]
    finally:
        pool.close()
    n_clear = sum(1 for r in seed_results if r["cleared"])
    passed = n_clear * 2 >= len(seeds) + (len(seeds) % 2)   # ≥2/3 (일반화: 과반)
    print(f"=== 집계: {n_clear}/{len(seeds)} seed 클리어 → {'PASS' if passed else 'FAIL'} ===")
    # 산출물: 최소 에피소드 성공 seed의 greedy plan + manifest(effective config 전량, R2-M1)
    ok = [r for r in seed_results if r["cleared"]]
    if ok:
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
                "config": {**cfg, "reward": REWARD},
                "pass": passed, "pass_rule": ">=2/3 seeds greedy clear within per-seed budget",
                "seeds": [{k: r[k] for k in ("seed", "cleared", "episodes", "wall_s", "best_reward")}
                          for r in seed_results],
                "curves": {str(r["seed"]): r["curve"] for r in seed_results},
                "best_seed": best["seed"],
            },
        }
        path = rl_json_path(args.stage)
        path.write_text(json.dumps(out, indent=1), encoding="utf-8")
        print(f"산출물 저장: {path}")
    return 0 if passed else 1


# ---------- --verify-r0 (fail-closed 로컬 게이트, R1-M2·R2-M3) ----------

def verify_r0(stage_id: int) -> int:
    fails: list[str] = []
    path = rl_json_path(stage_id)
    if not path.exists():
        print(f"[verify-r0] FAIL: {path} 없음")
        return 1
    d = json.loads(path.read_text(encoding="utf-8"))
    meta = d.get("rl_meta") or {}
    cfg = meta.get("config") or {}
    mdp = StageMDP(stage_id)
    # ① manifest 완전성 + 스테이지 바인딩 + pinned 계약(impl-R1 HIGH: 다른 config/스테이지 산출물 차단)
    if d.get("stage_id") != stage_id:
        fails.append(f"stage_id {d.get('stage_id')} != {stage_id}")
    if d.get("stage") != mdp.stage_scene:
        fails.append(f"stage {d.get('stage')} != {mdp.stage_scene}")
    if cfg.get("replay_deadline") != R0_PIN["replay_deadline"]:
        fails.append(f"config.replay_deadline != pinned {R0_PIN['replay_deadline']}")
    if d.get("deadline_frames") != R0_PIN["replay_deadline"]:
        fails.append(f"deadline_frames != pinned {R0_PIN['replay_deadline']}")
    if (d.get("expect") or {}).get("saved") != mdp.hp:
        fails.append(f"expect.saved != hp_stage {mdp.hp}")
    if meta.get("no_hint") is not True:
        fails.append("no_hint != true")
    if meta.get("grammar_version") != GRAMMAR_VERSION:
        fails.append(f"grammar_version {meta.get('grammar_version')} != {GRAMMAR_VERSION}")
    if meta.get("pass") is not True:
        fails.append("rl_meta.pass != true")
    if meta.get("envs_requested") != R0_PIN["envs"]:
        fails.append(f"envs_requested != {R0_PIN['envs']} (pinned)")
    if cfg.get("max_episodes") != R0_PIN["max_episodes"] or cfg.get("max_wall") != R0_PIN["max_wall"]:
        fails.append("max_episodes/max_wall이 pinned 예산과 다름")
    for k in ("envs_effective", "seeds"):
        if k not in meta:
            fails.append(f"rl_meta.{k} 누락")
    for k in ("batch", "lr", "entropy", "entropy_min", "entropy_decay", "hidden",
              "max_episodes", "max_wall", "train_deadline", "replay_deadline", "reward"):
        if k not in cfg:
            fails.append(f"config.{k} 누락")
    seeds = meta.get("seeds") or []
    if [s.get("seed") for s in seeds] != R0_PIN["seeds"]:
        fails.append(f"seeds {[s.get('seed') for s in seeds]} != pinned {R0_PIN['seeds']}")
    for s in seeds:
        if s.get("episodes", 10**9) > cfg.get("max_episodes", 0):
            fails.append(f"seed {s.get('seed')}: 에피소드 예산 초과")
        if s.get("wall_s", 10**9) > cfg.get("max_wall", 0):
            fails.append(f"seed {s.get('seed')}: wall 예산 초과")
    # ② predicate 재판정
    n_clear = sum(1 for s in seeds if s.get("cleared"))
    if n_clear < 2:
        fails.append(f"3-seed predicate 미달: cleared {n_clear}/3 (≥2 필요)")
    # ③ 독립 replay ×2 (단발 run_plan = 권위 경로) + saved==hp_stage
    digests = []
    for i in range(2):
        res = solve.run_plan(d["stage"], d["actions"], d["deadline_frames"], trace=False)
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
        print("[verify-r0] FAIL:")
        for f in fails:
            print("  -", f)
        return 1
    print(f"[verify-r0] PASS — manifest 완전 · predicate {n_clear}/3 · replay ×2 identical "
          f"{digests[0]}")
    return 0


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
    ap.add_argument("--verify-r0", action="store_true")
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--preflight-only", action="store_true")
    args = ap.parse_args()
    if args.verify_r0:
        return verify_r0(args.stage)
    if args.coverage:
        return coverage([11, 12])
    if args.preflight_only:
        mdp = StageMDP(args.stage)
        pool, n = build_pool(args.envs, mdp.stage_scene)
        pool.close()
        return 0 if n == args.envs else 1
    return run_training(args)


if __name__ == "__main__":
    raise SystemExit(main())
