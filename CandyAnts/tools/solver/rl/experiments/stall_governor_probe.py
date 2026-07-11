"""§16 정체-진단(StallGovernor) 격리 검증 — 순수 단위 8종 + 엔진 통합 3종 (§16.6 최종형).

단위(순수, Godot 불요): 격발/비격발 의미론·반복-지배(dup) 판별·격발 1회·개선 카운터 리셋·roundtrip.
통합(v2.1 fixture, 저예산): A. mode=always == 레거시(무 mode 키) curve 정확 일치(byte-identity)
B. stall 무격발(문턱 미달) == knowledge 없는 동일 레시피 curve 정확 일치(검출 런 보상 무개입,
   12배치 = batch%10 출력 경로 커버) C. 강제 격발 → 검출 중단 → always 재시작(escalate) + 회계.

실행: python tools/solver/rl/experiments/stall_governor_probe.py [--skip-godot]
"""
import argparse
import sys

sys.path.insert(0, "tools/solver/rl")
sys.path.insert(0, "tools/solver")
sys.path.insert(0, "scripts")
import train as T          # noqa: E402
from mdp import StageMDP   # noqa: E402

SCENE = "res://dev_stages/trap_blocker_v2/TrapBlockerV2Test.tscn"
STAGE_TRES = "dev_stages/trap_blocker_v2/trap_blocker_v2_test.tres"
LAYOUT_TRES = "dev_stages/trap_blocker_v2/dev_trap_blocker_v2_layout.tres"

PASS = FAIL = 0


def check(name: str, ok: bool, note: str = "") -> None:
    global PASS, FAIL
    PASS, FAIL = PASS + (1 if ok else 0), FAIL + (0 if ok else 1)
    print(f"  [{'PASS' if ok else 'FAIL'}] {name}{(' — ' + note) if note else ''}")


def unit_tests() -> None:
    print("[unit] StallGovernor 순수 의미론 (dup 격발 검출기 — §16.6 최종형)")
    G = T.StallGovernor
    # ① 초기 미격발
    g = G(3, 0.5)
    check("초기 fired=False", g.fired is False)
    # ② 매 배치 bestR 개선 → 영구 비격발
    g = G(3, 0.0)
    for i in range(10):
        g.observe_batch(i, True, ["A"] * 16)
    check("연속 개선 = 비격발", g.fired is False and not g.events)
    # ③ 정체 + 반복-지배(dup≈0.98 ≥ 0.5) → 정확히 stall_batches번째 관측에서 격발(1회)
    g = G(3, 0.5)
    g.observe_batch(0, False, ["A"] * 16)
    g.observe_batch(1, False, ["A"] * 16)
    check("문턱 직전 비격발", g.fired is False)
    g.observe_batch(2, False, ["A"] * 16)          # since_improve=3 → fire
    check("정체 3배치+dup 지배 → 격발", g.fired is True
          and g.events and g.events[0]["event"] == "on")
    g.observe_batch(3, False, ["A"] * 16)          # 격발 후 관측 = no-op(중단 전제)
    check("격발 후 추가 이벤트 없음", sum(1 for e in g.events if e["event"] == "on") == 1)
    # ④ 정체지만 전부-유니크(dup=0 < 0.5) → 비격발 + blocked 진단 계측 (§15.8 S17 s0 판별의 핵심)
    g = G(3, 0.5)
    for i in range(10):
        g.observe_batch(i, False, [f"plan{i}_{j}" for j in range(16)])
    check("정체+다양 plan = 비격발(+blocked 계측)", g.fired is False
          and not any(e["event"] == "on" for e in g.events)
          and g.blocked_n > 0 and g.blocked_max_dup == 0.0)
    # ⑤ 개선이 카운터를 리셋: 정체 2 + 개선 1 + 정체 2 → 비격발(stall_batches=3 연속 요구)
    g = G(3, 0.0)
    g.observe_batch(0, False, ["A"] * 4)
    g.observe_batch(1, False, ["A"] * 4)
    g.observe_batch(2, True, ["A"] * 4)
    g.observe_batch(3, False, ["A"] * 4)
    g.observe_batch(4, False, ["A"] * 4)
    check("개선이 정체 카운터 리셋", g.fired is False)
    # ⑥ roundtrip: to_dict → 복원 → 동작 동일
    g.observe_batch(5, False, ["A"] * 4)           # since=3 → fire
    d = g.to_dict()
    g2 = G(3, 0.0, data=d)
    check("ckpt roundtrip(fired 포함)", g2.fired == g.fired
          and g2.since_improve == g.since_improve and g2.events == g.events)


def mk_cfg(**kw) -> dict:
    cfg = dict(T.DEFAULTS)
    cfg.update(shaping="trace", train_deadline=3000, sil=True,
               max_batches=8, max_episodes=10 ** 9, max_wall=10 ** 12,
               blocker_coef=1.0, knowledge_coef=0.0)
    cfg.update(kw)
    return cfg


def integration_tests(envs: int) -> None:
    print("[integration] v2.1 fixture 저예산 (max_batches 8)")
    mdp = StageMDP(991, grammar=T.GRAMMAR_R2,
                   scene=SCENE, stage_tres=STAGE_TRES, layout_tres=LAYOUT_TRES)
    pool, _, _ = T.build_pool(envs, SCENE, with_trace=True)
    try:
        # A. mode=always(명시) == 레거시(무 mode 키) — byte-identity
        r_legacy, _ = T.train_seed(mdp, pool, 0, mk_cfg(knowledge_coef=1.0))
        r_always, _ = T.train_seed(mdp, pool, 0, mk_cfg(knowledge_coef=1.0,
                                                        knowledge_mode="always"))
        check("A: always == 레거시 (curve 정확 일치)",
              r_legacy["curve"] == r_always["curve"]
              and r_legacy["best_reward"] == r_always["best_reward"]
              and "knowledge_governor" not in r_always,
              f"curve n={len(r_legacy['curve'])}")
        # B. stall 무격발(문턱 미달) == knowledge-coef 0 — 검출 런 보상 경로 무개입.
        # max_batches=12로 batch%10 출력 경로까지 커버(§16.7 회귀: k_gate NameError를 probe가
        # 놓친 원인 = 전 통합 테스트가 batch 10 미달).
        r_nok, _ = T.train_seed(mdp, pool, 1, mk_cfg(max_batches=12))
        r_stall0, _ = T.train_seed(mdp, pool, 1, mk_cfg(max_batches=12, knowledge_coef=1.0,
                                                        knowledge_mode="stall",
                                                        stall_batches=9999, stall_share=1.1))
        check("B: stall 무격발 == knowledge 무 (curve 정확 일치)",
              r_nok["curve"] == r_stall0["curve"]
              and r_nok["best_reward"] == r_stall0["best_reward"]
              and r_stall0.get("knowledge_governor", {}).get("events") == [],
              f"curve n={len(r_nok['curve'])}")
        # C. 강제 격발(문턱 최소) → 검출 중단 → always 재시작(escalate) + 회계 동승
        r_force, st_force = T.train_seed_escalate(mdp, pool, 1, mk_cfg(knowledge_coef=1.0,
                                                                       knowledge_mode="stall",
                                                                       stall_batches=2,
                                                                       stall_share=0.0))
        esc = r_force.get("stall_escalation")
        check("C: 강제 격발 → escalate 재시작 + 검출 회계",
              esc is not None and esc["fire"]["event"] == "on"
              and esc["detect_batches"] >= 2
              and "knowledge_governor" not in r_force   # 구출 런 = always(governor 부재)
              and st_force.get("knowledge_mode_effective") == "always",
              f"esc={esc}")
        # D. escalated ckpt resume 계약(§16 codex R1-H1): ① stall CLI 재개 = fail-closed 거부
        #    ② always 재개 = 무중단 escalate와 파라미터 비트동일 + 곡선 일치(재개 등가성)
        import os
        import tempfile
        torch, _nn = T._torch()
        n = 4
        stall_cfg = mk_cfg(knowledge_coef=1.0, knowledge_mode="stall",
                           stall_batches=2, stall_share=0.0)
        always_cfg = {k: v for k, v in stall_cfg.items()
                      if k not in ("knowledge_mode", "stall_batches", "stall_share")}
        r_a, st_a = T.train_seed_escalate(mdp, pool, 3, dict(stall_cfg, max_batches=2 * n))
        r_b1, st_b1 = T.train_seed_escalate(mdp, pool, 3, dict(stall_cfg, max_batches=n))
        tmp = T.Path(tempfile.gettempdir()) / f"candyants_stall_equiv_{os.getpid()}.pt"
        try:
            T.save_ckpt(tmp, st_b1)
            ck = T.load_ckpt(tmp)
            rejected = False
            try:
                T.train_seed(mdp, pool, 3, dict(stall_cfg, max_batches=n), ck, "resume")
            except RuntimeError:
                rejected = True
            check("D1: escalated ckpt + stall CLI 재개 = fail-closed 거부", rejected)
            r_b2, st_b2 = T.train_seed(mdp, pool, 3, dict(always_cfg, max_batches=n),
                                       ck, "resume")
        finally:
            try:
                tmp.unlink()
            except FileNotFoundError:
                pass
        pa, pb = st_a["policy"], st_b2["policy"]
        bits_eq = (pa.keys() == pb.keys()
                   and all(torch.equal(pa[k], pb[k]) for k in pa))
        check("D2: escalated 재개 등가성(파라미터 비트동일 + 곡선 일치)",
              bits_eq and r_a["curve"] == r_b2["curve"]
              and r_b2["curve"][:len(r_b1["curve"])] == r_b1["curve"],
              f"curve n={len(r_a['curve'])}")
        # E. 중단된 stall-검출 ckpt → stall 재개 → 격발 → 구출 완주(§16 codex R2-H1):
        #    resume-모드 검출이 격발하면 rescue는 무-ckpt 재시작이어야 함(가드 크래시 금지).
        e_cfg = mk_cfg(knowledge_coef=1.0, knowledge_mode="stall",
                       stall_batches=3, stall_share=0.0)
        r_e1, st_e1 = T.train_seed(mdp, pool, 5, dict(e_cfg, max_batches=2))  # 미격발 검출 상태
        tmp2 = T.Path(tempfile.gettempdir()) / f"candyants_stall_interrupt_{os.getpid()}.pt"
        try:
            unfired = (st_e1.get("knowledge_mode_effective") == "stall_detect"
                       and not r_e1.get("stall_escalate"))
            T.save_ckpt(tmp2, st_e1)
            ck2 = T.load_ckpt(tmp2)
            r_e2, st_e2 = T.train_seed_escalate(mdp, pool, 5, dict(e_cfg, max_batches=10),
                                                ck2, "resume")
        finally:
            try:
                tmp2.unlink()
            except FileNotFoundError:
                pass
        check("E: 중단 검출 ckpt → 재개 → 격발 → 구출 완주(크래시 없음)",
              unfired and r_e2.get("stall_escalation") is not None
              and st_e2.get("knowledge_mode_effective") == "always",
              f"esc={r_e2.get('stall_escalation')}")
        # F. transfer-유래 검출 런의 재개→격발 = fail-closed(§16 codex R3-H1): 재개 ckpt에
        #    transfer 원본이 없어 구출 레짐 재구성 불가 → silent scratch 강등 금지. 시뮬레이션 =
        #    미격발 검출 상태의 seg_mode를 'transfer'로 세팅(transfer-유래 사슬의 재개 ckpt와 동형
        #    — seg_mode는 resume을 통해 전파되는 값이라 white-box 주입이 유효).
        st_f = dict(st_e1, seg_mode="transfer")
        tmp3 = T.Path(tempfile.gettempdir()) / f"candyants_stall_xferres_{os.getpid()}.pt"
        try:
            T.save_ckpt(tmp3, st_f)
            ck3 = T.load_ckpt(tmp3)
            rejected_xfer = False
            try:
                T.train_seed_escalate(mdp, pool, 5, dict(e_cfg, max_batches=10), ck3, "resume")
            except RuntimeError as e:
                rejected_xfer = "transfer" in str(e)
        finally:
            try:
                tmp3.unlink()
            except FileNotFoundError:
                pass
        check("F: transfer-유래 검출 재개→격발 = fail-closed(명시 안내)", rejected_xfer)
    finally:
        pool.close()


def main() -> int:
    ap = argparse.ArgumentParser(description="§16 StallGovernor 격리 검증")
    ap.add_argument("--skip-godot", action="store_true")
    ap.add_argument("--envs", type=int, default=2)
    args = ap.parse_args()
    unit_tests()
    if not args.skip_godot:
        integration_tests(args.envs)
    print(f"[probe] {'PASS' if FAIL == 0 else 'FAIL'} — {PASS} pass / {FAIL} fail")
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
