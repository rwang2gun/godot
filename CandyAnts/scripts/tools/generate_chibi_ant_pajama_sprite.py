from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "sprites" / "chibi_ant_pajama_girl_sprite.png"
SIZE = 768


def rgba(hex_color: str, alpha: int = 255):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def layer():
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def composite(base, overlay):
    base.alpha_composite(overlay)


def thick_line(draw, points, fill, width):
    draw.line(points, fill=fill, width=width, joint="curve")


def ellipse(draw, box, fill, outline="#17171d", width=6):
    draw.ellipse(box, fill=rgba(fill) if isinstance(fill, str) else fill, outline=rgba(outline), width=width)


def polygon(draw, points, fill, outline="#17171d", width=6):
    draw.polygon(points, fill=rgba(fill) if isinstance(fill, str) else fill)
    draw.line(points + [points[0]], fill=rgba(outline), width=width, joint="curve")


def make_sprite():
    img = layer()
    outline = rgba("#17171d")
    dark = rgba("#292c39")
    dark_2 = rgba("#222532")
    suit_hi = rgba("#515467", 90)
    skin = rgba("#ffd8bd")
    skin_shadow = rgba("#f0a986", 130)
    hair = rgba("#292832")
    hair_hi = rgba("#5c596a", 120)
    pink = rgba("#ec78a4")
    pink_hi = rgba("#ffc3d6")

    # Soft transparent ground shadow.
    sh = layer()
    sd = ImageDraw.Draw(sh)
    sd.ellipse((180, 680, 588, 735), fill=rgba("#4b3844", 55))
    sh = sh.filter(ImageFilter.GaussianBlur(8))
    composite(img, sh)

    d = ImageDraw.Draw(img)

    # Abdomen tail behind the body.
    d.ellipse((112, 498, 325, 674), fill=rgba("#31303b"), outline=outline, width=8)
    for x in (162, 221, 282):
        d.arc((x - 88, 510, x + 95, 674), 92, 268, fill=rgba("#191920", 125), width=4)

    # Legs and soft pajama feet.
    d.ellipse((247, 594, 352, 724), fill=dark, outline=outline, width=8)
    d.ellipse((238, 676, 324, 735), fill=dark_2, outline=outline, width=7)
    d.ellipse((405, 596, 532, 729), fill=dark, outline=outline, width=8)
    d.ellipse((459, 675, 558, 736), fill=dark_2, outline=outline, width=7)

    # Body.
    d.rounded_rectangle((245, 324, 519, 652), radius=120, fill=dark, outline=outline, width=8)
    d.ellipse((272, 413, 510, 650), fill=rgba("#3d3c49"), outline=outline, width=6)
    for y in (485, 535, 584):
        d.arc((282, y, 506, y + 78), 184, 354, fill=rgba("#181820", 95), width=4)

    # Hood behind face.
    d.ellipse((196, 74, 596, 450), fill=rgba("#333648"), outline=outline, width=9)
    d.ellipse((264, 168, 337, 242), fill=rgba("#20212d"), outline=outline, width=7)
    d.ellipse((503, 126, 577, 198), fill=rgba("#20212d"), outline=outline, width=7)
    d.ellipse((285, 185, 306, 207), fill=rgba("#dfe1ef", 160))
    d.ellipse((526, 142, 548, 163), fill=rgba("#dfe1ef", 160))

    # Antennae.
    thick_line(d, [(308, 164), (315, 88), (388, 51), (439, 66)], outline, 18)
    thick_line(d, [(308, 164), (315, 88), (388, 51), (439, 66)], rgba("#343644"), 11)
    thick_line(d, [(510, 133), (540, 48), (616, 18), (660, 39)], outline, 18)
    thick_line(d, [(510, 133), (540, 48), (616, 18), (660, 39)], rgba("#343644"), 11)

    # Neck and face.
    d.rounded_rectangle((348, 306, 428, 382), radius=35, fill=skin, outline=outline, width=6)
    d.ellipse((282, 160, 552, 407), fill=skin, outline=outline, width=7)
    d.ellipse((319, 337, 383, 365), fill=skin_shadow)
    d.ellipse((476, 318, 542, 347), fill=skin_shadow)

    # Hair.
    d.pieslice((220, 208, 357, 432), 78, 278, fill=hair, outline=outline, width=7)
    d.pieslice((486, 215, 595, 426), 260, 90, fill=hair, outline=outline, width=7)
    polygon(d, [(316, 168), (398, 153), (387, 294), (331, 294)], "#292832", width=6)
    polygon(d, [(383, 162), (488, 176), (493, 292), (421, 292)], "#292832", width=6)
    polygon(d, [(469, 185), (540, 221), (532, 320), (491, 294)], "#292832", width=6)
    thick_line(d, [(344, 191), (334, 240), (336, 286), (328, 322)], hair_hi, 3)
    thick_line(d, [(462, 190), (489, 226), (499, 272), (492, 310)], hair_hi, 3)

    # Bow hair clip.
    polygon(d, [(282, 268), (246, 240), (255, 305)], "#d8dbe8", width=5)
    polygon(d, [(299, 273), (350, 252), (334, 318)], "#d8dbe8", width=5)
    polygon(d, [(292, 288), (277, 335), (320, 329)], "#d8dbe8", width=5)
    ellipse(d, (276, 260, 306, 291), "#e4e6f0", width=5)
    ellipse(d, (286, 267, 299, 280), "#3d3f4f", width=3)

    # Candy pillow and wrappers, held in front.
    polygon(d, [(339, 424), (292, 394), (279, 460), (319, 507)], "#ff9fc2", width=7)
    polygon(d, [(519, 438), (591, 407), (609, 481), (543, 513)], "#ff9fc2", width=7)
    d.ellipse((323, 394, 535, 556), fill=pink, outline=outline, width=7)
    for box in ((379, 435, 421, 476), (451, 419, 492, 460), (471, 489, 516, 533), (348, 482, 382, 516)):
        d.ellipse(box, fill=rgba("#ffd9e7", 90))
    d.ellipse((365, 426, 412, 442), fill=rgba("#ffffff", 105))
    d.ellipse((391, 403, 416, 414), fill=rgba("#ffffff", 90))

    # Arms over pillow.
    d.rounded_rectangle((243, 422, 386, 538), radius=58, fill=dark, outline=outline, width=8)
    d.rounded_rectangle((466, 428, 557, 547), radius=52, fill=dark, outline=outline, width=8)

    # Redraw pillow center over partial arm overlap for a cuddled look.
    d.ellipse((338, 403, 523, 553), fill=pink, outline=outline, width=6)
    for box in ((383, 439, 424, 480), (456, 422, 494, 461), (475, 490, 517, 531), (350, 484, 383, 517)):
        d.ellipse(box, fill=rgba("#ffd9e7", 88))
    d.ellipse((366, 429, 411, 444), fill=rgba("#ffffff", 105))

    # Face details.
    thick_line(d, [(311, 312), (336, 286), (365, 307), (379, 331)], outline, 8)
    thick_line(d, [(452, 295), (485, 269), (521, 292), (533, 318)], outline, 8)
    thick_line(d, [(365, 284), (381, 259), (419, 234)], rgba("#58333b"), 4)
    thick_line(d, [(486, 255), (509, 236), (550, 253)], rgba("#58333b"), 4)
    d.pieslice((397, 318, 474, 398), 12, 168, fill=rgba("#6b252c"), outline=rgba("#6b252c"), width=5)
    d.pieslice((406, 330, 464, 392), 18, 162, fill=rgba("#ff927f"), outline=rgba("#6b252c"), width=4)
    for x in (319, 335, 351):
        thick_line(d, [(x, 342), (x + 9, 361)], rgba("#ff7979", 135), 3)
    for x in (493, 509, 525):
        thick_line(d, [(x, 327), (x + 9, 345)], rgba("#ff7979", 135), 3)

    # Suit highlights and motion accents.
    thick_line(d, [(258, 389), (246, 475), (274, 552), (326, 595)], suit_hi, 3)
    thick_line(d, [(464, 368), (514, 439), (520, 531), (489, 596)], suit_hi, 3)
    d.arc((120, 168, 188, 264), 140, 194, fill=rgba("#17171d", 150), width=4)
    d.arc((148, 178, 210, 262), 145, 186, fill=rgba("#17171d", 130), width=4)
    d.arc((615, 137, 692, 223), 306, 354, fill=rgba("#17171d", 150), width=4)
    d.arc((645, 154, 715, 234), 306, 348, fill=rgba("#17171d", 130), width=4)

    # Trim to transparent sprite bounds with a small margin.
    bbox = img.getbbox()
    if bbox:
        margin = 24
        crop = (
            max(0, bbox[0] - margin),
            max(0, bbox[1] - margin),
            min(SIZE, bbox[2] + margin),
            min(SIZE, bbox[3] + margin),
        )
        sprite = img.crop(crop)
    else:
        sprite = img
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sprite.save(OUT)
    return OUT, sprite.size


if __name__ == "__main__":
    path, dimensions = make_sprite()
    print(f"{path}")
    print(f"{dimensions[0]}x{dimensions[1]}")
