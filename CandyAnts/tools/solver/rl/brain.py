#!/usr/bin/env python3
"""공유 뇌(shared-brain) 커리큘럼 트레이너 — 하나의 r2.1 정책을 여러 스테이지에 걸쳐
누적 학습한다. 반복 실행할수록 한 가중치 파일(found/brain.pt)에 경험이 쌓여 점점 강해지는
것을 목표로 한다(사용자 요건 B).

근거(검증됨): r2.1 PolicyR2는 스테이지-불변(AdaptiveMaxPool로 가변 그리드 흡수 + 전역 스킬
어휘 head + per-stage 마스킹). 1~10 전 스테이지에서 정책 shape(max_len=6, flat_dim=816,
heads) 동일 → 같은 가중치가 모든 스테이지에 로드된다.

학습 전략(사용자 설계): 게이트·순차 진행 없음. 매 사이클 1~10 전체를 batches_per_stage씩
  균등 학습(예산 뺏기 없음 — 깬 스테이지도 유지 학습해 퇴보 방지). 목표는 순차 클리어가 아니라
  수차례 반복하며 **총 클리어 수가 늘어나는 것**.
  하드 스테이지 초점 = **잭팟(carryover)**: 클리어 못 한 스테이지는 미지급 클리어 보상을 다음
  사이클로 이월 누적(jackpot[s]) → 그 스테이지를 클리어하는 롤아웃에 커진 보상이 실려 강하게
  당겨진다. 클리어 시 지급하고 0으로 리셋. (예산을 뺏지 않아 퇴보한 스테이지도 정상 배치 + 커진
  잭팟으로 회복 — prev-cycle 기준 starvation 결함 해소.)
  안정화: lr 하향 + gradient clipping + 보상 정규화(advantage 표준화) + best 뇌 별도 보존.
  진화하는 신경망이 재풀이마다 다른 해를 낼 수 있어, **새로(distinct) 나온 해는 별도 로그**
  (brain_solutions.jsonl)에 누적한다.

무수정 재사용: train.py의 make_policy_r2/_sample_episode_r2/_grid_tensor/build_pool 등을
import만 한다(gated 코드 변경 0). REINFORCE 업데이트는 여기서 구성.

사용법(CandyAnts 폴더):
    python tools/solver/rl/brain.py                 # 5 사이클(기본), brain.pt 이어받기
    python tools/solver/rl/brain.py --cycles 30     # 오래 돌려 누적
    python tools/solver/rl/brain.py --reset         # 뇌 초기화하고 처음부터
    python tools/solver/rl/brain.py --show          # 현재 숙련 곡선만 출력

산출물(둘 다 found/ = gitignore): brain.pt(공유 가중치·재개), brain_progress.jsonl(사이클별 숙련).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
for p in (str(HERE), str(HERE.parent), str(ROOT / "scripts")):
    if p not in sys.path:
        sys.path.insert(0, p)

import train as T          # noqa: E402  — 헬퍼 무수정 재사용
from mdp import StageMDP   # noqa: E402

CURRICULUM = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]   # 도구 도입 순서(1~8 도입, 9~10 통합)
OUT_DIR = ROOT / "data" / "solutions" / "found"
BRAIN_CKPT = OUT_DIR / "brain.pt"
BEST_CKPT = OUT_DIR / "brain_best.pt"   # 최고 숙련 뇌 별도 보존(붕괴에도 최선 가중치 유실 방지)
PROGRESS = OUT_DIR / "brain_progress.jsonl"
SOL_LOG = OUT_DIR / "brain_solutions.jsonl"   # 사이클별 새로 발견한 distinct 해 누적 기록


def _plan_key(plan: list) -> str:
    return hashlib.sha256(json.dumps(plan, sort_keys=True).encode("utf-8")).hexdigest()[:16]


def _record_solution(cycle: int, mdp, res: dict, plan: list) -> None:
    """뇌가 이 사이클에 새로(distinct) 찾은 해를 별도 로그에 append(진화하는 신경망이 매 재풀이마다
    다른 해를 낼 수 있음 — 새 해만 기록). brain.pt의 seen 해시셋으로 dedup."""
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "cycle": cycle,
           "stage_id": mdp.stage_id, "stage": mdp.stage_scene, "saved": int(res.get("saved") or 0),
           "hp": mdp.hp, "frame": res.get("frame"), "plan_key": _plan_key(plan), "actions": plan}
    with open(SOL_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def _train_stage(policy, opt, mdp, grid_t, pool, cfg, n_batches: int, ent_coef: float,
                 baseline: float = 0.0, grad_clip: float = 1.0,
                 jackpot_s: float = 0.0) -> tuple[float, float]:
    """공유 정책을 한 스테이지에 n_batches 만큼 REINFORCE 업데이트.

    보상 = mdp.reward(터미널 verdict) + mdp.shaped_bonus(trace 기반 goal-거리·retired shaping) —
    train.py의 --shaping trace 경로와 동일 조립(계상 1회). rollout plan에 "trace":true를 넣어 엔진이
    궤적을 반환하게 하고, trace 소실은 fail-closed(silent shaping 격하 차단, train.py R4-MED 계승).

    안정화(2026-07-05 전략): ① 보상 정규화 — 배치 advantage를 표준편차로 스케일해 스테이지 간
    보상 크기 차가 공유 gradient를 독점하지 못하게 + 분산 감소. ② gradient clipping — 파괴적
    업데이트(0 붕괴)를 방지. 반환 = (마지막 배치 평균보상, 갱신된 baseline)."""
    torch, nn = T._torch()
    B = cfg["batch"]
    dl = cfg["train_deadline"]
    mean_r = 0.0
    for _ in range(n_batches):
        samples = [T._sample_episode_r2(mdp, policy, grid_t, greedy=False) for _ in range(B)]
        plans = [{"stage": mdp.stage_scene, "deadline_frames": dl, "trace": True,
                  "actions": mdp.decode_plan(p)} for (p, _, _) in samples]
        results = pool.evaluate(plans)
        for r in results:
            if not T._trace_valid(r.get("trace")):
                raise RuntimeError("trace-shaped 롤아웃에 유효 trace 부재 — 엔진 trace 회귀(fail-closed)")
        # 잭팟(carryover): 이 스테이지를 오래 못 깬 만큼 누적된 미지급 클리어 보상을, 학습 롤아웃이
        # 실제로 클리어했을 때만 가산 → 오래 정체한(또는 퇴보한) 스테이지의 재클리어를 강하게 강화.
        rewards = [mdp.reward(res, len(p)) + mdp.shaped_bonus(res)
                   + (jackpot_s if (res.get("cleared") and int(res.get("saved") or 0) == mdp.hp) else 0.0)
                   for (p, _, _), res in zip(samples, results)]
        mean_r = sum(rewards) / len(rewards)
        baseline = cfg["baseline_decay"] * baseline + (1 - cfg["baseline_decay"]) * mean_r
        var = sum((r - mean_r) ** 2 for r in rewards) / len(rewards)
        std = var ** 0.5 + 1e-6                        # 보상 정규화 스케일
        loss = torch.tensor(0.0)
        for (_p, logp, ent), rew in zip(samples, rewards):
            adv = (rew - baseline) / std               # 표준화 advantage(스테이지 간 균형)
            loss = loss + (-adv) * logp - ent_coef * ent
        loss = loss / B
        opt.zero_grad()
        loss.backward()
        nn.utils.clip_grad_norm_(policy.parameters(), grad_clip)   # 안정화: 붕괴 방지
        opt.step()
    return mean_r, baseline


def _eval_stage(policy, mdp, grid_t, pool, cfg) -> tuple[bool, dict, list]:
    """greedy 평가 — 공유 정책이 이 스테이지를 지금 깨는가(saved==hp)."""
    partial, _, _ = T._sample_episode_r2(mdp, policy, grid_t, greedy=True)
    plan = mdp.decode_plan(partial)
    res = pool.envs[0].step({"stage": mdp.stage_scene,
                             "deadline_frames": cfg["replay_deadline"], "actions": plan})
    cleared = bool(res.get("cleared")) and int(res.get("saved") or 0) == mdp.hp
    return cleared, res, plan


def _bar(mastered: set) -> str:
    return " ".join((f"[{s}]" if s in mastered else f" {s} ") for s in CURRICULUM)


def _load_brain(policy, opt, torch):
    if not BRAIN_CKPT.exists():
        return 0, set(), {}, 0, {}
    ck = torch.load(BRAIN_CKPT, weights_only=False)
    policy.load_state_dict(ck["policy"])
    opt.load_state_dict(ck["optimizer"])
    seen = {int(s): set(h) for s, h in (ck.get("seen") or {}).items()}
    jackpot = {int(s): float(v) for s, v in (ck.get("jackpot") or {}).items()}
    return ck.get("cycle", 0), set(ck.get("mastered", [])), seen, ck.get("best_mastered", 0), jackpot


def _save_brain(policy, opt, cycle, mastered, seen, best_mastered, jackpot, path=BRAIN_CKPT):
    tmp = path.with_suffix(".pt.tmp")
    import torch
    torch.save({"policy": policy.state_dict(), "optimizer": opt.state_dict(),
                "cycle": cycle, "mastered": sorted(mastered),
                "seen": {str(s): sorted(h) for s, h in seen.items()},
                "best_mastered": best_mastered,
                "jackpot": {str(s): round(v, 3) for s, v in jackpot.items()}}, tmp)
    os.replace(tmp, path)


def main() -> int:
    ap = argparse.ArgumentParser(description="공유 뇌 커리큘럼 트레이너(1~10)")
    ap.add_argument("--cycles", type=int, default=5, help="이번 실행에서 돌릴 사이클 수")
    ap.add_argument("--envs", type=int, default=4)
    ap.add_argument("--batches-per-stage", type=int, default=4,
                    help="스테이지당 배치 수/사이클(균등 — 예산 뺏기 없음, 깬 것도 유지 학습으로 망각 방지)")
    ap.add_argument("--jackpot-inc", type=float, default=2.0,
                    help="못 깬 스테이지가 사이클마다 누적하는 미지급 클리어 보상(=REWARD.cleared 스케일)")
    ap.add_argument("--jackpot-cap", type=float, default=20.0, help="잭팟 누적 상한")
    ap.add_argument("--lr", type=float, default=1e-3, help="학습률(안정화 위해 기본 하향)")
    ap.add_argument("--grad-clip", type=float, default=1.0, help="gradient clipping max-norm(안정화)")
    ap.add_argument("--reset", action="store_true", help="brain.pt 무시하고 처음부터")
    ap.add_argument("--show", action="store_true", help="현재 숙련 곡선만 출력하고 종료")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.show:
        if PROGRESS.exists():
            for ln in PROGRESS.read_text(encoding="utf-8").splitlines():
                d = json.loads(ln)
                m = {s for s in CURRICULUM if d.get(f"s{s}")}
                print(f"cycle {d['cycle']:>3}  숙련 {d['mastered']:>2}/10  {_bar(m)}")
        else:
            print("아직 진행 기록 없음(brain_progress.jsonl 부재)")
        return 0

    torch, _ = T._torch()
    cfg = dict(T.DEFAULTS)
    print(f"[brain] MDP/그리드 로드(1~10)…")
    mdps = {s: StageMDP(s, grammar=T.GRAMMAR_R2) for s in CURRICULUM}
    grids = {s: T._grid_tensor(mdps[s]) for s in CURRICULUM}

    # .godot 없으면 헤드리스 실패 예방
    if not (ROOT / ".godot").is_dir():
        print("[brain] .godot 없음 → 재임포트")
        from run_test import find_godot
        import subprocess
        subprocess.run([str(find_godot()), "--headless", "--import", "--path", str(ROOT)], cwd=str(ROOT))

    pool, n_eff, _ = T.build_pool(args.envs, mdps[1].stage_scene, with_trace=True)
    print(f"[brain] EnvPool envs_effective={n_eff}")
    baselines = {s: 0.0 for s in CURRICULUM}   # 스테이지별 REINFORCE baseline(사이클 간 지속)

    policy = T.make_policy_r2(mdps[1], cfg)
    opt = torch.optim.Adam(policy.parameters(), lr=args.lr)
    if args.reset:
        for p in (BRAIN_CKPT, BEST_CKPT):
            if p.exists():
                p.unlink()
    start_cycle, mastered, seen, best_mastered, jackpot = _load_brain(policy, opt, torch)
    for g in opt.param_groups:       # 로드된 optimizer state의 옛 lr을 새 --lr로 강제(안정화 적용)
        g["lr"] = args.lr
    jackpot = {s: jackpot.get(s, 0.0) for s in CURRICULUM}
    print(f"[brain] 시작 cycle={start_cycle} mastered={sorted(mastered)} best={best_mastered} "
          f"발견해 {sum(len(v) for v in seen.values())}종 lr={args.lr} clip={args.grad_clip} "
          f"{'(신규 뇌)' if start_cycle == 0 else '(이어받기)'}")

    ent_coef = max(cfg["entropy_min"], cfg["entropy"] * (cfg["entropy_decay"] ** start_cycle))
    t0 = time.monotonic()
    for c in range(start_cycle, start_cycle + args.cycles):
        # 균등 배분(예산 뺏기 없음) — 매 사이클 1~10 전체를 batches_per_stage씩 학습한다(이미 깬
        # 스테이지도 유지 학습으로 망각·퇴보 방지 → prev-cycle 기준 starvation 결함 해소). 하드
        # 스테이지 초점은 예산이 아니라 잭팟 보상이 담당(사용자 전략): 오래 못 깬 스테이지일수록
        # jackpot[s]가 커져 그 스테이지를 클리어하는 롤아웃에 큰 보상이 실린다.
        for s in CURRICULUM:
            _, baselines[s] = _train_stage(policy, opt, mdps[s], grids[s], pool, cfg,
                                          args.batches_per_stage, ent_coef, baselines[s],
                                          args.grad_clip, jackpot[s])

        # 전 스테이지 greedy 재평가 → 현행 숙련 집합 + **새로(distinct) 발견한 해**만 별도 기록
        row = {"cycle": c, "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        now_mastered = set()
        new_sols = 0
        for s in CURRICULUM:
            cleared, res, plan = _eval_stage(policy, mdps[s], grids[s], pool, cfg)
            row[f"s{s}"] = 1 if cleared else 0
            if cleared:
                now_mastered.add(s)
                bucket = seen.setdefault(s, set())
                k = _plan_key(plan)
                if k not in bucket:                    # 진화한 뇌가 낸 새 해만 기록(dedup)
                    bucket.add(k)
                    _record_solution(c, mdps[s], res, plan)
                    new_sols += 1
        mastered = now_mastered

        # 잭팟 갱신: 클리어=지급 후 리셋(0), 미클리어=미지급 클리어 보상을 다음 사이클로 이월 누적
        # (상한 cap). 예산을 뺏지 않으므로 퇴보한 스테이지도 다음 사이클 정상 배치 + 커진 잭팟으로 회복.
        for s in CURRICULUM:
            jackpot[s] = 0.0 if s in mastered else min(args.jackpot_cap, jackpot[s] + args.jackpot_inc)

        row["mastered"] = len(mastered)
        row["new_solutions"] = new_sols
        row["total_solutions"] = sum(len(v) for v in seen.values())
        row["jackpot_max"] = round(max(jackpot.values()), 1)

        is_best = len(mastered) > best_mastered      # best 뇌 별도 보존(붕괴에도 최선 유실 방지)
        if is_best:
            best_mastered = len(mastered)
        row["best_mastered"] = best_mastered
        _save_brain(policy, opt, c + 1, mastered, seen, best_mastered, jackpot)
        if is_best:
            _save_brain(policy, opt, c + 1, mastered, seen, best_mastered, jackpot, path=BEST_CKPT)
        with open(PROGRESS, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        dt = time.monotonic() - t0
        print(f"cycle {c:>3}  숙련 {len(mastered):>2}/10 (best {best_mastered}) 새해+{new_sols} "
              f"잭팟max={row['jackpot_max']}  {_bar(mastered)}  ({dt:.0f}s)")
        ent_coef = max(cfg["entropy_min"], ent_coef * cfg["entropy_decay"])

    pool.close()
    print(f"[brain] 완료. 누적 상태 → {T._rel(BRAIN_CKPT)} / 곡선 → {T._rel(PROGRESS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
