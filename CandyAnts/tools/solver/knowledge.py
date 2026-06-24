#!/usr/bin/env python3
"""
auto-solver Phase 4 (CBR/EBL) — 지식 볼트 파서·검색 (순수 / 엔진 비의존).

`knowledge/` Obsidian 볼트(마크다운+frontmatter+[[위키링크]])를 읽어, 솔버가 **위기 상황 → 링크된
도구 조회**(사용자 2026-06-24)로 답을 찾게 한다. model.py/tactics.py처럼 순수(subprocess 0).

검색 흐름:
  diagnose 신호(물 익사 가장자리·carry 갇힘·낙하사·사탕 미도달) → detect_crises로 crisis 노트 매칭 →
  그 노트의 resolves_with_skills/factors 링크 → solve가 후보 생성·우선순위·pruning에 사용.

외부 의존 없음: frontmatter는 flow 스칼라/리스트(`[a, b]`)·flow 맵(`{k: v}`)만 쓰는 단순형이라 미니 파서로 충분.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # tools/solver
VAULT = HERE / "knowledge"

for _s in (sys.stdout, sys.stderr):              # cp949 무관 UTF-8(다른 솔버 모듈과 동일)
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

_WIKILINK = re.compile(r"\[\[([a-z0-9-]+)\]\]")
_FM = re.compile(r"^---\n(.*?)\n---\n", re.S)


def _parse_value(v: str):
    v = v.strip()
    if v.startswith("[") and v.endswith("]"):
        inner = v[1:-1].strip()
        return [x.strip() for x in inner.split(",") if x.strip()] if inner else []
    if v.startswith("{") and v.endswith("}"):
        d = {}
        for pair in v[1:-1].split(","):
            if ":" in pair:
                k, val = pair.split(":", 1)
                d[k.strip()] = val.strip()
        return d
    return v


def _parse_frontmatter(text: str) -> dict:
    m = _FM.match(text)
    if not m:
        return {}
    fm: dict = {}
    for line in m.group(1).splitlines():
        line = line.rstrip()
        if not line or line.lstrip().startswith("#") or line.startswith(" "):
            continue                              # 들여쓴 줄(중첩)은 단순 무시(현 스키마 미사용)
        mm = re.match(r"^([\w-]+):\s*(.*)$", line)
        if mm:
            fm[mm.group(1)] = _parse_value(mm.group(2))
    return fm


def load_vault(path: Path = VAULT) -> dict:
    """볼트의 모든 노트(README 제외)를 {id: note}로. note = {id,type,fm,links,path}."""
    notes: dict = {}
    for md in sorted(path.rglob("*.md")):
        if md.name == "README.md":
            continue
        text = md.read_text(encoding="utf-8")
        fm = _parse_frontmatter(text)
        notes[md.stem] = {
            "id": md.stem, "type": fm.get("type"), "fm": fm,
            "links": sorted(set(_WIKILINK.findall(text))),
            "path": md.relative_to(path).as_posix(),
        }
    return notes


def dangling_links(notes: dict) -> dict:
    """타깃 노트가 없는 [[링크]] → {note_id: [missing,...]}. 볼트 무결성 점검."""
    out: dict = {}
    for n in notes.values():
        miss = [lk for lk in n["links"] if lk not in notes]
        if miss:
            out[n["id"]] = miss
    return out


def detect_crises(notes: dict, diag: dict, retired: dict | None = None,
                  trapped: dict | None = None) -> list[dict]:
    """diagnose 신호로 발화한 detect 토큰을 모아, 일치하는 crisis 노트를 반환.
    diag=model.diagnose(...), retired=model.count_retired(...), trapped={'carry':..,'total':..}."""
    retired = retired or {}
    trapped = trapped or {}
    fired: set = set()
    if any(t.get("to_water") for t in diag.get("reverse_targets", [])):
        fired.add("reverse_target.to_water")
    if retired.get("water", 0) > 0:
        fired.add("count_retired.water")
    if retired.get("fall", 0) > 0:
        fired.add("count_retired.fall")
    if trapped.get("carry", 0) > 0:
        fired.add("count_trapped.carry")
    if diag.get("picked_total", 0) < diag.get("candy_hp", 0):
        fired.add("picked_lt_hp")
    out = []
    for n in notes.values():
        if n["type"] != "crisis":
            continue
        det = n["fm"].get("detect", [])
        det = det if isinstance(det, list) else [det]
        if any(d in fired for d in det):
            out.append(n)
    return out


def resolve(notes: dict, diag: dict, retired: dict | None = None,
            trapped: dict | None = None) -> list[dict]:
    """위기 검색 결과: [{crisis, severity, skills, factors}] — solve가 후보 생성/우선순위에 사용."""
    res = []
    for c in detect_crises(notes, diag, retired, trapped):
        fm = c["fm"]
        res.append({
            "crisis": c["id"], "severity": fm.get("severity"),
            "skills": fm.get("resolves_with_skills", []),
            "factors": fm.get("resolves_with_factors", []),
        })
    return res


_REVERSE_LABEL = re.compile(r"^(?P<sid>\w+)@(?P<col>-?\d+),(?P<row>-?\d+):\w+?(?:ge|le)$")


def _cand_cell(cand: dict):
    """reverse 분기 후보 label에서 (col,row) 복원. 비-reverse label은 None."""
    m = _REVERSE_LABEL.match(cand.get("label", ""))
    return (int(m.group("col")), int(m.group("row"))) if m else None


def vault_prune(notes: dict, diag: dict, cands: list, retired: dict | None = None,
                trapped: dict | None = None):
    """위기 검색으로 활성화된 요소에 따라 후보를 prune. 반환 (filtered_cands, pruned_count, pruned_actions).

    현 규칙(de-risk 레버, [[backpath-offset]] 요소): 물 익사 위기에서 reverse 후보의 backpath **형제(off>=1)**를
    제거하고 off=0(가장자리 셀 자신)만 남긴다 — 휴리스틱이 형제마다 롤аут을 낭비하는 걸 막는다(S12 8→감소 기대).
    off=0 근거는 stage11/12 실측(현재까지 off=0이 정답). off 선택의 국소-패턴 의존은 미해결(누적 학습) →
    이 prune은 **현 볼트 지식이 보증하는 범위**의 잠정 규칙이며, vault_fn OFF(기본 search/게이트)에는 영향 없음.
    """
    for c in cands:
        c.setdefault("source", "fallback")
    factors = set()
    for c in detect_crises(notes, diag, retired, trapped):
        for f in c["fm"].get("resolves_with_factors", []):
            factors.add(f)
    if "backpath-offset" not in factors:
        return cands, 0, []
    # 물-가장자리 backpath off 맵: cell -> 최소 off.
    water_off: dict = {}
    for tgt in diag.get("reverse_targets", []):
        if not tgt.get("to_water"):
            continue
        bp = tgt.get("backpath") or [tgt.get("cell")]
        for off, cell in enumerate(bp):
            if cell is not None:
                water_off.setdefault(tuple(cell), off)
    kept, pruned_acts = [], []
    for cand in cands:
        cell = _cand_cell(cand)
        if cell is not None and cell in water_off:
            if water_off[cell] == 0:
                cand["source"] = "vault:water-drowning"   # off=0 물-가장자리(볼트 보증) — pruning 생존
                kept.append(cand)
            else:
                pruned_acts.append(cand["action"])         # off>=1 형제 — prune(반사실 검증용 액션 기록)
        else:
            kept.append(cand)                              # 비-물-가장자리 후보는 통과(fallback)
    return kept, len(pruned_acts), pruned_acts


def _selftest() -> int:
    """볼트 로드 + 무결성(dangling) + crisis 검색 데모. exit 0=OK / 1=문제."""
    notes = load_vault()
    by_type: dict = {}
    for n in notes.values():
        by_type.setdefault(n["type"], []).append(n["id"])
    print("=== knowledge vault ===")
    for t in sorted(by_type, key=lambda x: str(x)):
        print(f"  {t}: {len(by_type[t])}  {by_type[t]}")
    dangling = dangling_links(notes)
    if dangling:
        print("\n[dangling links] (타깃 노트 없음 — 앞으로 채울 것):")
        for nid, miss in sorted(dangling.items()):
            print(f"  {nid} → {miss}")
    # 데모: 물 익사 가장자리 진단 → 위기 검색
    fake_diag = {"reverse_targets": [{"to_water": True, "cell": (6, 11)}],
                 "picked_total": 0, "candy_hp": 4}
    print("\n=== 데모: diagnose(물 익사 가장자리) → 위기 검색 ===")
    for r in resolve(notes, fake_diag, retired={"water": 1, "fall": 0}, trapped={"carry": 0}):
        print(f"  위기 [{r['crisis']}] ({r['severity']}) → 도구 {r['skills']} · 요소 {r['factors']}")
    # crisis 노트가 가리킨 skill/factor가 실제 노트로 존재하는지(검색 가능성) 확인
    missing_targets = []
    for n in notes.values():
        if n["type"] != "crisis":
            continue
        for ref in n["fm"].get("resolves_with_skills", []) + n["fm"].get("resolves_with_factors", []):
            if ref not in notes:
                missing_targets.append((n["id"], ref))
    if missing_targets:
        print("\n[FAIL] crisis가 가리킨 도구/요소 노트 없음:", missing_targets)
        return 1
    # 실-신호 검출(re-review R1 MEDIUM): reverse_target.to_water 외 retired/trapped 신호도 위기를 발화해야 한다.
    checks = [
        ("water-drowning", {"reverse_targets": [], "picked_total": 1, "candy_hp": 1}, {"water": 1}, {}),
        ("fall-death", {"reverse_targets": [], "picked_total": 1, "candy_hp": 1}, {"fall": 1}, {}),
        ("carry-trapped", {"reverse_targets": [], "picked_total": 1, "candy_hp": 1}, {}, {"carry": 1}),
    ]
    print("\n=== 검출 신호 커버리지(retired/trapped 포함) ===")
    for cid, d, ret, trp in checks:
        ids = {c["id"] for c in detect_crises(notes, d, ret, trp)}
        ok = cid in ids
        print(f"  {ret or trp} → {sorted(ids)}  [{'OK' if ok else 'FAIL'} expect {cid}]")
        if not ok:
            print(f"\n[FAIL] 신호가 위기 {cid}를 발화 못 함 — detect 매핑 점검.")
            return 1
    print("\nknowledge selftest PASS — 볼트 로드·crisis 검색·링크 타깃·신호 커버리지 정합.")
    return 0


if __name__ == "__main__":
    raise SystemExit(_selftest())
