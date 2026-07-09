#!/usr/bin/env python3
"""found_viewer — data/solutions/found/ 에 기록된 해(solution)를 자기완결 HTML로 렌더링.

RL/휴리스틱 솔버가 해를 찾는 즉시 durable 기록으로 남기는
`*.found.json` 사이드카와 `log.jsonl` 을 읽어, 브라우저에서 바로 열어볼 수 있는
단일 HTML 파일(`found/index.html`)을 생성한다. 외부 의존성 없음(파일 더블클릭으로 열림).

사용:  python tools/solver/found_viewer.py            # 기본 경로로 index.html 갱신
       python tools/solver/found_viewer.py --open     # 생성 후 브라우저로 열기
"""
from __future__ import annotations

import argparse
import html
import json
import sys
import webbrowser
from pathlib import Path

import level_render

REPO = Path(__file__).resolve().parents[2]
FOUND_DIR = REPO / "data" / "solutions" / "found"


def build_level_svg(rec: dict) -> str:
    """레코드의 stage → 레이아웃/스폰/analysis 를 찾아 레벨 SVG 생성. 실패 시 빈 문자열."""
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
        # analysis.json 의 실제 발동 좌표(있고 액션 수가 맞을 때만)
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
        return level_render.render_svg(layout, actions, spawn=spawn, resolved=resolved)
    except Exception as exc:  # noqa: BLE001 — 렌더 실패해도 카드는 나와야 함
        print(f"warn: level svg {slug}: {exc}", file=sys.stderr)
        return ""


def load_records(found_dir: Path) -> list[dict]:
    """found/ 안의 모든 해 레코드를 모아 (stage_id, seed) 기준으로 최신 ts만 남긴다."""
    records: list[dict] = []

    for path in sorted(found_dir.glob("*.found.json")):
        try:
            records.append(json.loads(path.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, OSError) as exc:
            print(f"warn: skip {path.name}: {exc}", file=sys.stderr)

    log = found_dir / "log.jsonl"
    if log.exists():
        for line in log.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as exc:
                print(f"warn: skip log line: {exc}", file=sys.stderr)

    # dedupe: (stage_id, seed) 당 가장 최근 ts 하나만
    best: dict[tuple, dict] = {}
    for rec in records:
        key = (rec.get("stage_id"), rec.get("seed"))
        cur = best.get(key)
        if cur is None or str(rec.get("ts", "")) >= str(cur.get("ts", "")):
            best[key] = rec

    return sorted(best.values(), key=lambda r: (r.get("stage_id") or 0, r.get("seed") or 0))


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
    return json.dumps(tr, ensure_ascii=False)


def esc(s) -> str:
    return html.escape(str(s))


def stage_name(rec: dict) -> str:
    sid = rec.get("stage_id")
    scene = rec.get("stage", "")
    slug = Path(scene).stem if scene else f"Stage{sid:02d}" if isinstance(sid, int) else "?"
    return slug


def render(records: list[dict]) -> str:
    cards = []
    for rec in records:
        sid = rec.get("stage_id")
        saved = rec.get("saved")
        hp = rec.get("hp")
        full = saved is not None and hp is not None and saved >= hp
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

        badge = '<span class="badge full">전원 구출</span>' if full else '<span class="badge part">부분</span>'
        meta = (
            f'<span title="episodes">🎲 {esc(rec.get("episodes"))} ep</span>'
            f'<span title="frame">⏱ {esc(rec.get("frame"))}f</span>'
            f'<span title="grammar">📐 {esc(rec.get("grammar"))}</span>'
            f'<span title="seed">seed {esc(rec.get("seed"))}</span>'
        )
        level_svg = build_level_svg(rec)
        level_html = f'<div class="level-wrap">{level_svg}</div>' if level_svg else ""
        cards.append(f"""
    <article class="card" data-full="{str(full).lower()}">
      <header>
        <div class="title">
          <span class="sid">Stage {esc(sid)}</span>
          <span class="slug">{esc(stage_name(rec))}</span>
        </div>
        {badge}
      </header>
      {level_html}
      <div class="score">
        <span class="saved">{esc(saved)}</span><span class="sep">/</span><span class="hp">{esc(hp)}</span>
        <span class="score-label">구출 / 전체</span>
      </div>
      <div class="inv">{inv_html}</div>
      <ol class="steps">
        {steps_html}
      </ol>
      <footer class="meta">{meta}<span class="ts" title="발견 시각">{esc(rec.get("ts", ""))}</span></footer>
    </article>""")

    n_full = sum(1 for r in records if (r.get("saved") or 0) >= (r.get("hp") or 1))
    cards_html = "\n".join(cards) or '<p class="empty">아직 기록된 해가 없습니다.</p>'

    return f"""<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CandyAnts — 발견된 해 ({len(records)})</title>
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
  .step-target {{ }}
  .step-when {{ grid-column: 1 / -1; color: var(--muted); font-size: 11.5px; padding-left: 28px; }}
  footer.meta {{ display: flex; flex-wrap: wrap; gap: 10px; font-size: 11px; color: var(--muted);
    border-top: 1px solid var(--line); padding-top: 8px; margin-top: auto; }}
  footer.meta .ts {{ margin-left: auto; }}
  .muted {{ color: var(--muted); }}
  .empty {{ grid-column: 1/-1; text-align: center; color: var(--muted); padding: 60px; }}
  .level-wrap {{ background: #0d2340; border: 1px solid var(--line); border-radius: 10px; overflow: hidden; }}
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
  <div class="summary">{len(records)}개 스테이지 · 전원 구출 {n_full}개</div>
  <div class="controls">
    <button data-filter="all" class="active">전체</button>
    <button data-filter="full">전원 구출</button>
    <button data-filter="part">부분</button>
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
      const full = c.dataset.full === 'true';
      const show = f === 'all' || (f === 'full' && full) || (f === 'part' && !full);
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
    ap.add_argument("--open", action="store_true", help="생성 후 브라우저로 열기")
    args = ap.parse_args()

    found_dir = args.found_dir
    if not found_dir.exists():
        print(f"error: {found_dir} 없음", file=sys.stderr)
        return 1

    records = load_records(found_dir)
    out = args.out or (found_dir / "index.html")
    out.write_text(render(records), encoding="utf-8")
    print(f"wrote {out}  ({len(records)} solutions)")

    if args.open:
        webbrowser.open(out.resolve().as_uri())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
