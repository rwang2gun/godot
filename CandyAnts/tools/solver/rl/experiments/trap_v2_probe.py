"""함정 v2 fixture 엔진 프로브 (워크로그 §15) — "학습이 필요한 함정"의 함정성 손플랜 검증.

v1(trap_blocker)의 정직한 한계(§14.4 ④): 전 arm batch 5 즉시 클리어 → blocker-coef 유혹 가설 비변별.
v2(trap_blocker_v2) 설계: 위층 복도 → 낙하 → 낙하층 우측 물 익사가 무개입 기본 경로(FAIL).
정답 = 낙하층 col 12~13에 blocker 1개(지급 2개 중 1개만 사용 — 잉여분이 함정 도구).
유혹 = 복도 blocker: 개미들이 candy 상공을 왕복(blocker_redirect_value 양수 dense credit)하나
낙하 진입 차단 = 터미널 0. 잉여 = 정답 배치 후 2개째 발화 = 해 파괴.

프로브가 확인하는 함정성 3속성:
  ① noop FAIL(무개입은 전멸) — v1과 달리 클리어에 개입이 필요(학습 창 확보)
  ② correct CLEAR + honey/surplus FAIL — 정답/함정 분리
  ③ honey의 blocker_bonus > 0 — 유혹이 실제 dense 신호를 받음(가설의 전제)

실행: python tools/solver/rl/experiments/trap_v2_probe.py
"""
import sys
import time

sys.path.insert(0, "tools/solver/rl")
sys.path.insert(0, "tools/solver")
sys.path.insert(0, "scripts")
import train as T           # noqa: E402
from mdp import StageMDP    # noqa: E402
import model as M           # noqa: E402

SCENE = "res://dev_stages/trap_blocker_v2/TrapBlockerV2Test.tscn"
STAGE_TRES = "dev_stages/trap_blocker_v2/trap_blocker_v2_test.tres"
LAYOUT_TRES = "dev_stages/trap_blocker_v2/dev_trap_blocker_v2_layout.tres"
DEADLINE = 4500


def act(y0: float, y1: float, x: float, cmp: str = "ge", select: str = "max_x") -> dict:
    return {"skill": "blocker",
            "target": {"mode": "ant", "select": select, "y_min": float(y0), "y_max": float(y1)},
            "trigger": {"type": "ant_reaches_x", "cmp": cmp, "x": float(x)}}


# y-밴드: 복도 body row 6 ≈ y 331 / 중간선반 body row 10 ≈ y 523 / 바닥층 body row 14 ≈ y 715.
PLANS = {
    "noop     (무개입 — 중간선반 우측 물 전멸 기대)": [],
    "partial  (#1만 — 하강하나 바닥 좌측 물 전멸 기대)": [act(480, 528, 576)],
    "correct  (#1 선반 x>=576 + #2 바닥 x<=216)": [act(480, 528, 576),
                                                    act(672, 720, 216, cmp="le", select="min_x")],
    "honey    (복도 x>=384 셔틀 — 하강 전면 차단)": [act(288, 336, 384)],
}


def main() -> int:
    mdp = StageMDP(991, grammar=T.GRAMMAR_R2,
                   scene=SCENE, stage_tres=STAGE_TRES, layout_tres=LAYOUT_TRES)
    print(f"[probe] inv={mdp.inventory} hp={mdp.hp} ants={mdp.ants_total} D0={mdp.D0}")
    pool, _, _ = T.build_pool(1, SCENE, with_trace=True)
    t0 = time.monotonic()
    try:
        for name, actions in PLANS.items():
            plan = {"stage": SCENE, "deadline_frames": DEADLINE, "trace": True,
                    "report_fired": True, "actions": actions}
            r1, r2 = pool.evaluate([plan, plan])
            det = "det=OK" if T._digest(r1) == T._digest(r2) else "det=**MISMATCH**"
            cells = mdp.blocker_cells_from_res(r1)
            tr = r1.get("trace") or {}
            redirect = M.blocker_redirect_value(tr, mdp.layout, cells) if cells else 0.0
            bonus = mdp.blocker_bonus(r1, 1.0)
            retired = M.count_retired(tr, mdp.layout) if tr else {"water": 0, "fall": 0, "total": 0}
            verdict = ("CLEAR" if r1.get("cleared")
                       else f"FAIL({r1.get('reason')})")
            print(f"  {name}: {verdict} saved={r1.get('saved')} picked={r1.get('picked_total')} "
                  f"frame={r1.get('frame')} retired={retired} cells={sorted(cells)} "
                  f"redirect={redirect:.1f} bonus={bonus:.4f} {det}")
    finally:
        pool.close()
    print(f"[probe] done ({time.monotonic() - t0:.0f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
