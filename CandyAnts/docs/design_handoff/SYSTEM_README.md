# CandyAnts (캔디앤츠) — Design System

> A casual 2D side‑view puzzle game where autonomous ants ferry candy back home.
> Lemmings‑inspired, candy‑themed, **전체 이용가** (all‑ages, Korean‑first audience).

---

## What is CandyAnts?

CandyAnts is a Godot 4.6, 2D side‑view puzzle game that reframes the **Lemmings** "autonomous crowd + indirect control" loop as a **round‑trip candy carry**. Each level, brainless ants spawn at a *Home* hatch, walk forward until they hit the *Candy*, take a 1 HP bite, rotate 180° and carry the chunk back. The player never controls an ant directly — they paint the world with **8 skills** (Climber / Floater / Bomber / Blocker / Builder / Basher / Miner / Digger) to clear a path through the terrain. A stage is **cleared** when the candy is fully eaten *and* every carrier has made it home; the **score** is `saved / original_hp` (how much of the candy actually survived the trip).

Ants that die mid‑carry permanently lose their candy chunk — that loss pressure, plus the carrier's 0.78× speed penalty, is the central tension.

The target platform is **ROG Ally X** (handheld; gamepad + touch + optional KB+M), so every UI surface is designed for **1920×1080**, **gamepad‑first**, with **44pt+** touch targets and a virtual cursor.

---

## Sources

This design system was built against the following resources (read‑only references):

- **Codebase** — `CandyAnts/` (mounted locally; Godot 4.6 / GDScript)
  - `CandyAnts/docs/PRD.md` — product requirements (Korean)
  - `CandyAnts/docs/ARCHITECTURE.md` — vertical‑slice architecture, EventBus, ScoreSystem 4‑counter
  - `CandyAnts/docs/ADR.md` — 9 architectural decisions (2D side‑view, sweet HP economy, registry pattern)
  - `CandyAnts/docs/INPUT_MAPPING.md` — full Pad / Touch / KB+M input matrix for Ally X
  - `CandyAnts/scenes/ui/HUD.tscn`, `SkillToolbar.tscn` — current placeholder UI scenes
  - `CandyAnts/scripts/ui/HUD.gd`, `SkillToolbar.gd` — current UI logic
  - `CandyAnts/data/stages/stage01.tres` — stage data shape
- **Repo** — `github.com/rwang2gun/godot` (`CandyAnts/` and `BattlePrototype/`)

> **Important:** The codebase's `assets/sprites/`, `assets/tiles/`, `assets/audio/` folders are empty (`.gitkeep` only). There is **no existing art**, no logo, no icon set, no font choice committed yet. This system therefore *establishes* the visual identity rather than recreating one. Visual choices below are derived from the game's stated tone (PRD language, "전체 이용가", Lemmings genealogy) and flagged where they are designer judgement vs. extracted from source.

---

## Index

```
.
├── README.md                  ← this file
├── SKILL.md                   ← Agent‑Skill front‑matter for Claude Code
├── colors_and_type.css        ← all design tokens (CSS custom properties)
├── fonts/                     ← webfonts (Korean + display)
├── assets/                    ← logos, icons, sprite placeholders
│   ├── logo/
│   ├── icons/                 ← SVG skill icons + UI glyphs
│   ├── sprites/               ← ant + candy sprite placeholders
│   └── illustrations/         ← background scenes
├── preview/                   ← Design‑System‑tab cards (one HTML per token group)
├── ui_kits/
│   └── game/                  ← in‑game UI kit (HUD, toolbar, dialogs, level select)
└── slides/                    ← (omitted — no slide template was attached)
```

See **`preview/`** for visual specimen cards (rendered as cards in the Design System tab).
See **`ui_kits/game/index.html`** for an interactive recreation of a stage screen.

---

## Content fundamentals

### Voice
The game speaks in **Korean (ko‑KR) first**, English second. Source copy is in Korean throughout the PRD and ADR. Translations should keep the same upbeat, playful register.

- **POV** — second person ("당신") is **avoided**; the game speaks *about* the ants ("개미들이 사탕을 옮깁니다") rather than commanding the player. Skill buttons are labeled with the skill noun, not an imperative verb.
- **Tone** — warm, encouraging, never punishing. Failure copy frames a retry, not a loss. Numbers are soft ("사탕 한 조각", "10마리") rather than clinical.
- **Casing (Latin)** — Title Case for level names and screen titles; lowercase for body copy. ALL CAPS is reserved for the brand mark only.
- **Casing (Hangul)** — sentence‑natural, no honorific endings on UI ("재시작" not "재시작합니다"). Stage names are short and image‑forward ("첫 외출", "달콤한 길").
- **Numerals** — Arabic numerals everywhere ("10마리", "120초"), never spelled out.
- **Punctuation** — em‑dash for definitions, parenthesis for translations, ellipsis (…) for in‑progress states ("운반 중…").
- **Emoji** — **not used** in UI. The visual language carries the warmth; emoji would compete with custom iconography.

### Example copy

| Surface | Korean | English mirror |
|---|---|---|
| Stage title | 첫 외출 | First Outing |
| HUD — counters | 사탕 HP · 운반 중 · 귀가 · 잃음 | Candy HP · In transit · Saved · Lost |
| Win dialog | 사탕을 무사히 옮겼어요! | The candy made it home! |
| Loss dialog | 사탕이 부족했어요. 다시 해볼까요? | Not enough candy. Try again? |
| Skill — empty | 남은 횟수 0 | 0 left |
| Pause | 잠시 멈춤 | Paused |
| Release rate | 출구 속도 | Release rate |
| Nuke (give up) | 모두 보내기 | Send them all |

---

## Visual foundations

### Palette philosophy
The world is **candy‑warm**: cream paper, peach‑pink primary, mint accents, chocolate dark text. No muddy greys, no grim reds — *all‑ages* means safe, sweet, legible at a glance from across a couch. Colors are intentionally kept slightly desaturated (closer to `oklch(0.85 0.10 …)` than full vivids) so long play sessions don't fatigue the eye.

### Type
- **Display / UI** — **Jua** (Google Fonts) — a friendly rounded Korean display face, free to bundle, supports full Hangul + Latin. Conveys "child‑safe casual game" without going into Comic Sans territory.
- **Body / numbers** — **Gaegu** (Google Fonts) — handwritten, soft. Used for counters and small narration.
- **Mono / debug** — **JetBrains Mono** — only inside dev overlays.

> **Substitution flag** — no font file was attached in the codebase. Jua and Gaegu are placeholders chosen as nearest‑match for the genre. **Please confirm or replace** with the team's preferred Korean display face (e.g. Cafe24 Ohsquare, Pretendard Variable, BMHanna).

### Backgrounds
- **Cream paper** (`--bg`) is the default everywhere — never pure white, never grey.
- In‑game stage background is a **soft pastel sky → grass gradient** with a low‑contrast repeating dot pattern (candy sprinkles texture) at ~6% opacity. Never photographic, never gradient‑heavy.
- Dialog backdrops dim to `oklch(0.30 0.04 30 / 0.55)` (warm brown veil), not black.

### Borders & shadows
- **Chunky stroke** — 3px chocolate‑brown outline (`--ink`) on every interactive piece, like a sticker. This is the system's signature.
- **Drop shadow** — single offset, no blur (`4px 4px 0 var(--ink)`). Looks printed, not real.
- **Inner highlight** — `inset 0 4px 0 oklch(1 0 0 / 0.5)` on filled buttons gives a soft "candy gloss".
- Drop shadows on cards in‑world (level cards, dialogs) are slightly softer: `0 8px 0 var(--ink-soft)`.

### Corner radii
- **2xl (24px)** — dialogs, level cards, the candy itself
- **xl (16px)** — buttons, skill slots
- **lg (12px)** — small chips, counters
- **pill** — toggles, tag chips
- Never sharp — even debug overlays use 4px.

### Layout
- HUD pinned **top‑left** (counters) and **top‑right** (time + release rate). Clear of the skill toolbar at bottom.
- Skill toolbar pinned **bottom‑center**, 8 slots, slot size 96×96 (44pt+ touch friendly), gap 12px.
- Dialogs centered, max‑width 640px, never full‑bleed.
- Safe area respects 32px from every screen edge (handheld bezel safety).

### Animation
- **Easing** — `cubic-bezier(.5, 1.5, .5, 1)` (overshoot / squish) is the house easing. Buttons "boop" when pressed. Counters "pop" when they tick.
- **Durations** — 120ms for press, 220ms for state changes, 600ms for celebration bursts.
- **No fades** for primary feedback — things scale and squish. Fades are reserved for screen transitions only.
- **Bounce on idle** — the home hatch pulses 1.0 → 1.03 every 1.6s. Saved counter does a y:0 → −4 → 0 hop on tick.

### Hover / press states
- **Hover** — translate(0, −2px) and slightly increased inner highlight (no color change). Pointer‑capable devices only.
- **Press** — translate(0, +2px), shadow collapses to `2px 2px 0`, inner highlight darkens 8%. The button visibly *squishes into the page*.
- **Disabled** — desaturate to 60% and lower text alpha to 60%; outline stays full‑strength so buttons remain legible.
- **Focus (gamepad)** — a 3px outline halo offset by 4px in `--mint`. Required because the controller has no cursor.

### Transparency & blur
- Used sparingly. The pause overlay uses `backdrop-filter: blur(6px)` over the warm‑brown veil. Tooltips use solid fills, not glass — readability over fanciness.

### Imagery vibe
- All illustrations are **flat vector with chunky outlines**, warm‑lit. No photo, no grain, no gradients beyond the sky background. Cute > realistic.

### Cards
A "card" in this system = cream fill + 3px ink stroke + 4px hard ink shadow + 16–24px radius. No subtle gradients, no soft drop‑shadows, no internal divider lines.

---

## Iconography

**Approach:** custom hand‑drawn SVG icons for the **8 skills** (since each skill is a brand artifact — Climber, Floater, Bomber, Blocker, Builder, Basher, Miner, Digger), and **Lucide** (CDN) for generic UI glyphs (close, pause, settings, arrows). All skill icons live in `assets/icons/skills/` as inline SVG; UI glyphs are pulled from the [Lucide CDN](https://unpkg.com/lucide-static@latest) so they update centrally.

- **Stroke weight** — 2.5px on the 24px grid for UI glyphs; skill icons use a 3px ink stroke to match the rest of the UI signature.
- **Style** — outlined + flat fill. Skill icons get a single accent color from the palette (so the *shape* is what's recognized — color is decoration).
- **Emoji** — never used.
- **Unicode** — never used as icons.

> **Substitution flag** — no icon set ships in the codebase. The 8 skill icons in this system are placeholders drawn for this design system; **please review/replace** with final art when available.

---

## Working with this system

- Every token lives in `colors_and_type.css` as a CSS custom property. Import once at the top of any page.
- For a new screen, lift a component from `ui_kits/game/` rather than rebuilding. They're plain React/JSX (Babel‑in‑browser) — no build step, no React Router, just dropable JSX.
- For a Godot port, the same tokens map 1:1 to a Godot **Theme** resource (TODO: `theme/candyants.tres`).

---

## Caveats / open questions

1. **No real font files attached** — Jua + Gaegu chosen as nearest‑match. Confirm or replace.
2. **No real logo or sprite art** — all visuals here are placeholders generated for this system.
3. **No slides attached** — `slides/` omitted as instructed.
4. **No Korean copywriter pass** — copy examples above were drafted from PRD vocabulary and need a native review for tone consistency.
5. **Sound design out of scope** — PRD defers BGM/SFX to "Phase 후반 폴리싱"; this system covers visuals + motion only.
