---
name: bootstrap
duration_estimate: 3600
---

# Phase 1: 프로젝트 셋업 + Autoload 스켈레톤

## 목표
Godot 프로젝트가 에디터에서 열리고 메인 씬이 빈 화면을 띄운다. Autoload 3종이 등록 완료 상태.

## 변경 대상
- `project.godot` (Godot 4.6, 2D, 1920x1080, stretch_mode=canvas_items / aspect=expand)
- 폴더 스켈레톤:
  - `scenes/{stages,entities,entities/hazards,ui}/`
  - `scripts/{core,ant,ant/states,skills,world,world/hazards,ui}/`
  - `data/{stages,skills}/`
  - `assets/{sprites,tiles,audio}/`
- `scripts/core/GameManager.gd` (Autoload, 빈 셸 + `_ready()` 로그)
- `scripts/core/EventBus.gd` (Autoload, signal 7개 선언만 — ARCHITECTURE §4.3)
- `scripts/core/SkillRegistry.gd` (Autoload, 빈 `SKILL_SCRIPTS: Array[Script] = []` + `validate_stage()` + `get_skill()`)
- `scenes/Main.tscn` (Node 루트, 검은 화면)
- `.gitignore` (`.godot/`, `*.tmp`, `*.import` 등 표준)

## 검증 방법
1. Godot 4.6 에디터로 프로젝트 열기 → 에러 없이 로드
2. F5(Run) → Main.tscn이 씬 선택 다이얼로그에 나타나고 실행 시 검은 화면
3. 콘솔에서 GameManager `_ready()` 로그 확인
4. `SkillRegistry.validate_stage(StageData.new())` 호출이 에러 없이 빈 배열 반환

## 표준 절차
이 phase의 plan/review/deferred는 `phases/mvp/README.md` 참조.
