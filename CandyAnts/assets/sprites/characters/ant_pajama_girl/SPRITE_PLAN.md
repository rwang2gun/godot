# Ant Pajama Girl Sprite Plan

## Source Assets

- `ant_pajama_girl_concept.png`: primary character concept.
- `ant_pajama_girl_idle_sheet_concept.png`: 4-frame idle concept sheet.
- `ant_pajama_girl_walk_sheet_concept.png`: 6-frame walk concept sheet.
- `ant_pajama_girl_carry_sheet_concept.png`: 6-frame carrying walk concept sheet.
- `ant_pajama_girl_fall_sheet_concept.png`: 4-frame falling concept sheet.
- `ant_pajama_girl_blocker_sheet_concept.png`: 2-frame blocker stance concept sheet.
- `ant_pajama_girl_idle_sheet.png`: cleaned transparent idle sheet.
- `ant_pajama_girl_walk_sheet.png`: cleaned transparent walk sheet.
- `ant_pajama_girl_carry_sheet.png`: cleaned transparent carrying walk sheet.
- `ant_pajama_girl_fall_sheet.png`: cleaned transparent falling sheet.
- `ant_pajama_girl_blocker_sheet.png`: cleaned transparent blocker stance sheet.

## Character Rules

- Keep the round ant hood, two antennae, black bob hair, pale belly panel, pink neck button, mitten sleeves, rounded feet, and segmented abdomen tail.
- Preserve a cute, soft chibi silhouette with a large head and small body.
- Use the abdomen tail as a readable ant signal in every gameplay pose.
- Keep feet on a consistent baseline so frame changes do not jitter.
- Keep antenna motion subtle; it should sell life without changing the collision read.

## Animation Set

1. `idle`: 4 frames, breathing bounce, antenna wiggle. Draft sheet complete.
2. `walk`: 6 frames, tiny waddling steps, abdomen tail follow-through. Draft sheet complete.
3. `carry`: 6 frames, same walk rhythm while holding candy in front. Draft sheet complete.
4. `fall`: 4 frames, feet lifted, antennae trailing upward. Draft sheet complete; concept includes baked motion lines that should become separate VFX in a later cleanup pass.
5. `blocker`: 2 frames, planted stance, arms out or firm mitten pose. Draft sheet complete.
6. `saved`: 2-4 frames, happy hop or relieved smile.
7. `dead`: 1 frame, softened non-graphic fail pose.

## Godot Prep

- Convert final sheets to transparent PNG.
- Export equal-size cells per animation.
- Recommended starting cell size: `384x384` for source art, then downscale in import settings or runtime scale.
- Set the visual origin near the center of the feet.
- Keep physics collision independent from the illustration: current `Ant.tscn` collision is `12x10`.

## Next Production Step

Clean `ant_pajama_girl_idle_sheet_concept.png` into a true 4-frame transparent sprite sheet, then wire it into `Ant.tscn` as an `AnimatedSprite2D` while leaving the existing collision and state logic unchanged.
