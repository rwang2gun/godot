from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
CHAR_DIR = ROOT / "assets" / "sprites" / "characters" / "ant_pajama_girl"
SHEETS = {
    "idle": {
        "src": CHAR_DIR / "ant_pajama_girl_idle_sheet_concept.png",
        "out": CHAR_DIR / "ant_pajama_girl_idle_sheet.png",
        "frames": 4,
    },
    "walk": {
        "src": CHAR_DIR / "ant_pajama_girl_walk_sheet_concept.png",
        "out": CHAR_DIR / "ant_pajama_girl_walk_sheet.png",
        "frames": 6,
    },
    "carry": {
        "src": CHAR_DIR / "ant_pajama_girl_carry_sheet_concept.png",
        "out": CHAR_DIR / "ant_pajama_girl_carry_sheet.png",
        "frames": 6,
    },
    "fall": {
        "src": CHAR_DIR / "ant_pajama_girl_fall_sheet_concept.png",
        "out": CHAR_DIR / "ant_pajama_girl_fall_sheet.png",
        "frames": 4,
    },
    "blocker": {
        "src": CHAR_DIR / "ant_pajama_girl_blocker_sheet_concept.png",
        "out": CHAR_DIR / "ant_pajama_girl_blocker_sheet.png",
        "frames": 2,
    },
    "dig": {
        "src": CHAR_DIR / "ant_pajama_girl_dig_sheet_concept.png",
        "out": CHAR_DIR / "ant_pajama_girl_dig_sheet.png",
        "frames": 6,
    },
}


def is_background(pixel):
    r, g, b, a = pixel
    return a > 0 and r >= 238 and g >= 238 and b >= 238


def is_shadow(pixel):
    r, g, b, a = pixel
    if a == 0:
        return False
    # The generated concept sheet has a soft mauve floor shadow. It is low-sat,
    # pale, and sits disconnected from the character, so remove it for gameplay.
    return r >= 205 and g >= 188 and b >= 198 and abs(r - b) <= 38


def is_white_halo(pixel):
    r, g, b, a = pixel
    return a > 0 and r >= 228 and g >= 228 and b >= 228


def remove_connected_white_background(image):
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    queue = deque()
    seen = set()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or x < 0 or y < 0 or x >= width or y >= height:
            continue
        seen.add((x, y))
        if not is_background(pixels[x, y]):
            continue
        pixels[x, y] = (255, 255, 255, 0)
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))

    return image


def clean_halo_and_shadow(image):
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size

    shadow_start_y = int(height * 0.82)
    for y in range(shadow_start_y, height):
        for x in range(width):
            px = pixels[x, y]
            if is_shadow(px):
                pixels[x, y] = (255, 255, 255, 0)

    # Remove only white-ish pixels connected to transparency, preserving bright
    # eyes and highlights inside the character art.
    alpha = image.getchannel("A")
    transparent_neighbors = alpha.filter(ImageFilter.MaxFilter(3))
    pixels = image.load()
    neighbor_pixels = transparent_neighbors.load()
    for y in range(height):
        for x in range(width):
            if neighbor_pixels[x, y] < 255 and is_white_halo(pixels[x, y]):
                pixels[x, y] = (255, 255, 255, 0)

    return image


def prepare(name, spec):
    src = spec["src"]
    out_sheet = spec["out"]
    frame_count = spec["frames"]
    out_frames = CHAR_DIR / name

    if not src.exists():
        raise FileNotFoundError(src)

    sheet = clean_halo_and_shadow(remove_connected_white_background(Image.open(src)))
    out_frames.mkdir(parents=True, exist_ok=True)

    width, height = sheet.size
    frame_width = width // frame_count
    clean_sheet = Image.new("RGBA", (frame_width * frame_count, height), (0, 0, 0, 0))

    for i in range(frame_count):
        left = i * frame_width
        right = (i + 1) * frame_width if i < frame_count - 1 else width
        frame = sheet.crop((left, 0, right, height))
        if frame.size[0] != frame_width:
            normalized = Image.new("RGBA", (frame_width, height), (0, 0, 0, 0))
            normalized.alpha_composite(frame, (0, 0))
            frame = normalized
        frame_path = out_frames / f"{name}_{i:02d}.png"
        frame.save(frame_path)
        clean_sheet.alpha_composite(frame, (i * frame_width, 0))

    clean_sheet.save(out_sheet)
    print(out_sheet)
    print(f"{frame_width}x{height} x {frame_count}")


def main():
    for name, spec in SHEETS.items():
        prepare(name, spec)


if __name__ == "__main__":
    main()
