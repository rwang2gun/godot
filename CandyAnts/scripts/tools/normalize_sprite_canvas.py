#!/usr/bin/env python3
"""
normalize_sprite_canvas.py — ant 스프라이트 PNG 캔버스를 단일 height로 정규화.

문제: `assets/sprites/characters/ant_pajama_girl/` 9 animation의 캔버스 height가
  두 가족(431px tall, 276px short)으로 갈라져 있어 `AnimatedSprite2D` 단일
  position.y로는 animation 전환 시 발 baseline이 ~12.4px(scale 0.16) 점프한다.

해결: short 가족(height < 431)을 **TOP transparent padding**으로 height 431에
  맞춘다. width는 frame별 원본 유지 (centered=true에서 horizontal alignment는
  user의 원본 의도대로). content는 항상 PNG 바닥(y=H-1)에 발이 닿도록 보존.

스코프 (현재 적용):
  assets/sprites/characters/ant_pajama_girl/{idle,walk,carry,fall,blocker,
                                              build,climb,dig,victory}/*.png

candy는 정적 1-frame이라 가족 mismatch 영향 없음 — 본 스크립트 대상 X.

CLI:
  python normalize_sprite_canvas.py             # --scan과 동일
  python normalize_sprite_canvas.py --scan      # height별 frame 개수 리포트
  python normalize_sprite_canvas.py --apply     # 적용 (height < 431 PNG만 top-pad)
  python normalize_sprite_canvas.py --check     # 모든 PNG height == 431 검증 (CI 게이트)

Exit: 0 ok / 1 height mismatch (check 실패) / 2 malformed / 3 missing Pillow.
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("error: Pillow 미설치. `pip install Pillow` 후 재실행.", file=sys.stderr)
    sys.exit(3)

ROOT = Path(__file__).resolve().parents[2]
SPRITE_ROOT = ROOT / "assets" / "sprites" / "characters" / "ant_pajama_girl"
TARGET_HEIGHT = 431
# 캔버스 안에서 character content가 차지할 목표 높이. tall family(idle/walk/carry/climb)
# 의 평균 content_h가 ~407 ± 5 라 410으로 고정. 짧은 가족(fall/blocker/build/dig/victory
# 의 짧은 프레임)도 동일 content_h로 리사이즈해 game-render 스케일을 일치시킨다.
TARGET_CONTENT_HEIGHT = 410
# 캔버스 폭. 410으로 height-resize 후 가장 넓어지는 frame(build_03 205*410/226=372,
# fall_03 200*410/220=373)까지 클리핑 없이 수용. centered=true와 함께 character가
# 항상 node x=0. 양 옆 transparent padding은 ant의 자유 좌우 움직임에 영향 없음.
CANVAS_WIDTH = 400

ANIM_DIRS = ["idle", "walk", "carry", "fall", "blocker", "build", "climb", "dig", "victory"]


def iter_pngs():
    for anim in ANIM_DIRS:
        d = SPRITE_ROOT / anim
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.png")):
            yield p


def scan():
    by_height: dict[int, int] = {}
    by_anim: dict[str, set[int]] = {}
    total = 0
    for p in iter_pngs():
        with Image.open(p) as im:
            h = im.size[1]
        by_height[h] = by_height.get(h, 0) + 1
        by_anim.setdefault(p.parent.name, set()).add(h)
        total += 1
    print(f"[scan] total={total} target_height={TARGET_HEIGHT}")
    for h, n in sorted(by_height.items()):
        flag = " OK" if h == TARGET_HEIGHT else " PAD"
        print(f"  height={h}: count={n}{flag}")
    for anim in ANIM_DIRS:
        hs = by_anim.get(anim, set())
        if hs:
            print(f"  {anim}: heights={sorted(hs)}")
    needs = sum(n for h, n in by_height.items() if h != TARGET_HEIGHT)
    print(f"[scan] needs_padding={needs}")
    return 0 if needs == 0 else 0  # scan is informational


def apply():
    padded = 0
    skipped = 0
    for p in iter_pngs():
        with Image.open(p) as im:
            im = im.convert("RGBA")
            w, h = im.size
            if h == TARGET_HEIGHT:
                skipped += 1
                continue
            if h > TARGET_HEIGHT:
                print(f"error: {p.relative_to(ROOT)} height={h} > target {TARGET_HEIGHT}",
                      file=sys.stderr)
                return 2
            # top-pad with transparent — content stays at bottom (feet on bottom edge).
            new_im = Image.new("RGBA", (w, TARGET_HEIGHT), (0, 0, 0, 0))
            new_im.paste(im, (0, TARGET_HEIGHT - h))
            new_im.save(p, "PNG")
            padded += 1
            print(f"  padded {p.relative_to(ROOT)} {w}x{h} -> {w}x{TARGET_HEIGHT}")
    print(f"[apply] padded={padded} skipped={skipped}")
    return 0


def resize():
    """tight-crop -> resize content to height 410 -> bottom-center paste into CANVAS_WIDTH x 431."""
    processed = 0
    skipped = 0
    overflow: list[tuple[Path, int]] = []
    for p in iter_pngs():
        with Image.open(p) as im:
            im = im.convert("RGBA")
            bb = im.getbbox()
            if bb is None:
                skipped += 1
                continue
            cropped = im.crop(bb)
            cw, ch = cropped.size
            if ch == 0:
                skipped += 1
                continue
            scale = TARGET_CONTENT_HEIGHT / ch
            new_w = max(1, round(cw * scale))
            new_h = TARGET_CONTENT_HEIGHT
            resized = cropped.resize((new_w, new_h), Image.LANCZOS)
            if new_w > CANVAS_WIDTH:
                overflow.append((p.relative_to(ROOT), new_w))
            canvas = Image.new("RGBA", (CANVAS_WIDTH, TARGET_HEIGHT), (0, 0, 0, 0))
            paste_x = (CANVAS_WIDTH - new_w) // 2
            paste_y = TARGET_HEIGHT - new_h  # bottom-aligned
            canvas.paste(resized, (paste_x, paste_y), resized)
            canvas.save(p, "PNG")
            processed += 1
            print(f"  resize {p.relative_to(ROOT)} content={cw}x{ch} -> {new_w}x{new_h} "
                  f"canvas={CANVAS_WIDTH}x{TARGET_HEIGHT}")
    print(f"[resize] processed={processed} skipped={skipped}")
    if overflow:
        print(f"[resize] WARN: {len(overflow)} frame scaled width > CANVAS_WIDTH",
              file=sys.stderr)
        for p, w in overflow[:10]:
            print(f"  {p}: scaled_w={w}", file=sys.stderr)
    return 0


def check():
    bad = []
    for p in iter_pngs():
        with Image.open(p) as im:
            w, h = im.size
        if h != TARGET_HEIGHT:
            bad.append((p.relative_to(ROOT), h))
        elif w != CANVAS_WIDTH:
            bad.append((p.relative_to(ROOT), w))
    if bad:
        print(f"[check] FAIL: {len(bad)} PNG height != {TARGET_HEIGHT}", file=sys.stderr)
        for p, h in bad[:10]:
            print(f"  {p}: height={h}", file=sys.stderr)
        return 1
    print(f"[check] PASS: all ant PNG height == {TARGET_HEIGHT}")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--scan", action="store_true")
    ap.add_argument("--apply", action="store_true",
                    help="legacy: top-pad transparent to height 431, preserve width.")
    ap.add_argument("--resize", action="store_true",
                    help="recommended: tight-crop -> content height 410 -> 340x431 canvas.")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.resize:
        return resize()
    if args.apply:
        return apply()
    if args.check:
        return check()
    return scan()


if __name__ == "__main__":
    sys.exit(main())
