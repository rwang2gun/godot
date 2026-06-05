#!/usr/bin/env python3
"""CandyAnts 에셋 뷰어 생성기.

assets/ 폴더를 스캔해 매니페스트를 만들고, 그 매니페스트를 그대로 박아 넣은
self-contained HTML(tools/asset_viewer.html)을 출력한다. file:// 로 바로 열어도
디렉터리 접근 없이 동작한다(브라우저 fs 제약 회피).

에셋이 추가/삭제되면 그냥 다시 실행:
    python tools/gen_asset_viewer.py
"""
import json
import re
import struct
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "assets"
OUT = REPO / "tools" / "asset_viewer.html"

IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg"}
FONT_EXT = {".ttf", ".otf", ".woff", ".woff2"}
VIDEO_EXT = {".mp4", ".ogv", ".webm"}
# 뷰어에 노출하지 않을 부수 파일
SKIP_EXT = {".import", ".uid", ".md", ".txt", ".tres", ".gitkeep"}


def png_size(p: Path):
    try:
        with open(p, "rb") as f:
            head = f.read(26)
        if head[:8] == b"\x89PNG\r\n\x1a\n" and head[12:16] == b"IHDR":
            w, h = struct.unpack(">II", head[16:24])
            return w, h
    except Exception:
        pass
    return None


def jpeg_size(p: Path):
    try:
        with open(p, "rb") as f:
            if f.read(2) != b"\xff\xd8":
                return None
            while True:
                b = f.read(1)
                while b and b != b"\xff":
                    b = f.read(1)
                marker = f.read(1)
                if not marker:
                    return None
                if 0xC0 <= marker[0] <= 0xCF and marker[0] not in (0xC4, 0xC8, 0xCC):
                    f.read(3)
                    h, w = struct.unpack(">HH", f.read(4))
                    return w, h
                seg = f.read(2)
                if len(seg) < 2:
                    return None
                f.seek(struct.unpack(">H", seg)[0] - 2, 1)
    except Exception:
        return None


_SVG_WH = re.compile(r'\bwidth="([\d.]+)"[^>]*?\bheight="([\d.]+)"')
_SVG_VB = re.compile(r'viewBox="[\d.\-]+ [\d.\-]+ ([\d.]+) ([\d.]+)"')


def svg_size(p: Path):
    try:
        head = p.read_text(encoding="utf-8", errors="ignore")[:1000]
        m = _SVG_WH.search(head)
        if m:
            return int(float(m.group(1))), int(float(m.group(2)))
        m = _SVG_VB.search(head)
        if m:
            return int(float(m.group(1))), int(float(m.group(2)))
    except Exception:
        pass
    return None


def dims(p: Path, ext: str):
    if ext == ".png":
        return png_size(p)
    if ext in (".jpg", ".jpeg"):
        return jpeg_size(p)
    if ext == ".svg":
        return svg_size(p)
    return None


def category(rel: str) -> str:
    """assets/ 이하 경로를 사람이 읽는 카테고리로 묶는다."""
    parts = Path(rel).parts[1:]  # 'assets' 제거
    if not parts:
        return "misc"
    top = parts[0]
    if top == "icons":
        return "/".join(parts[:2]) if len(parts) > 2 else "icons"
    if top == "sprites":
        if len(parts) >= 2 and parts[1] == "characters":
            return "sprites/characters"
        return "/".join(parts[:2]) if len(parts) > 2 else "sprites"
    return top


def seq_key(rel: str):
    """'walk_00.png' 같은 프레임 시퀀스를 (디렉터리, prefix)로 묶는다.
    시퀀스가 아니면 None."""
    p = Path(rel)
    m = re.match(r"^(.*?)_(\d+)$", p.stem)
    if not m:
        return None
    return f"{p.parent.as_posix()}::{m.group(1)}", int(m.group(2))


def main():
    items = []
    for path in sorted(ASSETS.rglob("*")):
        if not path.is_file():
            continue
        ext = path.suffix.lower()
        if ext in SKIP_EXT or path.name == ".gitkeep":
            continue
        if ext not in (IMAGE_EXT | FONT_EXT | VIDEO_EXT):
            continue
        rel = path.relative_to(REPO).as_posix()  # assets/...
        kind = (
            "image" if ext in IMAGE_EXT
            else "font" if ext in FONT_EXT
            else "video"
        )
        d = dims(path, ext) if kind == "image" else None
        sk = seq_key(rel) if kind == "image" else None
        items.append({
            "path": rel,
            "name": path.name,
            "cat": category(rel),
            "kind": kind,
            "ext": ext.lstrip("."),
            "size": path.stat().st_size,
            "w": d[0] if d else None,
            "h": d[1] if d else None,
            "seq": sk[0] if sk else None,
            "frame": sk[1] if sk else None,
        })

    manifest = {
        "generated_from": "tools/gen_asset_viewer.py",
        "asset_root": "../",  # HTML(tools/) 기준 repo 루트
        "count": len(items),
        "items": items,
    }
    html = TEMPLATE.replace(
        "/*__MANIFEST__*/",
        json.dumps(manifest, ensure_ascii=False),
    )
    OUT.write_text(html, encoding="utf-8")
    cats = {}
    for it in items:
        cats[it["cat"]] = cats.get(it["cat"], 0) + 1
    print(f"[asset_viewer] {len(items)} assets -> {OUT.relative_to(REPO)}")
    for c in sorted(cats):
        print(f"  {c:28s} {cats[c]:3d}")


TEMPLATE = r"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CandyAnts 에셋 뷰어</title>
<style>
  :root {
    --bg:#1a1714; --panel:#242019; --panel2:#2d2820; --ink:#f2e9da; --muted:#b8ab95;
    --accent:#f0993f; --accent2:#ff4a9e; --green:#2fd95c; --blue:#5aa7ff;
    --border:#3a342a; --code:#16130f; --danger:#ff4a37; --card:150px;
  }
  * { box-sizing:border-box; }
  html,body { height:100%; }
  body {
    margin:0; font-family:"Segoe UI","Malgun Gothic",system-ui,sans-serif;
    background:var(--bg); color:var(--ink); display:flex; flex-direction:column; height:100vh;
  }
  header {
    background:linear-gradient(135deg,#2d2820,#1a1714); border-bottom:1px solid var(--border);
    padding:12px 22px; display:flex; align-items:center; gap:16px; flex-wrap:wrap;
  }
  header h1 { margin:0; font-size:18px; letter-spacing:-.3px; white-space:nowrap; }
  header h1 small { color:var(--muted); font-weight:400; font-size:12px; margin-left:8px; }
  .toolbar { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-left:auto; }
  .search {
    min-width:240px; background:var(--code); border:1px solid var(--border); border-radius:8px;
    padding:8px 12px; color:var(--ink); font:inherit; font-size:13px;
  }
  .search:focus { outline:none; border-color:var(--accent); }
  .seg { display:flex; border:1px solid var(--border); border-radius:8px; overflow:hidden; }
  .seg button {
    font:inherit; font-size:12px; font-weight:600; cursor:pointer; border:none;
    background:var(--panel2); color:var(--muted); padding:7px 11px; transition:.12s;
  }
  .seg button.on { background:var(--accent); color:#1a1714; }
  .seg button:hover:not(.on) { color:var(--ink); }
  label.chk { font-size:12px; color:var(--muted); display:inline-flex; gap:5px; align-items:center; cursor:pointer; }
  .wrap { flex:1; display:flex; min-height:0; }
  nav {
    width:230px; flex-shrink:0; background:var(--panel); border-right:1px solid var(--border);
    overflow:auto; padding:10px 8px;
  }
  nav .cat {
    display:flex; justify-content:space-between; align-items:center; gap:8px;
    padding:7px 11px; border-radius:8px; cursor:pointer; font-size:13px; color:var(--muted);
  }
  nav .cat:hover { background:var(--panel2); color:var(--ink); }
  nav .cat.on { background:var(--panel2); color:var(--accent); font-weight:700; }
  nav .cat .n { font-size:11px; color:var(--muted); background:var(--code); padding:1px 7px; border-radius:10px; }
  main { flex:1; overflow:auto; padding:16px 20px 80px; }
  .grid {
    display:grid; grid-template-columns:repeat(auto-fill,minmax(var(--card),1fr)); gap:14px;
  }
  .card {
    background:var(--panel); border:1px solid var(--border); border-radius:10px; overflow:hidden;
    display:flex; flex-direction:column; cursor:pointer; transition:.12s;
  }
  .card:hover { border-color:var(--accent); transform:translateY(-2px); }
  .thumb {
    height:130px; display:flex; align-items:center; justify-content:center; padding:8px;
    position:relative; overflow:hidden;
  }
  .thumb img, .thumb video { max-width:100%; max-height:100%; image-rendering:auto; }
  body.pixel .thumb img { image-rendering:pixelated; }
  .bg-checker { background-image:
      linear-gradient(45deg,#403a30 25%,transparent 25%),
      linear-gradient(-45deg,#403a30 25%,transparent 25%),
      linear-gradient(45deg,transparent 75%,#403a30 75%),
      linear-gradient(-45deg,transparent 75%,#403a30 75%);
    background-size:16px 16px; background-position:0 0,0 8px,8px -8px,-8px 0; background-color:#2a251e; }
  .bg-dark { background:#14110d; }
  .bg-light { background:#f2e9da; }
  .bg-magenta { background:#ff00ff; }
  .meta { padding:7px 9px; border-top:1px solid var(--border); }
  .meta .nm { font-size:12px; font-weight:600; word-break:break-all; line-height:1.25; }
  .meta .sub { font-size:10.5px; color:var(--muted); margin-top:3px; font-family:"Cascadia Code",Consolas,monospace; display:flex; gap:8px; flex-wrap:wrap; }
  .badge { position:absolute; top:6px; left:6px; font-size:9.5px; font-weight:700; padding:2px 7px;
    border-radius:6px; background:rgba(0,0,0,.55); color:var(--ink); letter-spacing:.3px; }
  .badge.seq { background:var(--accent2); color:#1a1714; }
  .badge.svg { background:var(--blue); color:#0b1a2e; }
  .badge.font { background:var(--green); color:#06210f; }
  .badge.vid { background:var(--accent); color:#1a1714; }
  .fontprev { font-size:24px; text-align:center; line-height:1.3; color:var(--ink); padding:4px; }
  .empty { color:var(--muted); padding:40px; text-align:center; font-size:14px; }
  .cathead { grid-column:1/-1; font-size:13px; color:var(--accent); font-weight:700; margin:6px 2px -2px;
    border-bottom:1px solid var(--border); padding-bottom:6px; letter-spacing:.3px; }
  /* lightbox */
  .lb { position:fixed; inset:0; background:rgba(8,6,4,.86); display:none; z-index:50;
    align-items:center; justify-content:center; flex-direction:column; padding:24px; }
  .lb.show { display:flex; }
  .lb .stage { flex:1; display:flex; align-items:center; justify-content:center; min-height:0; width:100%; }
  .lb .stage img, .lb .stage video { max-width:90vw; max-height:74vh; }
  body.pixel .lb .stage img { image-rendering:pixelated; }
  .lb .bar { margin-top:14px; display:flex; gap:14px; align-items:center; flex-wrap:wrap; justify-content:center;
    background:var(--panel); border:1px solid var(--border); border-radius:10px; padding:10px 16px; max-width:92vw; }
  .lb .bar .nm { font-size:14px; font-weight:700; }
  .lb .bar .sub { font-size:12px; color:var(--muted); font-family:"Cascadia Code",Consolas,monospace; }
  .lb .bar code { background:var(--code); padding:3px 8px; border-radius:6px; color:var(--green); font-size:11.5px; user-select:all; }
  .lb button, .lb a.btn { font:inherit; font-size:13px; font-weight:600; cursor:pointer; border-radius:8px;
    border:1px solid var(--border); background:var(--panel2); color:var(--ink); padding:7px 13px; text-decoration:none; }
  .lb button:hover, .lb a.btn:hover { border-color:var(--accent); }
  .lb .close { position:absolute; top:16px; right:20px; font-size:22px; padding:4px 14px; }
  .frames { display:flex; gap:6px; flex-wrap:wrap; justify-content:center; margin-top:10px; max-width:92vw; }
  .frames img { height:54px; border:1px solid var(--border); border-radius:6px; cursor:pointer; }
  .frames img.on { border-color:var(--accent2); }
</style>
</head>
<body class="pixel">
<header>
  <h1>🍬 CandyAnts 에셋 뷰어 <small id="total"></small></h1>
  <div class="toolbar">
    <input id="q" class="search" placeholder="이름/경로 검색…" autocomplete="off">
    <div class="seg" id="bgseg" title="썸네일 배경 (투명도 확인)">
      <button data-bg="checker" class="on">체커</button>
      <button data-bg="dark">어둠</button>
      <button data-bg="light">밝음</button>
      <button data-bg="magenta">마젠타</button>
    </div>
    <label class="chk"><input type="checkbox" id="pixel" checked> 픽셀</label>
    <label class="chk"><input type="checkbox" id="grouped" checked> 카테고리묶기</label>
    <div class="seg" id="sizeseg" title="썸네일 크기">
      <button data-card="110">S</button>
      <button data-card="150" class="on">M</button>
      <button data-card="220">L</button>
    </div>
  </div>
</header>
<div class="wrap">
  <nav id="nav"></nav>
  <main><div class="grid" id="grid"></div></main>
</div>

<div class="lb" id="lb">
  <button class="close" onclick="closeLb()">✕</button>
  <div class="stage" id="lbstage"></div>
  <div class="frames" id="lbframes"></div>
  <div class="bar">
    <div>
      <div class="nm" id="lbname"></div>
      <div class="sub" id="lbsub"></div>
    </div>
    <code id="lbpath"></code>
    <button id="lbplay" style="display:none" onclick="toggleAnim()">⏸ 정지</button>
    <a id="lbopen" class="btn" target="_blank">새 탭에서 열기</a>
  </div>
</div>

<script>
const MANIFEST = /*__MANIFEST__*/;
const ROOT = MANIFEST.asset_root;
const items = MANIFEST.items;
const src = p => ROOT + p;

// 안전한 DOM 빌더 (innerHTML 미사용)
function el(tag, props, kids){
  const n = document.createElement(tag);
  if (props) for (const k in props){
    const v = props[k];
    if (v == null) continue;
    if (k === "class") n.className = v;
    else if (k === "text") n.textContent = v;
    else if (k.slice(0,2) === "on") n[k] = v;
    else if (typeof v === "boolean") { if (v) n[k] = true; }
    else n.setAttribute(k, v);
  }
  if (kids != null) for (const c of [].concat(kids)) if (c != null) n.append(c);
  return n;
}
const cssId = p => p.replace(/[^a-z0-9]/gi, "_");
const fmtSize = b => b<1024 ? b+"B" : b<1048576 ? (b/1024).toFixed(b<10240?1:0)+"K" : (b/1048576).toFixed(1)+"M";
const dimStr = e => e.w ? `${e.w}×${e.h}` : "";

// --- 시퀀스 묶기 ---
const seqMap = {};
for (const it of items) if (it.seq) (seqMap[it.seq] ||= []).push(it);
for (const k in seqMap) seqMap[k].sort((a,b)=>a.frame-b.frame);

const entries = [];
const seen = new Set();
for (const it of items){
  if (it.seq){
    if (seen.has(it.seq)) continue;
    seen.add(it.seq);
    const frames = seqMap[it.seq];
    const nm = it.seq.split("::")[1] + "_*";
    entries.push({ ...frames[0], isSeq:true, seqId:it.seq, frames, name:nm, nframes:frames.length });
  } else {
    entries.push({ ...it, isSeq:false });
  }
}

const catCounts = {};
for (const e of entries) catCounts[e.cat] = (catCounts[e.cat]||0)+1;
const cats = Object.keys(catCounts).sort();

let activeCat = "ALL", query = "", grouped = true, curBg = "checker";
document.getElementById("total").textContent = `· ${items.length} files · ${entries.length} entries`;

// 폰트 @font-face 동적 주입 (style.textContent — innerHTML 아님)
const fontStyle = document.createElement("style");
let fontCss = "";
for (const e of entries) if (e.kind === "font")
  fontCss += `@font-face{font-family:'prev_${cssId(e.path)}';src:url('${src(e.path)}');}\n`;
fontStyle.textContent = fontCss;
document.head.appendChild(fontStyle);

// --- 네비 ---
const nav = document.getElementById("nav");
function navItem(c, n){
  const d = el("div", { class:"cat"+(c===activeCat?" on":"") }, [
    el("span", { text: c==="ALL" ? "전체" : c }),
    el("span", { class:"n", text:String(n) }),
  ]);
  d.dataset.cat = c;
  d.onclick = () => { activeCat = c; renderNav(); render(); };
  return d;
}
function renderNav(){
  nav.replaceChildren(navItem("ALL", entries.length), ...cats.map(c=>navItem(c, catCounts[c])));
}

// --- 그리드 ---
const grid = document.getElementById("grid");
function card(e){
  const thumb = el("div", { class:"thumb bg-"+curBg });
  let badge = null;
  if (e.isSeq)            badge = el("span", { class:"badge seq", text:"▶ "+e.nframes });
  else if (e.kind==="font")  badge = el("span", { class:"badge font", text:"FONT" });
  else if (e.kind==="video") badge = el("span", { class:"badge vid", text:"VIDEO" });
  else if (e.ext==="svg")    badge = el("span", { class:"badge svg", text:"SVG" });
  if (badge) thumb.append(badge);

  if (e.kind==="font"){
    const fp = el("div", { class:"fontprev" }, ["사탕개미", el("br"), "AaBb 123"]);
    fp.style.fontFamily = `'prev_${cssId(e.path)}'`;
    thumb.append(fp);
  } else if (e.kind==="video"){
    thumb.append(el("video", { src:src(e.path), muted:true }));
  } else {
    thumb.append(el("img", { loading:"lazy", src:src(e.path), alt:e.name }));
  }
  const sub = [dimStr(e), fmtSize(e.size), e.ext].filter(Boolean).join("  ·  ");
  const c = el("div", { class:"card" }, [
    thumb,
    el("div", { class:"meta" }, [
      el("div", { class:"nm", text:e.name }),
      el("div", { class:"sub", text:sub }),
    ]),
  ]);
  c.onclick = () => openLb(e);
  return c;
}
function render(){
  const q = query.trim().toLowerCase();
  let list = entries.filter(e=>{
    if (activeCat!=="ALL" && e.cat!==activeCat) return false;
    if (q && !(e.name.toLowerCase().includes(q) || e.path.toLowerCase().includes(q) || e.cat.toLowerCase().includes(q))) return false;
    return true;
  });
  grid.replaceChildren();
  if (!list.length){ grid.append(el("div", { class:"empty", text:"결과 없음" })); return; }
  list.sort((a,b)=> a.cat<b.cat?-1 : a.cat>b.cat?1 : (a.name<b.name?-1:1));
  let lastCat = null;
  for (const e of list){
    if (grouped && activeCat==="ALL" && e.cat!==lastCat){
      grid.append(el("div", { class:"cathead", text:`${e.cat} · ${catCounts[e.cat]}` }));
      lastCat = e.cat;
    }
    grid.append(card(e));
  }
}

// --- 라이트박스 + 애니 ---
let animTimer=null, animOn=false, animFrames=null, animIdx=0, curEntry=null;
const lb = document.getElementById("lb");
function openLb(e){
  curEntry = e;
  document.getElementById("lbname").textContent = e.name;
  document.getElementById("lbsub").textContent =
    [e.isSeq?`${e.nframes} frames`:"", dimStr(e), fmtSize(e.size), e.cat].filter(Boolean).join("  ·  ");
  document.getElementById("lbpath").textContent = e.path;
  document.getElementById("lbopen").href = src(e.path);
  const stage = document.getElementById("lbstage");
  const framesBar = document.getElementById("lbframes");
  const playBtn = document.getElementById("lbplay");
  stopAnim();
  stage.replaceChildren();
  framesBar.replaceChildren();
  playBtn.style.display = "none";

  if (e.isSeq){
    animFrames = e.frames; animIdx = 0;
    const img = el("img", { id:"lbimg", class:"bg-"+curBg, src:src(animFrames[0].path) });
    img.style.cssText = "padding:20px;border-radius:12px";
    stage.append(img);
    animFrames.forEach((f,i)=>{
      const t = el("img", { src:src(f.path), class:i===0?"on":"" });
      t.dataset.i = i;
      t.onclick = ev => { ev.stopPropagation(); stopAnim(); showFrame(i); };
      framesBar.append(t);
    });
    playBtn.style.display = ""; startAnim();
  } else if (e.kind==="font"){
    const big = el("span", { text:"가나다라 ABCabc 0123456789" }); big.style.fontSize = "38px";
    const tag = el("span", { text:"★ 다음 별을 향해! +Y는 아래쪽 ↓" }); tag.style.fontSize = "30px";
    const d = el("div", null, ["사탕개미 CandyAnts", el("br"), big, el("br"), tag]);
    d.style.cssText = `font-family:'prev_${cssId(e.path)}';font-size:60px;text-align:center;color:var(--ink);line-height:1.4;padding:20px`;
    stage.append(d);
  } else if (e.kind==="video"){
    stage.append(el("video", { src:src(e.path), controls:true, autoplay:true, loop:true, muted:true }));
  } else {
    const img = el("img", { class:"bg-"+curBg, src:src(e.path) });
    img.style.cssText = "padding:20px;border-radius:12px";
    stage.append(img);
  }
  lb.classList.add("show");
}
function showFrame(i){
  animIdx = i;
  const img = document.getElementById("lbimg");
  if (img) img.src = src(animFrames[i].path);
  document.querySelectorAll("#lbframes img").forEach(im=>im.classList.toggle("on", +im.dataset.i===i));
}
function startAnim(){
  animOn = true; document.getElementById("lbplay").textContent = "⏸ 정지";
  animTimer = setInterval(()=>showFrame((animIdx+1)%animFrames.length), 130);
}
function stopAnim(){
  animOn = false; if (animTimer) clearInterval(animTimer); animTimer = null;
  const b = document.getElementById("lbplay"); if (b) b.textContent = "▶ 재생";
}
function toggleAnim(){ animOn ? stopAnim() : startAnim(); }
function closeLb(){ stopAnim(); lb.classList.remove("show"); }
lb.onclick = e => { if (e.target===lb) closeLb(); };
document.addEventListener("keydown", e=>{
  if (e.key==="Escape") closeLb();
  if (!lb.classList.contains("show") || !curEntry || !curEntry.isSeq) return;
  if (e.key==="ArrowRight"){ stopAnim(); showFrame((animIdx+1)%animFrames.length); }
  if (e.key==="ArrowLeft"){ stopAnim(); showFrame((animIdx-1+animFrames.length)%animFrames.length); }
  if (e.key===" "){ e.preventDefault(); toggleAnim(); }
});

// --- 컨트롤 ---
document.getElementById("bgseg").onclick = e=>{
  const b = e.target.closest("button"); if (!b) return;
  curBg = b.dataset.bg;
  document.querySelectorAll("#bgseg button").forEach(x=>x.classList.toggle("on", x===b));
  document.querySelectorAll(".thumb").forEach(t=>{ t.className = "thumb bg-"+curBg; });
};
document.getElementById("sizeseg").onclick = e=>{
  const b = e.target.closest("button"); if (!b) return;
  document.querySelectorAll("#sizeseg button").forEach(x=>x.classList.toggle("on", x===b));
  document.documentElement.style.setProperty("--card", b.dataset.card+"px");
};
document.getElementById("pixel").onchange = e => document.body.classList.toggle("pixel", e.target.checked);
document.getElementById("grouped").onchange = e => { grouped = e.target.checked; render(); };
document.getElementById("q").oninput = e => { query = e.target.value; render(); };

renderNav();
render();
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
