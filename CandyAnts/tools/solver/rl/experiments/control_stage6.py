"""대조군 — stage 6, 정상 보상(solving). perturb_stage6.py와 동일 셋업, 보상만 정상.
같은 초기 아키텍처가 보상에 따라 정반대 행동을 학습함을 보이기 위함.
정상 보상 = mdp.reward + mdp.shaped_bonus. saved(풀이)·deep_left(왼쪽굴착) 동시 측정.
"""
import sys
sys.path.insert(0, "tools/solver/rl"); sys.path.insert(0, "tools/solver"); sys.path.insert(0, "scripts")
import train as T
from mdp import StageMDP

STAGE = 6
LEFT_X = 9
torch, nn = T._torch()
cfg = dict(T.DEFAULTS)
mdp = StageMDP(STAGE, grammar=T.GRAMMAR_R2)
grid_t = T._grid_tensor(mdp)
pool, n_eff, _ = T.build_pool(6, mdp.stage_scene, with_trace=True)
print(f"[control6] hp={mdp.hp} inv={mdp.inventory} candy={mdp.layout['candy']} envs={n_eff}")
print("[control6] 정상 보상(solving). perturb와 동일 셋업.")


def _deep_left(trace) -> int:
    best = 0
    for _si, samples in (trace or {}).items():
        for s in samples:
            if int(s[1]) <= LEFT_X:
                best = max(best, int(s[2]))
    return best


def normal_reward(res, plen) -> float:
    return mdp.reward(res, plen) + mdp.shaped_bonus(res)


def greedy_check():
    partial, _, _ = T._sample_episode_r2(mdp, policy, grid_t, greedy=True)
    plan = mdp.decode_plan(partial)
    res = pool.envs[0].step({"stage": mdp.stage_scene, "deadline_frames": cfg["replay_deadline"],
                             "trace": True, "actions": plan})
    return (int(res.get("saved") or 0), int(res.get("picked_total") or 0),
            _deep_left(res.get("trace")), len(plan))


policy = T.make_policy_r2(mdp, cfg)
opt = torch.optim.Adam(policy.parameters(), lr=2e-3)
Bn = cfg["batch"]; dl = cfg["train_deadline"]
baseline = 0.0
ent = 0.08
print("batch | meanR(normal) | greedy: saved(solving) picked deep_left")
for bi in range(1, 121):
    samples = [T._sample_episode_r2(mdp, policy, grid_t, greedy=False) for _ in range(Bn)]
    plans = [{"stage": mdp.stage_scene, "deadline_frames": dl, "trace": True,
              "actions": mdp.decode_plan(p)} for (p, _, _) in samples]
    results = pool.evaluate(plans)
    rewards = [normal_reward(r, len(p)) for (p, _, _), r in zip(samples, results)]
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
        saved, picked, dl_row, plen = greedy_check()
        print(f"  {bi:3d} | {mean_r:.3f}     | saved={saved}/{mdp.hp} picked={picked} deep_left={dl_row} plan={plen}")

saved, picked, dl_row, plen = greedy_check()
print(f"\n[result] greedy: saved(solving)={saved}/{mdp.hp} picked={picked} deep_left_row={dl_row}")
print("verdict:", "SOLVING (normal reward -> pursues candy home)" if saved >= mdp.hp
      else f"partial solving (saved {saved}, picked {picked}) - solving 방향 학습 중")
pool.close()
