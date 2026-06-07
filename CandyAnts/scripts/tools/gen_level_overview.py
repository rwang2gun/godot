#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LEVEL_OVERVIEW.html 생성기 — 9 스테이지의 맵 구성/퍼즐 요소/난이도 곡선을 한 장의
자체 완결 정적 HTML로 렌더한다. data/stages/*.tres + data/stage_layouts/*.tres 파싱.
(정적 생성 — 클라이언트 JS/innerHTML 없음.)
사용: python scripts/tools/gen_level_overview.py  ->  docs/LEVEL_OVERVIEW.html
(*.html은 .gitignore 대상 — 로컬 보기용 산출물)
"""
from __future__ import annotations
import re, html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAGES = ROOT / "data" / "stages"
LAYOUTS = ROOT / "data" / "stage_layouts"
OUT = ROOT / "docs" / "LEVEL_OVERVIEW.html"

def grab_dict_cells(text, key):
    m = re.search(re.escape(key) + r"\s*=\s*\{", text)
    if not m: return {}
    i = m.end()-1; depth=0
    while i < len(text):
        if text[i]=='{': depth+=1
        elif text[i]=='}':
            depth-=1
            if depth==0: break
        i+=1
    body = text[m.end():i]
    d={}
    for mm in re.finditer(r'"(-?\d+),(-?\d+)"\s*:\s*"([^"]+)"', body):
        d[(int(mm.group(1)),int(mm.group(2)))]=mm.group(3)
    return d

def grab_vec(text, key):
    m = re.search(re.escape(key)+r"\s*=\s*Vector2i\((-?\d+),\s*(-?\d+)\)", text)
    return (int(m.group(1)),int(m.group(2))) if m else None

def grab_int(text, key, default=0):
    m = re.search(re.escape(key)+r"\s*=\s*([0-9]+)", text)
    return int(m.group(1)) if m else default

def grab_float(text, key, default=None):
    m = re.search(re.escape(key)+r"\s*=\s*([0-9.]+)", text)
    return float(m.group(1)) if m else default

def grab_str(text, key):
    m = re.search(re.escape(key)+r'\s*=\s*"([^"]*)"', text)
    return m.group(1) if m else ""

def grab_str_array(text, key):
    m = re.search(re.escape(key)+r'\s*=\s*Array\[String\]\(\[([^\]]*)\]\)', text)
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []

def grab_inventory(text):
    m = re.search(r"skill_inventory\s*=\s*\{([^}]*)\}", text, re.S)
    if not m: return {}
    return {mm.group(1):int(mm.group(2)) for mm in re.finditer(r'"([^"]+)"\s*:\s*([0-9]+)', m.group(1))}

def grab_float_array(text, key):
    m = re.search(re.escape(key)+r'\s*=\s*Array\[float\]\(\[([^\]]*)\]\)', text)
    return [float(x) for x in re.findall(r'[0-9.]+', m.group(1))] if m else []

SKILL_KR = {"climber":"벽 오르기","blocker":"길 막기","floater":"낙하산","bridge":"다리 만들기",
"builder":"계단 짓기","sand_mound":"막대 세우기","digger":"땅파기","basher":"벽 부수기",
"cutter":"길 먹기","leaf_jump":"나뭇잎 점프"}

META = {
1:{"theme":"climber 트레잇 기초","axis":"기초","diff":1,
   "puzzle":"중앙 1칸 분지에 빠진 뒤 반대편 1칸 벽을 climber로 타고 나온다. 양방향 대칭이라 사탕 회수 왕복도 같은 climber로 자기완결. climber의 ‘벽=등반’ 단일 규칙만 가르친다.",
   "roles":{"climber":"분지 벽 등반 (필수)","blocker":"가장자리 이탈 방지 보조 도구"}},
2:{"theme":"climber + 낙하산 분배","axis":"기초","diff":2,
   "puzzle":"메사 정상의 사탕을 climber로 올라 회수하고, 6칸 낙하 귀가에서 기절(≥5칸 자유낙하)을 피한다. floater 1개를 한 마리에게 줘 ‘분배자’로 정착시키면 지나는 모든 개미가 낙하산을 받아 안전 강하 — 낙하산 공유 개념 학습.",
   "roles":{"climber":"메사 등반","floater":"분배자 정착 → 무리 안전 강하","blocker":"보조"}},
3:{"theme":"bridge — 건설 ① 평지","axis":"건설","diff":3,
   "puzzle":"사탕 호수의 이중 갭(섬을 사이에 둔 두 물구덩이)을 bridge 2개로 건넌다. 각 갭 직전 가장자리에서 즉시 건설 → 다리는 영구라 전원이 왕복. 물은 즉사라 다리 없이는 전멸.",
   "roles":{"bridge":"두 갭을 평지 다리로 횡단 (각 1개)"}},
4:{"theme":"builder — 건설 ② 대각","axis":"건설","diff":4,
   "puzzle":"갭 너머 높은 단의 사탕. builder로 대각 계단을 1회 건설하면 후속 개미도 step-up으로 자동 등반, 하강은 부드러운 계단 미끄럼. ‘위로 올라가는 건설’을 bridge(평지)와 대비.",
   "roles":{"builder":"대각 계단 건설 (1회 → 영구)"}},
5:{"theme":"sand_mound + floater — 건설 ③ 수직","axis":"건설","diff":5,
   "puzzle":"고립된 막대과자 탑(플랫폼) 위 사탕. sand_mound 수직 사다리를 1회 세우면 후속 개미가 자동 등반. 6칸 하강 귀가는 floater 분배자로 안전화. 수직 건설 + 분배 복습.",
   "roles":{"sand_mound":"수직 사다리 (1회 → 후속 자동 등반)","floater":"분배자 → 하강 안전화"}},
6:{"theme":"digger + climber — 파괴 ① 수직","axis":"파괴","diff":7,
   "puzzle":"흙 선반 아래 챔버의 사탕. 전원이 선반으로 내려온 뒤(안전 4칸 낙하) digger로 선반에 구멍 1개 → 무리가 안전 강하 → 사탕 회수 → climber로 기둥을 타고 복귀. ‘내려가기 → 파기 → 올라오기’ 다단 시퀀싱이라 스테이지 번호 대비 부담(난이도 스파이크).",
   "roles":{"digger":"흙 선반 굴착 (구멍 1개, 필수)","climber":"챔버 → 홈 복귀 등반 (필수)"}},
7:{"theme":"basher — 파괴 ② 수평","axis":"파괴","diff":6,
   "puzzle":"홈과 사탕 사이 흙 벽. basher로 수평 통로를 1회 굴착하면 영구라 왕복 친화적. 파괴계의 가장 단순한 형태 — 수평 한 방.",
   "roles":{"basher":"흙 벽 수평 굴착 (1회 → 영구 통로)"}},
8:{"theme":"cutter + leaf_jump — 파괴 ③ 식물·점프","axis":"파괴","diff":7,
   "puzzle":"박하 식물 벽 + 끈끈이(밟으면 3초 정지). cutter로 식물을 절단해 통로를 내고 leaf_jump 점프대를 활용. 60초 시간 압박으로 파괴계 마무리 + 새 점프 메커니즘 도입.",
   "roles":{"cutter":"식물 벽 절단 (basher의 식물판)","leaf_jump":"점프대 설치/도약"}},
9:{"theme":"종합 — bridge·basher·blocker·sand_mound","axis":"종합","diff":8,
   "puzzle":"마지막 종합 과자점. 물 갭은 bridge로, 흙 구조는 basher로, 상단 사탕 플랫폼은 sand_mound로 — 건설·파괴 스킬을 순서대로 엮는 복합 관문. blocker는 무리 통제 보조. 캠페인 총정리.",
   "roles":{"bridge":"물 갭 횡단","basher":"흙 구조 굴착","sand_mound":"상단 사탕 도달","blocker":"무리 통제 보조"}},
}
AXIS_COLOR = {"기초":"#36b37e","건설":"#3a86d4","파괴":"#e0843a","종합":"#9b5de5"}

def parse_stage(n):
    st = (STAGES/f"stage{n:02d}.tres").read_text(encoding="utf-8")
    ly = (LAYOUTS/f"stage{n:02d}_layout.tres").read_text(encoding="utf-8")
    return {
        "id":n,"name":grab_str(st,"display_name"),
        "total":grab_int(st,"total_ants"),"hp":grab_int(st,"candy_hp"),
        "time":grab_float(st,"time_limit_seconds",120.0) or 120.0,
        "inv":grab_inventory(st),"stars":grab_float_array(st,"star_thresholds"),
        "tiles":grab_dict_cells(ly,"tile_map"),"haz":grab_dict_cells(ly,"hazard_map"),
        "home":grab_vec(ly,"home_cell"),"candy":grab_vec(ly,"candy_cell"),
        "meta":META[n],
    }

def cell_class(s,x,y):
    if s["home"]==(x,y): return "c-home"
    if s["candy"]==(x,y): return "c-candy"
    if (x,y) in s["haz"]: return "h-"+s["haz"][(x,y)]
    if (x,y) in s["tiles"]: return "t-"+s["tiles"][(x,y)]
    return ""

def render_map(s):
    keys=list(s["tiles"])+list(s["haz"])
    if s["home"]: keys.append(s["home"])
    if s["candy"]: keys.append(s["candy"])
    ys=[y for (x,y) in keys if -1<=x<=24]
    if not ys: return ""
    y0,y1=min(ys),max(ys)
    rows=[]
    for y in range(y0,y1+1):
        cells="".join(f'<div class="cell {cell_class(s,x,y)}"></div>' for x in range(0,24))
        rows.append(f'<div class="r">{cells}</div>')
    return '<div class="map">'+"".join(rows)+'</div>'

def legend(s):
    tv=set(s["tiles"].values()); hv=set(s["haz"].values())
    items=[]
    if tv & {"solid","earth"}: items.append(("var(--brown)","흙/지면"))
    if "cookie" in tv: items.append(("var(--cookie)","쿠키(불괴)"))
    if "plant" in tv: items.append(("var(--plant)","식물"))
    if "water" in hv: items.append(("var(--water)","물(즉사)"))
    if "sticky" in hv: items.append(("var(--sticky)","끈끈이"))
    items += [("var(--home)","홈"),("var(--candy)","사탕")]
    sp="".join(f'<span><i class="sw" style="background:{c}"></i>{html.escape(t)}</span>' for c,t in items)
    return f'<div class="legend">{sp}</div>'

def stars_str(a):
    return " / ".join(f"{round(v*100)}%" for v in a) if a else "기본"

def card(s):
    m=s["meta"]
    inv=", ".join(f"{html.escape(SKILL_KR.get(k,k))}×{v}" for k,v in s["inv"].items())
    roles="".join(f'<li><b>{html.escape(SKILL_KR.get(k,k))}</b> — {html.escape(v)}</li>' for k,v in m["roles"].items())
    return (f'<div class="card"><div class="hd"><span class="badge">S{s["id"]}</span>'
      f'<h3>{html.escape(s["name"])}</h3><span class="axis-tag axis-{m["axis"]}">{m["axis"]}</span></div>'
      f'<div class="theme">{html.escape(m["theme"])}</div>'
      f'<div class="params"><span class="chip">개미 <b>{s["total"]}</b></span>'
      f'<span class="chip">사탕 HP <b>{s["hp"]}</b></span>'
      f'<span class="chip">제한 <b>{round(s["time"])}s</b></span>'
      f'<span class="chip">인벤 <b>{inv}</b></span>'
      f'<span class="chip stars">★ {stars_str(s["stars"])}</span></div>'
      f'<div class="maprow">{render_map(s)}</div>{legend(s)}'
      f'<p class="puzzle">{html.escape(m["puzzle"])}</p><ul class="roles">{roles}</ul></div>')

def curve(stages):
    mx=max(s["meta"]["diff"] for s in stages)
    bars=""
    for s in stages:
        m=s["meta"]; h=round(28+m["diff"]/mx*120); col=AXIS_COLOR[m["axis"]]
        bars+=(f'<div class="bar"><div class="n">{m["diff"]}</div>'
          f'<div class="col" style="height:{h}px;background:linear-gradient(180deg,{col}aa,{col})"></div>'
          f'<div class="lab">S{s["id"]}<br>{html.escape(s["name"])}</div></div>')
    return ('<div class="curve"><h2>난이도 곡선 (체감 인지 부하 · 1~10)</h2>'
      f'<div class="bars">{bars}</div>'
      '<div class="axis-key"><span><b style="color:#36b37e">기초</b> 트레잇 학습</span>'
      '<span><b style="color:#3a86d4">건설</b> bridge·builder·sand_mound</span>'
      '<span><b style="color:#e0843a">파괴</b> digger·basher·cutter</span>'
      '<span><b style="color:#9b5de5">종합</b> 복합</span>'
      '<span style="color:#c0392b">※ S6는 슬롯 대비 인지 부하 스파이크(다단 시퀀싱)</span></div></div>')

CSS = """
:root{--bg:#fff7fb;--card:#fff;--ink:#3a2b33;--muted:#8a7680;--line:#f0d9e6;
--brown:#9c6634;--brown2:#7c4f28;--cookie:#9fb3dd;--plant:#5fae4c;--water:#56c4ec;--sticky:#d39a44;
--home:#36b37e;--candy:#e84a8a;--accent:#e84a8a;--sky:#eaf6ff;}
*{box-sizing:border-box}
body{margin:0;font-family:"Pretendard","Segoe UI",system-ui,sans-serif;color:var(--ink);
line-height:1.6;background:linear-gradient(180deg,#fdeaf3,#eaf6ff 60%);}
.wrap{max-width:1180px;margin:0 auto;padding:28px 20px 80px}
h1{font-size:30px;margin:0 0 4px;letter-spacing:-.5px}
h1 .sub{font-size:15px;color:var(--muted);font-weight:500;margin-left:8px}
.lead{color:var(--muted);margin:0 0 24px}
.curve{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:20px 22px;margin-bottom:26px;box-shadow:0 6px 22px rgba(232,74,138,.06)}
.curve h2{margin:0 0 14px;font-size:18px}
.bars{display:flex;align-items:flex-end;gap:10px;height:180px}
.bar{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:6px}
.bar .col{width:100%;border-radius:8px 8px 4px 4px}
.bar .n{font-size:11px;color:var(--muted)}
.bar .lab{font-size:11.5px;font-weight:600;text-align:center;height:32px;line-height:1.15}
.axis-key{display:flex;gap:14px;flex-wrap:wrap;margin-top:14px;font-size:12px;color:var(--muted)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(530px,1fr));gap:20px}
@media(max-width:1120px){.grid{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:18px 20px;box-shadow:0 6px 22px rgba(232,74,138,.06)}
.hd{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:6px}
.badge{background:var(--accent);color:#fff;font-weight:700;border-radius:10px;padding:2px 10px;font-size:14px}
.hd h3{margin:0;font-size:19px}
.theme{font-size:12.5px;color:var(--muted);margin-bottom:8px}
.axis-tag{font-size:11px;font-weight:700;padding:2px 9px;border-radius:20px;color:#fff}
.axis-기초{background:#36b37e}.axis-건설{background:#3a86d4}.axis-파괴{background:#e0843a}.axis-종합{background:#9b5de5}
.params{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0 12px}
.chip{background:#fbeef5;border:1px solid var(--line);border-radius:8px;padding:2px 9px;font-size:12px;color:#73525f}
.chip b{color:var(--ink)} .chip.stars{color:#b9912f}
.maprow{display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap}
.map{background:var(--sky);border:1px solid var(--line);border-radius:10px;padding:6px;line-height:0}
.r{display:flex}
.cell{width:13px;height:13px}
.t-solid,.t-earth{background:var(--brown)}
.t-cookie{background:var(--cookie)}.t-plant{background:var(--plant)}.t-background{background:#efd8c2}
.h-water{background:var(--water)}.h-sticky{background:var(--sticky)}
.c-home{background:var(--home);border-radius:50%}
.c-candy{background:var(--candy);border-radius:3px;box-shadow:0 0 0 1px #fff}
.legend{font-size:11px;color:var(--muted);display:flex;gap:10px;flex-wrap:wrap;margin-top:6px}
.legend span{display:inline-flex;align-items:center;gap:4px}
.sw{width:11px;height:11px;border-radius:3px;display:inline-block}
.puzzle{font-size:13.5px;margin:10px 0 8px}
.roles{margin:0;padding:0;list-style:none;font-size:12.5px}
.roles li{padding:3px 0;border-top:1px dashed var(--line)}
.roles b{color:var(--brown2)}
.foot{margin-top:30px;color:var(--muted);font-size:12px;text-align:center}
"""

def main():
    stages=[parse_stage(n) for n in range(1,10)]
    body=("<h1>CandyAnts — 레벨 개요 <span class=\"sub\">S1 ~ S9 · 맵 구성 · 퍼즐 요소 · 난이도 곡선</span></h1>"
      "<p class=\"lead\">캠페인 9스테이지를 <b>기초(트레잇) → 건설 3종 → 파괴 3종 → 종합</b> 순으로 배치한 학습 곡선. "
      "각 스테이지는 새 스킬 하나를 핵심으로 가르친다. (지형·파라미터는 현재 데이터 자동 렌더)</p>"
      + curve(stages)
      + '<div class="grid">'+"".join(card(s) for s in stages)+'</div>'
      + '<p class="foot">자동 생성: scripts/tools/gen_level_overview.py · data/stages·stage_layouts 현재 값 · (*.html은 gitignore — 로컬 보기용)</p>')
    page=("<!DOCTYPE html><html lang=\"ko\"><head><meta charset=\"utf-8\">"
      "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
      "<title>CandyAnts — 레벨 개요 (S1~S9)</title><style>"+CSS+"</style></head>"
      "<body><div class=\"wrap\">"+body+"</div></body></html>")
    OUT.write_text(page, encoding="utf-8")
    print(f"[gen] wrote {OUT} ({len(page)} bytes)")
    for s in stages:
        print(f"  S{s['id']} {s['name']}: total={s['total']} hp={s['hp']} time={round(s['time'])}s inv={s['inv']} stars={s['stars']}")

if __name__=="__main__":
    main()
