# Skill Icons

Source: `docs/design_handoff/assets/icons/skills/` (designer-authored placeholders).
Origin: 2026-05-09 phase 8 plan revision 시 manual normalize 산출 (디자이너/사용자 처리).

본 phase(9)는 본 디렉토리 normalize 책임 없음 — `scripts/tools/normalize_svg.py`가 동일 매핑(`scripts/tools/svg_color_map.json`)으로 재현 가능하지만, byte-identical 보장 없으므로 phase 8 산출물 그대로 유지. `tests/SvgImportSmokeTest.gd` 검사 범위에는 포함 (8장 sanity 검증).

향후 갱신 시 (디자이너 후속):
1. `docs/design_handoff/assets/icons/skills/<name>.svg` 갱신.
2. (옵션) `python scripts/tools/normalize_svg.py`로 재현 가능하게 만들고 싶다면 normalize_svg.py 입력 file list에 추가 — 현재 본 스크립트는 5장(logo×3 + sprites/home + illustrations/stage_bg)만 처리 (Option A).
3. `python scripts/run_test.py tests/SvgImportSmokeTest.tscn` PASS 확인.

License: 프로젝트 내부 placeholder. 디자이너 최종 픽 후 동일 파일명으로 교체.

8 files: basher, blocker, bomber, builder, climber, digger, floater, miner (각 `.svg`).
