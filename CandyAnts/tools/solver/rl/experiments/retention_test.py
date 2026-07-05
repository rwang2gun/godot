"""Retention(비휘발) 실험.

stage 6 해결 네트워크를 로드 -> stage 5(climber 없는 다른 스테이지)를 학습(간섭) ->
stage 6이 여전히 풀리는지(보존) vs 까먹는지(휘발) 추적. 까먹으면 재학습 eps를 처음(1600)과 비교.
가설(사용자): 지식이 보존되면 재시도가 훨씬 빨라야 함. 처음부터 재학습 = 휘발.
"""
import sys
sys.path.insert(0, "tools/solver/rl"); sys.path.insert(0, "tools/solver"); sys.path.insert(0, "scripts")
import train as T
from mdp import StageMDP

torch, nn = T._torch()
cfg = dict(T.DEFAULTS)
mdp6 = StageMDP(6, grammar=T.GRAMMAR_R2); g6 = T._grid_tensor(mdp6)
mdp5 = StageMDP(5, grammar=T.GRAMMAR_R2); g5 = T._grid_tensor(mdp5)
pool, n_eff, _ = T.build_pool(6, mdp6.stage_scene, with_trace=True)


def greedy_saved(mdp, grid):
    partial, _, _ = T._sample_episode_r2(mdp, policy, grid, greedy=True)
    plan = mdp.decode_plan(partial)
    res = pool.envs[0].step({"stage": mdp.stage_scene, "deadline_frames": cfg["replay_deadline"],
                             "trace": True, "actions": plan})
    return int(res.get("saved") or 0)


def train_batch(mdp, grid, ent):
    global baseline
    Bn = cfg["batch"]
    samples = [T._sample_episode_r2(mdp, policy, grid, greedy=False) for _ in range(Bn)]
    plans = [{"stage": mdp.stage_scene, "deadline_frames": cfg["train_deadline"], "trace": True,
              "actions": mdp.decode_plan(p)} for (p, _, _) in samples]
    results = pool.evaluate(plans)
    rewards = [mdp.reward(r, len(p)) + mdp.shaped_bonus(r) for (p, _, _), r in zip(samples, results)]
    mr = sum(rewards) / len(rewards)
    baseline = 0.9 * baseline + 0.1 * mr
    var = sum((x - mr) ** 2 for x in rewards) / len(rewards)
    std = var ** 0.5 + 1e-6
    loss = torch.tensor(0.0)
    for (_p, logp, entp), rew in zip(samples, rewards):
        loss = loss + (-((rew - baseline) / std)) * logp - ent * entp
    opt.zero_grad(); (loss / Bn).backward()
    nn.utils.clip_grad_norm_(policy.parameters(), 1.0); opt.step()
    return mr


# 1) stage 6 해결 네트워크 로드
policy = T.make_policy_r2(mdp6, cfg)
ck = torch.load("data/solutions/rl_ckpt/stage06_seed1.r2.pt", weights_only=False)
policy.load_state_dict(ck["policy"])
opt = torch.optim.Adam(policy.parameters(), lr=2e-3)
baseline = 0.0
print(f"[retention] 로드 직후: stage6 saved={greedy_saved(mdp6, g6)}/{mdp6.hp} "
      f"stage5 saved={greedy_saved(mdp5, g5)}/{mdp5.hp}  (stage6=5면 해결상태 확인)")

# 2) stage 5 학습(간섭) — stage 6 보존 추적
print("\n--- stage 5 학습(간섭) 중 stage 6 보존 추적 ---")
print("batch | stage5 saved(학습중) | stage6 saved(보존?)")
ent = 0.06
for bi in range(1, 61):
    train_batch(mdp5, g5, ent)
    ent = max(0.05, ent * 0.99)
    if bi % 5 == 0:
        s5 = greedy_saved(mdp5, g5); s6 = greedy_saved(mdp6, g6)
        print(f"  {bi:3d} | {s5}/{mdp5.hp}              | {s6}/{mdp6.hp}  {'<== 휘발!' if s6 < mdp6.hp else '(보존)'}")

# 3) 간섭 후 stage 6 재학습 — 재발견 eps
s6_after = greedy_saved(mdp6, g6)
print(f"\n[간섭 후] stage6 saved={s6_after}/{mdp6.hp}")
if s6_after >= mdp6.hp:
    print("=> 보존됨: stage 5 학습에도 stage 6 유지. 재시도 0 eps.")
else:
    print("=> 휘발됨. stage 6 재학습 시작 → 재발견까지 몇 배치 걸리는지(처음=100배치/1600eps와 비교)")
    re_ent = 0.08
    resolved_at = None
    for bi in range(1, 101):
        train_batch(mdp6, g6, re_ent)
        re_ent = max(0.05, re_ent * 0.99)
        if bi % 5 == 0:
            s6 = greedy_saved(mdp6, g6)
            print(f"  재학습 batch {bi:3d} | stage6 saved={s6}/{mdp6.hp}")
            if s6 >= mdp6.hp:
                resolved_at = bi; break
    if resolved_at:
        print(f"\n[결과] 재발견 = {resolved_at}배치({resolved_at*16}eps) vs 처음 ~100배치(1600eps)")
        print("판정:", "빠른 재발견 = 부분 보존(전이)" if resolved_at < 60
              else "처음과 비슷 = 완전 휘발(재학습)")
    else:
        print("\n[결과] 100배치 내 재발견 실패 = 심각한 휘발(처음보다 나을 것도 없음)")
pool.close()
