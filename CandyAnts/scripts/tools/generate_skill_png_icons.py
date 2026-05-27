from __future__ import annotations

from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "icons" / "skills"
CURSOR_OUT = OUT / "cursors"
SPRITES = ROOT / "assets" / "sprites" / "characters" / "ant_pajama_girl"
SIZE = 128
SCALE = 4

# Core Color Palette
INK = (37, 33, 43, 255)
CREAM = (252, 247, 236, 255)
WHITE = (255, 255, 255, 255)
POINTER_FILL = (255, 255, 255, 245)

def s(v: int | float) -> int:
    return int(round(v * SCALE))

def rect(values: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(s(v) for v in values)

def load_sprite(anim: str, frame: int) -> Image.Image:
    src = Image.open(SPRITES / anim / f"{anim}_{frame:02d}.png").convert("RGBA")
    bbox = src.getbbox()
    if bbox is None:
        return src
    return src.crop(bbox)

def fit_sprite(sprite: Image.Image, height: int) -> Image.Image:
    ratio = height / sprite.height
    return sprite.resize((max(1, int(sprite.width * ratio)), height), Image.Resampling.LANCZOS)

def paste_center(canvas: Image.Image, sprite: Image.Image, cx: int, bottom: int) -> None:
    x = s(cx) - sprite.width // 2
    y = s(bottom) - sprite.height
    canvas.alpha_composite(sprite, (x, y))

def line(d: ImageDraw.ImageDraw, points: list[tuple[int, int]], fill=INK, width=5) -> None:
    d.line([(s(x), s(y)) for x, y in points], fill=fill, width=s(width), joint="curve")

def draw_pointer(d: ImageDraw.ImageDraw) -> None:
    points = [(4, 4), (4, 34), (34, 4)]
    scaled = [tuple(map(s, p)) for p in points]
    d.polygon(scaled, fill=POINTER_FILL)
    line(d, [(4, 4), (4, 34), (34, 4), (4, 4)], fill=(255, 255, 255, 255), width=4.0)
    line(d, [(4, 4), (4, 34), (34, 4), (4, 4)], fill=INK, width=2.0)

def draw_radial_gradient(draw, cx, cy, r, color_inner, color_outer):
    for i in range(r, 0, -1):
        t = i / r
        curr_color = tuple(
            int(color_inner[j] * (1 - t) + color_outer[j] * t)
            for j in range(4)
        )
        draw.ellipse((cx - i, cy - i, cx + i, cy + i), fill=curr_color)

def draw_sparkle(d, cx, cy, size):
    points = [
        (cx, cy - size),
        (cx + size * 0.3, cy - size * 0.3),
        (cx + size, cy),
        (cx + size * 0.3, cy + size * 0.3),
        (cx, cy + size),
        (cx - size * 0.3, cy + size * 0.3),
        (cx - size, cy),
        (cx - size * 0.3, cy - size * 0.3)
    ]
    d.polygon(points, fill=(255, 255, 255, 220))

def draw_candy_badge_bg(img: Image.Image, d: ImageDraw.ImageDraw, color_inner, color_outer) -> None:
    s_size = SIZE * SCALE
    cx, cy = s_size // 2, s_size // 2
    r_outer = s(58)
    r_inner = s(52)
    
    # 1. Draw outer chocolate border
    d.ellipse((cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer), fill=INK)
    
    # 2. Draw inner candy-themed radial gradient
    draw_radial_gradient(d, cx, cy, r_inner, color_inner, color_outer)
    
    # 3. Draw sugar sparkles
    draw_sparkle(d, cx - s(25), cy - s(25), s(6))
    draw_sparkle(d, cx + s(30), cy - s(15), s(4))
    draw_sparkle(d, cx - s(20), cy + s(28), s(3))
    
    # 4. Draw glossy highlight arc
    highlight_img = Image.new("RGBA", (s_size, s_size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight_img)
    hd.ellipse((cx - r_inner + s(4), cy - r_inner + s(4), cx + r_inner - s(4), cy + r_inner - s(4)), fill=(255, 255, 255, 50))
    hd.ellipse((cx - r_inner - s(10), cy - r_inner + s(22), cx + r_inner + s(10), cy + r_inner + s(60)), fill=(0, 0, 0, 0))
    img.alpha_composite(highlight_img)

def draw_wafer_plank(d: ImageDraw.ImageDraw, x: int, y: int, w: int = 45, h: int = 12) -> None:
    d.rounded_rectangle(rect((x, y, x + w, y + h)), radius=s(3), fill=(235, 185, 115, 255), outline=INK, width=s(2.5))
    # Wafer crosshatch detail
    for offset in range(4, w - 4, 6):
        d.line([(s(x + offset), s(y + 2)), (s(x + offset + 3), s(y + h - 2))], fill=(195, 140, 75, 255), width=s(1))

# Skill-specific themes (Inner light color, Outer saturated color)
THEMES = {
    "climber": ((220, 245, 230, 255), (116, 184, 147, 255)),     # Mint Green
    "floater": ((225, 242, 250, 255), (116, 181, 216, 255)),     # Soda Blue
    "blocker": ((255, 235, 238, 255), (244, 143, 177, 255)),     # Strawberry Pink
    "builder": ((255, 248, 220, 255), (224, 184, 102, 255)),     # Cookie Gold
    "distributor": ((224, 250, 240, 255), (116, 195, 170, 255)), # Mint Cyan
    "sand_mound": ((254, 248, 225, 255), (230, 195, 120, 255)),  # Sugar Yellow
    "bridge": ((255, 245, 230, 255), (224, 180, 110, 255)),      # Biscuit Orange
    "basher": ((245, 235, 225, 255), (160, 115, 85, 255)),       # Chocolate Brown
    "digger": ((240, 230, 220, 255), (145, 95, 65, 255)),        # Earth Ginger
    "cutter": ((235, 245, 225, 255), (140, 185, 120, 255)),      # Leaf Green
}

def blocker(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["blocker"])
    # Lollipop shield
    s_size = SIZE * SCALE
    cx, cy = s_size // 2, s_size // 2
    # Draw lollipop shield behind character hands
    d.ellipse(rect((78, 55, 106, 83)), fill=(244, 143, 177, 255), outline=INK, width=s(2))
    # Swirl
    d.arc(rect((82, 59, 102, 79)), 0, 360, fill=WHITE, width=s(1.5))
    line(d, [(92, 83), (92, 105)], fill=CREAM, width=2)
    
    ant = fit_sprite(load_sprite("blocker", 1), s(82))
    paste_center(img, ant, 60, 105)

def builder(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["builder"])
    # Planks
    for i, y in enumerate([91, 77, 63]):
        draw_wafer_plank(d, 45 + i * 8, y, 42, 11)
    ant = fit_sprite(load_sprite("build", 1), s(80))
    paste_center(img, ant, 51, 105)

def climber(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["climber"])
    # Candy cane ladder side rails
    for x in [83, 95]:
        d.rounded_rectangle(rect((x - 1, 26, x + 1, 105)), radius=s(1), fill=CREAM, outline=INK, width=s(1.5))
        # Striping
        for y in range(s(28), s(104), s(8)):
            d.line([(s(x - 1), y), (s(x + 1), y - s(3))], fill=(229, 57, 53, 255), width=s(1.5))
    # Rungs
    for y in [38, 55, 72, 89]:
        d.rounded_rectangle(rect((82, y - 1, 96, y + 1)), radius=s(0.5), fill=(224, 184, 102, 255), outline=INK, width=s(1.2))
        
    ant = fit_sprite(load_sprite("climb", 0), s(76))
    paste_center(img, ant, 59, 105)

def floater(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["floater"])
    # Cotton candy umbrella
    d.pieslice(rect((25, 22, 103, 78)), 180, 360, fill=(244, 143, 177, 255), outline=INK, width=s(3.5))
    # White swirl highlights
    d.arc(rect((35, 32, 93, 78)), 180, 360, fill=WHITE, width=s(2))
    line(d, [(64, 62), (64, 84)], fill=INK, width=2.5)
    
    ant = fit_sprite(load_sprite("fall", 1), s(58))
    paste_center(img, ant, 65, 108)

def distributor(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["distributor"])
    # Lollipop flags
    for p in [(34, 39), (64, 27), (94, 40)]:
        line(d, [(64, 70), p], fill=INK, width=2)
        d.ellipse(rect((p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8)), fill=(255, 167, 38, 255), outline=INK, width=s(2))
        d.arc(rect((p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4)), 0, 360, fill=WHITE, width=s(1))
    ant = fit_sprite(load_sprite("victory", 2), s(58))
    paste_center(img, ant, 64, 108)

def sand_mound(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["sand_mound"])
    # Sugar sand mound
    d.polygon([tuple(map(s, p)) for p in [(27, 103), (44, 65), (57, 91), (73, 55), (103, 103)]], fill=(230, 195, 120, 255))
    line(d, [(27, 103), (44, 65), (57, 91), (73, 55), (103, 103), (27, 103)], fill=INK, width=3.2)
    # Sprinkles on sand
    for p in [(44, 87), (61, 78), (80, 86)]:
        d.ellipse(rect((p[0] - 2, p[1] - 2, p[0] + 2, p[1] + 2)), fill=(244, 143, 177, 255))
    ant = fit_sprite(load_sprite("build", 3), s(68))
    paste_center(img, ant, 49, 100)

def bridge(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["bridge"])
    # Biscuits bridge
    for x in [28, 51, 74]:
        draw_wafer_plank(d, x, 75, 30, 12)
    line(d, [(30, 88), (98, 88)], fill=INK, width=3)
    ant = fit_sprite(load_sprite("build", 0), s(70))
    paste_center(img, ant, 55, 104)

def basher(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["basher"])
    # Cookie tunnel background
    d.rounded_rectangle(rect((76, 38, 104, 96)), radius=s(8), fill=(109, 76, 65, 255), outline=INK, width=s(3))
    # Cookie crumbs
    for y in [50, 65, 80]:
        line(d, [(79, y), (101, y)], fill=(86, 57, 40, 255), width=1.6)
    ant = fit_sprite(load_sprite("dig", 0), s(78))
    paste_center(img, ant, 54, 106)

def digger(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["digger"])
    # Chocolate cookie ground hole
    d.rounded_rectangle(rect((43, 82, 88, 106)), radius=s(8), fill=(109, 76, 65, 255), outline=INK, width=s(3))
    d.polygon([tuple(map(s, p)) for p in [(66, 111), (43, 96), (88, 96)]], fill=(109, 76, 65, 255))
    line(d, [(43, 96), (66, 111), (88, 96)], fill=INK, width=3)
    ant = fit_sprite(load_sprite("dig", 3), s(80))
    paste_center(img, ant, 64, 103)

def cutter(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    draw_candy_badge_bg(img, d, *THEMES["cutter"])
    # Peppermint leaf and candy shears
    d.ellipse(rect((76, 38, 104, 64)), fill=(129, 199, 132, 255), outline=INK, width=s(3))
    d.ellipse(rect((84, 69, 110, 94)), fill=(129, 199, 132, 255), outline=INK, width=s(3))
    # Shears
    line(d, [(55, 46), (90, 83)], fill=(200, 200, 200, 255), width=4)
    line(d, [(56, 93), (91, 57)], fill=(200, 200, 200, 255), width=4)
    d.ellipse(rect((45, 36, 60, 51)), fill=(255, 138, 101, 255), outline=INK, width=s(2))
    d.ellipse(rect((45, 88, 60, 103)), fill=(255, 138, 101, 255), outline=INK, width=s(2))
    ant = fit_sprite(load_sprite("dig", 4), s(64))
    paste_center(img, ant, 49, 106)

def draw_icon(name: str, painter: Callable[[Image.Image, ImageDraw.ImageDraw], None]) -> None:
    img, d = base_canvas()
    painter(img, d)
    button_img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    button_img.save(OUT / f"{name}.png")

    cursor_img = img.copy()
    cursor_draw = ImageDraw.Draw(cursor_img)
    draw_pointer(cursor_draw)
    cursor_img = cursor_img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    cursor_img.save(CURSOR_OUT / f"{name}.png")

def base_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    return img, d

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    CURSOR_OUT.mkdir(parents=True, exist_ok=True)
    painters = {
        "blocker": blocker,
        "builder": builder,
        "climber": climber,
        "floater": floater,
        "distributor": distributor,
        "sand_mound": sand_mound,
        "bridge": bridge,
        "basher": basher,
        "digger": digger,
        "cutter": cutter,
    }
    for name, painter in painters.items():
        draw_icon(name, painter)
    print("Successfully generated all 10 premium skill PNG icons!")

if __name__ == "__main__":
    main()
