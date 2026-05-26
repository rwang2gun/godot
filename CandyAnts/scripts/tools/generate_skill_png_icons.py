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

INK = (37, 33, 43, 255)
INK_SOFT = (60, 53, 67, 255)
CREAM = (252, 247, 236, 255)
PEACH = (243, 174, 161, 255)
SAND = (211, 169, 95, 255)
EARTH = (123, 82, 54, 255)
COOKIE = (224, 184, 102, 255)
MINT = (116, 184, 147, 255)
LEAF = (96, 166, 99, 255)
SKY = (116, 181, 216, 255)
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
	# Cursor hotspot is the PNG's top-left corner in SkillToolbar.
	# A simple triangle stays readable after OS cursor scaling.
	points = [(4, 4), (4, 34), (34, 4)]
	scaled = [tuple(map(s, p)) for p in points]
	d.polygon(scaled, fill=POINTER_FILL)
	line(d, [(4, 4), (4, 34), (34, 4), (4, 4)], fill=(255, 255, 255, 255), width=4.0)
	line(d, [(4, 4), (4, 34), (34, 4), (4, 4)], fill=INK, width=2.0)


def base_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
	img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	return img, d


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


def draw_plank(d: ImageDraw.ImageDraw, x: int, y: int, w: int = 45, h: int = 12) -> None:
    d.rounded_rectangle(rect((x, y, x + w, y + h)), radius=s(4), fill=COOKIE, outline=INK, width=s(3))
    line(d, [(x + 7, y + h // 2), (x + w - 6, y + h // 2)], fill=(165, 118, 67, 255), width=1.8)


def blocker(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    ant = fit_sprite(load_sprite("blocker", 1), s(82))
    paste_center(img, ant, 64, 105)


def builder(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    for i, y in enumerate([91, 77, 63]):
        draw_plank(d, 45 + i * 8, y, 42, 11)
    ant = fit_sprite(load_sprite("build", 1), s(80))
    paste_center(img, ant, 51, 105)


def climber(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle(rect((83, 26, 95, 105)), radius=s(5), fill=INK_SOFT, outline=INK, width=s(3))
    for y in [38, 55, 72, 89]:
        line(d, [(82, y), (95, y)], fill=(86, 76, 92, 255), width=2)
    ant = fit_sprite(load_sprite("climb", 0), s(76))
    paste_center(img, ant, 59, 105)


def floater(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    d.pieslice(rect((25, 22, 103, 78)), 180, 360, fill=SKY, outline=INK, width=s(4))
    for x in [42, 55, 68, 81]:
        line(d, [(x, 62), (63, 84)], fill=INK, width=1.8)
    ant = fit_sprite(load_sprite("fall", 1), s(58))
    paste_center(img, ant, 65, 108)


def distributor(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    for p in [(34, 39), (64, 27), (94, 40), (37, 78), (91, 80)]:
        line(d, [(64, 70), p], fill=MINT, width=2.5)
        d.ellipse(rect((p[0] - 7, p[1] - 7, p[0] + 7, p[1] + 7)), fill=WHITE, outline=INK, width=s(2))
    ant = fit_sprite(load_sprite("victory", 2), s(58))
    paste_center(img, ant, 64, 108)


def sand_mound(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    d.polygon([tuple(map(s, p)) for p in [(27, 103), (44, 65), (57, 91), (73, 55), (103, 103)]], fill=SAND)
    line(d, [(27, 103), (44, 65), (57, 91), (73, 55), (103, 103), (27, 103)], fill=INK, width=3.2)
    for p in [(44, 87), (61, 78), (80, 86)]:
        d.ellipse(rect((p[0] - 2, p[1] - 2, p[0] + 2, p[1] + 2)), fill=EARTH)
    ant = fit_sprite(load_sprite("build", 3), s(68))
    paste_center(img, ant, 49, 100)


def bridge(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    for x in [28, 51, 74]:
        draw_plank(d, x, 75, 30, 12)
    line(d, [(30, 88), (98, 88)], fill=INK, width=3)
    ant = fit_sprite(load_sprite("build", 0), s(70))
    paste_center(img, ant, 55, 104)


def basher(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle(rect((76, 38, 104, 96)), radius=s(8), fill=EARTH, outline=INK, width=s(3))
    for y in [50, 65, 80]:
        line(d, [(79, y), (101, y)], fill=(86, 57, 40, 255), width=1.6)
    ant = fit_sprite(load_sprite("dig", 0), s(78))
    paste_center(img, ant, 54, 106)


def digger(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    d.rounded_rectangle(rect((43, 82, 88, 106)), radius=s(8), fill=EARTH, outline=INK, width=s(3))
    d.polygon([tuple(map(s, p)) for p in [(66, 111), (43, 96), (88, 96)]], fill=EARTH)
    line(d, [(43, 96), (66, 111), (88, 96)], fill=INK, width=3)
    ant = fit_sprite(load_sprite("dig", 3), s(80))
    paste_center(img, ant, 64, 103)


def cutter(img: Image.Image, d: ImageDraw.ImageDraw) -> None:
    d.ellipse(rect((76, 38, 104, 64)), fill=LEAF, outline=INK, width=s(3))
    d.ellipse(rect((84, 69, 110, 94)), fill=LEAF, outline=INK, width=s(3))
    line(d, [(55, 46), (90, 83)], fill=(170, 179, 184, 255), width=4)
    line(d, [(56, 93), (91, 57)], fill=(170, 179, 184, 255), width=4)
    d.ellipse(rect((45, 36, 60, 51)), fill=PEACH, outline=INK, width=s(2))
    d.ellipse(rect((45, 88, 60, 103)), fill=PEACH, outline=INK, width=s(2))
    ant = fit_sprite(load_sprite("dig", 4), s(64))
    paste_center(img, ant, 49, 106)


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


if __name__ == "__main__":
    main()
