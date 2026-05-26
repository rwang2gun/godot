from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "icons" / "traits"
SIZE = 64
SCALE = 4

INK = (37, 33, 43, 255)
ROPE = (202, 151, 83, 255)
ROPE_DARK = (133, 88, 52, 255)
CREAM = (255, 246, 222, 255)
PEACH = (244, 177, 164, 255)
MINT = (107, 190, 166, 255)
MINT_DARK = (53, 133, 119, 255)
WHITE = (255, 255, 255, 255)


def s(v: int | float) -> int:
    return int(round(v * SCALE))


def pts(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    return [(s(x), s(y)) for x, y in points]


def ellipse_box(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    return tuple(s(v) for v in box)


def draw_climber_rope() -> None:
    img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Soft cream knot backing keeps the badge readable over dark character hair/body.
    d.ellipse((s(17), s(7), s(49), s(39)), fill=CREAM, outline=INK, width=s(2))
    d.arc((s(20), s(10), s(46), s(36)), 20, 330, fill=ROPE, width=s(7))
    d.arc((s(20), s(10), s(46), s(36)), 20, 330, fill=INK, width=s(2))

    # Hanging rope tail.
    d.line(pts([(33, 36), (33, 57)]), fill=INK, width=s(6))
    d.line(pts([(33, 36), (33, 57)]), fill=ROPE, width=s(3))
    for y in [42, 49, 56]:
        d.line(pts([(27, y), (39, y - 5)]), fill=ROPE_DARK, width=s(2))

    # Small knot at the end.
    d.ellipse((s(26), s(51), s(40), s(63)), fill=ROPE, outline=INK, width=s(2))
    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    img.save(OUT / "climber_rope.png")


def draw_climber_glove() -> None:
    img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Drop shadow.
    d.ellipse(ellipse_box((14, 46, 53, 61)), fill=(37, 33, 43, 55))

    # Mint cuff, deliberately larger than the fingers so it reads at badge size.
    d.rounded_rectangle(
        ellipse_box((17, 39, 47, 58)),
        radius=s(7),
        fill=MINT,
        outline=INK,
        width=s(2),
    )
    d.line(pts([(24, 41), (24, 56)]), fill=WHITE, width=s(1))
    d.line(pts([(33, 40), (33, 58)]), fill=WHITE, width=s(1))
    d.line(pts([(42, 42), (42, 55)]), fill=WHITE, width=s(1))

    # Thumb and palm.
    d.ellipse(ellipse_box((8, 30, 25, 48)), fill=CREAM, outline=INK, width=s(2))
    d.ellipse(ellipse_box((19, 22, 49, 51)), fill=CREAM, outline=INK, width=s(2))

    # Four rounded fingers.
    fingers = [
        (20, 8, 29, 29),
        (29, 5, 38, 29),
        (38, 8, 47, 31),
        (47, 16, 56, 36),
    ]
    for box in fingers:
        d.rounded_rectangle(ellipse_box(box), radius=s(5), fill=CREAM, outline=INK, width=s(2))

    # Soft pads make the item feel like a wearable glove, not a UI symbol.
    d.ellipse(ellipse_box((26, 30, 41, 43)), fill=PEACH, outline=INK, width=s(1))
    d.ellipse(ellipse_box((13, 35, 22, 45)), fill=PEACH, outline=INK, width=s(1))

    # Simplified web: few bold strands so the badge stays readable when scaled down.
    center = (34, 36)
    strand_targets = [(24, 25), (34, 24), (46, 28), (48, 39), (39, 47), (27, 45)]
    for target in strand_targets:
        d.line(pts([center, target]), fill=MINT_DARK, width=s(1))
    d.arc(ellipse_box((25, 27, 44, 45)), 205, 20, fill=MINT_DARK, width=s(1))
    d.arc(ellipse_box((21, 22, 50, 51)), 205, 20, fill=MINT_DARK, width=s(1))

    # Tiny glint on the webbing.
    d.line(pts([(51, 11), (51, 20)]), fill=WHITE, width=s(1))
    d.line(pts([(47, 15), (55, 15)]), fill=WHITE, width=s(1))

    img = img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    img.save(OUT / "climber_glove.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    draw_climber_rope()
    draw_climber_glove()


if __name__ == "__main__":
    main()
