from PIL import Image, ImageDraw

ROOT = "d:/claude/godot/CandyAnts"
OUT_DIR = f"{ROOT}/assets/sprites/terrain"

def draw_surface():
    # Target size: 320x24, internally 1280x96 for anti-aliasing
    w, h = 1280, 96
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Chocolate outline base at the bottom
    d.rectangle((0, 80, w, 96), fill=(37, 33, 43, 255))
    
    # Golden cookie body
    # Draw vertical gradient
    for y in range(0, 80):
        t = y / 80
        r = int(244 * (1 - t) + 210 * t)
        g = int(203 * (1 - t) + 160 * t)
        b = int(143 * (1 - t) + 90 * t)
        d.line([(0, y), (w, y)], fill=(r, g, b, 255))
        
    # Top chocolate border
    d.line([(0, 0), (w, 0)], fill=(37, 33, 43, 255), width=8)
    
    # Sweet sugar glaze: a pink/white wavy frosting line along the top
    for x in range(0, w, 32):
        d.chord((x - 16, 2, x + 48, 30), 180, 360, fill=(255, 205, 210, 255))
        
    # Draw colorful candy sprinkles on the surface
    # Sprinkles colors: Red, Blue, Green, Yellow, Orange
    sprinkle_colors = [
        (229, 57, 53, 255),   # red
        (30, 136, 229, 255),   # blue
        (67, 160, 71, 255),    # green
        (253, 216, 53, 255),   # yellow
        (244, 81, 30, 255)     # orange
    ]
    
    # Let's seed a deterministic pseudo-random sequence for sprinkles
    import random
    random.seed(42)
    for _ in range(35):
        sx = random.randint(10, w - 10)
        sy = random.randint(12, 60)
        sw = random.randint(16, 28)
        sh = random.randint(6, 10)
        color = random.choice(sprinkle_colors)
        
        # Draw a little rotated sprinkle rectangle
        # To make it simple and clean, draw a rounded rectangle
        d.rounded_rectangle((sx, sy, sx + sw, sy + sh), radius=3, fill=color, outline=(37, 33, 43, 255), width=2)

    # Resize down
    final = img.resize((320, 24), Image.Resampling.LANCZOS)
    final.save(f"{OUT_DIR}/cookie_tile_surface.png", "PNG")
    
    # Generate flipped version
    flipped = final.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flipped.save(f"{OUT_DIR}/cookie_tile_surface_flip.png", "PNG")
    print("Generated cookie_tile_surface.png and flipped variant.")

def draw_background():
    # Target size: 320x52, internally 1280x208
    w, h = 1280, 208
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    
    # Gradient: rich chocolatey brown
    for y in range(h):
        t = y / h
        r = int(109 * (1 - t) + 80 * t)
        g = int(76 * (1 - t) + 50 * t)
        b = int(65 * (1 - t) + 30 * t)
        d.line([(0, y), (w, y)], fill=(r, g, b, 255))
        
    # Draw cookie biscuit chunks (large rounded shapes)
    import random
    random.seed(1337)
    
    chocolate = (37, 33, 43, 255)
    light_chocolate = (141, 110, 99, 255)
    dark_chocolate = (62, 39, 35, 255)
    
    # Draw biscuit brick pattern
    for row in range(4):
        y_start = row * 52
        offset = 80 if row % 2 == 1 else 0
        for x_start in range(-160 + offset, w + 160, 320):
            # Draw a biscuit block with rounded corners
            d.rounded_rectangle(
                (x_start + 12, y_start + 8, x_start + 308, y_start + 44),
                radius=16,
                fill=dark_chocolate,
                outline=chocolate,
                width=8
            )
            # Add some inner texture dots / sparkles inside each block
            for _ in range(5):
                tx = x_start + random.randint(30, 290)
                ty = y_start + random.randint(12, 40)
                d.ellipse((tx - 4, ty - 4, tx + 4, ty + 4), fill=light_chocolate)

    # Resize down
    final = img.resize((320, 52), Image.Resampling.LANCZOS)
    final.save(f"{OUT_DIR}/cookie_tile_background.png", "PNG")
    
    # Generate flipped version
    flipped = final.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    flipped.save(f"{OUT_DIR}/cookie_tile_background_flip.png", "PNG")
    print("Generated cookie_tile_background.png and flipped variant.")

if __name__ == "__main__":
    draw_surface()
    draw_background()
