import os
from PIL import Image

def process_basher_tiles():
    workspace = r"D:\claude\godot\CandyAnts"
    brain_dir = r"C:\Users\code1412\.gemini\antigravity\brain\477ac1d3-0090-4363-ba84-65d68053ade3"
    
    # Locate generated images
    gen_root_path = None
    gen_top_path = None
    gen_spawner_path = None
    for filename in os.listdir(brain_dir):
        if filename.startswith("basher_root_square") and filename.endswith(".png"):
            gen_root_path = os.path.join(brain_dir, filename)
        elif filename.startswith("basher_top_square") and filename.endswith(".png"):
            gen_top_path = os.path.join(brain_dir, filename)
        elif filename.startswith("cookie_surface_square_spawner") and filename.endswith(".png"):
            gen_spawner_path = os.path.join(brain_dir, filename)
            
    print(f"Generated root tile found at: {gen_root_path}")
    print(f"Generated top tile found at: {gen_top_path}")
    print(f"Generated spawner tile found at: {gen_spawner_path}")
    
    if not gen_root_path or not gen_top_path or not gen_spawner_path:
        print("Error: Could not find generated tile files in brain dir.")
        return

    # Load reference solid tile to extract the exact chocolate base texture and border colors
    ref_solid_path = os.path.join(workspace, "assets", "sprites", "terrain", "usable_square", "cookie_solid_rotatable_square_01.png")
    if not os.path.exists(ref_solid_path):
        print(f"Error: Reference solid tile not found at {ref_solid_path}")
        return
        
    ref_img = Image.open(ref_solid_path).convert("RGBA")
    ref_pix = ref_img.load()
    
    # Load reference surface tile for spawner seamless borders
    ref_surf_path = os.path.join(workspace, "assets", "sprites", "terrain", "usable_square", "cookie_surface_square_01.png")
    if not os.path.exists(ref_surf_path):
        print(f"Error: Reference surface tile not found at {ref_surf_path}")
        return
    ref_surf_img = Image.open(ref_surf_path).convert("RGBA")
    ref_surf_pix = ref_surf_img.load()
    
    # Process Root Tile (bumpy at the top)
    root_gen = Image.open(gen_root_path).convert("RGBA")
    root_resized = root_gen.resize((48, 48), Image.Resampling.LANCZOS)
    root_pix = root_resized.load()
    
    final_root = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    final_root_pix = final_root.load()
    
    for y in range(48):
        for x in range(48):
            r, g, b, a = root_pix[x, y]
            is_transparent = (r > 180 and g > 180 and b > 180)
            
            if is_transparent:
                final_root_pix[x, y] = (0, 0, 0, 0)
            else:
                # Chocolate area: ensure seamless tiling with static/dynamic solid tiles
                if x == 0 or x == 47 or y == 47:
                    final_root_pix[x, y] = ref_pix[x, y]
                else:
                    final_root_pix[x, y] = (r, g, b, 255)
                    
    # Save Root Tile
    dest_root = os.path.join(workspace, "assets", "sprites", "terrain", "usable_square", "basher_root_square.png")
    final_root.save(dest_root)
    print(f"Processed root tile saved to: {dest_root}")
    
    # Process Top Tile (bumpy at the bottom)
    top_gen = Image.open(gen_top_path).convert("RGBA")
    top_resized = top_gen.resize((48, 48), Image.Resampling.LANCZOS)
    top_pix = top_resized.load()
    
    final_top = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    final_top_pix = final_top.load()
    
    for y in range(48):
        for x in range(48):
            r, g, b, a = top_pix[x, y]
            is_transparent = (r > 180 and g > 180 and b > 180)
            
            if is_transparent:
                final_top_pix[x, y] = (0, 0, 0, 0)
            else:
                # Chocolate area: ensure seamless tiling with static/dynamic solid tiles
                if x == 0 or x == 47 or y == 0:
                    final_top_pix[x, y] = ref_pix[x, y]
                else:
                    final_top_pix[x, y] = (r, g, b, 255)
                    
    # Save Top Tile
    dest_top = os.path.join(workspace, "assets", "sprites", "terrain", "usable_square", "basher_top_square.png")
    final_top.save(dest_top)
    print(f"Processed top tile saved to: {dest_top}")

    # Process Spawner Surface Tile
    spawner_gen = Image.open(gen_spawner_path).convert("RGBA")
    spawner_resized = spawner_gen.resize((48, 48), Image.Resampling.LANCZOS)
    spawner_pix = spawner_resized.load()
    
    final_spawner = Image.new("RGBA", (48, 48), (255, 255, 255, 255))
    final_spawner_pix = final_spawner.load()
    
    for y in range(48):
        for x in range(48):
            r, g, b, a = spawner_pix[x, y]
            # Solid block: copy border pixels from the reference surface tile to match adjacent tiles
            if x == 0 or x == 47 or y == 47:
                final_spawner_pix[x, y] = ref_surf_pix[x, y]
            else:
                final_spawner_pix[x, y] = (r, g, b, 255)
                
    # Save Spawner Surface Tile
    dest_spawner = os.path.join(workspace, "assets", "sprites", "terrain", "usable_square", "cookie_surface_square_spawner.png")
    final_spawner.save(dest_spawner)
    print(f"Processed spawner tile saved to: {dest_spawner}")

if __name__ == "__main__":
    process_basher_tiles()
