#!/usr/bin/env python3
"""
auto-solver — 스테이지 풀이/실행 통합 front-door.

`run_test.py`는 순수 테스트 씬 러너로 두고(기능 중심), "스테이지를 결정론 하니스로 실행해 무수정 게임
verdict(D4)를 얻는" 모든 솔버 경로를 여기로 모은다. verdict는 **항상 stdout의 SOLVER_RESULT(또는 테스트
PASS 마커)를 파싱**해 판정하므로, run_test의 `--quit-after` 안전망이 exit 0(=PASS와 동일)으로 끝나
멀티런 테스트의 타임아웃을 PASS로 위장하는 false-green이 **구조적으로 불가능**하다.

Subcommands:
    replay <plan.json>                  단일 플랜 결정론 리플레이 → 결과 JSON (run_plan.run_plan_file)
    selftest                            골든 + solve.json 회귀 게이트 (run_plan.selftest)
    search <stage_id> [--max-rollouts N]  닫힌-루프 탐색 (solve.solve)
    harness-test                        PlanRunner 불변식 회귀(PlanReplayHarnessTest)를 마커-파싱으로 신뢰 실행

replay/selftest/search는 기존 진입점(`scripts/run_plan.py`, `tools/solver/solve.py`)의 구현을 그대로
import해 위임한다(동작·결정론 불변). harness-test만 신규다.

Env: GODOT_BIN (run_test.py가 사용).
    CANDYANTS_HARNESS_QUIT_AFTER  harness-test의 --quit-after 프레임 budget(기본 120000). 가드 검증용 축소 가능.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# 콘솔 코드페이지(cp949 등)와 무관하게 한글·기호(— ⚠ 등) print/write가 죽지 않도록 UTF-8 강제(Windows
# UnicodeEncodeError 방지, analyze.py와 동일). 게이트 명령이 인코딩 크래시로 끊겨 false-fail 나는 것 차단.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

HERE = Path(__file__).resolve().parent          # tools/solver
ROOT = HERE.parents[1]                            # .../CandyAnts
RUN_TEST = ROOT / "scripts" / "run_test.py"

# 기존 reliable 진입점을 그 아래로 정리(import-dispatch). 동작은 불변 — 게이트로 보호된 작동 솔버를 깨지 않음.
sys.path.insert(0, str(ROOT / "scripts"))         # run_plan.py
sys.path.insert(0, str(HERE))                     # solve.py, model.py
import run_plan                                    # noqa: E402  (scripts/run_plan.py)
import solve                                       # noqa: E402  (tools/solver/solve.py)
import tactics                                      # noqa: E402  (⛔ ARCHIVED Phase 4 — transfer-bench seed 모드 전용, ARCHIVE.md)
import knowledge                                    # noqa: E402  (tools/solver/knowledge.py, 지식 볼트 — LIVE: diverse 위기 어휘)

# ---------- harness-test (신규): PlanReplayHarnessTest를 exit-code가 아니라 PASS 마커로 판정 ----------
HARNESS_TEST_SCENE = "tests/PlanReplayHarnessTest.tscn"
HARNESS_TEST_PASS = "[PlanReplayHarnessTest] PASS"
HARNESS_TEST_FAIL = "[PlanReplayHarnessTest] FAIL"
DEFAULT_HARNESS_QUIT_AFTER = 120000               # 멀티런(>18000f 필요) 완주 여유. run_test 기본(18000)은 부족.


def harness_test() -> int:
    """PlanReplayHarnessTest(멀티런 PlanRunner 불변식 회귀)를 **신뢰 실행**한다.

    이 테스트는 한 씬에서 ~10개의 in-process 리플레이를 순차 수행해 18000프레임(run_test 기본 budget)을
    초과한다. run_test의 `--quit-after` 안전망이 먼저 발동하면 Godot이 exit 0(=`quit(0)`=PASS와 동일)으로
    종료 → 게이트가 "통과"로 오인(타임아웃 false-green). 여기선:
      1. `--fixed-fps 60` + 넉넉한 `--quit-after`(기본 120000)로 ~8s 완주(안전망 회피),
      2. **exit-code가 아니라 테스트가 직접 찍는 PASS 마커**를 파싱해 판정(마커 없음/FAIL 마커 = FAIL).
    """
    budget = os.environ.get("CANDYANTS_HARNESS_QUIT_AFTER", str(DEFAULT_HARNESS_QUIT_AFTER))
    env = os.environ.copy()
    env["CANDYANTS_DETERMINISTIC"] = "1"          # 테스트 내부에서도 강제하나 명시(결정론·프레임 일관)
    p = subprocess.run(
        [sys.executable, str(RUN_TEST), HARNESS_TEST_SCENE, "--fixed-fps", "60", "--quit-after", budget],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(ROOT), env=env,
    )
    out = p.stdout or ""
    sys.stdout.write(out)                          # 라이브 스트림은 잃지만 게이트엔 무해(완주 후 일괄 출력)
    if p.stderr:
        sys.stderr.write(p.stderr)
    sys.stdout.flush()
    if HARNESS_TEST_FAIL in out:
        print("[try_solve] harness-test FAIL — 테스트가 FAIL 마커 보고(불변식 회귀)", flush=True)
        return 1
    if HARNESS_TEST_PASS not in out:
        print("[try_solve] harness-test FAIL — PASS 마커 없음(--quit-after 안전망에 잘림? exit=%d, budget=%s). "
              "exit 0이어도 마커 없으면 신뢰 안 함 — 타임아웃 false-green 차단." % (p.returncode, budget), flush=True)
        return 1
    if p.returncode != 0:
        # 마커는 찍혔으나 이후 비정상 종료(teardown 크래시·엔진/래퍼 오류). 마커가 있다고 nonzero를 삼키면
        # *새로운* fail-open이 된다(codex R2). 타임아웃은 "exit 0 + 마커 없음"이라 위 분기로 잡히고, 여기선
        # "마커 + nonzero"를 잡는다 — **PASS = 마커 AND exit 0 둘 다** 요구.
        print("[try_solve] harness-test FAIL — PASS 마커는 있으나 exit=%d (마커 출력 후 비정상 종료). "
              "마커+exit0 둘 다 요구." % p.returncode, flush=True)
        return 1
    print("[try_solve] harness-test PASS — PASS 마커 + exit 0 확인(budget=%s)" % budget, flush=True)
    return 0


# ---------- transfer-bench (Phase 4): 지식 볼트 ON/OFF A/B + 귀속 ----------
def _fresh_stats() -> dict:
    return {"cleared": False, "rollouts": 0, "decisive_origin": None, "plan_sources": [],
            "seeded_attempts": 0, "seeded_successes": 0, "fallback_attempts": 0,
            "fallback_successes": 0, "vault_pruned": 0, "final_plan": None,
            "tried_log": [], "pruned_log": []}


def _pruning_justified(off: dict, on: dict):
    """반사실 귀속(re-review R1 HIGH-2): ON이 prune한 각 후보가 OFF에서 **같은 base로 롤아웃돼 미클리어**였는지
    확인. prune된 후보가 OFF에서 클리어했거나(=shortcut 삭제) OFF가 평가조차 안 했으면(=비-유효 미확인) 정당화 실패.
    반환 (justified: bool, checked: int). same_solution+pruned는 '최적화' 증거일 뿐, 이 검증이 '비-유효 형제만
    버렸다'를 증명해 '전이/지식' 증거로 격상."""
    off_tried = off.get("tried_log", [])
    pruned = on.get("pruned_log", [])
    for p in pruned:
        match = next((t for t in off_tried
                      if t.get("base") == p.get("base") and t.get("action") == p.get("action")), None)
        if match is None or match.get("cleared"):
            return False, len(pruned)
    return True, len(pruned)


def transfer_bench(test_ids: list[int], max_rollouts: int, mode: str = "vault") -> int:
    """⛔ ARCHIVED (Phase 4 강제 종료, 2026-06-24 — ARCHIVE.md). 속도-전이 가설(boost/pruning)을 falsify한
    음성-입증 하니스. **보존**하나 라이브 게이트 아님(seed=falsified, vault-pruning=incompleteness 산물). 재실행은
    역사 재현용으로만. — (이하 원 설계 기록)
    볼트 지식 ON/OFF A/B로 전이 효과를 측정·귀속한다.

    각 test에 대해 **동일 경로**(결정론·동일 budget)를 두 번:
      OFF = 볼트 없음(현행 백지 탐색).
      ON  = mode=vault → knowledge.vault_prune(위기→링크 요소로 형제 후보 prune; de-risk 레버).
            mode=seed  → tactics seed(보너스+source-tag; 4a 레거시, NO-TRANSFER 입증됨).
    solve.json은 안 씀(save=False) → 게이트 산출물 불변.

    **귀속(mode=vault, 같은-해+pruning)**: ON이 클리어 AND 롤아웃 < OFF AND **OFF와 동일 해(final_plan)**
    AND vault_pruned>0. "같은 답을 더 적은 롤аут으로 — 감소는 볼트가 prune한 형제 후보로 설명." fallback이
    다른 답을 우연히 낸 게 아님을 same-solution이 보장.
    **귀속(mode=seed, provenance)**: ON 클리어 AND 롤아웃 < OFF AND 결정적 액션 출처=seeded:.
    OFF가 cap 내 미클리어면 inconclusive(베이스라인 부재 → cap 상향).
    """
    print("⛔ [ARCHIVED] transfer-bench = Phase 4 강제 종료 메커니즘(속도-전이 falsified: boost NO-TRANSFER + "
          "pruning=incompleteness 산물). 라이브 게이트 아님 — 역사 재현 전용. (tools/solver/ARCHIVE.md)")
    notes = knowledge.load_vault() if mode == "vault" else {}
    library = tactics.manual_library() if mode == "seed" else []
    print(f"=== transfer-bench (Phase 4, mode={mode}) === cap={max_rollouts}"
          + (f" vault_notes={len(notes)}" if mode == "vault" else f" library={[t['id'] for t in library]}"))
    seed_fn = (lambda l, d, i, m: tactics.seed(l, d, i, m, library)) if mode == "seed" else None  # noqa: E731
    vault_fn = ((lambda d, c, ret, trp: knowledge.vault_prune(notes, d, c, ret, trp))
                if mode == "vault" else None)                                                       # noqa: E731
    rows, all_ok = [], True
    for tid in test_ids:
        print(f"\n----- TEST stage{tid:02d}: OFF (baseline) -----")
        off = _fresh_stats()
        solve.solve(tid, max_rollouts, stats=off, save=False)
        print(f"\n----- TEST stage{tid:02d}: ON (mode={mode}) -----")
        on = _fresh_stats()
        solve.solve(tid, max_rollouts, seed_fn=seed_fn, vault_fn=vault_fn, stats=on, save=False)

        reduced = bool(on.get("cleared") and off.get("cleared") and on["rollouts"] < off["rollouts"])
        inconclusive = not off.get("cleared")
        same_solution = on.get("final_plan") == off.get("final_plan")
        decisive_seeded = bool(on.get("decisive_origin") and str(on["decisive_origin"]).startswith("seeded:"))
        justified, n_pruned_checked = _pruning_justified(off, on)
        if mode == "vault":
            # 귀속(re-review R1 HIGH-2): 롤아웃 감소 + 같은 해 + prune>0 + **prune 형제가 OFF서 미클리어(반사실)**.
            ok = bool(on.get("cleared") and reduced and same_solution and on.get("vault_pruned", 0) > 0 and justified)
        else:
            ok = bool(on.get("cleared") and reduced and decisive_seeded)
        verdict = ("INCONCLUSIVE(OFF가 cap 내 미클리어 — cap 상향)" if inconclusive
                   else ("TRANSFER-OK" if ok else "NO-TRANSFER"))
        if not ok:
            all_ok = False
        row = {"stage": tid, "mode": mode, "off_cleared": off.get("cleared"), "off_rollouts": off.get("rollouts"),
               "on_cleared": on.get("cleared"), "on_rollouts": on.get("rollouts"), "rollout_reduced": reduced,
               "same_solution": same_solution, "vault_pruned": on.get("vault_pruned"),
               "pruning_justified": justified, "pruned_checked": n_pruned_checked,
               "decisive_origin": on.get("decisive_origin"), "decisive_seeded": decisive_seeded,
               "verdict": verdict}
        rows.append(row)
        print(f"\nTRANSFER_BENCH_ROW {json.dumps(row, ensure_ascii=False)}")

    print("\n=== transfer-bench 요약 ===")
    for r in rows:
        extra = (f"pruned={r['vault_pruned']} same_sol={r['same_solution']} justified={r['pruning_justified']}"
                 if mode == "vault" else f"decisive={r['decisive_origin']}")
        print(f"  stage{r['stage']:02d}: OFF {r['off_rollouts']}롤(clr={r['off_cleared']}) → "
              f"ON {r['on_rollouts']}롤(clr={r['on_cleared']}) | {extra} | {r['verdict']}")
    marker = "TRANSFER_BENCH PASS" if all_ok else "TRANSFER_BENCH FAIL"
    print(f"\n{marker} {json.dumps({'all_ok': all_ok, 'mode': mode, 'rows': rows}, ensure_ascii=False)}")
    if not all_ok:
        print("[try_solve] transfer-bench FAIL — 전이 미입증(롤아웃 감소 AND 귀속 미충족). 사용자 보고·재설계.")
        return 1
    print("[try_solve] transfer-bench PASS — 전이가 롤아웃 감소 + 귀속으로 입증됨.")
    return 0


# ---------- rediscover-verify: 탐색 휴리스틱 재발견 회귀 게이트 (codex impl-review MEDIUM) ----------
# selftest는 저장된 plan을 **replay**할 뿐 solve.solve()/model.propose()를 안 돈다 → 탐색 휴리스틱 회귀
# (early 체인 게이트·carry-mirror 가중·결정론 파손)가 plan replay를 통과해버린다(codex impl-review MEDIUM).
# 여기선 각 타깃을 **재발견**(solve.solve, save=False)해 cleared + 재발견 plan의 액션 시그니처(순서 포함)가
# 커밋된 solve.json과 일치하는지 단언한다. 대상 = `up` 루프(early/carry)를 실제로 도는 대표 스테이지:
#   20 = early-chain(이 변경이 켜는 신규 경로) / 4 = early-arm 단발(early_armed=False 단축 = byte-identical
#   경로) / 13 = carry-chain(early 미발화 유지) / 19 = **cell-up stacking**(sand_mound ③ 분기·wall_targets·
#   같은-col exclude·off-sweep 회귀; 5d② 신규 경로) / 22 = **5e cell-up fall-edge + D2 burial-protect**(목표-위
#   절벽 cell-up + carry-arm burial 해소; witness off=2 (10,6) 실제 발견 단언). blocker-only는 up 루프 미진입.
REDISCOVER_TARGETS = {4: 10, 13: 35, 19: 30, 20: 60, 22: 40}   # stage_id → max_rollouts(여유 cap; 시그니처 비교라 cap 무관)


def rediscover_verify(targets: dict) -> int:
    all_ok = True
    # ① cell-up 검출/후보 단위 박제(엔진 불요, fail-closed) — wall_targets 방향/soundness/정렬 + R3-M1 off=5 emit.
    if not solve.model._selfcheck_wall_targets():
        print("[rediscover-verify] FAIL — _selfcheck_wall_targets (cell-up 검출/후보 회귀).")
        return 1
    # ①' LA2 reserve가 정상 per-round first-step pool을 안 줄임(codex impl R7, 순수 단위).
    if not solve._selfcheck_la2_reserve():
        print("[rediscover-verify] FAIL — _selfcheck_la2_reserve (LA2 reserve first-step 보존 회귀).")
        return 1
    # ①'' carrymax quota 계약(매몰 append·base-live 판정·LA2 base2 배선 — codex carrymax R4 M2, 순수 단위).
    if not solve.model._selfcheck_carrymax_quota():
        print("[rediscover-verify] FAIL — _selfcheck_carrymax_quota (carrymax quota/speculative-base 회귀).")
        return 1
    # ② up-루프 대표 스테이지를 solve.solve(save=False)로 재발견 → cleared + 액션 시그니처 일치.
    for sid in sorted(targets):
        cap = targets[sid]
        sol_path = solve.ROOT / "data" / "solutions" / f"stage{sid:02d}.solve.json"
        if not sol_path.exists():
            print(f"[rediscover-verify] FAIL stage{sid:02d} — solve.json 없음(fail-closed)")
            all_ok = False
            continue
        expected = json.loads(sol_path.read_text(encoding="utf-8")).get("actions", [])
        exp_sigs = [solve._action_sig(a) for a in expected]
        st = {"cleared": False, "final_plan": None, "rollouts": 0}
        solve.solve(sid, cap, save=False, stats=st)
        got_sigs = [solve._action_sig(a) for a in (st.get("final_plan") or [])]
        ok = bool(st.get("cleared")) and got_sigs == exp_sigs
        print(f"[rediscover-verify] {'PASS' if ok else 'FAIL'} stage{sid:02d} — cleared={st.get('cleared')} "
              f"rollouts={st.get('rollouts')} actions={len(got_sigs)}/{len(exp_sigs)}")
        if not ok:
            print(f"  expected={exp_sigs}\n  got     ={got_sigs}")
            all_ok = False
    if not all_ok:
        print("[rediscover-verify] FAIL — 재발견 회귀(cleared 또는 액션 시그니처 불일치).")
        return 1
    print(f"[rediscover-verify] PASS — {len(targets)} 스테이지 재발견 cleared + 액션 시그니처 일치 "
          f"(stages {sorted(targets)}).")
    return 0


# ---------- diverse: 가능성-공간 다양-해(5b) — diverse.py 위임 ----------
import diverse  # noqa: E402  (tools/solver/diverse.py — range-sweep·4요소 class·게이트, 순수+엔진)


# ---------- replay / selftest / search: 기존 구현 위임 ----------
def replay(plan_arg: str) -> int:
    plan_path = Path(plan_arg)
    if not plan_path.is_absolute():
        plan_path = (Path.cwd() / plan_path).resolve()
    if not plan_path.exists():
        print("[try_solve] plan file not found: %s" % plan_path)
        return 1
    result = run_plan.run_plan_file(plan_path)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if (result.get("cleared") and int(result.get("saved", 0)) >= 1) else 1


def main() -> int:
    ap = argparse.ArgumentParser(prog="try_solve", description="auto-solver 스테이지 풀이/실행 front-door")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_replay = sub.add_parser("replay", help="단일 플랜 결정론 리플레이 → 결과 JSON")
    p_replay.add_argument("plan", help="플랜 JSON 경로")

    sub.add_parser("selftest", help="골든 + solve.json 회귀 게이트")

    p_search = sub.add_parser("search", help="닫힌-루프 탐색(solve)")
    p_search.add_argument("stage_id", type=int)
    p_search.add_argument("--max-rollouts", type=int, default=10, help="롤아웃 상한(기본 10).")

    sub.add_parser("harness-test", help="PlanReplayHarnessTest를 마커-파싱으로 신뢰 실행")

    sub.add_parser("rediscover-verify", help="탐색 휴리스틱 재발견 회귀 게이트(up-루프 대표 스테이지 solve 재실행)")

    # ⛔ ARCHIVED (Phase 4 강제 종료, ARCHIVE.md): help 텍스트에 ARCHIVED 명시 + 실행은 `--archived-ok` 명시적
    # opt-in 요구(plan-review R1 MEDIUM — 죽은 메커니즘을 지원 워크플로로 오인·실행 못 하게). 라이브 게이트 아님.
    # (argparse는 서브파서 help=SUPPRESS를 `==SUPPRESS==`로 흉하게 노출 → 라벨+opt-in 방식 채택.)
    p_bench = sub.add_parser("transfer-bench", help="⛔ARCHIVED (Phase 4 종료) — 라이브 게이트 아님, 역사 재현 전용")
    p_bench.add_argument("--archived-ok", action="store_true",
                         help="ARCHIVED 메커니즘 실행을 명시적으로 승인(없으면 거부).")
    p_bench.add_argument("--test", type=int, action="append", required=True,
                         help="전이 측정할 test 스테이지 id(반복 가능, 예: --test 12 --test 13).")
    p_bench.add_argument("--max-rollouts", type=int, default=30, help="롤아웃 상한(기본 30 — OFF 베이스라인 확보용).")
    p_bench.add_argument("--mode", choices=["vault", "seed"], default="vault",
                         help="ON 메커니즘: vault=볼트 pruning(기본) / seed=레거시 전술 boost.")

    p_div = sub.add_parser("diverse", help="가능성-공간 다양-해 발견 + 풀이법 보고서(5b, 의도판단·의견 없음)")
    p_div.add_argument("stage_id", type=int)
    p_div.add_argument("--extra-cap", type=int, default=40,
                       help="첫 class 발견 후 추가 탐색 롤아웃 예산(기본 40). 초과 시 남은 탐색 중단.")
    p_div.add_argument("--max-rollouts", type=int, default=30, help="탐색당 롤아웃 상한(기본 30).")
    p_div.add_argument("--workers", type=int, default=4, help="병렬 롤아웃 수(range-sweep 가속, 기본 4).")
    p_div.add_argument("--save", action="store_true",
                       help="가능성-공간 보고서를 data/solutions/stageNN.diverse.json으로 영속(5c, 기본 미저장).")

    p_dv = sub.add_parser("diverse-verify", help="저장된 diverse.json range 경계/내부/gap 결정론 리플레이 게이트(5c)")
    p_dv.add_argument("stage_id", type=int, nargs="?", help="검증할 stage id(없으면 모든 diverse.json)")
    p_dv.add_argument("--workers", type=int, default=4, help="병렬 롤아웃 수(기본 4).")

    args = ap.parse_args()
    if args.cmd == "replay":
        return replay(args.plan)
    if args.cmd == "selftest":
        return run_plan.selftest()
    if args.cmd == "search":
        return solve.solve(args.stage_id, args.max_rollouts)
    if args.cmd == "harness-test":
        return harness_test()
    if args.cmd == "rediscover-verify":
        return rediscover_verify(REDISCOVER_TARGETS)
    if args.cmd == "transfer-bench":
        if not args.archived_ok:
            print("⛔ transfer-bench는 ARCHIVED (Phase 4 강제 종료 — 속도-전이 falsified, tools/solver/ARCHIVE.md). "
                  "라이브 게이트/워크플로 아님. 역사 재현이 목적이면 `--archived-ok`를 명시하세요.")
            return 2
        return transfer_bench(args.test, args.max_rollouts, args.mode)
    if args.cmd == "diverse":
        return diverse.diverse_report(args.stage_id, args.max_rollouts, args.extra_cap, args.save, args.workers)
    if args.cmd == "diverse-verify":
        ids = [args.stage_id] if args.stage_id is not None else diverse._diverse_stage_ids()
        return diverse.verify_diverse(ids, args.workers)
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
