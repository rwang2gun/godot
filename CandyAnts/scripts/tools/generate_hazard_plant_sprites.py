from PIL import Image, ImageDraw
import math

ROOT = "d:/claude/godot/CandyAnts"
OUT_DIR = f"{ROOT}/assets/sprites/terrain"

def draw_soda_water():
    # 48x48 output, 192x192 internally
    size = 192
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Gradient background: translucent soda blue
    for y in range(size):
        t = y / size
        # Interpolate between light soda blue and deeper soda blue
        r = int(120 * (1 - t) + 70 * t)
        g = int(200 * (1 - t) + 150 * t)
        b = int(240 * (1 - t) + 220 * t)
        a = int(160 * (1 - t) + 210 * t) # slightly more solid at the bottom
        d.line([(0, y), (size, y)], fill=(r, g, b, a))
        
    # Draw soft water ripples at the top
    for x in range(0, size, 24):
        # Draw wave arc
        d.arc((x - 12, -10, x + 36, 12), 0, 180, fill=(255, 255, 255, 120), width=6)
        
    # Draw bubbles (white circles of various sizes and opacities)
    bubbles = [
        (40, 50, 8, 180),
        (120, 30, 12, 140),
        (80, 90, 6, 200),
        (150, 110, 10, 160),
        (30, 140, 14, 120),
        (110, 150, 8, 190),
        (160, 60, 7, 150),
    ]
    for bx, by, br, ba in bubbles:
        # Draw bubble rim
        d.ellipse((bx - br, by - br, bx + br, by + br), outline=(255, 255, 255, ba), width=3)
        # Highlight glint on the bubble
        d.ellipse((bx - br//2, by - br//2, bx - br//4, by - br//4), fill=(255, 255, 255, int(ba * 0.7)))

    final = img.resize((48, 48), Image.Resampling.LANCZOS)
    final.save(f"{OUT_DIR}/soda_water.png", "PNG")
    print("Generated soda_water.png")

def draw_sticky_caramel():
    # 48x48 output, 192x192 internally
    size = 192
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Gradient background: rich caramel brown to dark chocolate
    for y in range(size):
        t = y / size
        r = int(220 * (1 - t) + 120 * t)
        g = int(145 * (1 - t) + 65 * t)
        b = int(60 * (1 - t) + 25 * t)
        a = int(200 * (1 - t) + 240 * t)
        d.line([(0, y), (size, y)], fill=(r, g, b, a))
        
    # Draw gooey vertical drip patterns
    # A few vertical curves using curves/lines
    drips = [
        [(20, 0), (35, 60), (45, 120), (30, 192)],
        [(80, 0), (70, 70), (95, 130), (85, 192)],
        [(140, 0), (155, 80), (135, 140), (150, 192)]
    ]
    for points in drips:
        # Draw thick strokes for caramel layers
        d.line([(px, py) for px, py in points], fill=(240, 175, 90, 150), width=16, joint="curve")
        
    # Draw shiny gloss highlights (specular white streaks)
    highlights = [
        [(30, 20), (38, 50)],
        [(85, 80), (90, 110)],
        [(145, 40), (148, 70)],
        [(15, 130), (22, 160)]
    ]
    for points in highlights:
        d.line([(px, py) for px, py in points], fill=(255, 255, 255, 180), width=4, joint="curve")

    # Dark borders to outline the sticky block
    d.line([(0, 0), (0, size)], fill=(37, 33, 43, 255), width=8)
    d.line([(size-1, 0), (size-1, size)], fill=(37, 33, 43, 255), width=8)
    d.line([(0, size-1), (size, size-1)], fill=(37, 33, 43, 255), width=8)

    final = img.resize((48, 48), Image.Resampling.LANCZOS)
    final.save(f"{OUT_DIR}/sticky_caramel.png", "PNG")
    print("Generated sticky_caramel.png")

def draw_peppermint_plant():
    # 64x64 output, 256x256 internally
    size = 256
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    cx, cy = size // 2, size // 2
    
    # 1. Draw Mint Leaves (Green) behind the candy
    # We draw leaf shapes using polygons and outline
    def draw_leaf(d, angle_deg, flip=False):
        rad = math.radians(angle_deg)
        cos_a, sin_a = math.cos(rad), math.sin(rad)
        
        # Leaf points relative to center
        # Simple leaf shape: tip at (0, -90), base at (0, 0)
        leaf_pts = [
            (0, 0),
            (-35, -30),
            (-50, -65),
            (0, -100),
            (50, -65),
            (35, -30),
        ]
        
        # Rotate points
        rotated = []
        for px, py in leaf_pts:
            if flip:
                px = -px
            rx = cx + (px * cos_a - py * sin_a)
            ry = cy + (px * sin_a + py * cos_a)
            rotated.append((rx, ry))
            
        # Draw leaf fill and border
        d.polygon(rotated, fill=(129, 199, 132, 255), outline=(37, 33, 43, 255), width=8)
        # Leaf veins
        vein_pts = [(0, 0), (0, -85)]
        rx1 = cx + (vein_pts[0][0] * cos_a - vein_pts[0][1] * sin_a)
        ry1 = cy + (vein_pts[0][0] * sin_a + vein_pts[0][1] * cos_a)
        rx2 = cx + (vein_pts[1][0] * cos_a - vein_pts[1][1] * sin_a)
        ry2 = cy + (vein_pts[1][0] * sin_a + vein_pts[1][1] * cos_a)
        d.line([(rx1, ry1), (rx2, ry2)], fill=(37, 33, 43, 255), width=6)

    draw_leaf(d, -45)
    draw_leaf(d, 45, flip=True)
    
    # 2. Draw Peppermint Candy Wheel in center
    r_candy = 65
    chocolate = (37, 33, 43, 255)
    
    # Candy border
    d.ellipse((cx - r_candy - 4, cy - r_candy - 4, cx + r_candy + 4, cy + r_candy + 4), fill=chocolate)
    d.ellipse((cx - r_candy, cy - r_candy, cx + r_candy, cy + r_candy), fill=(255, 255, 255, 255))
    
    # Red swirls (drawn as wedges)
    for angle in range(0, 360, 45):
        d.pieslice((cx - r_candy, cy - r_candy, cx + r_candy, cy + r_candy), angle, angle + 22, fill=(229, 57, 53, 255))
        
    # Re-draw border ring and center circle
    d.ellipse((cx - r_candy, cy - r_candy, cx + r_candy, cy + r_candy), outline=chocolate, width=6)
    d.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), fill=(255, 255, 255, 255), outline=chocolate, width=6)
    
    final = img.resize((64, 64), Image.Resampling.LANCZOS)
    final.save(f"{OUT_DIR}/peppermint_plant.png", "PNG")
    print("Generated peppermint_plant.png")

if __name__ == "__main__":
    draw_soda_water()
    draw_sticky_caramel()
    draw_peppermint_plant()
