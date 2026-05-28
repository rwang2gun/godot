import os
from PIL import Image

def make_seamless_2d(im, target_w, target_h, overlap_x, overlap_y):
    # Resize to target + overlap
    temp_w = target_w + overlap_x
    temp_h = target_h + overlap_y
    resized = im.resize((temp_w, temp_h), Image.Resampling.LANCZOS)
    
    # 1. Horizontal blend
    h_blended = Image.new("RGBA", (target_w, temp_h))
    pix_in = resized.load()
    pix_out = h_blended.load()
    
    for y in range(temp_h):
        for x in range(target_w):
            if x >= overlap_x:
                pix_out[x, y] = pix_in[x, y]
            else:
                alpha = x / float(overlap_x)
                c_right = pix_in[x + target_w, y]
                c_left = pix_in[x, y]
                r = int(c_right[0] * (1.0 - alpha) + c_left[0] * alpha)
                g = int(c_right[1] * (1.0 - alpha) + c_left[1] * alpha)
                b = int(c_right[2] * (1.0 - alpha) + c_left[2] * alpha)
                a = int(c_right[3] * (1.0 - alpha) + c_left[3] * alpha)
                pix_out[x, y] = (r, g, b, a)
                
    # 2. Vertical blend
    if overlap_y > 0:
        v_blended = Image.new("RGBA", (target_w, target_h))
        pix_in2 = h_blended.load()
        pix_out2 = v_blended.load()
        
        for x in range(target_w):
            for y in range(target_h):
                if y >= overlap_y:
                    pix_out2[x, y] = pix_in2[x, y]
                else:
                    alpha = y / float(overlap_y)
                    c_bottom = pix_in2[x, y + target_h]
                    c_top = pix_in2[x, y]
                    r = int(c_bottom[0] * (1.0 - alpha) + c_top[0] * alpha)
                    g = int(c_bottom[1] * (1.0 - alpha) + c_top[1] * alpha)
                    b = int(c_bottom[2] * (1.0 - alpha) + c_top[2] * alpha)
                    a = int(c_bottom[3] * (1.0 - alpha) + c_top[3] * alpha)
                    pix_out2[x, y] = (r, g, b, a)
        return v_blended
    else:
        # If no vertical overlap, just crop/resize to target_h
        return h_blended.crop((0, 0, target_w, target_h))

def process_tiles():
    brain_dir = "C:/Users/code1412/.gemini/antigravity/brain/88aa8bbb-0bdb-4d7c-859c-66d1badecdfb"
    dest_dir = "D:/claude/godot/CandyAnts/assets/sprites/terrain"
    
    src_path = os.path.join(brain_dir, "cookie_tile_vertical_slice_1779981292050.png")
    
    # Target size for the tile sheet: 336x48 (7 tiles of 48x48)
    target_w = 336
    target_h = 48
    overlap_x = 48
    
    print(f"Loading source image from {src_path}...")
    im = Image.open(src_path).convert("RGBA")
    
    # 1. Processing Surface Tile
    print("1. Processing Surface Tile...")
    # Crop a clean band of flat cookie floor from the top (y=150 to y=390)
    cropped_surface = im.crop((0, 150, 1024, 390))
    seamless_surface = make_seamless_2d(cropped_surface, target_w, target_h, overlap_x, 0)
    
    # Save Surface
    seamless_surface.save(os.path.join(dest_dir, "cookie_tile_surface.png"), "PNG")
    seamless_surface.save(os.path.join(dest_dir, "cookie_tile_surface_painted.png"), "PNG")
    
    flipped_surface = seamless_surface.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flipped_surface.save(os.path.join(dest_dir, "cookie_tile_surface_flip.png"), "PNG")
    flipped_surface.save(os.path.join(dest_dir, "cookie_tile_surface_painted_flip.png"), "PNG")
    print("Saved Surface files.")
    
    # 2. Processing Under-Surface Tile
    print("2. Processing Under-Surface Tile...")
    # Crop the transition region from cookie crust down to chocolate (y=390 to y=630)
    # This aligns perfectly with the bottom of the surface tile at y=390
    cropped_under = im.crop((0, 390, 1024, 630))
    # We do NOT apply any sky transparency since it's a solid connected tile directly under the surface
    seamless_under = make_seamless_2d(cropped_under, target_w, target_h, overlap_x, 0)
    
    # Save Under-Surface
    seamless_under.save(os.path.join(dest_dir, "cookie_tile_under_surface.png"), "PNG")
    seamless_under.save(os.path.join(dest_dir, "cookie_tile_under_surface_painted.png"), "PNG")
    
    flipped_under = seamless_under.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flipped_under.save(os.path.join(dest_dir, "cookie_tile_under_surface_flip.png"), "PNG")
    flipped_under.save(os.path.join(dest_dir, "cookie_tile_under_surface_painted_flip.png"), "PNG")
    print("Saved Under-Surface files.")
    
    # 3. Processing Background Tile
    print("3. Processing Background Tile...")
    # Crop the chocolate region (y=630 to y=870). For vertical repeat, crop with overlap (y=630 to y=900)
    cropped_bg = im.crop((0, 630, 1024, 910)) # height 280, overlap of 40px
    # 8px vertical overlap at target size (48px height)
    seamless_bg = make_seamless_2d(cropped_bg, target_w, target_h, overlap_x, 8)
    
    # Save Background
    seamless_bg.save(os.path.join(dest_dir, "cookie_tile_background.png"), "PNG")
    seamless_bg.save(os.path.join(dest_dir, "cookie_tile_background_painted.png"), "PNG")
    
    flipped_bg = seamless_bg.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flipped_bg.save(os.path.join(dest_dir, "cookie_tile_background_flip.png"), "PNG")
    flipped_bg.save(os.path.join(dest_dir, "cookie_tile_background_painted_flip.png"), "PNG")
    print("Saved Background files.")
    
    print("All terrain tile files successfully processed and written to assets/sprites/terrain!")

if __name__ == "__main__":
    process_tiles()
