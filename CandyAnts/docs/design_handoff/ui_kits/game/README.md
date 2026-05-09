# Game UI kit

In-game surfaces for CandyAnts at **1280×720** (scaled mock; production target 1920×1080).

## Files
- `index.html` — interactive recreation of Stage 1 (animated ants, working HUD, skill toolbar, win/loss dialog, pause)
- `Atoms.jsx` — `Button`, `Chip`, `Counter`, `SkillSlot`
- `HUD.jsx` — top counter cluster + time + release-rate stepper + pause button
- `SkillToolbar.jsx` — bottom-center 8-slot skill bar (numbers 1–8 are hotkeys)
- `StageScene.jsx` — animated stage backdrop with looping ants, candy, home hatch
- `StageDialog.jsx` — win/loss modal with stars

## Try it
- Press `1`–`8` to switch the selected skill. Each press tries to spend one charge.
- Press `space` or `P` to pause.
- Click "완료 데모" / "실패 데모" (bottom-right) to preview the end-of-stage dialog.

## What this is *not*
A faithful port of the existing Godot UI. The codebase ships only placeholder `Label` text and an empty `HBoxContainer` for the toolbar — there are no committed visuals to recreate. Every visual decision here is a *proposal* for the production UI, derived from the design tokens in `colors_and_type.css`.
