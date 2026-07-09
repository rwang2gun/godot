"""지식-축적 보상(§14.3 v3) 격리검증 — KnowledgeLedger 순수 로직 probe (엔진 불요).

사용자 규칙 검증 항목:
  P1 신규 토큰(필드 값) 첫 사용 = +  (시행착오여도 지식이면 보상)
  P2 첫 시행착오(미클리어·프런티어 미갱신) = 페널티 0 (사용 주저 방지)
  P3 같은 시행착오 반복 = 누진 페널티 (횟수↑ → 페널티↑, cap 클립)
  P4 프런티어 개선(빈손→candy 또는 운반→home) = 페널티 면제
  P5 클리어 = 페널티 면제 (성공 반복 보호 — SIL/수렴 파괴 방지)
  P6 불사용 = 어떤 항에도 미등장(중립) — plan에 없는 스킬은 원장에 흔적 없음
  P7 SIL 사용-시점 재평가(repeat_term) = 관측 전용(원장 미갱신)
  P8 ckpt 왕복(to_dict → 재구성) = 상태 보존

실행: python tools/solver/rl/experiments/knowledge_probe.py
"""
import sys

sys.path.insert(0, "tools/solver/rl")
sys.path.insert(0, "tools/solver")
sys.path.insert(0, "scripts")
from train import KnowledgeLedger, KNOWLEDGE  # noqa: E402

LAYOUT = {"candy": (10, 5), "home": (0, 5), "hazard": set()}   # _goal_cell 계약 = 단일 셀 튜플


def mk_trace(cells):
    """개미 1마리 trace — cells = [(frame, cx, cy, carry), ...]."""
    return {"0": [list(c) for c in cells]}


def res(cleared=False, trace=None):
    return {"cleared": cleared, "trace": trace or {}}


PLAN_A = [{"skill": 3, "trigger": 1, "param": 7, "select": 0, "state": 2}]
PLAN_B = [{"skill": 3, "trigger": 2, "param": 7, "select": 0, "state": 2}]  # trigger만 상이

FAILS = []


def check(name, cond, note=""):
    tag = "PASS" if cond else "FAIL"
    print(f"  [{tag}] {name}{' — ' + note if note else ''}")
    if not cond:
        FAILS.append(name)


def main():
    led = KnowledgeLedger(1.0)

    # P1+P2: 첫 에피소드(plan A, walker가 candy 근처 d=3까지) — 신규 토큰 5개 보상, 페널티 0
    t1 = mk_trace([(0, 0, 5, 0), (100, 7, 5, 0)])          # d: 10 → 3 (프런티어 갱신)
    b1 = led.observe(PLAN_A, res(trace=t1), LAYOUT)
    check("P1 신규 토큰 보상", abs(b1 - 5 * KNOWLEDGE["new_token"]) < 1e-9, f"b={b1:.3f} (5필드×{KNOWLEDGE['new_token']})")

    # 같은 plan, 프런티어 정체(d=3 재현, 갱신 없음) → 첫 시행착오: 페널티 0
    b2 = led.observe(PLAN_A, res(trace=t1), LAYOUT)
    check("P2 첫 시행착오 페널티 0", abs(b2) < 1e-9, f"b={b2:.3f}")

    # P3: 반복 → 누진
    b3 = led.observe(PLAN_A, res(trace=t1), LAYOUT)
    b4 = led.observe(PLAN_A, res(trace=t1), LAYOUT)
    check("P3 누진 페널티", b3 < 0 and b4 < b3,
          f"2회차 {b3:.3f} → 3회차 {b4:.3f}")
    # cap 클립
    for _ in range(KNOWLEDGE["repeat_cap"] + 20):
        last = led.observe(PLAN_A, res(trace=t1), LAYOUT)
    cap_val = -KNOWLEDGE["repeat"] * KNOWLEDGE["repeat_cap"]
    check("P3 cap 클립", abs(last - cap_val) < 1e-9, f"{last:.3f} == {cap_val:.3f}")

    # P4: 같은 plan이라도 프런티어 개선(운반 개미가 home d=2 도달) → 면제 + 카운트 미증가
    n_before = led.plan_fail_n["".join([])] if False else dict(led.plan_fail_n)
    t2 = mk_trace([(0, 10, 5, 1), (100, 2, 5, 1)])         # carry: home 8 → 2 (첫 carry 프런티어)
    b5 = led.observe(PLAN_A, res(trace=t2), LAYOUT)
    check("P4 프런티어 개선 면제", b5 >= 0.0, f"b={b5:.3f}")
    check("P4 면제 시 반복 카운트 미증가",
          led.plan_fail_n == n_before, "plan_fail_n 불변")

    # P5: 클리어 반복 → 면제 (프런티어 정체여도)
    b6 = led.observe(PLAN_A, res(cleared=True, trace=t1), LAYOUT)
    b7 = led.observe(PLAN_A, res(cleared=True, trace=t1), LAYOUT)
    check("P5 클리어 반복 면제", b6 >= 0.0 and b7 >= 0.0, f"b={b6:.3f}, {b7:.3f}")

    # P6: 불사용 중립 — plan B(신규 trigger 토큰 1개)에 blocker 미포함 여부와 무관, 원장은 plan에
    # 등장한 것만 기록(미사용 인벤 항 자체가 없음 — 구조 검증: 필드 키만 존재)
    b8 = led.observe(PLAN_B, res(trace=t1), LAYOUT)
    check("P6 신규 필드 값만 가산(나머지 기지)", abs(b8 - KNOWLEDGE["new_token"]) < 1e-9,
          f"b={b8:.3f} (trigger=2 하나만 신규)")

    # P7: repeat_term 관측 전용
    import json
    sig = json.dumps(PLAN_A, sort_keys=True)
    n0 = led.plan_fail_n.get(sig, 0)
    _ = led.repeat_term(sig)
    check("P7 repeat_term 미갱신", led.plan_fail_n.get(sig, 0) == n0)

    # P8: ckpt 왕복
    led2 = KnowledgeLedger(1.0, led.to_dict())
    check("P8 ckpt 왕복 보존",
          led2.token_seen == led.token_seen and led2.plan_fail_n == led.plan_fail_n
          and led2.best_w == led.best_w and led2.best_c == led.best_c)

    print(f"\n=== {'PASS' if not FAILS else 'FAIL'} ({8 - 0 if not FAILS else len(FAILS)} 항목"
          f"{'' if not FAILS else ' 실패: ' + ', '.join(FAILS)}) ===")
    return 0 if not FAILS else 1


if __name__ == "__main__":
    raise SystemExit(main())
