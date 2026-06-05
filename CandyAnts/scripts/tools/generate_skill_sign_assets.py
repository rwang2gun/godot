from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites" / "world"
SIZE = 48
SCALE = 4

INK = (37, 33, 43, 255)
WOOD_DARK = (91, 57, 38, 255)
WOOD = (171, 104, 55, 255)
WOOD_LIGHT = (232, 169, 91, 255)
CREAM = (252, 247, 236, 255)
GOLD = (242, 188, 84, 255)
SHADOW = (37, 33, 43, 80)


def s(v: int | float) -> int:
    return int(round(v * SCALE))


def rect(values: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(s(v) for v in values)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Ground/contact shadow inside the 48x48 terrain cell.
    d.ellipse(rect((14, 39, 34, 46)), fill=SHADOW)

    # Stake.
    d.rounded_rectangle(rect((21, 19, 27, 46)), radius=s(2), fill=WOOD_DARK, outline=INK, width=s(1.5))
    d.rounded_rectangle(rect((23, 20, 26, 44)), radius=s(1), fill=WOOD, width=s(1))
    d.line((s(25), s(22), s(25), s(43)), fill=WOOD_LIGHT, width=s(1))

    # Board body. The inner cream panel is where SkillSign overlays the skill icon.
    d.rounded_rectangle(rect((6, 4, 42, 27)), radius=s(5), fill=INK)
    d.rounded_rectangle(rect((8, 6, 40, 25)), radius=s(4), fill=WOOD)
    d.rounded_rectangle(rect((12, 8, 36, 23)), radius=s(3), fill=CREAM)

    # Candy trim and small nail heads.
    d.line((s(11), s(7), s(37), s(7)), fill=GOLD, width=s(1))
    d.ellipse(rect((9, 8, 12, 11)), fill=WOOD_DARK)
    d.ellipse(rect((36, 8, 39, 11)), fill=WOOD_DARK)

    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    img.save(OUT / "skill_sign_board.png")
    print(OUT / "skill_sign_board.png")


if __name__ == "__main__":
    main()
