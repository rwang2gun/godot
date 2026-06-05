from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
LOGO = ROOT / "assets" / "logo"
OUT = LOGO / "app_icon"
BASE_SIZE = 1024
SIZES = [1024, 512, 256, 180, 144, 128, 64, 32]


def load_rgba(path: Path) -> Image.Image:
    img = Image.open(path).convert("RGBA")
    bbox = img.getbbox()
    return img.crop(bbox) if bbox else img


def fit_height(img: Image.Image, height: int) -> Image.Image:
    ratio = height / img.height
    return img.resize((max(1, int(img.width * ratio)), height), Image.Resampling.LANCZOS)


def fit_width(img: Image.Image, width: int) -> Image.Image:
    ratio = width / img.width
    return img.resize((width, max(1, int(img.height * ratio))), Image.Resampling.LANCZOS)


def paste_center(canvas: Image.Image, img: Image.Image, cx: int, cy: int) -> None:
    canvas.alpha_composite(img, (cx - img.width // 2, cy - img.height // 2))


def radial_background() -> Image.Image:
    size = BASE_SIZE
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Soft candy-sky radial field.
    cx, cy = int(size * 0.46), int(size * 0.42)
    inner = (255, 246, 252, 255)
    mid = (255, 182, 215, 255)
    outer = (92, 181, 224, 255)
    max_r = int(size * 0.72)
    for r in range(max_r, 0, -4):
        t = r / max_r
        if t < 0.55:
            k = t / 0.55
            color = tuple(int(inner[i] * (1 - k) + mid[i] * k) for i in range(4))
        else:
            k = (t - 0.55) / 0.45
            color = tuple(int(mid[i] * (1 - k) + outer[i] * k) for i in range(4))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)

    # Chocolate rim and warm inner ring, like the skill buttons but app-icon scale.
    rim = int(size * 0.485)
    d.ellipse((size // 2 - rim, size // 2 - rim, size // 2 + rim, size // 2 + rim), outline=(58, 43, 49, 255), width=34)
    d.ellipse((size // 2 - rim + 32, size // 2 - rim + 32, size // 2 + rim - 32, size // 2 + rim - 32), outline=(255, 240, 205, 185), width=14)

    # A few sugar sparkles that survive downscaling.
    for x, y, s in [(210, 230, 20), (792, 232, 18), (805, 746, 15), (280, 790, 12)]:
        pts = [
            (x, y - s), (x + s * 0.3, y - s * 0.3), (x + s, y),
            (x + s * 0.3, y + s * 0.3), (x, y + s),
            (x - s * 0.3, y + s * 0.3), (x - s, y), (x - s * 0.3, y - s * 0.3),
        ]
        d.polygon(pts, fill=(255, 255, 255, 220))

    return img


def compose_artwork(canvas: Image.Image) -> None:
    """Draw the mascot face + wordmark onto a 1024 canvas (background-agnostic)."""
    mascot = load_rgba(LOGO / "mascot_premium.png")
    title = load_rgba(LOGO / "logo_wordmark_readable_v2.png")

    # Show the face, not the full body. Moving the large mascot downward crops the body out
    # while keeping antennae and eyes readable at launcher sizes.
    mascot = fit_height(mascot, 1120)
    paste_center(canvas, mascot, 500, 710)

    # Put the title above the face. The wordmark already has strong candy styling, so no
    # extra gem overlay is needed.
    title = fit_width(title, 690)
    title_shadow = Image.new("RGBA", title.size, (0, 0, 0, 0))
    title_shadow.alpha_composite(title)
    title_shadow = title_shadow.filter(ImageFilter.GaussianBlur(8))
    canvas.alpha_composite(title_shadow, (BASE_SIZE // 2 - title.width // 2 + 4, 126))
    canvas.alpha_composite(title, (BASE_SIZE // 2 - title.width // 2, 116))


def make_icon() -> Image.Image:
    canvas = radial_background()
    compose_artwork(canvas)

    # App-store style safe mask: keep square PNG but round only the artwork silhouette slightly.
    rounded = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    mask = Image.new("L", (BASE_SIZE, BASE_SIZE), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((0, 0, BASE_SIZE - 1, BASE_SIZE - 1), radius=150, fill=255)
    rounded.alpha_composite(canvas)
    rounded.putalpha(mask)
    return rounded


def make_artwork_only() -> Image.Image:
    """Foreground artwork (mascot + title) on a transparent square, no background."""
    canvas = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (0, 0, 0, 0))
    compose_artwork(canvas)
    return canvas


def make_icon_opaque() -> Image.Image:
    """Full-bleed square icon with NO transparency (required for iOS / App Store)."""
    # iOS rounds corners itself and rejects any alpha channel, so fill the whole square.
    base = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), (92, 181, 224, 255))  # outer candy-sky
    base.alpha_composite(radial_background())
    compose_artwork(base)
    return base.convert("RGB")


def fit_into_box(art: Image.Image, canvas_size: int, box_frac: float) -> Image.Image:
    """Crop art to content, scale to fit a centered box, return centered on transparent canvas."""
    bbox = art.getbbox()
    cropped = art.crop(bbox) if bbox else art
    box = int(canvas_size * box_frac)
    ratio = min(box / cropped.width, box / cropped.height)
    scaled = cropped.resize(
        (max(1, int(cropped.width * ratio)), max(1, int(cropped.height * ratio))),
        Image.Resampling.LANCZOS,
    )
    out = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    out.alpha_composite(scaled, ((canvas_size - scaled.width) // 2, (canvas_size - scaled.height) // 2))
    return out


def make_windows_ico(icon: Image.Image) -> None:
    """Multi-resolution .ico embedded into the .exe by Godot's Windows exporter (rcedit)."""
    ico_sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    base = icon.resize((256, 256), Image.Resampling.LANCZOS)
    base.save(OUT / "app_icon.ico", format="ICO", sizes=ico_sizes)


def make_android_icons(icon: Image.Image) -> None:
    out = OUT / "android"
    out.mkdir(parents=True, exist_ok=True)

    # Legacy square launcher icon (alpha ok; the launcher masks it).
    icon.resize((192, 192), Image.Resampling.LANCZOS).save(out / "main_192.png")

    # Adaptive icons are 432x432; only the central 66dp/108dp (~66%) is guaranteed visible.
    art = make_artwork_only()
    foreground = fit_into_box(art, 432, 0.62)
    foreground.save(out / "adaptive_foreground_432.png")

    background = radial_background().resize((432, 432), Image.Resampling.LANCZOS)
    background = background.convert("RGB")  # adaptive background must be opaque full-bleed
    background.save(out / "adaptive_background_432.png")

    # Themed (monochrome) icon: white silhouette of the foreground; Android applies its tint.
    mono = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    white = Image.new("RGBA", (432, 432), (255, 255, 255, 255))
    mono.paste(white, (0, 0), foreground.split()[3])
    mono.save(out / "adaptive_monochrome_432.png")


def make_ios_icons() -> None:
    out = OUT / "ios"
    out.mkdir(parents=True, exist_ok=True)
    opaque = make_icon_opaque()
    ios_sizes = [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40, 29]
    for size in ios_sizes:
        opaque.resize((size, size), Image.Resampling.LANCZOS).save(out / f"icon_{size}.png")


def make_verify_sheet(icon: Image.Image) -> None:
    """Single contact sheet so the platform variants can be eyeballed at a glance."""
    tiles = [
        ("win .ico 256", icon.resize((256, 256), Image.Resampling.LANCZOS)),
        ("android main", Image.open(OUT / "android" / "main_192.png").convert("RGBA").resize((256, 256))),
        ("android fg", Image.open(OUT / "android" / "adaptive_foreground_432.png").convert("RGBA").resize((256, 256))),
        ("android bg", Image.open(OUT / "android" / "adaptive_background_432.png").convert("RGBA").resize((256, 256))),
        ("android mono", Image.open(OUT / "android" / "adaptive_monochrome_432.png").convert("RGBA").resize((256, 256))),
        ("ios 1024", Image.open(OUT / "ios" / "icon_1024.png").convert("RGBA").resize((256, 256))),
    ]
    pad, cols = 16, 3
    rows = (len(tiles) + cols - 1) // cols
    cell = 256 + pad
    sheet = Image.new("RGBA", (cols * cell + pad, rows * (cell + 22) + pad), (40, 40, 48, 255))
    d = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(tiles):
        cx = pad + (i % cols) * cell
        cy = pad + (i // cols) * (cell + 22)
        sheet.alpha_composite(img.convert("RGBA"), (cx, cy + 18))
        d.text((cx + 2, cy + 2), label, fill=(255, 255, 255, 255))
    sheet.convert("RGB").save(ROOT / "verify_app_icon_platforms.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    icon = make_icon()
    icon.save(LOGO / "app_icon.png")
    icon.save(OUT / "app_icon_1024.png")
    for size in SIZES:
        resized = icon.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(OUT / f"app_icon_{size}.png")
    print("Generated base app icons:", ", ".join(str(size) for size in SIZES))

    make_windows_ico(icon)
    print("Generated Windows .ico (16/32/48/64/128/256)")

    make_android_icons(icon)
    print("Generated Android icons (main_192 + adaptive fg/bg/monochrome_432)")

    make_ios_icons()
    print("Generated iOS icons (1024..29, opaque, no alpha)")

    make_verify_sheet(icon)
    print("Wrote verify_app_icon_platforms.png")


if __name__ == "__main__":
    main()
