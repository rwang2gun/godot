---
name: candyants-design
description: Use this skill to generate well-branded interfaces and assets for CandyAnts (캔디앤츠), a casual 2D side-view candy/ant puzzle game for all-ages Korean audiences. Either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files. The system has:

- `colors_and_type.css` — every design token (colors, type, spacing, radii, shadow, motion, semantic aliases) as CSS custom properties. Import once.
- `assets/` — logo, skill icons (Climber/Floater/Bomber/Blocker/Builder/Basher/Miner/Digger), sprite placeholders (ant, ant_carrying, candy, home), stage background.
- `preview/` — visual specimen cards (one HTML per token group).
- `ui_kits/game/` — JSX components (`Atoms`, `HUD`, `SkillToolbar`, `StageScene`, `StageDialog`) + an `index.html` that runs a Stage 1 mock with working keyboard/skill interactions.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code (the Godot project), read the rules in README.md to become an expert in designing with this brand — colors map 1:1 to a Godot Theme resource.

If the user invokes this skill without any other guidance, ask them what they want to build or design (a stage, a menu, a dialog, a marketing page?), ask some questions, and act as an expert designer who outputs HTML artifacts *or* production code, depending on the need.

Hard rules to keep CandyAnts feeling like CandyAnts:

- **Cream paper, never white**, **chocolate ink, never black** — `--bg` and `--ink` are the two non-negotiables.
- **Sticker shadow** (`4px 4px 0 var(--ink)`) on every interactive element. No soft drop-shadows.
- **Boop easing** (`cubic-bezier(.5, 1.5, .5, 1)`) on every state change. Things squish, never fade.
- **Korean copy first**, English second. Sentence-natural Hangul, no honorifics on UI.
- **No emoji**. Use the skill icon SVGs in `assets/icons/skills/` for game actions, Lucide CDN for generic glyphs.
- **44pt+ touch targets** — design target is the ROG Ally X handheld.
- **Eight skills, fixed order**: Climber → Floater → Bomber → Blocker → Builder → Basher → Miner → Digger.
- **HUD counter colors are stable**: candy HP = peach, in-transit = grape, saved = mint, lost = berry, time = lemon-700. Never recolor these.
