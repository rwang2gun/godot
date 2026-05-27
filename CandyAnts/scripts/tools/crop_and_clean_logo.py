from PIL import Image

def clean_and_crop(input_path, output_path, is_logo=False, min_dist=35, max_dist=130):
    img = Image.convert_mode = Image.open(input_path).convert("RGBA")
    data = img.load()
    width, height = img.size
    
    # 1. Find all connected components of white-ish pixels
    visited = set()
    components = []
    
    for x in range(width):
        for y in range(height):
            if (x, y) not in visited:
                r, g, b, a = data[x, y]
                dist = (255 - r) + (255 - g) + (255 - b)
                if dist < 150 or a == 0:  # white-ish or transparent
                    # BFS to find component
                    comp = []
                    queue = [(x, y)]
                    visited.add((x, y))
                    while queue:
                        curr = queue.pop(0)
                        comp.append(curr)
                        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            nx, ny = curr[0] + dx, curr[1] + dy
                            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                                nr, ng, nb, na = data[nx, ny]
                                ndist = (255 - nr) + (255 - ng) + (255 - nb)
                                if ndist < 150 or na == 0:
                                    visited.add((nx, ny))
                                    queue.append((nx, ny))
                    components.append(comp)
                    
    # Sort components by size
    components.sort(key=len, reverse=True)
    
    # The largest component is always the outer background (Comp 0)
    bg_pixels = set(components[0])
    
    # For the logo, we also want to transparentize the inner holes of letters.
    # An inner hole is a large white component (size >= 300) that does NOT touch the border.
    if is_logo:
        for comp in components[1:]:
            min_x = min(p[0] for p in comp)
            max_x = max(p[0] for p in comp)
            min_y = min(p[1] for p in comp)
            max_y = max(p[1] for p in comp)
            touches_border = min_x == 0 or max_x == width-1 or min_y == 0 or max_y == height-1
            
            # If it's a large internal white component, it's an inner hole!
            if not touches_border and len(comp) >= 300:
                print(f"Adding letter hole component of size {len(comp)} to transparency mask.")
                for p in comp:
                    bg_pixels.add(p)
                    
    # 2. Apply alpha keying based on the bg_pixels mask
    for x in range(width):
        for y in range(height):
            if (x, y) in bg_pixels:
                r, g, b, a = data[x, y]
                dist = (255 - r) + (255 - g) + (255 - b)
                if dist < min_dist:
                    data[x, y] = (0, 0, 0, 0)
                elif dist < max_dist:
                    factor = (dist - min_dist) / (max_dist - min_dist)
                    new_a = int(255 * factor)
                    data[x, y] = (r, g, b, new_a)
                else:
                    # Soft edge blend
                    data[x, y] = (r, g, b, 255)
            else:
                # Opaque interior (face, belly, candy reflections, candy cane white stripes)
                r, g, b, a = data[x, y]
                data[x, y] = (r, g, b, 255)

    # 3. Crop to content bounding box
    bbox = img.getbbox()
    if bbox:
        cropped = img.crop(bbox)
        cropped.save(output_path, "PNG")
        print(f"Successfully cleaned and cropped {output_path} to {bbox}")
    else:
        img.save(output_path, "PNG")
        print(f"Could not crop {output_path}")

if __name__ == "__main__":
    # Clean the newly generated solid white images
    clean_and_crop(
        r"C:\Users\code1412\.gemini\antigravity\brain\8534a7f7-edb9-4635-8841-e86ebabc0278\mascot_bg_removal_1779895704807.png",
        r"d:\claude\godot\CandyAnts\assets\logo\mascot_premium.png",
        is_logo=False,
        min_dist=35,
        max_dist=130
    )
    clean_and_crop(
        r"C:\Users\code1412\.gemini\antigravity\brain\8534a7f7-edb9-4635-8841-e86ebabc0278\logo_pure_white_1779895802631.png",
        r"d:\claude\godot\CandyAnts\assets\logo\logo_wordmark_premium.png",
        is_logo=True,
        min_dist=30,
        max_dist=110
    )
