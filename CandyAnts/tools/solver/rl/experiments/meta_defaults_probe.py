#!/usr/bin/env python3
"""stage_meta 기본값 ↔ 엔진 StageData.gd @export 기본값 정합 probe (2026-07-14 §4.1 분모 버그 회귀 가드).

배경: solve.py stage_meta의 _int 기본값이 엔진 기본과 어긋나면, .tres에 필드를 생략한 스테이지에서
python측 meta가 엔진 실제와 다른 상수로 굳는다 — 실증 사례 = total_ants 기본 0 → mdp
ants_total=max(1,0)=1 → shaping retired 항·blocker_bonus 분모 10× 축소(S24·S25, S25 bestR 2.280
재구성으로 확정). 이 probe는 그 "재이탈"을 구조적으로 차단한다:
  ① StageData.gd에서 @export 기본값을 직접 파싱해 stage_meta의 필드-생략 기본값과 대조
     (한쪽만 바뀌면 즉시 FAIL — 하드코딩 기대값이 아니라 엔진 소스가 SoT).
  ② 명시값 경로: 필드가 있으면 그 값 그대로(기본값 미개입).
  ③ 명시 ↔ 기본 동치: 엔진 기본과 같은 값을 명시한 tres == 필드 생략 tres (2026-07-14 §4 검증 (c)).
  ④ 실전 대조: total_ants 미지정 스테이지(24·25)가 엔진 기본(10)으로 파싱되는지.

실행: PYTHONIOENCODING=utf-8 python tools/solver/rl/experiments/meta_defaults_probe.py  (Godot 불요)
"""
from __future__ import annotations

import re
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]                                  # .../CandyAnts
sys.path.insert(0, str(REPO / "tools" / "solver"))
import solve  # noqa: E402

STAGEDATA = REPO / "scripts" / "core" / "StageData.gd"
# stage_meta가 기본값을 갖는 스칼라 필드 ↔ StageData @export 대응 (신규 필드 추가 시 여기 등재)
FIELDS = ("total_ants", "candy_hp", "time_limit_seconds")


def engine_defaults() -> dict:
    """StageData.gd @export 기본값 파싱 — 엔진측 SoT. 필드를 못 찾으면 probe FAIL(파싱 규칙이
    엔진 소스 변화를 못 따라가는 것도 결함)."""
    src = STAGEDATA.read_text(encoding="utf-8")
    out = {}
    for f in FIELDS:
        m = re.search(rf"@export var {f}\s*:\s*(?:int|float)\s*=\s*([\d.]+)", src)
        assert m, f"StageData.gd에서 @export {f} 기본값을 찾지 못함 — probe 파싱 규칙 갱신 필요"
        out[f] = float(m.group(1))
    return out


def meta_from(content: str) -> dict:
    with tempfile.NamedTemporaryFile("w", suffix=".tres", delete=False,
                                     encoding="utf-8") as tf:
        tf.write(content)
        p = tf.name
    try:
        return solve.stage_meta(0, tres_path=p)
    finally:
        Path(p).unlink(missing_ok=True)


def main() -> int:
    n = 0

    def ok(cond, msg):
        nonlocal n
        assert cond, msg
        n += 1
        print(f"  PASS {msg}")

    eng = engine_defaults()

    # ① 필드 전부 생략 → stage_meta 기본 == 엔진 기본 (양측 SoT 대조 — 재이탈 차단 본체)
    empty = meta_from("script = null\n")
    for f in FIELDS:
        ok(float(empty[f]) == eng[f],
           f"기본값 정합 {f}: stage_meta={empty[f]} == StageData.gd={eng[f]}")

    # ② 명시값 경로 — 기본값 미개입
    explicit = meta_from("total_ants = 7\ncandy_hp = 3\ntime_limit_seconds = 45.5\n")
    ok(explicit["total_ants"] == 7 and isinstance(explicit["total_ants"], int), "명시 total_ants=7")
    ok(explicit["candy_hp"] == 3, "명시 candy_hp=3")
    ok(explicit["time_limit_seconds"] == 45.5, "명시 time_limit_seconds=45.5")

    # ③ 엔진 기본과 같은 값 명시 ↔ 생략 동치 (2026-07-14 §4 검증 (c))
    spelled = meta_from("".join(
        f"{f} = {int(eng[f]) if eng[f].is_integer() and f != 'time_limit_seconds' else eng[f]}\n"
        for f in FIELDS))
    for f in FIELDS:
        ok(float(spelled[f]) == float(empty[f]), f"명시↔기본 동치 {f}")

    # ④ 실전: total_ants 미지정 스테이지(S24·S25)가 엔진 기본으로 파싱
    for sid in (24, 25):
        m = solve.stage_meta(sid)
        ok(float(m["total_ants"]) == eng["total_ants"],
           f"stage{sid} total_ants={m['total_ants']} (엔진 기본 {int(eng['total_ants'])})")
    # 대조군: 명시 스테이지는 명시값 유지 (S21=8, S10=5)
    ok(solve.stage_meta(21)["total_ants"] == 8, "stage21 total_ants=8 (명시값 유지)")
    ok(solve.stage_meta(10)["total_ants"] == 5, "stage10 total_ants=5 (명시값 유지)")

    print(f"=== meta_defaults_probe: {n}/{n} PASS ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
