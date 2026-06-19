import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
INPUT_DIR = Path("C:/Users/code1412/.gemini/antigravity/brain/7ec5e222-de19-4184-b0a0-d459e3d3f435/temp_generated_icons")
OUTPUT_DIR = Path("C:/Users/code1412/.gemini/antigravity/brain/7ec5e222-de19-4184-b0a0-d459e3d3f435/temp_processed_icons")
CURSOR_OUTPUT_DIR = OUTPUT_DIR / "cursors"

# Final destinations (will copy here after user approval)
LIVE_DIR = ROOT / "assets" / "icons" / "skills"
LIVE_CURSOR_DIR = LIVE_DIR / "cursors"

SIZE = 128
INK = (37, 33, 43, 255)

def apply_circular_crop(img: Image.Image, padding: int = 12) -> Image.Image:
    """Crops the image to a perfect circle centered, making corners transparent."""
    W, H = img.size
    # Create transparent canvas
    cropped = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Create 8-bit grayscale mask for anti-aliasing
    mask = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(mask)
    
    # Circle diameter is slightly smaller than W to avoid touching edges
    r = W // 2 - padding
    cx, cy = W // 2, H // 2
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    
    # Paste original image onto transparent canvas using the circular mask
    cropped.paste(img, (0, 0), mask=mask)
    return cropped

def draw_cursor_pointer(img: Image.Image) -> Image.Image:
    """Overlays a clean pointer arrow on the top-left corner on a 128x128 canvas."""
    cursor = img.copy()
    d = ImageDraw.Draw(cursor)
    
    # Pointer path coordinates (128x128 space)
    points = [(4, 4), (4, 34), (34, 4)]
    
    # 1. Fill polygon with semi-transparent white
    d.polygon(points, fill=(255, 255, 255, 245))
    
    # 2. Outer outline (thick white)
    d.line([points[0], points[1], points[2], points[0]], fill=(255, 255, 255, 255), width=4, joint="curve")
    
    # 3. Inner outline (thin dark ink)
    d.line([points[0], points[1], points[2], points[0]], fill=INK, width=2, joint="curve")
    
    return cursor

def process_all(to_live: bool = False):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    CURSOR_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    skills = [
        "blocker", "slideR", "slideL", "climber", "floater", "distributor",
        "sand_mound", "bridge", "basher", "digger", "cutter"
    ]
    
    print(f"Starting processing... to_live={to_live}")
    for skill in skills:
        src_path = INPUT_DIR / f"{skill}.png"
        if not src_path.exists():
            print(f"Error: {src_path} does not exist!")
            continue
            
        # Open source image
        with Image.open(src_path) as img:
            img = img.convert("RGBA")
            
            # 1. Crop to circle (removing corners)
            # We use a 16px padding on 1024x1024 to cleanly cut off any generated borders
            cropped_img = apply_circular_crop(img, padding=16)
            
            # 2. Resize to 128x128
            resized_img = cropped_img.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
            
            # 3. Create cursor variant
            cursor_img = draw_cursor_pointer(resized_img)
            
            # Save to preview directory
            btn_out = OUTPUT_DIR / f"{skill}.png"
            cur_out = CURSOR_OUTPUT_DIR / f"{skill}.png"
            resized_img.save(btn_out, "PNG")
            cursor_img.save(cur_out, "PNG")
            print(f"Processed {skill} -> {btn_out}")
            
            # If approved and copying directly to game files
            if to_live:
                LIVE_DIR.mkdir(parents=True, exist_ok=True)
                LIVE_CURSOR_DIR.mkdir(parents=True, exist_ok=True)
                
                live_btn_path = LIVE_DIR / f"{skill}.png"
                live_cur_path = LIVE_CURSOR_DIR / f"{skill}.png"
                resized_img.save(live_btn_path, "PNG")
                cursor_img.save(live_cur_path, "PNG")
                print(f"Applied live: {live_btn_path}")

if __name__ == "__main__":
    import sys
    # If run with '--apply', it will overwrite live assets
    apply = "--apply" in sys.argv
    process_all(to_live=apply)
