"""현재 brain.pt로 각 스테이지 greedy 평가 → picked/saved/hp 부분 진전 실측."""
import sys
sys.path.insert(0, "tools/solver/rl"); sys.path.insert(0, "tools/solver"); sys.path.insert(0, "scripts")
import train as T
import brain as B
from mdp import StageMDP

torch, _ = T._torch()
cfg = dict(T.DEFAULTS)
mdps = {s: StageMDP(s, grammar=T.GRAMMAR_R2) for s in B.CURRICULUM}
grids = {s: T._grid_tensor(mdps[s]) for s in B.CURRICULUM}
pool, n, _ = T.build_pool(6, mdps[1].stage_scene, with_trace=True)
policy = T.make_policy_r2(mdps[1], cfg)
opt = torch.optim.Adam(policy.parameters(), lr=cfg["lr"])
c, mastered, seen, best, jp = B._load_brain(policy, opt, torch)
print(f"brain cycle={c} mastered={sorted(mastered)}")
print("stage | hp | picked | saved | cleared | 진단")
print("------+----+--------+-------+---------+------")
for s in B.CURRICULUM:
    m = mdps[s]
    cleared, res, plan = B._eval_stage(policy, m, grids[s], pool, cfg)
    picked = int(res.get("picked_total") or 0)
    saved = int(res.get("saved") or 0)
    if saved == m.hp:
        diag = "완전클리어"
    elif saved > 0:
        diag = "복귀 일부(2차 병목)"
    elif picked > 0:
        diag = "집기만(복귀 0 — 2차 병목)"
    else:
        diag = "집지도 못함(1차/탐험 병목)"
    print(f"  {s:2d}  | {m.hp:2d} |  {picked:3d}   |  {saved:3d}  | {str(cleared):5s}   | {diag}")
pool.close()
