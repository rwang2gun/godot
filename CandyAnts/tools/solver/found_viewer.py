#!/usr/bin/env python3
"""found_viewer — data/solutions/found/ 에 기록된 해(solution)를 자기완결 HTML로 렌더링.

RL/휴리스틱 솔버가 해를 찾는 즉시 durable 기록으로 남기는
`*.found.json`(클리어 해) / `*.partial.json`(미클리어 최고-진척 플랜) 사이드카와
`log.jsonl` / `partials.jsonl` 을 읽어, 브라우저에서 바로 열어볼 수 있는
단일 HTML 파일(`found/index.html`)을 생성한다. 외부 의존성 없음(파일 더블클릭으로 열림).

보고 계약(2026-07-11 사용자):
  - 클리어 해는 **solution-class 중복 제거 후 전부** 보고 — 동치 서명 = 액션별
    (skill, target 정규화, trigger 정규화; x·y밴드는 셀 양자화, frame은 60f 버킷) 정렬 튜플.
    같은 class를 찾은 seed들은 한 카드로 합치고 seed 목록을 표기한다.
  - 클리어가 하나도 없는 스테이지는 **최고-진척(partial) 플랜**을 대신 보고.
  - `--replay` 시 각 고유 해/부분해를 결정론 리플레이(trace)해 개미 **궤적**(빈손/운반 색 분리,
    낙오 ✕)을 레벨 SVG에 겹친다. 결과는 replay_cache/ 에 플랜-해시로 캐시(재빌드 오프라인).

사용:  python tools/solver/found_viewer.py            # 기본 경로로 index.html 갱신(오프라인)
       python tools/solver/found_viewer.py --replay   # 캐시 없는 해를 리플레이해 궤적/지표 채움
       python tools/solver/found_viewer.py --open     # 생성 후 브라우저로 열기
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import sys
import webbrowser
from pathlib import Path

import level_render
import solution_registry

REPO = Path(__file__).resolve().parents[2]
FOUND_DIR = REPO / "data" / "solutions" / "found"
CELL = 48


# ---------- 로딩 ----------

def _load_latest(found_dir: Path, sidecar_glob: str, jsonl_name: str) -> list[dict]:
    """사이드카 + jsonl을 모아 (stage_id, seed) 기준 최신 ts만 남긴다."""
    records: list[dict] = []
    for path in sorted(found_dir.glob(sidecar_glob)):
        try:
            records.append(json.loads(path.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError) as exc:
            print(f"warn: skip {path.name}: {exc}", file=sys.stderr)
    log = found_dir / jsonl_name
    if log.exists():
        for line in log.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as exc:
                print(f"warn: skip {jsonl_name} line: {exc}", file=sys.stderr)
    best: dict[tuple, dict] = {}
    for rec in records:
        key = (rec.get("stage_id"), rec.get("seed"))
        cur = best.get(key)
        if cur is None or str(rec.get("ts", "")) >= str(cur.get("ts", "")):
            best[key] = rec
    return sorted(best.values(), key=lambda r: (r.get("stage_id") or 0, r.get("seed") or 0))


def load_found(found_dir: Path) -> list[dict]:
    return _load_latest(found_dir, "*.found.json", "log.jsonl")


def load_partials(found_dir: Path) -> list[dict]:
    return _load_latest(found_dir, "*.partial.json", "partials.jsonl")


def parse_stages(spec: str) -> set[int]:
    """"1-25" / "3,7,20-25" 형태를 정수 집합으로 (sweep_stages.py와 동일 규약)."""
    out: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if "-" in part:
            a, b = part.split("-", 1)
            out.update(range(int(a), int(b) + 1))
        else:
            out.add(int(part))
    return out


def load_registries(found_dir: Path, keep: set[int] | None
                    ) -> tuple[list[dict], set[int], set[int]]:
    """stageNN.solutions.json(권위) 로드 → (카드 레코드들, 레지스트리 보유 스테이지, 파기-대기 스테이지).
    레벨 digest가 현재와 다른 레지스트리 = 파기 대기: 해를 보고서에서 제외하고 표기만 한다
    (실제 파기는 다음 학습 기록 시 record_clear가 수행)."""
    recs: list[dict] = []
    covered: set[int] = set()
    stale: set[int] = set()
    for p in sorted(found_dir.glob("*.solutions.json")):
        try:
            reg = json.loads(p.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            print(f"warn: skip {p.name}: {exc}", file=sys.stderr)
            continue
        sid = reg.get("stage_id")
        if keep is not None and sid not in keep:
            continue
        cur = solution_registry.level_digest(sid) if isinstance(sid, int) else None
        if reg.get("level_digest") and cur and reg["level_digest"] != cur:
            print(f"warn: stage{sid:02d} 레벨 변경 감지 — 등재 해 {len(reg.get('solutions', []))}개 "
                  f"파기 대기(다음 학습 기록 시 리셋)", file=sys.stderr)
            covered.add(sid)
            stale.add(sid)
            continue
        covered.add(sid)
        for sol in reg.get("solutions", []):
            rec = dict(sol)
            rec["stage_id"] = sid
            rec.setdefault("stage", reg.get("stage"))
            rec["ts"] = sol.get("last_ts") or sol.get("first_ts") or ""
            rec["_seeds"] = set(sol.get("seeds") or [])
            rec["_runs"] = int(sol.get("runs") or 1)
            recs.append(rec)
    return recs, covered, stale


# ---------- solution-class 중복 제거 (정규화 로직 = solution_registry 단일 출처) ----------

def class_key(rec: dict) -> tuple:
    """레거시(레지스트리 없는 스테이지) 중복 제거 키 — 플랜 정규화(solution_registry.plan_key).
    레지스트리가 있는 스테이지는 기록 시점에 실행-동치(trace digest)로 이미 정리돼 있다."""
    return (rec.get("stage_id"), solution_registry.plan_key(rec.get("actions") or []))


def dedup_by_class(records: list[dict], better) -> list[dict]:
    """class_key로 병합. 대표 = better(a, b)가 고른 레코드. 병합 메타(_seeds/_runs)를 대표에 부착."""
    groups: dict[tuple, dict] = {}
    for rec in records:
        key = class_key(rec)
        g = groups.get(key)
        if g is None:
            rec = dict(rec)
            rec["_seeds"] = {rec.get("seed")}
            rec["_runs"] = 1
            groups[key] = rec
        else:
            g["_seeds"].add(rec.get("seed"))
            g["_runs"] += 1
            if better(rec, g):
                keep_seeds, keep_runs = g["_seeds"], g["_runs"]
                rec = dict(rec)
                rec["_seeds"], rec["_runs"] = keep_seeds, keep_runs
                groups[key] = rec
    return sorted(groups.values(),
                  key=lambda r: (r.get("stage_id") or 0, min(s for s in r["_seeds"] if s is not None)
                                 if any(s is not None for s in r["_seeds"]) else 0))


def _found_better(a: dict, b: dict) -> bool:
    """클리어 해 대표 선정 — 더 빠른 클리어(frame 오름차순), 동률이면 최신."""
    fa, fb = a.get("frame") or 10 ** 9, b.get("frame") or 10 ** 9
    if fa != fb:
        return fa < fb
    return str(a.get("ts", "")) >= str(b.get("ts", ""))


def _partial_better(a: dict, b: dict) -> bool:
    """부분해 대표 선정 — 리플레이 지표(구출→픽업) 우선, 없으면 best_reward."""
    ra, rb = a.get("_replay") or {}, b.get("_replay") or {}
    ka = (ra.get("saved") or 0, ra.get("picked_total") or 0, a.get("best_reward") or float("-inf"))
    kb = (rb.get("saved") or 0, rb.get("picked_total") or 0, b.get("best_reward") or float("-inf"))
    return ka > kb


# ---------- 리플레이(궤적·지표) 캐시 ----------

def _replay_key(rec: dict) -> str:
    payload = json.dumps({"stage": rec.get("stage"),
                          "deadline": rec.get("deadline_frames") or 6000,
                          "actions": rec.get("actions") or []},
                         sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def attach_replays(records: list[dict], found_dir: Path, do_replay: bool) -> None:
    """각 레코드에 캐시된 리플레이 결과(_replay: trace+지표)를 붙인다.
    do_replay=True면 캐시 미스를 결정론 리플레이(solve.run_plan, D4 무수정 verdict)로 채운다."""
    cache_dir = found_dir / "replay_cache"
    run_plan = None
    for rec in records:
        key = _replay_key(rec)
        cpath = cache_dir / f"stage{(rec.get('stage_id') or 0):02d}_{key}.json"
        if cpath.exists():
            try:
                rec["_replay"] = json.loads(cpath.read_text(encoding="utf-8"))
                continue
            except (json.JSONDecodeError, OSError):
                pass
        if not do_replay:
            continue
        if run_plan is None:
            import solve  # 지연 import — 오프라인 빌드는 solve/Godot 불요
            run_plan = solve.run_plan
        try:
            res = run_plan(rec["stage"], rec.get("actions") or [],
                           rec.get("deadline_frames") or 6000, trace=True)
        except Exception as exc:  # noqa: BLE001 — 리플레이 실패해도 카드는 나와야 함
            print(f"warn: replay stage{rec.get('stage_id')}: {exc}", file=sys.stderr)
            continue
        if not isinstance(res, dict):
            print(f"warn: replay stage{rec.get('stage_id')}: SOLVER_RESULT 없음", file=sys.stderr)
            continue
        cache_dir.mkdir(parents=True, exist_ok=True)
        cpath.write_text(json.dumps(res, ensure_ascii=False), encoding="utf-8")
        rec["_replay"] = res
        print(f"replayed stage{rec.get('stage_id'):02d} "
              f"saved={res.get('saved')} frame={res.get('frame')} → {cpath.name}")


# ---------- 렌더링 ----------

def build_level_svg(rec: dict) -> str:
    """레코드의 stage → 레이아웃/스폰/analysis/궤적을 찾아 레벨 SVG 생성. 실패 시 빈 문자열."""
    scene = rec.get("stage", "")
    slug = Path(scene).stem  # "Stage11"
    if not slug:
        return ""
    layout_path = REPO / "data" / "stage_layouts" / f"{slug.lower()}_layout.tres"
    if not layout_path.exists():
        return ""
    try:
        layout = level_render.parse_layout(layout_path)
        spawn = level_render.parse_spawn(REPO / "scenes" / "stages" / f"{slug}.tscn")
        actions = rec.get("actions", [])
        resolved = None
        ana = REPO / "data" / "solutions" / f"{slug.lower()}.analysis.json"
        if ana.exists():
            try:
                pa = json.loads(ana.read_text(encoding="utf-8")).get("per_action", [])
                pts = [x.get("target", {}).get("target_pos") for x in pa]
                if len(pts) == len(actions) and all(pts):
                    resolved = pts
            except (json.JSONDecodeError, OSError):
                pass
        trace = (rec.get("_replay") or {}).get("trace") or None
        return level_render.render_svg(layout, actions, spawn=spawn,
                                       resolved=resolved, trace=trace)
    except Exception as exc:  # noqa: BLE001 — 렌더 실패해도 카드는 나와야 함
        print(f"warn: level svg {slug}: {exc}", file=sys.stderr)
        return ""


def fmt_target(t: dict) -> str:
    """action target 딕셔너리를 사람이 읽을 문자열로."""
    mode = t.get("mode")
    if mode == "cell":
        cx, cy = t.get("cell", [None, None])
        return f"칸 ({cx}, {cy})"
    if mode == "ant":
        bits = []
        sel = t.get("select")
        if sel:
            bits.append({"max_x": "가장 앞선", "min_x": "가장 뒤쳐진"}.get(sel, sel))
        bits.append("개미")
        state = t.get("state")
        if state and state != "any":
            bits.append(f"[{ {'carrying': '운반중', 'walker': '이동중'}.get(state, state) }]")
        y_min, y_max = t.get("y_min"), t.get("y_max")
        if y_min is not None and y_max is not None:
            bits.append(f"(y {y_min:g}~{y_max:g})")
        return " ".join(bits)
    return json.dumps(t, ensure_ascii=False)


def fmt_trigger(tr: dict) -> str:
    """action trigger 딕셔너리를 사람이 읽을 문자열로."""
    ttype = tr.get("type")
    if ttype == "ant_reaches_x":
        cmp = {"ge": "≥", "le": "≤", "gt": ">", "lt": "<"}.get(tr.get("cmp"), tr.get("cmp"))
        return f"개미 x {cmp} {tr.get('x'):g} 일 때"
    if ttype == "picked_ge":
        return f"사탕 {tr.get('n')}개 이상 집었을 때"
    if ttype in ("at_frame", "at_frame_exact"):
        return f"{tr.get('frame')}프레임에"
    return json.dumps(tr, ensure_ascii=False)


def esc(s) -> str:
    return html.escape(str(s))


def stage_name(rec: dict) -> str:
    sid = rec.get("stage_id")
    scene = rec.get("stage", "")
    slug = Path(scene).stem if scene else f"Stage{sid:02d}" if isinstance(sid, int) else "?"
    return slug


def _seed_label(rec: dict) -> str:
    seeds = sorted(s for s in rec.get("_seeds", {rec.get("seed")}) if s is not None)
    lab = "seed " + "·".join(str(s) for s in seeds)
    runs = rec.get("_runs", 1)
    if runs > len(seeds):
        lab += f" ({runs}회)"
    return lab


def _card(rec: dict, cleared: bool) -> str:
    sid = rec.get("stage_id")
    rep = rec.get("_replay") or {}
    saved = rec.get("saved") if cleared else rep.get("saved")
    hp = rec.get("hp")
    inv = rec.get("inventory", {}) or {}
    inv_html = " ".join(
        f'<span class="skill">{esc(k)}<b>×{esc(v)}</b></span>' for k, v in inv.items()
    ) or '<span class="muted">(스킬 없음)</span>'

    steps = []
    for i, a in enumerate(rec.get("actions", []), 1):
        steps.append(
            f'<li><span class="step-n">{i}</span>'
            f'<span class="step-skill">{esc(a.get("skill"))}</span>'
            f'<span class="step-arrow">→</span>'
            f'<span class="step-target">{esc(fmt_target(a.get("target", {})))}</span>'
            f'<span class="step-when">{esc(fmt_trigger(a.get("trigger", {})))}</span></li>'
        )
    steps_html = "\n".join(steps) or '<li class="muted">액션 없음</li>'

    if cleared:
        badge = '<span class="badge full">클리어</span>'
        frame = rec.get("frame")
    else:
        badge = '<span class="badge part">미클리어 · 최고 진척</span>'
        frame = rep.get("frame")

    meta_bits = [f'<span title="episodes">🎲 {esc(rec.get("episodes"))} ep</span>']
    if frame is not None:
        meta_bits.append(f'<span title="frame">⏱ {esc(frame)}f</span>')
    if not cleared:
        br = rec.get("best_reward")
        if br is not None:
            meta_bits.append(f'<span title="최고 base 보상">bestR {br:.3f}</span>')
        if rep:
            meta_bits.append(f'<span title="리플레이 픽업">🍬 픽업 {esc(rep.get("picked_total"))}</span>')
    meta_bits.append(f'<span title="grammar">📐 {esc(rec.get("grammar"))}</span>')
    meta_bits.append(f'<span class="seeds">{esc(_seed_label(rec))}</span>')
    meta = "".join(meta_bits)

    level_svg = build_level_svg(rec)
    legend = ('<div class="legend"><i style="background:#8ecbff"></i>빈손 '
              '<i style="background:#ff8a8a"></i>운반 <b class="x">✕</b>낙오</div>'
              if (rec.get("_replay") or {}).get("trace") else "")
    level_html = f'<div class="level-wrap">{level_svg}{legend}</div>' if level_svg else ""
    saved_disp = esc(saved) if saved is not None else "?"
    return f"""
    <article class="card" data-cleared="{str(cleared).lower()}" data-stage="{esc(sid)}">
      <header>
        <div class="title">
          <span class="sid">Stage {esc(sid)}</span>
          <span class="slug">{esc(stage_name(rec))}</span>
        </div>
        {badge}
      </header>
      {level_html}
      <div class="score">
        <span class="saved">{saved_disp}</span><span class="sep">/</span><span class="hp">{esc(hp)}</span>
        <span class="score-label">구출 / 전체</span>
      </div>
      <div class="inv">{inv_html}</div>
      <ol class="steps">
        {steps_html}
      </ol>
      <footer class="meta">{meta}<span class="ts" title="발견 시각">{esc(rec.get("ts", ""))}</span></footer>
    </article>"""


def render(found_groups: list[dict], partial_groups: list[dict],
           stale_ids: set[int] | None = None) -> str:
    tagged = [(r, True) for r in found_groups] + [(r, False) for r in partial_groups]
    tagged.sort(key=lambda t: (t[0].get("stage_id") or 0, 0 if t[1] else 1))
    cards = [_card(rec, cleared) for rec, cleared in tagged]
    cards_html = "\n".join(cards) or '<p class="empty">아직 기록된 해가 없습니다.</p>'

    cleared_ids = {r.get("stage_id") for r in found_groups}
    stage_ids = {r.get("stage_id") for r in found_groups + partial_groups}
    n_stage = len(stage_ids)
    n_clear_stage = len(cleared_ids)
    summary = (f"{n_stage}개 스테이지 · 클리어 {n_clear_stage} · 미클리어 {n_stage - n_clear_stage}"
               f" · 고유 해 {len(found_groups)}개")
    if stale_ids:
        summary += (' · <span class="stale">레벨 변경으로 파기 대기: '
                    + ", ".join(f"S{s}" for s in sorted(stale_ids)) + "</span>")

    return f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CandyAnts — 발견된 해 ({len(found_groups)})</title>
<style>
  :root {{
    --bg: #14100c; --panel: #1f1913; --panel2: #29211a; --line: #3a2f24;
    --text: #f2e9dd; --muted: #9a8c7a; --accent: #ffb454; --green: #7bd88f; --amber: #e0a458;
  }}
  * {{ box-sizing: border-box; }}
  body {{ margin: 0; background: var(--bg); color: var(--text);
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif; }}
  header.top {{ padding: 28px 24px 16px; border-bottom: 1px solid var(--line);
    display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap; }}
  header.top h1 {{ margin: 0; font-size: 22px; letter-spacing: .3px; }}
  header.top h1 .ant {{ color: var(--accent); }}
  .summary {{ color: var(--muted); font-size: 14px; }}
  .summary .stale {{ color: #ff7d7d; }}
  .controls {{ margin-left: auto; display: flex; gap: 8px; }}
  .controls button {{ background: var(--panel2); color: var(--text); border: 1px solid var(--line);
    padding: 6px 12px; border-radius: 999px; cursor: pointer; font-size: 13px; }}
  .controls button.active {{ background: var(--accent); color: #221a10; border-color: var(--accent); font-weight: 600; }}
  main {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 16px; padding: 20px 24px 60px; max-width: 1400px; margin: 0 auto; }}
  .card {{ background: var(--panel); border: 1px solid var(--line); border-radius: 14px;
    padding: 16px 16px 12px; display: flex; flex-direction: column; gap: 12px; }}
  .card header {{ display: flex; align-items: center; justify-content: space-between; gap: 8px; }}
  .title {{ display: flex; align-items: baseline; gap: 8px; }}
  .sid {{ font-size: 17px; font-weight: 700; }}
  .slug {{ font-size: 12px; color: var(--muted); }}
  .badge {{ font-size: 11px; padding: 3px 9px; border-radius: 999px; white-space: nowrap; }}
  .badge.full {{ background: rgba(123,216,143,.15); color: var(--green); border: 1px solid rgba(123,216,143,.4); }}
  .badge.part {{ background: rgba(224,164,88,.15); color: var(--amber); border: 1px solid rgba(224,164,88,.4); }}
  .score {{ display: flex; align-items: baseline; gap: 6px; }}
  .score .saved {{ font-size: 30px; font-weight: 800; color: var(--green); line-height: 1; }}
  .score .sep {{ font-size: 22px; color: var(--muted); }}
  .score .hp {{ font-size: 22px; color: var(--text); }}
  .score-label {{ font-size: 11px; color: var(--muted); margin-left: 6px; }}
  .inv {{ display: flex; flex-wrap: wrap; gap: 6px; }}
  .skill {{ background: var(--panel2); border: 1px solid var(--line); border-radius: 8px;
    padding: 3px 9px; font-size: 12px; }}
  .skill b {{ color: var(--accent); margin-left: 3px; font-weight: 700; }}
  ol.steps {{ list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }}
  ol.steps li {{ display: grid; grid-template-columns: auto auto auto 1fr; align-items: center; gap: 8px;
    background: var(--panel2); border-radius: 8px; padding: 7px 10px; font-size: 12.5px; }}
  .step-n {{ width: 20px; height: 20px; border-radius: 50%; background: var(--accent); color: #221a10;
    display: inline-flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 700; }}
  .step-skill {{ font-weight: 600; color: var(--accent); }}
  .step-arrow {{ color: var(--muted); }}
  .step-when {{ grid-column: 1 / -1; color: var(--muted); font-size: 11.5px; padding-left: 28px; }}
  footer.meta {{ display: flex; flex-wrap: wrap; gap: 10px; font-size: 11px; color: var(--muted);
    border-top: 1px solid var(--line); padding-top: 8px; margin-top: auto; }}
  footer.meta .ts {{ margin-left: auto; }}
  footer.meta .seeds {{ color: var(--accent); }}
  .muted {{ color: var(--muted); }}
  .empty {{ grid-column: 1/-1; text-align: center; color: var(--muted); padding: 60px; }}
  .level-wrap {{ background: #0d2340; border: 1px solid var(--line); border-radius: 10px; overflow: hidden;
    position: relative; }}
  .legend {{ position: absolute; right: 6px; bottom: 4px; font-size: 10.5px; color: #dfe9f5;
    background: rgba(0,0,0,.45); border-radius: 6px; padding: 2px 7px; }}
  .legend i {{ display: inline-block; width: 14px; height: 3px; vertical-align: middle;
    margin: 0 3px 0 6px; border-radius: 2px; }}
  .legend b.x {{ color: #ff4d4d; margin: 0 3px 0 6px; }}
  svg.level {{ display: block; width: 100%; height: auto; max-height: 260px; }}
  svg.level text.mk {{ fill: #fff; font: 700 12px sans-serif; text-anchor: middle; paint-order: stroke;
    stroke: #000; stroke-width: 3px; }}
  svg.level text.pin {{ fill: #111; font: 800 14px sans-serif; text-anchor: middle; }}
  svg.level text.alab {{ font: 700 13px sans-serif; text-anchor: middle; paint-order: stroke;
    stroke: #000; stroke-width: 3px; }}
  svg.level text.cap {{ fill: #ffd98a; font: 600 15px sans-serif; text-anchor: start; paint-order: stroke;
    stroke: #000; stroke-width: 4px; }}
</style>
</head>
<body>
<header class="top">
  <h1><span class="ant">🐜</span> CandyAnts · 발견된 해</h1>
  <div class="summary">{summary}</div>
  <div class="controls">
    <button data-filter="all" class="active">전체</button>
    <button data-filter="clear">클리어</button>
    <button data-filter="partial">미클리어</button>
  </div>
</header>
<main id="grid">
{cards_html}
</main>
<script>
  const buttons = document.querySelectorAll('.controls button');
  const cards = document.querySelectorAll('.card');
  buttons.forEach(b => b.addEventListener('click', () => {{
    buttons.forEach(x => x.classList.remove('active'));
    b.classList.add('active');
    const f = b.dataset.filter;
    cards.forEach(c => {{
      const cleared = c.dataset.cleared === 'true';
      const show = f === 'all' || (f === 'clear' && cleared) || (f === 'partial' && !cleared);
      c.style.display = show ? '' : 'none';
    }});
  }}));
</script>
</body>
</html>
"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--found-dir", type=Path, default=FOUND_DIR)
    ap.add_argument("--out", type=Path, default=None, help="출력 HTML 경로 (기본: <found-dir>/index.html)")
    ap.add_argument("--replay", action="store_true",
                    help="캐시에 없는 해/부분해를 결정론 리플레이해 궤적·지표를 채움(Godot 필요)")
    ap.add_argument("--stages", default=None,
                    help='포함할 스테이지 필터, 예 "1-25" (기본: 전부 — dev fixture 990+ 포함)')
    ap.add_argument("--open", action="store_true", help="생성 후 브라우저로 열기")
    args = ap.parse_args()

    found_dir = args.found_dir
    if not found_dir.exists():
        print(f"error: {found_dir} 없음", file=sys.stderr)
        return 1

    keep = parse_stages(args.stages) if args.stages else None
    # ① 레지스트리(권위) — 기록 시점에 실행-동치 dedup·레벨 digest 바인딩된 '정리된 해'
    reg_recs, covered, stale = load_registries(found_dir, keep)
    found = load_found(found_dir)
    partials = load_partials(found_dir)
    if keep is not None:
        found = [r for r in found if r.get("stage_id") in keep]
        partials = [r for r in partials if r.get("stage_id") in keep]
    # ② 레거시 사이드카/log = 레지스트리 없는 스테이지 한정(plan_key 중복 제거 폴백)
    found = [r for r in found if r.get("stage_id") not in covered]
    found_groups = reg_recs + dedup_by_class(found, _found_better)
    # ③ 파기-대기 스테이지 제외 + partial 자체 레벨 digest 불일치 제외
    partials = [r for r in partials if r.get("stage_id") not in stale]

    def _partial_level_ok(r: dict) -> bool:
        ld, sid = r.get("level_digest"), r.get("stage_id")
        if not ld or not isinstance(sid, int):
            return True                        # 레거시(digest 없는) partial은 통과
        cur = solution_registry.level_digest(sid)
        return cur is None or ld == cur

    partials = [r for r in partials if _partial_level_ok(r)]
    # 클리어가 있는 스테이지의 partial은 잉여
    cleared_ids = {r.get("stage_id") for r in found_groups}
    partials = [r for r in partials if r.get("stage_id") not in cleared_ids]

    # 리플레이 부착: 캐시 우선, --replay 시 미스 채움(partial 대표 선정이 리플레이 지표를 쓰므로 선행)
    attach_replays(found_groups + partials, found_dir, do_replay=args.replay)
    partial_groups = dedup_by_class(partials, _partial_better)

    out = args.out or (found_dir / "index.html")
    out.write_text(render(found_groups, partial_groups, stale), encoding="utf-8")
    n_stage = len({r.get("stage_id") for r in found_groups + partial_groups})
    print(f"wrote {out}  (고유 해 {len(found_groups)} · 부분해 {len(partial_groups)} · "
          f"스테이지 {n_stage})")

    if args.open:
        webbrowser.open(out.resolve().as_uri())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
