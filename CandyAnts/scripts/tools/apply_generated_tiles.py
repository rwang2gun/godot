import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]

# Raw generated images
SURF_RAW = Path("C:/Users/code1412/.gemini/antigravity/brain/7ec5e222-de19-4184-b0a0-d459e3d3f435/sand_tile_surface_raw_1780066157665.png")
UNDER_RAW = Path("C:/Users/code1412/.gemini/antigravity/brain/7ec5e222-de19-4184-b0a0-d459e3d3f435/sand_tile_under_surface_raw_1780066178181.png")
BG_RAW = Path("C:/Users/code1412/.gemini/antigravity/brain/7ec5e222-de19-4184-b0a0-d459e3d3f435/sand_tile_background_raw_1780066204173.png")

OUTPUT_DIR = Path("C:/Users/code1412/.gemini/antigravity/brain/7ec5e222-de19-4184-b0a0-d459e3d3f435/temp_generated_tiles")
LIVE_DIR = ROOT / "assets" / "sprites" / "terrain"

TARGET_SIZE = 48

def remove_background(img: Image.Image) -> Image.Image:
    """Removes the white background outside the object using a floodfill-from-corners algorithm."""
    img = img.convert("RGBA")
    W, H = img.size
    
    # 1. Create a binary mask of white-ish pixels (R, G, B > 230)
    white_mask = Image.new("L", (W, H), 0)
    pix_in = img.load()
    pix_wm = white_mask.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = pix_in[x, y]
            if r > 230 and g > 230 and b > 230:
                pix_wm[x, y] = 255
                
    # 2. Floodfill from the four corners of white_mask with value 128
    for start_point in [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)]:
        if pix_wm[start_point[0], start_point[1]] == 255:
            ImageDraw.floodfill(white_mask, start_point, 128)
            
    # 3. Apply transparency
    pix_mask = white_mask.load()
    for y in range(H):
        for x in range(W):
            if pix_mask[x, y] == 128:
                r, g, b, a = pix_in[x, y]
                pix_in[x, y] = (r, g, b, 0)
                
    return img

def process_single_tile(raw_path: Path, output_filename: str, align_bottom: bool = False, apply_live: bool = False):
    if not raw_path.exists():
        print(f"Error: Raw image {raw_path} not found.")
        return
        
    with Image.open(raw_path) as img:
        img = img.convert("RGBA")
        W, H = img.size
        
        # 1. First make the background transparent
        cleaned = remove_background(img)
        
        # 2. Find the exact bounding box of the non-transparent sand object
        bbox = cleaned.getbbox() # (left, upper, right, lower)
        if bbox is None:
            print(f"Error: Empty image for {raw_path}")
            return
            
        left, upper, right, lower = bbox
        obj_w = right - left
        obj_h = lower - upper
        print(f"[{output_filename}] Object bbox: {bbox} (width: {obj_w}px, height: {obj_h}px)")
        
        # We crop using a square box (aspect ratio 1:1) to prevent distortion
        crop_size = max(obj_w, obj_h)
        
        # Determine crop box coordinates based on alignment rules
        cx = (left + right) // 2
        x1 = max(0, cx - crop_size // 2)
        x2 = min(W, x1 + crop_size)
        
        # If the crop size exceeds boundaries, clamp it
        if x2 - x1 < crop_size:
            crop_size = x2 - x1
            
        if align_bottom:
            # For Surface tile: Align the bottom of the sand dome with the bottom of the cropped box
            y2 = min(H, lower)
            y1 = max(0, y2 - crop_size)
            # Adjust if clamped at 0
            if y2 - y1 < crop_size:
                y2 = min(H, y1 + crop_size)
        else:
            # For Under-surface and Background: Center vertically
            cy = (upper + lower) // 2
            y1 = max(0, cy - crop_size // 2)
            y2 = min(H, y1 + crop_size)
            # Adjust if clamped
            if y2 - y1 < crop_size:
                y1 = max(0, y2 - crop_size)
                
        cropped = cleaned.crop((x1, y1, x2, y2))
        
        # Resize to target 48x48
        final_tile = cropped.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS)
        
        # Save preview
        final_tile.save(OUTPUT_DIR / output_filename, "PNG")
        print(f"Processed preview: {OUTPUT_DIR / output_filename} (aligned {'bottom' if align_bottom else 'center'})")
        
        if apply_live:
            LIVE_DIR.mkdir(parents=True, exist_ok=True)
            final_tile.save(LIVE_DIR / output_filename, "PNG")
            print(f"Applied live: {LIVE_DIR / output_filename}")

def process_all(apply_live: bool = False):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # surface: bottom-aligned
    process_single_tile(SURF_RAW, "sand_tile_surface.png", align_bottom=True, apply_live=apply_live)
    # under_surface and background: center-aligned
    process_single_tile(UNDER_RAW, "sand_tile_under_surface.png", align_bottom=False, apply_live=apply_live)
    process_single_tile(BG_RAW, "sand_tile_background.png", align_bottom=False, apply_live=apply_live)

if __name__ == "__main__":
    apply = "--apply" in sys.argv
    process_all(apply_live=apply)
