# Handoff: CandyAnts UI — Design System → Godot 4.6

> **🚨 IMPORTANT — This bundle is now absorbed at `CandyAnts/docs/design_handoff/` as a designer-source reference.**
>
> The **production source-of-truth for game runtime is `docs/UI_GUIDE.md` + `assets/`** (not this README).
>
> - **Design tokens (colors, typography, spacing, etc.) SoT**: `docs/UI_GUIDE.md` §1·§2.
> - **Production SVG assets SoT**: `assets/**/*.svg` (normalized via `scripts/tools/normalize_svg.py`).
> - **This bundle's `assets/**/*.svg`** uses `oklch(...)` paints and class-only styling (no `<defs><style>`). **Godot 4 SVG importer cannot render them directly.** Do **NOT** copy 1:1 into the codebase.
> - **Required pipeline**: `docs/design_handoff/assets/*.svg` → `scripts/tools/normalize_svg.py` (oklch→hex, class→inline fill/stroke per `scripts/tools/svg_color_map.json`) → `assets/*.svg` → `tests/SvgImportSmokeTest.gd` PASS.
> - **The "1:1 copy" / "drop-in" instructions further down in this README are obsolete.** Read them as design intent only; follow the `phases/mvp/phase08-*.md` + `docs/UI_GUIDE.md` §2.6 instead.
> - **Designer updates**: overwrite this folder, then re-run `normalize_svg.py` and update `svg_color_map.json` if new classes/oklch values appear.

## Overview

This bundle hands off the **CandyAnts (캔디앤츠) visual design system** to a developer who will implement it in the existing **Godot 4.6 / GDScript** codebase at `CandyAnts/`. It contains design tokens, vector assets, an interactive HTML prototype of the in-stage UI, and per-screen specs.

The goal of the implementation work is to:
1. Encode every visual token into a Godot **Theme** resource so all `Control` nodes auto-style correctly.
2. Import the SVG assets (logo, skill icons, ant/candy/home sprites, stage background) into the project.
3. Replace the existing placeholder UI scenes (`scenes/ui/HUD.tscn`, `scenes/ui/SkillToolbar.tscn`) with the designed layouts.
4. Hook the visual layer to the existing `EventBus` / `ScoreSystem` / `StageData` so counters and skill inventory drive the new UI.

## About the design files

**The HTML/CSS/JSX files in this bundle are design references — not production code.** They were authored to specify look, layout, motion, and interaction, and run as a clickable prototype in a browser. The implementation task is to **recreate these designs natively in Godot** using the project's established patterns:

- `CanvasLayer` + `Control` node trees for HUD/toolbar/dialog
- A central `Theme` resource (`res://theme/candyants.tres`) for all styling
- `AnimationPlayer` or tween for the "boop" / "pop" motion
- Existing autoloads (`EventBus`, `ScoreSystem`) for state

Do not import the React/Babel runtime or run HTML inside the game.

## Fidelity

**High-fidelity.** All colors, typography, spacing, radii, shadows, and motion easing are committed values. Color values use `oklch()` in CSS — convert to sRGB hex when entering them into Godot `Color` fields (every value below lists both for convenience).

The SVG **mascot/sprite art is intentionally placeholder** (simple shapes establishing tone). Final ant/candy/home illustrations should be redrawn by an illustrator and dropped into `docs/design_handoff/assets/` at the same paths — **then re-run `scripts/tools/normalize_svg.py`** so the production `assets/` files inherit the update through the same normalization pipeline (oklch→hex, class→inline). The skill icons, logo silhouette, and stage background are also placeholder-quality and follow the same flow.

---

## Target codebase

```
CandyAnts/                          (already exists)
├── project.godot
├── scenes/
│   ├── Main.tscn
│   └── ui/
│       ├── HUD.tscn                ← REPLACE (currently 3 empty Labels)
│       └── SkillToolbar.tscn       ← REPLACE (currently empty HBoxContainer)
├── scripts/
│   ├── ui/
│   │   ├── HUD.gd                  ← REWIRE to new node paths
│   │   └── SkillToolbar.gd         ← REWIRE to new node paths
│   └── skills/                     (8 skill scripts already exist)
├── data/stages/stage01.tres        (StageData resource — leave as-is)
└── assets/
    ├── sprites/                    ← currently empty (.gitkeep only)
    ├── tiles/                      ← currently empty
    └── audio/                      ← currently empty
```

**Files to add:**
```
CandyAnts/
├── theme/
│   └── candyants.tres              ← NEW Theme resource (this is the big one)
├── assets/
│   ├── fonts/
│   │   ├── Jua-Regular.ttf         ← download from Google Fonts
│   │   └── Gaegu-Bold.ttf
│   ├── logo/{wordmark,icon,mascot}.svg
│   ├── icons/skills/{climber,floater,bomber,blocker,builder,basher,miner,digger}.svg
│   ├── sprites/{ant,ant_carrying,ant_climber,…,ant_dead,ant_saved}.svg
│   └── illustrations/stage_bg.svg
└── scenes/ui/
    └── StageDialog.tscn            ← NEW — win/loss modal
```

---

## Design tokens

All tokens live in `colors_and_type.css` (in this bundle). Below is the canonical hex form for entry into Godot inspector / `Color()` literals.

### Colors — paper & ink (foundation)
| Token        | oklch                  | sRGB hex   | Use                     |
|--------------|------------------------|------------|-------------------------|
| `--cream-50` | `oklch(.985 .012 75)`  | `#FBF8F1`  | Page bg (`--bg`)        |
| `--cream-100`| `oklch(.965 .020 70)`  | `#F5EFE3`  | Card surface            |
| `--cream-200`| `oklch(.93  .030 70)`  | `#E9DFCB`  | Recessed surface        |
| `--cream-300`| `oklch(.88  .040 65)`  | `#D9C9AC`  | Hairline divider        |
| `--ink-900`  | `oklch(.26  .045 50)`  | `#3A2A1C`  | Body text + outlines    |
| `--ink-700`  | `oklch(.40  .060 50)`  | `#5C4530`  | Secondary text          |
| `--ink-500`  | `oklch(.58  .045 55)`  | `#8C7660`  | Tertiary / disabled     |

### Colors — brand & semantic
| Token         | sRGB hex   | Used for                    |
|---------------|------------|-----------------------------|
| `--peach-300` | `#FAD9C4`  | Primary tint                |
| `--peach-500` | `#F2A48F`  | **PRIMARY** (candy HP color)|
| `--peach-700` | `#D17A60`  | Primary press               |
| `--mint-300`  | `#D4F0E5`  | Success tint                |
| `--mint-500`  | `#9ED9C2`  | **SUCCESS** (saved color)   |
| `--mint-700`  | `#5EA88A`  | Success press               |
| `--berry-300` | `#F7C9C4`  | Danger tint                 |
| `--berry-500` | `#E48579`  | **DANGER** (lost color)     |
| `--berry-700` | `#B85546`  | Danger press                |
| `--lemon-300` | `#FCEFC2`  | Warn tint                   |
| `--lemon-500` | `#F0D77B`  | **WARN**                    |
| `--lemon-700` | `#C9A93C`  | Time-counter color          |
| `--grape-300` | `#DCCEE2`  | Info tint                   |
| `--grape-500` | `#B49AC5`  | **INFO** (in-transit color) |

> Convert `oklch()` to sRGB using the spec ([w3.org/TR/css-color-4](https://www.w3.org/TR/css-color-4/#color-conversion-code)). Hex values above are pre-converted approximations — verify with an oklch tool before final commit.

### Stable HUD-counter color mapping (do not change)
- candy HP → `--peach-500`
- in-transit → `--grape-500`
- saved → `--mint-500`
- lost → `--berry-500`
- time → `--lemon-700`

### Typography
| Token            | Family               | Use                              |
|------------------|----------------------|----------------------------------|
| `--font-display` | **Jua** (Google)     | Titles, big counters, buttons    |
| `--font-body`    | **Gaegu** Bold (Google) | Body, dialog descriptions     |
| `--font-mono`    | JetBrains Mono       | Debug overlays only              |

Sizes (px): 12, 14, 16, 20 (body default), 24, 32, 44, 64, 96.
Line-height: tight 1.05, snug 1.20, body 1.45.

> **Substitution flag** — Jua/Gaegu chosen as nearest-match for "all-ages Korean casual game". Confirm or replace before final art pass.

### Spacing (8px base)
4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96. Plus `--safe-area: 32px` for handheld bezel safety.

### Radii
sm 8 · md 12 · lg 16 · xl 20 · 2xl 24 · pill 999.

### Stroke + shadow (the brand signature)
- **Stroke** — every interactive element has a **3px** chocolate-ink outline (`--ink-900`).
- **Sticker shadow** (signature):
  - sm `2px 2px 0 #3A2A1C`
  - default `4px 4px 0 #3A2A1C`
  - lg `6px 6px 0 #3A2A1C`
- **Card shadow** (softer): `0 8px 0 rgba(58,42,28,0.35)`
- **Gloss** (filled buttons): `inset 0 4px 0 rgba(255,255,255,0.45)`
- **NEVER** use Godot's default soft `box_shadow` — there isn't one in `StyleBoxFlat`. Implement the sticker shadow as a second background `StyleBoxFlat` offset by (4,4) behind the foreground, OR use a custom `_draw()` override.

### Motion
- House easing: `cubic-bezier(0.5, 1.5, 0.5, 1)` (overshoot — "boop"). In Godot tween: `Tween.TRANS_BACK` with `Tween.EASE_OUT` is the closest equivalent.
- Durations: press 120ms, state 220ms, celebrate 600ms.
- **No fades for primary feedback.** Things scale and squish.
- Counters do a `caPop` keyframe on every value change: `scale(.8) → scale(1.08) → scale(1)` over 220ms.
- Home hatch idle: `scale(1.0) → scale(1.03)` every 1.6s.

---

## Screens

### 1. Stage in-play (`scenes/ui/HUD.tscn` + `SkillToolbar.tscn`)
**Reference:** `ui_kits/game/index.html` (interactive prototype)

**Layout (1920×1080, all 32px from edges):**

| Region              | Position             | Contents |
|---------------------|----------------------|----------|
| Top-left counter cluster | `top: 32, left: 32`, horizontal flex, gap 12 | 4 counters: Candy HP, In Transit, Saved, Lost |
| Top-right cluster   | `top: 32, right: 32`, horizontal flex, gap 12 | Time counter · Release-rate stepper · Pause button (56×56 square) |
| Bottom skill strip  | `bottom: 0, left: 0, right: 0`, height ~140px | Cream-200 fill, 3px ink top-border. Centered `HBoxContainer` of 8 SkillSlots, gap 14 |

**Counter component** (one card per counter):
- Size: ~110×84
- Background: `--surface` (#F5EFE3), 3px ink border, 16px radius, 2px sticker shadow
- Top line: 12px Jua label "candy hp" (uppercase, letter-spacing .04em) with a 10px circle dot in the counter's stable color
- Big number: 32px Jua, color = the counter's stable color, tabular-nums
- Bottom line: 11px Jua Korean label ("사탕 HP")

**SkillSlot** (one button per skill):
- Size: 88×88 (already 44pt+ touch friendly)
- Background: `--cream-100` if armed, `--peach-300` if selected, plus a 3px `--mint-500` outline-offset focus ring
- 3px ink border, 16px radius, default sticker shadow + gloss
- 56×56 SVG icon centered
- Top-right count badge: ink fill, white text, 13px Jua, pill, 2px cream border
- Top-left hotkey: 10px JetBrains Mono in a translucent white pill (1–8)
- Bottom label: 11px Jua, Korean skill name (등반/낙하산/폭탄/차단/계단/굴착/채굴/땅파기)
- Empty (count = 0): saturate(.3) + opacity(.55) + disabled

**Release-rate stepper:**
- Two small `−`/`+` buttons (28×28, 2px ink, 8px radius), 24px Jua number between them
- Range 1–99, step 5

**Hotkeys** (pad/keyboard):
- `1`–`8` → select skill slot 1–8 (matches existing `INPUT_MAPPING.md`)
- `space` / `P` → toggle pause
- See `CandyAnts/docs/INPUT_MAPPING.md` for full Pad / Touch / KB+M matrix

**Animation hooks (call from existing systems):**
- `EventBus.candy_hp_changed(new_hp)` → caPop on candy-HP counter
- `EventBus.ant_saved` → caPop on saved counter, and (optional) trigger a 600ms confetti burst at the home hatch
- `EventBus.ant_lost` → caPop on lost counter
- Pause toggled → scale stage to 0% playback rate; pause overlay (warm-brown veil at 0.55, blur 6px)

### 2. Stage complete dialog (NEW: `scenes/ui/StageDialog.tscn`)
**Reference:** `preview/dialog.html` and the in-context overlay in `ui_kits/game/index.html` (click "완료 데모")

**Layout:**
- Full-screen modal. Backdrop: `oklch(0.30 0.04 30 / 0.55)` (warm brown veil), `backdrop_filter: blur(6px)` — in Godot, a `ColorRect` with `Color(0.20, 0.13, 0.07, 0.55)` and a `BackBufferCopy`+blur shader.
- Card: 380px wide, centered, `--surface` fill, 3px ink, 24px radius, 6px sticker shadow, padding 18×22
- Animation on open: caPop (220ms TRANS_BACK)

**Content:**
- Title (Jua 22, ink): `사탕을 무사히 옮겼어요!` / `사탕이 부족했어요`
- Subtitle (Gaegu 13, fg-muted): English mirror
- **Hero score line:** big Jua 36, `8 / 10 조각` (saved / original_hp from existing `ScoreSystem`)
- 3-star rating row (44×44 stars, lemon-500 fill / cream-200 dim, 3px ink, polygon clip-path)
  - Thresholds: 0–49% → ☆☆☆, 50–79% → ★☆☆, 80–94% → ★★☆, 95%+ → ★★★
- Stat chips row: `귀가 8` `잃음 2` `남은 시간 47s` (pill, 14px Jua)
- Buttons: `다시 하기` (secondary) + `다음 단계` / `계속하기` (primary)

### 3. Skill icons & ant sprites
All under `assets/`. They render at any scale (vector) — laid out on a 64-unit grid for icons and 96-unit grid for sprites.

> **OBSOLETE**: the original "copy 1:1 into the codebase" instruction does **not** apply. Run `scripts/tools/normalize_svg.py` first (see top-of-file warning + `phases/mvp/phase08-ui-theme-assets.md`).

**11 ant sprite states** (`assets/sprites/`):
- `ant.svg` — walker
- `ant_carrying.svg` — carrying candy
- `ant_faller.svg` — falling
- `ant_dead.svg` — dead
- `ant_saved.svg` — celebrating (use on home-arrival burst)
- `ant_climber.svg`, `ant_floater.svg`, `ant_bomber.svg`, `ant_blocker.svg`, `ant_builder.svg`, `ant_basher.svg`, `ant_miner.svg`, `ant_digger.svg` — one per skill state

In Godot, drive these via an `AnimatedSprite2D` with a `SpriteFrames` resource keyed by `Ant.state` enum, OR with a regular `Sprite2D` whose `texture` is swapped on state change (cheaper, fine for vector).

---

## Godot Theme mapping

Create `res://theme/candyants.tres` with these styles. (Properties listed are the ones that differ from default; everything else may stay default.)

### Default font
```
default_font = preload("res://assets/fonts/Jua-Regular.ttf")
default_font_size = 20
default_color = Color(0.227, 0.165, 0.110)   # ink-900
```

### Button (StyleBoxFlat for normal/hover/pressed/disabled)
- `bg_color` = `#F2A48F` (peach-500)
- `border_width_*` = 3
- `border_color` = `#3A2A1C` (ink-900)
- `corner_radius_*` = 16
- `content_margin_*` = (10, 22) (vertical, horizontal)
- `shadow_color` = `#3A2A1C`, `shadow_offset` = (4, 4), `shadow_size` = 0
  *(StyleBoxFlat shadows are blurred — for a hard-edge sticker shadow, draw a duplicate StyleBoxFlat 4px offset behind, or use a `NinePatchRect` overlay. See "Sticker shadow recipe" below.)*
- `pressed`: same but `bg_color = #D17A60` (peach-700), `shadow_offset = (2,2)`, and add `expand_margin_*` to fake the translate(2px,2px) by shrinking content margins by 2.
- `disabled`: `bg_color = #C8B5A6` (peach-500 desaturated 60%), `font_color` 60% alpha.

### Panel (cards, dialogs)
- `bg_color` = `#F5EFE3` (cream-100)
- `border_width_*` = 3, `border_color` = `#3A2A1C`
- `corner_radius_*` = 24

### Label
- `font_color` = `#3A2A1C` (ink-900)
- For muted: override per-instance to `#5C4530` (ink-700)

### CheckButton / SpinBox / Slider
- All borders 3px ink, all radii 8–12, all backgrounds `#F5EFE3`. Detail per the prototype.

### Sticker-shadow recipe (StyleBoxFlat alone can't do hard offsets)
Two options:
1. **Duplicate StyleBoxFlat layer**: wrap each themed control in a parent `Control` and draw a second `StyleBoxFlat` (ink fill, same radius, same size) with a `(4, 4)` offset behind it. Cheapest.
2. **Custom `_draw()` override**: extend `Button` and override `_draw()` to call `draw_rect` for the shadow before the default draw. More flexible.
3. **NinePatchRect**: render the 4px-offset ink rect as a 9-patch behind the control.

Pick (1) for HUD counters, (3) for dialogs.

### Motion in Godot
```gdscript
# caPop (220ms scale bounce)
var t := create_tween()
t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
t.tween_property(node, "scale", Vector2(1.08, 1.08), 0.10)
t.tween_property(node, "scale", Vector2(1.0, 1.0), 0.12)

# Press boop (120ms)
btn.pressed.connect(func():
    var t := create_tween()
    t.tween_property(btn, "position", btn.position + Vector2(2, 2), 0.06)
    t.tween_property(btn, "position", btn.position, 0.06)
)

# Idle home hatch bob (loop, 1.6s)
var t := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
t.tween_property(home_sprite, "scale", Vector2(1.03, 1.03), 0.8)
t.tween_property(home_sprite, "scale", Vector2(1.0, 1.0), 0.8)
```

---

## State management

The existing autoloads already expose what the UI needs — wire to them, do not duplicate state:

- `EventBus` (autoload) — connect HUD signals here:
  - `candy_hp_changed(hp: int)`
  - `ant_in_transit_changed(n: int)`
  - `ant_saved`
  - `ant_lost`
  - `time_changed(seconds_left: int)`
  - `release_rate_changed(rate: int)`
  - `stage_complete(success: bool, score: float)`

- `ScoreSystem` (autoload) — read for the dialog: `score = saved / original_hp` already computed
- `StageData` resource — `data/stages/stageNN.tres` carries `time_limit`, `release_rate`, `skill_inventory: Dictionary`, `original_hp`
- `Skill` registry — `scripts/skills/*.gd` already implements all 8 skills; the toolbar's job is just dispatch via `SkillRegistry.activate(id, position)`

---

## Files in this bundle

```
design_handoff_candyants_ui/
├── README.md                       ← this file (canonical handoff)
├── SYSTEM_README.md                ← original design-system README (deeper context)
├── SKILL.md                        ← Claude-skill front-matter (optional: ignore for impl)
├── colors_and_type.css             ← single source of truth for tokens
├── assets/
│   ├── logo/{wordmark,icon,mascot}.svg
│   ├── icons/skills/*.svg          (8 files, 64-unit grid)
│   ├── sprites/*.svg               (12 files: 11 ant states + candy + home)
│   └── illustrations/stage_bg.svg
├── ui_kits/game/                   ← interactive HTML prototype
│   ├── index.html                  ← OPEN THIS in a browser to see the design live
│   ├── Atoms.jsx                   (Button / Chip / Counter / SkillSlot)
│   ├── HUD.jsx
│   ├── SkillToolbar.jsx
│   ├── StageScene.jsx
│   ├── StageDialog.jsx
│   └── README.md
└── preview/                        ← visual specimen cards (one HTML per token group)
    ├── colors_brand.html, colors_scales.html, colors_cream_ink.html, colors_hud_counters.html
    ├── type_display.html, type_body.html, type_scale.html
    ├── spacing.html, radii.html, shadows.html, motion.html
    ├── buttons.html, skill_toolbar.html, icons_skills.html, dialog.html
    ├── logo.html, sprites.html
```

## Recommended implementation order

> **OBSOLETE** — replaced by `phases/mvp/phase08~12-*.md`. The phases below are the original (pre-absorption) plan; follow the phase files for the actual sequence.

1. ~~**Download fonts**~~ → phase 8 산출 (`assets/fonts/`)
2. ~~**Copy SVG assets 1:1**~~ → phase 8 normalize_svg.py 경유 정규화 후 `assets/`로
3. ~~**Create `theme/candyants.tres`**~~ → phase 8
4. ~~**Replace `HUD.tscn`**~~ → phase 9 (atoms 신설) + phase 10 (HUD/Toolbar 씬 교체)
5. ~~**Replace `SkillToolbar.tscn`**~~ → phase 10
6. ~~**Build `StageDialog.tscn`**~~ → phase 11
7. ~~**Replace placeholder ant/candy/home**~~ → 정규화된 SVG 사용. phase 10/11에서 sprite swap.
8. ~~**Add motion**~~ → phase 9 Motion.gd 헬퍼 + phase 10/11 호출자

Each step ships independently — there's no big-bang here.

## Caveats

- **Fonts unconfirmed.** Jua/Gaegu may not be the team's final pick. Replace at the Theme level — only one place to change.
- **Sprite art is placeholder.** Final illustrator pass needed. The 12 ant states define the *animation states required*, not the final aesthetic.
- **No copy review.** Korean strings drafted from the PRD vocabulary; native review recommended.
- **No SFX/music.** Out of scope per the PRD ("Phase 후반 폴리싱").
