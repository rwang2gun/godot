# auto-solver §R4 acceptance 1 — r4.0 문법 커버리지 게이트 (fail-closed STOP 관문. 2026-07-10)
#
# R4 커버리지 subset(plan §R4 R2-M5): S11~S17의 stage{NN}.solve.json + stage{NN}.rl*.json + S19.
# 각 known 해를 r4.0으로 encode→decode(landmark lowering)→엔진 리플레이(deadline 7000)해
# cleared ∧ saved==hp를 단언한다. 인코딩 갭(리플레이 실패) 1건이라도 = GATE FAIL = 즉시 STOP
# (plan 계약 — fallback 우회 금지, 사용자 보고).
#
# 비게이트 탐사(동일 plan R2-M5): stage23/24.witness.json의 r4.0 인코딩 가능성 측정·박제
# (수기 stretch needle — 게이트 비대상, 결과는 정보 제공).
#
# usage: python tools/solver/rl/experiments/r4_coverage.py [--json OUT] [--include-witness]

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RL_DIR = Path(__file__).resolve().parents[1]
SOLVER_DIR = RL_DIR.parent
sys.path.insert(0, str(RL_DIR))
sys.path.insert(0, str(SOLVER_DIR))

import mdp      # noqa: E402
import solve    # noqa: E402

ROOT = SOLVER_DIR.parents[1]
SOLUTIONS = ROOT / "data" / "solutions"
COVERAGE_STAGES = [11, 12, 13, 14, 15, 16, 17, 19]   # plan §R4 커버리지 subset
REPLAY_DEADLINE = 7000                                # R4_PIN(표준 판정 deadline)


def solution_files(sid: int) -> list[Path]:
    out = sorted(SOLUTIONS.glob(f"stage{sid:02d}.solve.json"))
    out += sorted(SOLUTIONS.glob(f"stage{sid:02d}.rl*.json"))
    return out


def roundtrip_one(m, path: Path) -> dict:
    d = json.loads(path.read_text(encoding="utf-8"))
    actions = d["actions"]
    enc = [m.encode_action(a) for a in actions]
    dec = m.decode_plan(enc)
    # 인코딩 드리프트 회계(정직): 원 액션 vs lowered 액션의 공간 차이.
    drifts = []
    for orig, low in zip(actions, dec):
        o_t, l_t = orig.get("trigger", {}), low.get("trigger", {})
        dx = None
        if o_t.get("type") == "ant_reaches_x" and l_t.get("type") == "ant_reaches_x":
            dx = abs(float(o_t["x"]) - float(l_t["x"])) / m.cs
        drow = None
        o_tg, l_tg = orig.get("target", {}), low.get("target", {})
        if "y_min" in o_tg and "y_min" in l_tg:
            drow = abs(float(o_tg["y_min"]) - float(l_tg["y_min"])) / m.cs
        if o_tg.get("mode") == "cell" and l_tg.get("mode") == "cell":
            oc, lc = o_tg["cell"], l_tg["cell"]
            drow = abs(int(oc[1]) - int(lc[1]))
            dx = abs(int(oc[0]) - int(lc[0]))
        drifts.append({"dx_cells": dx, "drow_cells": drow})
    res = solve.run_plan(m.stage_scene, dec, deadline=REPLAY_DEADLINE, trace=False)
    ok = bool(res.get("cleared")) and int(res.get("saved") or 0) >= m.hp
    return {"file": path.name, "n_actions": len(actions), "cleared": bool(res.get("cleared")),
            "saved": int(res.get("saved") or 0), "hp": m.hp, "frame": res.get("frame"),
            "ok": ok, "drifts": drifts,
            "lowered_plan": dec}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", type=str, default=None)
    ap.add_argument("--include-witness", action="store_true", default=True)
    args = ap.parse_args()

    report: dict = {"gate": [], "witness_exploration": [], "landmark_schema_digest": None}
    gate_fail = 0
    for sid in COVERAGE_STAGES:
        files = solution_files(sid)
        if not files:
            print(f"[r4-coverage] S{sid}: 해 파일 0 — subset 정의와 repo 불일치(FAIL)")
            gate_fail += 1
            continue
        m = mdp.StageMDP(sid, max_len=8, grammar=mdp.GRAMMAR_R4)
        report["landmark_schema_digest"] = m.landmark_digest
        for f in files:
            # FAIL 정직-박제 산출물(actions=null — 해 아님, 예: stage13.rl2.json R2 acceptance FAIL
            # 기록)은 커버리지 대상 밖. 명시 스킵(침묵 아님).
            if not json.loads(f.read_text(encoding="utf-8")).get("actions"):
                print(f"[r4-coverage] SKIP S{sid} {f.name}: actions=null(FAIL-박제 산출물, 해 아님)")
                report["gate"].append({"stage": sid, "file": f.name, "skipped": "actions_null"})
                continue
            r = roundtrip_one(m, f)
            r["stage"] = sid
            r["n_landmarks"] = len(m.landmark_instances)
            report["gate"].append(r)
            status = "OK " if r["ok"] else "FAIL"
            mx = max((d["dx_cells"] or 0) for d in r["drifts"]) if r["drifts"] else 0
            mr = max((d["drow_cells"] or 0) for d in r["drifts"]) if r["drifts"] else 0
            print(f"[r4-coverage] {status} S{sid} {f.name}: saved={r['saved']}/{r['hp']} "
                  f"frame={r['frame']} max_drift(dx={mx:.1f} drow={mr:.1f}) lm={r['n_landmarks']}")
            if not r["ok"]:
                gate_fail += 1

    # 비게이트: witness 인코딩 가능성 탐사(정보 제공 — 게이트 판정 무관).
    if args.include_witness:
        for sid in (23, 24):
            wf = SOLUTIONS / f"stage{sid}.witness.json"
            if not wf.exists():
                continue
            try:
                m = mdp.StageMDP(sid, max_len=10, grammar=mdp.GRAMMAR_R4)
                r = roundtrip_one(m, wf)
                r["stage"] = sid
                report["witness_exploration"].append(r)
                print(f"[r4-coverage] (non-gate) witness S{sid}: "
                      f"{'replay-clear' if r['ok'] else 'NOT-encodable-or-fails'} "
                      f"saved={r['saved']}/{r['hp']}")
            except Exception as e:                        # 탐사 — 실패도 박제
                report["witness_exploration"].append({"stage": sid, "error": str(e)})
                print(f"[r4-coverage] (non-gate) witness S{sid}: encode error {e}")

    verdict = "PASS" if gate_fail == 0 else f"FAIL({gate_fail})"
    report["verdict"] = verdict
    print(f"[r4-coverage] GATE {verdict} — {len(report['gate'])} plans, "
          f"digest={report['landmark_schema_digest'][:16] if report['landmark_schema_digest'] else '?'}")
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=1, ensure_ascii=False),
                                   encoding="utf-8")
    return 0 if gate_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
