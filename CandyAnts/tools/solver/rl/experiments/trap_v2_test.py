"""함정 v2 학습 A/B (워크로그 §15) — "학습이 필요한 함정"에서 보상 설계 3-arm 변별.

fixture = dev_stages/trap_blocker_v2 (함정성 손플랜 검증 = trap_v2_probe.py):
  무개입 = 전멸 FAIL(no_more_ants, water 5/5) → 클리어에 개입 필요(학습 창 확보 — v1 비변별 해소).
  정답 = 낙하층 blocker 1개(x>=576권, 지급 2 중 1 사용) → CLEAR 4/4 @1340f, bonus 0.15.
  유혹(honey) = 복도 blocker → 셔틀 FAIL(deadline)인데 bonus 0.075 양수(§14.1 유혹 기울기 실재).

3-arm이 가르는 질문:
  ① BASELINE vs NOBONUS: blocker-coef dense 신호가 이 함정 지형에서 순이득인가 순해인가(§14.1 유혹 가설).
  ② KNOWLEDGE vs BASELINE: 지식-축적(미개선 반복 누진 페널티)이 honey 고착을 깎아 학습을 가속하는가
     (= knowledge 상시화(레시피 편입) 판단 근거).

실행: python tools/solver/rl/experiments/trap_v2_test.py [--seeds 0,1,2] [--cap 120]
"""
import argparse
import sys
import time

sys.path.insert(0, "tools/solver/rl")
sys.path.insert(0, "tools/solver")
sys.path.insert(0, "scripts")
import train as T          # noqa: E402
from mdp import StageMDP   # noqa: E402

SCENE = "res://dev_stages/trap_blocker_v2/TrapBlockerV2Test.tscn"
STAGE_TRES = "dev_stages/trap_blocker_v2/trap_blocker_v2_test.tres"
LAYOUT_TRES = "dev_stages/trap_blocker_v2/dev_trap_blocker_v2_layout.tres"


def mk_cfg(cap: int, blocker: float, knowledge: float) -> dict:
    cfg = dict(T.DEFAULTS)
    cfg.update(shaping="trace", train_deadline=3000, sil=True,
               max_batches=cap, max_episodes=10 ** 9, max_wall=10 ** 12,
               blocker_coef=blocker, knowledge_coef=knowledge)
    return cfg


def main() -> int:
    ap = argparse.ArgumentParser(description="함정 v2 보상 3-arm(§15)")
    ap.add_argument("--seeds", type=str, default="0,1,2", help="콤마 목록")
    ap.add_argument("--cap", type=int, default=120, help="batch 상한(=DNF 컷)")
    ap.add_argument("--envs", type=int, default=4)
    args = ap.parse_args()
    seeds = [int(x) for x in args.seeds.split(",")]

    mdp = StageMDP(991, grammar=T.GRAMMAR_R2,
                   scene=SCENE, stage_tres=STAGE_TRES, layout_tres=LAYOUT_TRES)
    pool, n_eff, _ = T.build_pool(args.envs, SCENE, with_trace=True)
    print(f"[trap-v2] envs={n_eff} cap={args.cap} seeds={seeds} inv={mdp.inventory} hp={mdp.hp}")
    t0 = time.monotonic()
    arms = [("NOBONUS   blocker=0   knowledge=0  ", 0.0, 0.0),
            ("BASELINE  blocker=1.0 knowledge=0  ", 1.0, 0.0),
            ("KNOWLEDGE blocker=1.0 knowledge=1.0", 1.0, 1.0)]
    try:
        for name, b, k in arms:
            print(f"\n=== ARM {name} ===")
            for s in seeds:
                res, _ = T.train_seed(mdp, pool, s, mk_cfg(args.cap, b, k))
                tag = (f"CLEAR @ batch {res['batches']} ({res['episodes']} eps)" if res["cleared"]
                       else f"DNF (cap {res['batches']}, bestR {res['best_reward']:.3f}, "
                            f"best={res.get('best_episode')})")
                print(f"  seed {s}: {tag}", flush=True)
    finally:
        pool.close()
    print(f"\n[trap-v2] 완료 ({time.monotonic() - t0:.0f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
