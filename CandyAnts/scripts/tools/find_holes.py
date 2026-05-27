from PIL import Image

def find_components(path):
    img = Image.open(path).convert("RGBA")
    data = img.load()
    width, height = img.size
    
    visited = set()
    components = []
    
    for x in range(width):
        for y in range(height):
            if (x, y) not in visited:
                r, g, b, a = data[x, y]
                dist = (255 - r) + (255 - g) + (255 - b)
                if dist < 120:  # white-ish
                    # start BFS/DFS
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
                                if ndist < 120:
                                    visited.add((nx, ny))
                                    queue.append((nx, ny))
                    components.append(comp)
                    
    # Print components sorted by size
    components.sort(key=len, reverse=True)
    print(f"Found {len(components)} white components.")
    for i, comp in enumerate(components[:15]):
        min_x = min(p[0] for p in comp)
        max_x = max(p[0] for p in comp)
        min_y = min(p[1] for p in comp)
        max_y = max(p[1] for p in comp)
        touches_border = min_x == 0 or max_x == width-1 or min_y == 0 or max_y == height-1
        print(f"Comp {i}: size={len(comp)}, bbox=({min_x}, {min_y}, {max_x}, {max_y}), border={touches_border}")

if __name__ == "__main__":
    find_components(r"C:\Users\code1412\.gemini\antigravity\brain\8534a7f7-edb9-4635-8841-e86ebabc0278\logo_pure_white_1779895802631.png")
