# -*- coding: utf-8 -*-
"""verify-r4 음성 probe (plan §R4 acceptance 5 — 변조→FAIL→복원→PASS, §R3 선례).

대상: stage19.rl4.json (기본; --stage로 변경). 각 probe는 산출물/코드 상수를 변조해
verify_r4가 fail-closed로 거부하는지 실증하고, 전부 복원 후 최종 PASS를 확인한다.
"""
import argparse, copy, io, json, sys
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve()
for p in ROOT.parents:
    if (p / "project.godot").exists():
        REPO = p
        break
else:
    REPO = Path("D:/Projects/godot/CandyAnts")
sys.path.insert(0, str(REPO / "tools" / "solver" / "rl"))
sys.path.insert(0, str(REPO / "tools" / "solver"))

import train  # noqa: E402
import landmarks  # noqa: E402


def run_verify(stage_id):
    buf = io.StringIO()
    with redirect_stdout(buf):
        rc = train.verify_r4(stage_id)
    return rc, buf.getvalue().strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stage", type=int, default=19)
    args = ap.parse_args()
    sid = args.stage
    path = train.rl4_json_path(sid)
    original_text = path.read_text(encoding="utf-8")
    base = json.loads(original_text)

    def write_mut(fn):
        d = copy.deepcopy(base)
        fn(d)
        path.write_text(json.dumps(d, ensure_ascii=False, indent=1), encoding="utf-8")

    # 산출물-변조 probe: (이름, 변조 함수)
    def m_grammar(d): d["rl_meta"]["grammar_version"] = "r2.1"                      # grammar 위장
    def m_lmdig(d): d["rl_meta"]["landmark_schema_digest"] = "0" * 16               # landmark 스키마 변조
    def m_mask(d): d["rl_meta"]["mask_digest"] = "deadbeef"                         # 후보 열거/마스크 drift
    def m_count(d): d["rl_meta"]["landmark_count"] = int(d["rl_meta"]["landmark_count"]) + 1
    def m_layout(d): d["rl_meta"]["layout_digest"] = "f" * 16                       # stale 레이아웃
    def m_kdig(d): d["rl_meta"]["knowledge_contract_digest"] = "1" * 8              # 내부 계약 digest 변조
    def m_budget(d): d["rl_meta"]["config"]["max_episodes"] = 5000                  # 예산 pin 변조
    def m_maxlen(d): d["rl_meta"]["config"]["max_len"] = 6                          # max_len pin 변조
    def m_seed(d): d["rl_meta"]["seeds"].append({"seed": 7, "cleared": True})       # 비-pinned seed
    def m_null(d): d["actions"] = None                                              # 클리어 해 없음
    def m_offgrid(d): d["actions"][0]["trigger"]["x"] = 99999.0                     # 오프그리드(인코딩 불가)

    probes = [
        ("grammar 위장(r2.1)", m_grammar),
        ("landmark_schema_digest 변조", m_lmdig),
        ("mask_digest 변조(열거 drift)", m_mask),
        ("landmark_count 변조", m_count),
        ("layout_digest 변조(stale)", m_layout),
        ("knowledge_contract_digest 변조", m_kdig),
        ("config.max_episodes 변조(5000)", m_budget),
        ("config.max_len 변조(6)", m_maxlen),
        ("비-pinned seed(7) 주입", m_seed),
        ("actions=null", m_null),
        ("오프그리드 trigger-x(99999)", m_offgrid),
    ]

    results = []
    try:
        for name, fn in probes:
            write_mut(fn)
            rc, out = run_verify(sid)
            detected = rc != 0
            results.append((name, detected, out.splitlines()[-1] if out else ""))
            print(f"[probe] {name}: {'FAIL 검출 OK' if detected else '!!! 미검출(gate 구멍)'}")
        # 코드-상수 probe (in-process monkeypatch)
        path.write_text(original_text, encoding="utf-8")  # 산출물은 원본으로
        cap0 = landmarks.LANDMARK_CANDIDATE_CAP
        landmarks.LANDMARK_CANDIDATE_CAP = 64
        rc, out = run_verify(sid)
        landmarks.LANDMARK_CANDIDATE_CAP = cap0
        detected = rc != 0
        results.append(("LANDMARK_CANDIDATE_CAP 코드 변조(64)", detected, ""))
        print(f"[probe] LANDMARK_CANDIDATE_CAP 코드 변조(64): {'FAIL 검출 OK' if detected else '!!! 미검출'}")

        k0 = train.KNOWLEDGE["new_token"]
        train.KNOWLEDGE["new_token"] = 0.99
        rc, out = run_verify(sid)
        train.KNOWLEDGE["new_token"] = k0
        detected = rc != 0
        results.append(("KNOWLEDGE 코드 상수 변조", detected, ""))
        print(f"[probe] KNOWLEDGE 코드 상수 변조: {'FAIL 검출 OK' if detected else '!!! 미검출'}")
    finally:
        path.write_text(original_text, encoding="utf-8")

    # 복원 후 최종 PASS(replay x2 포함)
    rc, out = run_verify(sid)
    print(f"[restore] verify-r4 stage{sid}: {'PASS' if rc == 0 else 'FAIL(복원 실패!)'}")
    print(out.splitlines()[-1] if out else "")

    n_ok = sum(1 for _, d, _ in results if d)
    print(f"\n=== 집계: 음성 {n_ok}/{len(results)} 검출, 복원 {'PASS' if rc == 0 else 'FAIL'} ===")
    return 0 if (n_ok == len(results) and rc == 0) else 1


if __name__ == "__main__":
    sys.exit(main())
