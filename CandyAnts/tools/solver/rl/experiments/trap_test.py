"""함정-도구 fixture 실험(워크로그 §14.4 ④) — "불사용이 정답" 스테이지에서 보상 설계 검증.

fixture = dev_stages/trap_blocker: 평평한 복도+양끝 벽, blocker×2 지급되나 **불필요**.
엔진 실측(2026-07-10): 무발화 plan(사실상 불사용) CLEAR 4/4 @1189f / 복도 한복판 blocker FAIL(픽업 0, timeout).
즉 blocker 발화-유효 사용은 해롭고, 무발화 트리거·무해 배치가 정답 경로.

가설(§14.1): BASELINE(blocker-coef만)은 한복판 배치에도 redirect_value(진척 후 반전)가 양수라
함정 사용이 dense 보상을 받아 유혹됨 → 학습 지연/실패. KNOWLEDGE(+지식-축적)는 불사용 중립 +
미개선 반복 누진 페널티로 함정 고착을 깎음 → 더 빠른/안정적 클리어.

실행: python tools/solver/rl/experiments/trap_test.py [--seeds 0,1] [--cap 40]
"""
import argparse
import sys
import time

sys.path.insert(0, "tools/solver/rl")
sys.path.insert(0, "tools/solver")
sys.path.insert(0, "scripts")
import train as T          # noqa: E402
from mdp import StageMDP   # noqa: E402

SCENE = "res://dev_stages/trap_blocker/TrapBlockerTest.tscn"
STAGE_TRES = "dev_stages/trap_blocker/trap_blocker_test.tres"
LAYOUT_TRES = "dev_stages/trap_blocker/dev_trap_blocker_layout.tres"


def mk_cfg(cap: int, blocker: float, knowledge: float) -> dict:
    cfg = dict(T.DEFAULTS)
    cfg.update(shaping="trace", train_deadline=3000, sil=True,
               max_batches=cap, max_episodes=10 ** 9, max_wall=10 ** 12,
               blocker_coef=blocker, knowledge_coef=knowledge)
    return cfg


def main() -> int:
    ap = argparse.ArgumentParser(description="함정-도구 보상 검증(§14.4 ④)")
    ap.add_argument("--seeds", type=str, default="0,1", help="콤마 목록")
    ap.add_argument("--cap", type=int, default=40, help="batch 상한(=DNF 컷)")
    ap.add_argument("--envs", type=int, default=4)
    args = ap.parse_args()
    seeds = [int(x) for x in args.seeds.split(",")]

    mdp = StageMDP(990, grammar=T.GRAMMAR_R2,
                   scene=SCENE, stage_tres=STAGE_TRES, layout_tres=LAYOUT_TRES)
    pool, n_eff, _ = T.build_pool(args.envs, SCENE, with_trace=True)
    print(f"[trap] envs={n_eff} cap={args.cap} seeds={seeds} inv={mdp.inventory} hp={mdp.hp}")
    t0 = time.monotonic()
    arms = [("BASELINE  blocker=1.0 knowledge=0  ", 1.0, 0.0),
            ("KNOWLEDGE blocker=1.0 knowledge=1.0", 1.0, 1.0)]
    try:
        for name, b, k in arms:
            print(f"\n=== ARM {name} ===")
            for s in seeds:
                res, _ = T.train_seed(mdp, pool, s, mk_cfg(args.cap, b, k))
                tag = (f"CLEAR @ batch {res['batches']} ({res['episodes']} eps)" if res["cleared"]
                       else f"DNF (cap {res['batches']}, bestR {res['best_reward']:.3f}, "
                            f"best={res.get('best_episode')})")
                print(f"  seed {s}: {tag}")
    finally:
        pool.close()
    print(f"\n[trap] 완료 ({time.monotonic() - t0:.0f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
