#!/usr/bin/env python3
"""
normalize_svg.py — handoff SVG 5장 정규화 → assets/ (Option A, phase 9).

스코프: 5개 파일 하드코딩.
  docs/design_handoff/assets/logo/wordmark.svg
  docs/design_handoff/assets/logo/icon.svg
  docs/design_handoff/assets/logo/mascot.svg
  docs/design_handoff/assets/sprites/home.svg
  docs/design_handoff/assets/illustrations/stage_bg.svg

기존 assets/icons/skills/*.svg 8장은 비대상 (phase 8 manual 산출물 유지).

resolve_order (strict 1:1, tolerance 도입 X, alpha 유무 조건 분기):
  (0) white-alpha shortcut: oklch(1 0 0 / a) → rgba(255,255,255,a) (alpha 있을 때 우선)
  (1) alpha 있음 + (L,C,H) ∈ TOKENS → alpha_variants REQUIRED, 미스 시 exit 1
      (token hex 폴백 금지 — alpha-bearing token oklch의 transparency를 보존하기 위함)
  (1') alpha 있음 + (L,C,H) ∉ TOKENS → alpha_variants 우선, 미스 시 CSS Color 4 (rgba 출력)
  (2) alpha 없음 + (L,C,H) ∈ TOKENS → token hex
  (3) alpha 없음 + (L,C,H) ∉ TOKENS + oklch_extras 매칭 → 매핑 hex
  (4) 셋 다 미스 → CSS Color 4 spec 변환 (oklch → oklab → linear sRGB → sRGB), gamut fail 시 exit 1

색 위치 (전 위치 일괄):
  fill / stroke / stop-color / flood-color / lighting-color / color 속성
  인라인 style="..." 안의 *-color 선언
  <defs><style> 블록 안 CSS 선언 (인라인 후 블록 제거)

CLI:
  python normalize_svg.py                    # 5장 정규화 실행
  python normalize_svg.py --scan             # 5장 enumerate (no write)
  python normalize_svg.py --scan-handoff-all # handoff 전체 mapping coverage gate
  python normalize_svg.py --check            # 5장 멱등 검증 (output == 기존 assets/<...>)
  python normalize_svg.py --self-test        # resolve_order 단위 검증

Exit: 0 success / 1 unmapped/gamut fail / 2 malformed input.
외부 의존성 0건: xml.etree, re, json, math, pathlib, sys 만 사용.
"""

import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HANDOFF_ROOT = ROOT / "docs" / "design_handoff" / "assets"
ASSETS_ROOT = ROOT / "assets"
COLOR_MAP_PATH = ROOT / "scripts" / "tools" / "svg_color_map.json"

# UI_GUIDE §1.1·§1.2 token table (oklch tuple → sRGB hex).
# Key = (L, C, H) raw float. Exact float comparison via Python dict lookup.
# Note: int H and float H hash identically (75 == 75.0), so both forms work.
TOKENS = {
    (0.985, 0.012,  75): "#FBF8F1",  # cream_50
    (0.965, 0.020,  70): "#F5EFE3",  # cream_100
    (0.93,  0.030,  70): "#E9DFCB",  # cream_200
    (0.88,  0.040,  65): "#D9C9AC",  # cream_300
    (0.26,  0.045,  50): "#3A2A1C",  # ink_900
    (0.40,  0.060,  50): "#5C4530",  # ink_700
    (0.58,  0.045,  55): "#8C7660",  # ink_500
    (0.90,  0.08,   35): "#FAD9C4",  # peach_300
    (0.78,  0.155,  28): "#F2A48F",  # peach_500
    (0.62,  0.165,  30): "#D17A60",  # peach_700
    (0.92,  0.07,  175): "#D4F0E5",  # mint_300
    (0.82,  0.13,  175): "#9ED9C2",  # mint_500
    (0.60,  0.13,  175): "#5EA88A",  # mint_700
    (0.86,  0.10,   10): "#F7C9C4",  # berry_300
    (0.70,  0.20,   15): "#E48579",  # berry_500
    (0.55,  0.20,   15): "#B85546",  # berry_700
    (0.95,  0.10,   95): "#FCEFC2",  # lemon_300
    (0.88,  0.16,   95): "#F0D77B",  # lemon_500
    (0.72,  0.16,   90): "#C9A93C",  # lemon_700
    (0.88,  0.07,  300): "#DCCEE2",  # grape_300
    (0.72,  0.14,  300): "#B49AC5",  # grape_500
    (0.55,  0.14,  300): "#7E5A9A",  # grape_700
    (0.92,  0.05,  235): "#CCDFEA",  # sky_300
    (0.88,  0.07,  140): "#B0DCB4",  # grass_300
}

NORMALIZE_TARGETS = [
    ("logo/wordmark.svg",            "logo/wordmark.svg"),
    ("logo/icon.svg",                "logo/icon.svg"),
    ("logo/mascot.svg",              "logo/mascot.svg"),
    ("sprites/home.svg",             "sprites/home.svg"),
    ("illustrations/stage_bg.svg",   "illustrations/stage_bg.svg"),
]

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)

COLOR_ATTRS = ("fill", "stroke", "stop-color", "flood-color", "lighting-color", "color")

OKLCH_RE = re.compile(
    r"oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*/\s*([\d.]+))?\s*\)"
)
HEX_RE = re.compile(r"#[0-9a-fA-F]{3,8}")
RGBA_RE = re.compile(r"rgba?\([^)]*\)")
CLASS_RE = re.compile(r"class\s*=\s*[\"']([^\"']+)[\"']")
STYLE_DECL_RE = re.compile(r"([\w-]+)\s*:\s*([^;]+?)\s*(?:;|$)")
CSS_RULE_RE = re.compile(r"\.([\w-]+)\s*\{([^}]*)\}")


# ---------------------------------------------------------------------------
# Color map loading + helpers
# ---------------------------------------------------------------------------

def load_color_map() -> dict:
    return json.loads(COLOR_MAP_PATH.read_text(encoding="utf-8"))


def oklch_to_srgb_hex(L: float, C: float, H: float) -> str:
    """CSS Color 4 oklch → oklab → linear sRGB → sRGB. Returns lowercase hex.

    Raises ValueError if out of gamut after clamping (≥1.0 over per-channel).
    """
    hr = math.radians(H)
    a = C * math.cos(hr)
    b = C * math.sin(hr)

    # oklab → linear sRGB (matrix from CSS Color 4 spec)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b

    l = l_ ** 3
    m = m_ ** 3
    s = s_ ** 3

    r_lin =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g_lin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b_lin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def to_srgb(c: float) -> float:
        if c <= 0.0031308:
            return 12.92 * c
        return 1.055 * (c ** (1 / 2.4)) - 0.055

    rs, gs, bs = to_srgb(r_lin), to_srgb(g_lin), to_srgb(b_lin)
    # Clamp; if heavily out of gamut, raise.
    def clamp_or_raise(v: float) -> int:
        if v < -0.01 or v > 1.01:
            raise ValueError(f"gamut out: {v}")
        return max(0, min(255, round(v * 255)))

    r, g, b = clamp_or_raise(rs), clamp_or_raise(gs), clamp_or_raise(bs)
    return f"#{r:02x}{g:02x}{b:02x}"


def _parse_variant_key(key: str) -> tuple | None:
    """Parse 'L C H' or 'L C H / a' → (L, C, H[, a]). Returns None if not parseable."""
    m = re.match(r"^([\d.]+)\s+([\d.]+)\s+([\d.]+)(?:\s*/\s*([\d.]+))?$", key.strip())
    if not m:
        return None
    L = float(m.group(1)); C = float(m.group(2)); H = float(m.group(3))
    if m.group(4):
        return (L, C, H, float(m.group(4)))
    return (L, C, H)


def _find_variant_match(needle: tuple, color_map_section: dict) -> str | None:
    """Find a section entry whose parsed key matches `needle`. Tolerates format
    differences (0.4 vs 0.40) by parsing both sides to float tuples."""
    for k, v in color_map_section.items():
        if k.startswith("_"):
            continue
        parsed = _parse_variant_key(k)
        if parsed == needle:
            return v
    return None


def resolve_oklch(L: float, C: float, H: float, alpha: float | None, color_map: dict) -> str:
    """Apply resolve_order. Returns hex or rgba(...) string. Raises if unmapped + gamut fail.

    Branch labels match svg_color_map.json `_about.resolve_order` (0/1/1'/2/3/4).
    """
    # (0) white-alpha shortcut
    if L == 1.0 and C == 0.0 and H == 0.0 and alpha is not None:
        return f"rgba(255,255,255,{alpha})"

    # (1) / (1') alpha-present branch — alpha_variants first
    if alpha is not None:
        v = _find_variant_match((L, C, H, alpha), color_map.get("alpha_variants", {}))
        if v is not None:
            return v
        # (1) Token oklch + alpha + no alpha_variants → fail (preserves transparency).
        if (L, C, H) in TOKENS:
            raise ValueError(
                f"token oklch({L} {C} {H}) with alpha={alpha} requires alpha_variants entry"
            )
        # (1') Non-token alpha-present → fall through to CSS Color 4 conversion below.

    # (2) alpha-absent token table
    tup = (L, C, H)
    if alpha is None and tup in TOKENS:
        return TOKENS[tup]

    # (3) alpha-absent oklch_extras (non-token only)
    if alpha is None:
        v = _find_variant_match((L, C, H), color_map.get("oklch_extras", {}))
        if v is not None:
            return v

    # (4) CSS Color 4 spec fallback (alpha-absent fallthrough; also reached by 1')
    try:
        hex_val = oklch_to_srgb_hex(L, C, H)
        if alpha is not None:
            # rare: token-external oklch with alpha → emit rgba
            r = int(hex_val[1:3], 16); g = int(hex_val[3:5], 16); b = int(hex_val[5:7], 16)
            return f"rgba({r},{g},{b},{alpha})"
        return hex_val.upper()
    except ValueError as e:
        raise ValueError(f"oklch({L} {C} {H}) unmapped + gamut fail: {e}")


def _fmt(v: float) -> str:
    """Format float for svg_color_map key lookup. Strips trailing zeros for consistency.

    Designed so that handoff oklch (e.g. '0.78 0.155 28') matches map keys verbatim.
    Map keys in svg_color_map.json should use the same canonical form.
    """
    s = f"{v:g}"
    return s


def resolve_literal_hex(hex_val: str, color_map: dict) -> str:
    """literal_color_map → mapped, allowed_literals → passthrough, else raise."""
    lower = hex_val.lower()
    lmap = color_map.get("literal_color_map", {})
    if lower in lmap:
        return lmap[lower]
    if hex_val in lmap:
        return lmap[hex_val]
    allowed = [v.lower() for v in color_map.get("allowed_literals", {}).get("values", [])]
    if lower in allowed:
        return hex_val
    # Also accept exact token hex (e.g., already #3A2A1C)
    token_hex = {h.lower() for h in TOKENS.values()}
    if lower in token_hex:
        return hex_val
    # Also accept hex that appears as a value in literal_color_map or oklch_extras
    mapped_targets = {v.lower() for v in lmap.values()}
    if lower in mapped_targets:
        return hex_val
    extras_targets = {v.lower() for v in color_map.get("oklch_extras", {}).values() if isinstance(v, str) and v.startswith("#")}
    if lower in extras_targets:
        return hex_val
    raise ValueError(f"literal hex unmapped: {hex_val}")


def resolve_color_string(value: str, color_map: dict) -> str:
    """Transform a color value (oklch / hex / rgba / 'none' / 'currentColor' / url(#ref))."""
    value = value.strip()
    if value in ("none", "transparent", "currentColor", "inherit"):
        return value

    # url(#gradient_id) — SVG paint server reference, leave intact
    if value.startswith("url("):
        return value

    # oklch
    m = OKLCH_RE.fullmatch(value)
    if m:
        L = float(m.group(1)); C = float(m.group(2)); H = float(m.group(3))
        alpha = float(m.group(4)) if m.group(4) else None
        return resolve_oklch(L, C, H, alpha, color_map)

    # rgba passthrough
    if value.startswith("rgba(") or value.startswith("rgb("):
        return value

    # hex
    if value.startswith("#"):
        return resolve_literal_hex(value, color_map)

    # Named colors not expected; raise.
    raise ValueError(f"unknown color value: {value}")


# ---------------------------------------------------------------------------
# Style / class inlining
# ---------------------------------------------------------------------------

def parse_style_string(style: str) -> dict:
    return {m.group(1).strip(): m.group(2).strip() for m in STYLE_DECL_RE.finditer(style)}


def serialize_style(decls: dict) -> str:
    return ";".join(f"{k}:{v}" for k, v in decls.items())


def transform_style_value(decls: dict, color_map: dict) -> dict:
    out = {}
    for k, v in decls.items():
        if k in COLOR_ATTRS:
            out[k] = resolve_color_string(v, color_map)
        else:
            out[k] = v
    return out


def _is_style_tag(tag: str) -> bool:
    # Match both namespaced ({http://...}style) and unnamespaced (style) forms.
    return tag == f"{{{SVG_NS}}}style" or tag == "style"


def collect_defs_styles(root: ET.Element) -> dict:
    """Returns {class_name: {fill, stroke, ...}} parsed from <style> blocks (any depth)."""
    out = {}
    for el in root.iter():
        if not _is_style_tag(el.tag):
            continue
        css = (el.text or "")
        for m in CSS_RULE_RE.finditer(css):
            cls = m.group(1)
            decls = parse_style_string(m.group(2))
            out.setdefault(cls, {}).update(decls)
    return out


def strip_defs_styles(root: ET.Element) -> None:
    """Remove all <style> elements (namespaced or not). <defs> kept if has other children."""
    for parent in root.iter():
        styles = [c for c in list(parent) if _is_style_tag(c.tag)]
        for s in styles:
            parent.remove(s)


# ---------------------------------------------------------------------------
# Main element transform
# ---------------------------------------------------------------------------

def transform_element(el: ET.Element, color_map: dict, defs_classes: dict) -> None:
    # class → inline
    cls_attr = el.attrib.get("class")
    if cls_attr is not None:
        classes = cls_attr.split()
        merged = {}
        for cls in classes:
            entry = color_map.get("class_map", {}).get(cls)
            if entry is None and cls in defs_classes:
                entry = defs_classes[cls]
            if entry is None:
                raise ValueError(f"unmapped class: {cls}")
            if entry.get("_skip_inline"):
                continue
            for k, v in entry.items():
                if k.startswith("_"):
                    continue
                merged[k] = v
        for k, v in merged.items():
            # Element-level attribute wins over class-derived defaults.
            if k not in el.attrib:
                el.attrib[k] = v
        del el.attrib["class"]

    # color attributes
    for attr in COLOR_ATTRS:
        if attr in el.attrib:
            el.attrib[attr] = resolve_color_string(el.attrib[attr], color_map)

    # inline style
    if "style" in el.attrib:
        decls = parse_style_string(el.attrib["style"])
        decls = transform_style_value(decls, color_map)
        if decls:
            el.attrib["style"] = serialize_style(decls)
        else:
            del el.attrib["style"]


def normalize_tree(tree: ET.ElementTree, color_map: dict) -> None:
    root = tree.getroot()
    defs_classes = collect_defs_styles(root)
    strip_defs_styles(root)
    for el in root.iter():
        transform_element(el, color_map, defs_classes)


# ---------------------------------------------------------------------------
# I/O + commands
# ---------------------------------------------------------------------------

def normalize_one(handoff_path: Path, out_path: Path, color_map: dict) -> None:
    tree = ET.parse(handoff_path)
    normalize_tree(tree, color_map)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    # Write with declaration
    body = ET.tostring(tree.getroot(), encoding="unicode", short_empty_elements=True)
    out_path.write_text(body, encoding="utf-8")


def cmd_normalize(color_map: dict) -> int:
    failures = []
    for rel_in, rel_out in NORMALIZE_TARGETS:
        src = HANDOFF_ROOT / rel_in
        dst = ASSETS_ROOT / rel_out
        try:
            normalize_one(src, dst, color_map)
            print(f"[OK] {rel_in} → {rel_out}")
        except ValueError as e:
            failures.append(f"{rel_in}: {e}")
            print(f"[FAIL] {rel_in}: {e}", file=sys.stderr)
        except ET.ParseError as e:
            failures.append(f"{rel_in}: parse error {e}")
            print(f"[PARSE] {rel_in}: {e}", file=sys.stderr)
            return 2
    return 0 if not failures else 1


def cmd_scan(handoff_paths: list[Path], color_map: dict, label: str) -> int:
    """Enumerate oklch / class / hex / rgba in given files. exit 1 if any unmapped."""
    unmapped_classes = set()
    unmapped_oklch = set()
    unmapped_literals = set()
    for p in handoff_paths:
        try:
            text = p.read_text(encoding="utf-8")
        except FileNotFoundError:
            print(f"[skip-missing] {p}")
            continue
        # classes — prefer XML parse to avoid CLASS_RE matching `class="..."` strings
        # inside attribute values, CDATA, or comments. Fallback to regex only on parse fail.
        tree_obj = None
        try:
            tree_obj = ET.parse(p)
        except ET.ParseError:
            tree_obj = None
        if tree_obj is not None:
            defs = collect_defs_styles(tree_obj.getroot())
            for el in tree_obj.getroot().iter():
                cls_attr = el.attrib.get("class")
                if cls_attr is None:
                    continue
                for cls in cls_attr.split():
                    if cls in color_map.get("class_map", {}):
                        continue
                    if cls in defs:
                        continue
                    unmapped_classes.add(cls)
        else:
            for m in CLASS_RE.finditer(text):
                for cls in m.group(1).split():
                    if cls not in color_map.get("class_map", {}):
                        unmapped_classes.add(cls)
        # oklch — scan uses the same resolve_oklch path as normalize to avoid divergence.
        # Resolve_oklch raises ValueError on truly unmapped/gamut-fail; everything that resolves
        # (including CSS Color 4 fallback for alpha-present non-token) counts as mapped.
        for m in OKLCH_RE.finditer(text):
            L, C, H = float(m.group(1)), float(m.group(2)), float(m.group(3))
            alpha = float(m.group(4)) if m.group(4) else None
            try:
                resolve_oklch(L, C, H, alpha, color_map)
            except ValueError:
                key = f"({L} {C} {H}" + (f" / {alpha})" if alpha is not None else ")")
                unmapped_oklch.add(key)
        # literal hex
        for m in HEX_RE.finditer(text):
            try:
                resolve_literal_hex(m.group(0), color_map)
            except ValueError:
                unmapped_literals.add(m.group(0))

    print(f"=== {label} scan result ===")
    print(f"unmapped classes  : {sorted(unmapped_classes)}")
    print(f"unmapped oklch    : {sorted(unmapped_oklch)}")
    print(f"unmapped literals : {sorted(unmapped_literals)}")
    if unmapped_classes or unmapped_oklch or unmapped_literals:
        return 1
    return 0


def cmd_scan_5(color_map: dict) -> int:
    paths = [HANDOFF_ROOT / rel_in for rel_in, _ in NORMALIZE_TARGETS]
    return cmd_scan(paths, color_map, "5-file (--scan)")


def cmd_scan_handoff_all(color_map: dict) -> int:
    paths = list(HANDOFF_ROOT.rglob("*.svg"))
    return cmd_scan(paths, color_map, f"handoff-all ({len(paths)} files)")


def cmd_check(color_map: dict) -> int:
    """멱등 검증 — normalize 결과가 기존 assets/<...>와 byte-identical."""
    diffs = []
    for rel_in, rel_out in NORMALIZE_TARGETS:
        src = HANDOFF_ROOT / rel_in
        existing = ASSETS_ROOT / rel_out
        if not existing.exists():
            diffs.append(f"missing: {rel_out}")
            continue
        try:
            tree = ET.parse(src)
            normalize_tree(tree, color_map)
            produced = ET.tostring(tree.getroot(), encoding="unicode", short_empty_elements=True)
            current = existing.read_text(encoding="utf-8")
            if produced != current:
                diffs.append(f"drift: {rel_out}")
        except Exception as e:
            diffs.append(f"error: {rel_out}: {e}")
    if diffs:
        for d in diffs:
            print(f"[CHECK FAIL] {d}", file=sys.stderr)
        return 1
    print(f"[CHECK PASS] {len(NORMALIZE_TARGETS)} files idempotent")
    return 0


def cmd_self_test(color_map: dict) -> int:
    """resolve_order 단위 검증."""
    failures = []

    # Test 1: alpha_variants 각 키가 resolve_oklch를 통과해 expected rgba와 일치
    for key, expected in color_map.get("alpha_variants", {}).items():
        if key.startswith("_"):
            continue
        m = re.match(r"([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*/\s*([\d.]+)", key)
        if not m:
            failures.append(f"alpha_variants key parse: {key}")
            continue
        L, C, H, a = float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))
        got = resolve_oklch(L, C, H, a, color_map)
        if got != expected:
            failures.append(f"alpha_variants resolve mismatch: {key} expected={expected} got={got}")

    # Test 2: oklch_extras 각 키가 token oklch와 충돌 안 함
    for key in color_map.get("oklch_extras", {}).keys():
        if key.startswith("_"):
            continue
        m = re.match(r"([\d.]+)\s+([\d.]+)\s+([\d.]+)", key)
        if not m:
            continue
        L, C, H = float(m.group(1)), float(m.group(2)), float(m.group(3))
        if (L, C, H) in TOKENS:
            failures.append(f"oklch_extras has token oklch: {key}")

    # Test 3: white-alpha shortcut
    got = resolve_oklch(1.0, 0.0, 0.0, 0.5, color_map)
    if got != "rgba(255,255,255,0.5)":
        failures.append(f"white-alpha shortcut fail: got {got}")

    # Test 4: token table direct
    got = resolve_oklch(0.78, 0.155, 28, None, color_map)
    if got != "#F2A48F":
        failures.append(f"token peach_500 fail: got {got}")

    # Test 5: allowed literal passthrough
    got = resolve_literal_hex("#ffffff", color_map)
    if got != "#ffffff":
        failures.append(f"allowed literal #ffffff fail: got {got}")

    if failures:
        for f in failures:
            print(f"[SELF-TEST FAIL] {f}", file=sys.stderr)
        return 1
    print("[SELF-TEST PASS] resolve_order + alpha_variants + sanity")
    return 0


def main(argv: list[str]) -> int:
    valid_flags = {"--scan", "--scan-handoff-all", "--check", "--self-test", "--strict"}
    args = argv[1:]
    unknown = [a for a in args if a not in valid_flags]
    if unknown:
        print(f"unknown flag(s): {unknown}", file=sys.stderr)
        print(f"valid: {sorted(valid_flags)}", file=sys.stderr)
        return 2
    # Mutual exclusion: only one mode flag at a time (--strict is a default-on modifier).
    mode_flags = [a for a in args if a != "--strict"]
    if len(mode_flags) > 1:
        print(f"only one mode flag allowed at a time, got: {mode_flags}", file=sys.stderr)
        return 2

    color_map = load_color_map()
    if "--scan" in args:
        return cmd_scan_5(color_map)
    if "--scan-handoff-all" in args:
        return cmd_scan_handoff_all(color_map)
    if "--check" in args:
        return cmd_check(color_map)
    if "--self-test" in args:
        return cmd_self_test(color_map)
    return cmd_normalize(color_map)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
