"""보상 교란(counterfactual) 실험 — stage 6.

가설: 에이전트가 보상을 능동적으로 쫓는가 vs 그냥 성공해서 지급됐나.
정상 보상(saved/cleared) 전부 제거. 교란 보상 = **왼쪽(x<=9)을 깊게 파서 개미를 아래로 보내면 보상**.
candy는 (18,12) 깊은-오른쪽이라, 왼쪽-깊이는 자연 도달 불가(digger 능동 사용 필요) + solving과 반대 방향.
-> greedy가 왼쪽을 파서 개미를 깊이 내려보내고 saved=0이면 = 보상을 쫓음 확증.
"""
import sys
sys.path.insert(0, "tools/solver/rl"); sys.path.insert(0, "tools/solver"); sys.path.insert(0, "scripts")
import train as T
from mdp import StageMDP

STAGE = 6
LEFT_X = 9          # 이 x 이하 = candy 반대편(왼쪽)
NATURAL_FLOOR = 8   # 스킬 없이 개미가 닿는 최하단 row
torch, nn = T._torch()
cfg = dict(T.DEFAULTS)
mdp = StageMDP(STAGE, grammar=T.GRAMMAR_R2)
grid_t = T._grid_tensor(mdp)
pool, n_eff, _ = T.build_pool(6, mdp.stage_scene, with_trace=True)
H = mdp.H
print(f"[perturb6] hp={mdp.hp} inv={mdp.inventory} candy={mdp.layout['candy']} H={H} envs={n_eff}")
print(f"[perturb6] 교란 목표 = 왼쪽(x<={LEFT_X}) 깊이 파기(row>{NATURAL_FLOOR}), solving 보상 0")


def _deep_left(trace) -> int:
    """왼쪽(x<=LEFT_X)에서 개미가 도달한 가장 깊은 row(클수록 깊음). 없으면 0."""
    best = 0
    for _si, samples in (trace or {}).items():
        for s in samples:
            if int(s[1]) <= LEFT_X:
                best = max(best, int(s[2]))
    return best


def perturbed_reward(res) -> float:
    d = _deep_left(res.get("trace"))
    r = max(0, d - NATURAL_FLOOR) / max(1, H - NATURAL_FLOOR)   # 자연 바닥보다 깊을수록 up
    if d >= 11:
        r += 2.0                                                # 확실히 깊게 판 보너스
    return r


def greedy_check():
    partial, _, _ = T._sample_episode_r2(mdp, policy, grid_t, greedy=True)
    plan = mdp.decode_plan(partial)
    res = pool.envs[0].step({"stage": mdp.stage_scene, "deadline_frames": cfg["replay_deadline"],
                             "trace": True, "actions": plan})
    return _deep_left(res.get("trace")), int(res.get("saved") or 0), len(plan)


policy = T.make_policy_r2(mdp, cfg)
opt = torch.optim.Adam(policy.parameters(), lr=2e-3)
Bn = cfg["batch"]; dl = cfg["train_deadline"]
baseline = 0.0
ent = 0.08
print("batch | meanR(perturbed) | greedy: deep_left(row) saved(solving)")
for bi in range(1, 121):
    samples = [T._sample_episode_r2(mdp, policy, grid_t, greedy=False) for _ in range(Bn)]
    plans = [{"stage": mdp.stage_scene, "deadline_frames": dl, "trace": True,
              "actions": mdp.decode_plan(p)} for (p, _, _) in samples]
    results = pool.evaluate(plans)
    rewards = [perturbed_reward(r) for r in results]
    mean_r = sum(rewards) / len(rewards)
    baseline = 0.9 * baseline + 0.1 * mean_r
    var = sum((x - mean_r) ** 2 for x in rewards) / len(rewards)
    std = var ** 0.5 + 1e-6
    loss = torch.tensor(0.0)
    for (_p, logp, entp), rew in zip(samples, rewards):
        loss = loss + (-((rew - baseline) / std)) * logp - ent * entp
    loss = loss / Bn
    opt.zero_grad(); loss.backward()
    nn.utils.clip_grad_norm_(policy.parameters(), 1.0)
    opt.step()
    ent = max(0.05, ent * 0.99)
    if bi % 10 == 0:
        dl_row, saved, plen = greedy_check()
        print(f"  {bi:3d} | {mean_r:.3f}      | deep_left_row={dl_row} saved={saved}/{mdp.hp} plan={plen}")

dl_row, saved, plen = greedy_check()
print(f"\n[result] greedy: deep_left_row={dl_row} (>{NATURAL_FLOOR}=능동 굴착) / saved(solving)={saved}/{mdp.hp}")
verdict = ("REWARD-SEEKING confirmed (digs left-deep, abandons solving)" if dl_row >= 11 and saved < mdp.hp
           else "solving instead (NOT reward-following)" if saved >= mdp.hp
           else "ambiguous/underlearned")
print("verdict:", verdict)
pool.close()
