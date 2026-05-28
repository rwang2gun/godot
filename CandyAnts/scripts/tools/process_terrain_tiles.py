import os
import sys
from PIL import Image, ImageDraw

def make_seamless(input_path, output_path, crop_box, target_size, is_surface=False, thresh=30):
    print(f"Processing {input_path}...")
    if not os.path.exists(input_path):
        print(f"Error: Source file {input_path} does not exist.")
        return False
        
    # 1. Open source
    im = Image.open(input_path).convert("RGBA")
    w, h = im.size
    print(f"Source size: {w}x{h}")
    
    # 2. Transparency processing for surface
    if is_surface:
        print("Performing floodfill transparency on surface background...")
        # Clean top edge white space
        # Start floodfill from several coordinates along the top border to ensure all background areas are captured
        for x in range(0, w, 20):
            pix = im.getpixel((x, 0))
            # If the pixel is close to white (RGB values all > 230) and not yet transparent
            if pix[3] > 0 and sum(pix[:3]) > 690:
                ImageDraw.floodfill(im, (x, 0), (0, 0, 0, 0), thresh=thresh)
        print("Transparency floodfill completed.")
    
    # 3. Crop to the desired aspect ratio region
    cropped = im.crop(crop_box)
    print(f"Cropped region box {crop_box} (size: {cropped.size})")
    
    # 4. Resize to (352, target_height) where 352 = 320 + 32 (overlap width)
    target_w = target_size[0]
    target_h = target_size[1]
    temp_w = target_w + 32 # 352
    temp_h = target_h
    
    resized = cropped.resize((temp_w, temp_h), Image.Resampling.LANCZOS)
    print(f"Resized temporary image size: {resized.size}")
    
    # 5. Apply cross-fade blending to make it seamless (reducing width from 352 to 320)
    seamless = Image.new("RGBA", (target_w, target_h))
    pix_in = resized.load()
    pix_out = seamless.load()
    
    for y in range(target_h):
        for x in range(target_w):
            if x >= 32:
                pix_out[x, y] = pix_in[x, y]
            else:
                alpha = x / 32.0
                c_right = pix_in[x + 320, y]
                c_left = pix_in[x, y]
                
                # Blend channels smoothly
                r = int(c_right[0] * (1.0 - alpha) + c_left[0] * alpha)
                g = int(c_right[1] * (1.0 - alpha) + c_left[1] * alpha)
                b = int(c_right[2] * (1.0 - alpha) + c_left[2] * alpha)
                a = int(c_right[3] * (1.0 - alpha) + c_left[3] * alpha)
                pix_out[x, y] = (r, g, b, a)
                
    # 6. Save output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    seamless.save(output_path, "PNG")
    print(f"Saved seamless tile to: {output_path} (size: {seamless.size})")
    
    # 7. Save flipped version
    flipped = seamless.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flip_path = output_path.replace(".png", "_flip.png")
    flipped.save(flip_path, "PNG")
    print(f"Saved flipped seamless tile to: {flip_path}")
    return True

if __name__ == "__main__":
    # Source paths
    surface_src = r"C:\Users\code1412\.gemini\antigravity\brain\8534a7f7-edb9-4635-8841-e86ebabc0278\cookie_tile_surface_premium_source_1779972852282.png"
    background_src = r"C:\Users\code1412\.gemini\antigravity\brain\8534a7f7-edb9-4635-8841-e86ebabc0278\cookie_tile_background_premium_source_1779972867376.png"
    
    # Target paths
    workspace_dir = r"d:\claude\godot\CandyAnts"
    surface_dest = os.path.join(workspace_dir, "assets", "sprites", "terrain", "cookie_tile_surface.png")
    background_dest = os.path.join(workspace_dir, "assets", "sprites", "terrain", "cookie_tile_background.png")
    
    # Step 2.1: Surface processing
    # Crop box for surface: (left, top, right, bottom)
    # Width: 0 to 1024. Height: y=298 to 375 (77 pixels height)
    surface_crop_box = (0, 298, 1024, 375)
    surface_target_size = (320, 24)
    success_surface = make_seamless(
        surface_src, 
        surface_dest, 
        surface_crop_box, 
        surface_target_size, 
        is_surface=True, 
        thresh=30
    )
    
    # Step 2.2: Background processing
    # Crop box for background: (left, top, right, bottom)
    # Width: x=110 to 914 (804 pixels width). Height: y=440 to 571 (131 pixels height)
    background_crop_box = (110, 440, 914, 571)
    background_target_size = (320, 52)
    success_bg = make_seamless(
        background_src, 
        background_dest, 
        background_crop_box, 
        background_target_size, 
        is_surface=False
    )
    
    if success_surface and success_bg:
        print("Terrain tile processing finished successfully!")
    else:
        print("Terrain tile processing failed.")
        sys.exit(1)
