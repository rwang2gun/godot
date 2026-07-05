#!/usr/bin/env python3
"""공유 뇌(shared-brain) 커리큘럼 트레이너 — 하나의 r2.1 정책을 여러 스테이지에 걸쳐
누적 학습한다. 반복 실행할수록 한 가중치 파일(found/brain.pt)에 경험이 쌓여 점점 강해지는
것을 목표로 한다(사용자 요건 B).

근거(검증됨): r2.1 PolicyR2는 스테이지-불변(AdaptiveMaxPool로 가변 그리드 흡수 + 전역 스킬
어휘 head + per-stage 마스킹). 1~10 전 스테이지에서 정책 shape(max_len=6, flat_dim=816,
heads) 동일 → 같은 가중치가 모든 스테이지에 로드된다.

학습 전략(사용자 설계): 게이트·순차 진행 없음. 매 사이클 1~10 전체를 순회하며 각 스테이지에
  시간을 조금씩만 쓴다(못 깬 스테이지=learn, 이미 깬 스테이지=가벼운 refresh로 망각 방지).
  한 스테이지를 오래 잡지 않고 다음으로 넘어가 새 학습을 누적 — 목표는 순차 클리어가 아니라
  수차례 반복하며 **총 클리어 수가 늘어나는 것**. 매 사이클 10개 greedy 재평가.
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
                 baseline: float = 0.0) -> tuple[float, float]:
    """공유 정책을 한 스테이지에 n_batches 만큼 REINFORCE 업데이트.

    보상 = mdp.reward(터미널 verdict) + mdp.shaped_bonus(trace 기반 goal-거리·retired shaping) —
    train.py의 --shaping trace 경로와 동일 조립(계상 1회). rollout plan에 "trace":true를 넣어 엔진이
    궤적을 반환하게 하고, trace 소실은 fail-closed(silent shaping 격하 차단, train.py R4-MED 계승).
    반환 = (마지막 배치 평균보상, 갱신된 baseline)."""
    torch, _ = T._torch()
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
        rewards = [mdp.reward(res, len(p)) + mdp.shaped_bonus(res)
                   for (p, _, _), res in zip(samples, results)]
        mean_r = sum(rewards) / len(rewards)
        baseline = cfg["baseline_decay"] * baseline + (1 - cfg["baseline_decay"]) * mean_r
        loss = torch.tensor(0.0)
        for (_p, logp, ent), rew in zip(samples, rewards):
            loss = loss + (-(rew - baseline)) * logp - ent_coef * ent
        loss = loss / B
        opt.zero_grad()
        loss.backward()
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
        return 0, set(), {}
    ck = torch.load(BRAIN_CKPT, weights_only=False)
    policy.load_state_dict(ck["policy"])
    opt.load_state_dict(ck["optimizer"])
    seen = {int(s): set(h) for s, h in (ck.get("seen") or {}).items()}
    return ck.get("cycle", 0), set(ck.get("mastered", [])), seen


def _save_brain(policy, opt, cycle, mastered, seen):
    tmp = BRAIN_CKPT.with_suffix(".pt.tmp")
    import torch
    torch.save({"policy": policy.state_dict(), "optimizer": opt.state_dict(),
                "cycle": cycle, "mastered": sorted(mastered),
                "seen": {str(s): sorted(h) for s, h in seen.items()}}, tmp)
    os.replace(tmp, BRAIN_CKPT)


def main() -> int:
    ap = argparse.ArgumentParser(description="공유 뇌 커리큘럼 트레이너(1~10)")
    ap.add_argument("--cycles", type=int, default=5, help="이번 실행에서 돌릴 사이클 수")
    ap.add_argument("--envs", type=int, default=4)
    ap.add_argument("--learn-batches", type=int, default=5,
                    help="아직 못 깬 스테이지의 배치 수/사이클(짧게 여러 번 — 한 스테이지 독점 방지)")
    ap.add_argument("--refresh-batches", type=int, default=2,
                    help="이미 깬 스테이지의 배치 수/사이클(망각 방지 refresh)")
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
    opt = torch.optim.Adam(policy.parameters(), lr=cfg["lr"])
    if args.reset and BRAIN_CKPT.exists():
        BRAIN_CKPT.unlink()
    start_cycle, mastered, seen = _load_brain(policy, opt, torch)
    print(f"[brain] 시작 cycle={start_cycle} mastered={sorted(mastered)} "
          f"발견해 {sum(len(v) for v in seen.values())}종 "
          f"{'(신규 뇌)' if start_cycle == 0 else '(이어받기)'}")

    ent_coef = max(cfg["entropy_min"], cfg["entropy"] * (cfg["entropy_decay"] ** start_cycle))
    t0 = time.monotonic()
    for c in range(start_cycle, start_cycle + args.cycles):
        # 게이트 없음 — 매 사이클 1~10 전체를 순회한다(순차 클리어 불요, 총 클리어 수 증가가 목표).
        # 한 스테이지에 오래 잡히지 않도록 못 깬 스테이지는 짧게 learn, 이미 깬 스테이지는 가벼운 refresh.
        for s in CURRICULUM:
            nb = args.refresh_batches if s in mastered else args.learn_batches
            if nb <= 0:
                continue
            _, baselines[s] = _train_stage(policy, opt, mdps[s], grids[s], pool, cfg,
                                          nb, ent_coef, baselines[s])

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
        row["mastered"] = len(mastered)
        row["new_solutions"] = new_sols
        row["total_solutions"] = sum(len(v) for v in seen.values())

        _save_brain(policy, opt, c + 1, mastered, seen)
        with open(PROGRESS, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        dt = time.monotonic() - t0
        print(f"cycle {c:>3}  숙련 {len(mastered):>2}/10  새해+{new_sols} "
              f"(누적 {row['total_solutions']}종)  {_bar(mastered)}  ({dt:.0f}s)")
        ent_coef = max(cfg["entropy_min"], ent_coef * cfg["entropy_decay"])

    pool.close()
    print(f"[brain] 완료. 누적 상태 → {T._rel(BRAIN_CKPT)} / 곡선 → {T._rel(PROGRESS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
