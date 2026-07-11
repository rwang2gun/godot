#!/usr/bin/env python3
"""solution_registry — 스테이지별 '정리된 해' 레지스트리 (2026-07-11 사용자 계약).

계약:
  - **중복 기준 = 실행-결과 동치**: 결정론 리플레이의 개미 궤적(trace)+판정(saved/frame) digest가
    같으면 같은 해. 트리거 표현이 달라도(S1: xle17/any vs pick>=2/carrying vs xle18+y밴드 — 전부
    frame 1587 동일 실행) 엔진에서 같은 일이 일어나면 중복, 배치가 실제로 다르면(S5 sand_mound
    (13,8)/(18,8)/(15,9)) 복수 해. trace 부재 런은 플랜-정규화 키(plan_key)로 보수적 폴백(과분할 허용).
  - **레벨 변경 시 파기**: 레지스트리는 레벨 컨텐츠 digest(stage .tres + layout .tres + .tscn)에
    바인딩. 기록 시점에 digest가 다르면 기존 해 전부 파기하고 새 레벨 기준으로 재시작.
  - **신규만 기록**: 이미 정리된 해와 중복이면 seeds/runs 카운트만 갱신(사이드카·log 미기록).

파일: data/solutions/found/stageNN.solutions.json (스테이지당 1개, 원자적 교체).
뷰어(found_viewer)는 레지스트리가 있는 스테이지는 레지스트리를 권위로 쓰고, 없는 스테이지만
레거시 사이드카/log를 읽는다.

CLI:  python tools/solver/solution_registry.py --migrate   # 레거시 found 기록+replay_cache로부터
      레지스트리 일괄 생성(현재 레벨 digest로 스탬프 — 레벨이 그 후 안 바뀌었다는 전제의 1회 이행).
"""
from __future__ import annotations

import hashlib
import json
import os
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FOUND_DIR = REPO / "data" / "solutions" / "found"
CELL = 48


# ---------- 플랜 정규화 (트리거 표현 무관 보조 키) ----------

def canon_action(a: dict, cs: int = CELL) -> tuple:
    """액션 동치 서명 — 좌표는 셀 양자화, frame은 60f(1s) 버킷. 실행-동치보다 거친 보조 키."""
    t = a.get("target", {}) or {}
    tr = a.get("trigger", {}) or {}
    if t.get("mode") == "cell":
        tgt: tuple = ("cell", tuple(t.get("cell") or ()))
    else:
        band = None
        if t.get("y_min") is not None and t.get("y_max") is not None:
            band = (int(float(t["y_min"]) // cs), int(float(t["y_max"]) // cs))
        tgt = ("ant", t.get("select"), t.get("state") or "any", band)
    typ = tr.get("type")
    if typ == "ant_reaches_x":
        trg: tuple = (typ, tr.get("cmp"), int(float(tr.get("x") or 0) // cs))
    elif typ == "picked_ge":
        trg = (typ, tr.get("n"))
    elif typ in ("at_frame", "at_frame_exact"):
        trg = (typ, int(float(tr.get("frame") or 0) // 60))
    else:
        trg = (typ, json.dumps({k: v for k, v in tr.items() if k != "type"},
                               sort_keys=True, ensure_ascii=False))
    return (a.get("skill"), tgt, trg)


def plan_key(actions: list[dict]) -> str:
    """플랜의 정규화 키(액션 순서 무관) — trace 부재 시 중복 판정 폴백."""
    sigs = sorted(repr(canon_action(a)) for a in (actions or []))
    return hashlib.sha256("\n".join(sigs).encode("utf-8")).hexdigest()[:16]


# ---------- 실행-결과 동치 키 ----------

def exec_digest(res: dict) -> str | None:
    """롤아웃/리플레이 결과의 실행 동치 digest — trace(스폰인덱스 정규화) + saved + frame.
    trace가 없으면 None(호출측이 plan_key 폴백)."""
    trace = res.get("trace")
    if not trace:
        return None
    norm = {str(k): trace[k] for k in sorted(trace, key=lambda x: int(x))}
    payload = json.dumps({"trace": norm, "saved": res.get("saved"),
                          "frame": res.get("frame")},
                         sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


# ---------- 레벨 digest (파기 트리거) ----------

def level_digest(stage_id: int) -> str | None:
    """레벨 컨텐츠 digest — 스테이지 .tres + layout .tres + .tscn 바이트 결합 sha256.
    (_exec_config_digest stage_resource_digest와 같은 트리오. 파일 없으면 None = 바인딩 불가.)"""
    files = [REPO / "data" / "stages" / f"stage{stage_id:02d}.tres",
             REPO / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres",
             REPO / "scenes" / "stages" / f"Stage{stage_id:02d}.tscn"]
    h = hashlib.sha256()
    for p in files:
        if not p.exists():
            return None
        h.update(p.read_bytes())
    return h.hexdigest()[:16]


# ---------- 레지스트리 I/O ----------

def registry_path(stage_id: int, found_dir: Path = FOUND_DIR) -> Path:
    return found_dir / f"stage{stage_id:02d}.solutions.json"


def load_registry(stage_id: int, found_dir: Path = FOUND_DIR) -> dict | None:
    p = registry_path(stage_id, found_dir)
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def _save(reg: dict, found_dir: Path) -> None:
    p = registry_path(reg["stage_id"], found_dir)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(reg, indent=1, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, p)


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def record_clear(rec: dict, res: dict, found_dir: Path = FOUND_DIR) -> str:
    """클리어 해 1건을 레지스트리에 반영. 반환 = "new"(신규 해) / "dup"(중복 — 카운트만 갱신)
    / "reset"(레벨 변경 감지 → 기존 해 파기 후 신규 등록).

    rec = train.py found 레코드(stage_id/seed/actions/saved/frame/... 포함),
    res = 해당 클리어의 롤아웃 결과(trace 포함 시 실행-동치 키, 아니면 plan_key 폴백)."""
    sid = int(rec["stage_id"])
    cur_digest = level_digest(sid)
    reg = load_registry(sid, found_dir)
    outcome = "new"
    if reg is None or (cur_digest is not None and reg.get("level_digest") != cur_digest):
        if reg is not None:
            outcome = "reset"  # 레벨 변경 → 기존 해 파기(사용자 계약)
        reg = {"stage_id": sid, "stage": rec.get("stage"), "level_digest": cur_digest,
               "updated": _now(), "solutions": []}

    ed = exec_digest(res)
    pk = plan_key(rec.get("actions") or [])
    seed = rec.get("seed")
    for sol in reg["solutions"]:
        same = (ed is not None and sol.get("exec_digest") == ed) or \
               (ed is None and sol.get("exec_digest") is None and sol.get("plan_key") == pk)
        if same:
            if seed is not None and seed not in sol["seeds"]:
                sol["seeds"].append(seed)
                sol["seeds"].sort()
            sol["runs"] = int(sol.get("runs") or 0) + 1
            sol["last_ts"] = rec.get("ts") or _now()
            reg["updated"] = _now()
            _save(reg, found_dir)
            return "dup" if outcome == "new" else outcome

    reg["solutions"].append({
        "exec_digest": ed,
        "plan_key": pk,
        "actions": rec.get("actions") or [],
        "saved": rec.get("saved"), "frame": rec.get("frame"), "hp": rec.get("hp"),
        "seeds": [seed] if seed is not None else [],
        "runs": 1,
        "first_ts": rec.get("ts") or _now(), "last_ts": rec.get("ts") or _now(),
        "grammar": rec.get("grammar"), "episodes": rec.get("episodes"),
        "deadline_frames": rec.get("deadline_frames"),
        "inventory": rec.get("inventory") or {},
        "stage": rec.get("stage"),
    })
    reg["updated"] = _now()
    _save(reg, found_dir)
    return outcome


# ---------- 레거시 이행 ----------

def migrate(found_dir: Path = FOUND_DIR, stage_max: int = 25) -> None:
    """레거시 *.found.json + log.jsonl (+ replay_cache trace)로 레지스트리 일괄 생성.
    현재 레벨 digest로 스탬프 — '그 해들이 현재 레벨에서 발견됐다'는 전제의 1회 이행 도구.
    replay_cache에 trace가 있으면 실행-동치 키, 없으면 plan_key 폴백."""
    records: list[dict] = []
    for p in sorted(found_dir.glob("*.found.json")):
        try:
            records.append(json.loads(p.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError):
            pass
    log = found_dir / "log.jsonl"
    if log.exists():
        for line in log.read_text(encoding="utf-8").splitlines():
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    cache_dir = found_dir / "replay_cache"
    n_new = n_dup = n_skip = 0
    for rec in sorted(records, key=lambda r: str(r.get("ts", ""))):
        sid = rec.get("stage_id")
        if not isinstance(sid, int) or not (1 <= sid <= stage_max):
            continue
        # 레지스트리 = "현재 레벨에서 검증된 해"만 — 현재 레벨로 리플레이된 캐시(cleared)가 있는
        # 기록만 이행. 캐시 없는 옛 기록은 스킵(log.jsonl 히스토리에 잔존, 필요 시 --replay 후 재이행).
        key_payload = json.dumps({"stage": rec.get("stage"),
                                  "deadline": rec.get("deadline_frames") or 6000,
                                  "actions": rec.get("actions") or []},
                                 sort_keys=True, ensure_ascii=False)
        ck = hashlib.sha256(key_payload.encode("utf-8")).hexdigest()[:16]
        cpath = cache_dir / f"stage{sid:02d}_{ck}.json"
        if not cpath.exists():
            n_skip += 1
            continue
        try:
            res = json.loads(cpath.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            n_skip += 1
            continue
        if not res.get("cleared") or not res.get("trace"):
            n_skip += 1
            continue
        out = record_clear(rec, res, found_dir)
        if out in ("new", "reset"):
            n_new += 1
        else:
            n_dup += 1
    print(f"migrate: 신규 {n_new} · 중복 흡수 {n_dup} · 스킵(캐시 부재/미클리어) {n_skip}")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--migrate", action="store_true", help="레거시 기록 → 레지스트리 일괄 이행")
    ap.add_argument("--found-dir", type=Path, default=FOUND_DIR)
    args = ap.parse_args()
    if args.migrate:
        migrate(args.found_dir)
    else:
        ap.print_help()
