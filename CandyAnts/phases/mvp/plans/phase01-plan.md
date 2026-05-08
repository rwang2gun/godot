# Phase 1 Plan: 프로젝트 셋업 + Autoload 스켈레톤

## 목표 (1줄)
Godot 4.6 프로젝트가 에디터에서 에러 없이 열리고, F5 실행 시 빈 Main 씬이 뜨며, Autoload 3종(GameManager/EventBus/SkillRegistry)이 등록·초기화된다.

## 변경/추가 파일 목록

### 루트
- `project.godot` (신규) — Godot 4.6 config_version=5, application/run/main_scene=`res://scenes/Main.tscn`, viewport 1920x1080, stretch_mode=canvas_items, aspect=expand, autoload 3종 등록
- `.gitignore` (신규) — Godot 표준 패턴
- `icon.svg` 또는 `icon.png` (선택, 기본 아이콘 — Godot이 자동 생성하므로 생략 가능)

### 폴더 스켈레톤 (`.gitkeep` 1개씩)
```
scenes/{stages,entities,entities/hazards,ui}/
scripts/{core,ant,ant/states,skills,world,world/hazards,ui}/
data/{stages,skills}/
assets/{sprites,tiles,audio}/
tests/                                # TDD Guard 대비 빈 폴더 (Phase 2부터 활용)
```

### 코드 (Autoload 빈 셸)
- `scripts/core/GameManager.gd` — `extends Node`, `_ready()`에서 print 로그
- `scripts/core/EventBus.gd` — `extends Node`, ARCHITECTURE §4.3의 signal 7종 선언만
- `scripts/core/SkillRegistry.gd` — `extends Node`, `SKILL_SCRIPTS: Array[Script] = []`, `_skills: Dictionary = {}`, `_ready()`에서 빈 배열 반복(=no-op), `get_skill(id)`, `validate_stage(stage)` 메서드

### 씬
- `scenes/Main.tscn` — 루트 `Node` 1개. 자식 노드 0개. (검은 화면)

### 부수 (커밋 금지 — ephemeral)
- `scripts/hooks/.tdd_bypass` — **이 phase 작업 중에만 working tree에 존재**. 커밋 직전(=`execute.py complete 1` 호출 직전) **반드시 제거**. 안전망으로 `.gitignore`에 `scripts/hooks/.tdd_bypass` 패턴을 추가해 실수 stage 차단.

## 씬 트리 구조

### `scenes/Main.tscn`
```
Main : Node          (루트, attached script 없음)
```
의도: 검은 viewport만 뜨면 OK. 후속 phase에서 stage scene 라우팅용 셸로 확장.

### Autoload (project.godot에서 등록)
```
[autoload]
GameManager="*res://scripts/core/GameManager.gd"
EventBus="*res://scripts/core/EventBus.gd"
SkillRegistry="*res://scripts/core/SkillRegistry.gd"
```
`*` prefix = 싱글톤(Node) 자동 인스턴스. 이름 = 글로벌 식별자.

## 시그널 흐름

이 phase는 발화/수신 없음. **선언만** 한다.

```gdscript
# EventBus.gd
signal candy_depleted
signal candy_piece_picked(remaining_hp: int)
signal candy_piece_lost(by_ant: Node)
signal ant_died(ant: Node, was_carrying: bool)
signal ant_saved(ant: Node, with_candy: bool)
signal stage_cleared(score: float)
signal stage_failed(reason: String)
signal release_rate_changed(new_rate: int)
```

> ARCHITECTURE §4.3은 8개로 보이나 사실 7+1: `release_rate_changed`까지 포함해 8개 모두 선언. 타입 힌트의 `Ant`는 Phase 2에서 정의되므로 **이 phase에서는 `Node`로 둔다**. Phase 2에서 `class_name Ant` 등록 후 시그널 시그니처를 `Ant`로 좁힌다(deferred 항목).

## SkillRegistry 빈 셸 — 정확한 시그니처

```gdscript
extends Node

const SKILL_SCRIPTS: Array[Script] = []

var _skills: Dictionary = {}

func _ready() -> void:
	for script: Script in SKILL_SCRIPTS:
		var id: String = script.ID
		assert(id != "_base_", "Skill must override ID")
		assert(not _skills.has(id), "Duplicate skill ID: %s" % id)
		_skills[id] = script

func get_skill(id: String) -> Script:
	return _skills.get(id)

func validate_stage(stage: Resource) -> Array[String]:
	var errors: Array[String] = []
	if stage == null:
		return errors
	if "available_skills" in stage:
		for id: String in stage.available_skills:
			if not _skills.has(id):
				errors.append("Unknown skill in available_skills: %s" % id)
	if "skill_inventory" in stage:
		for id: String in stage.skill_inventory.keys():
			if not _skills.has(id):
				errors.append("Unknown skill in skill_inventory: %s" % id)
	return errors
```

핵심 결정:
- `validate_stage` 매개변수는 `Resource` (StageData는 Phase 2에 정의되므로 forward dep 회피)
- `null` 또는 미정 프로퍼티에 안전 (`if "x" in stage`)
- `_ready()` 루프는 빈 배열이라 no-op이지만 코드 형태는 최종형 유지 — Phase 3부터 자연 동작

## 엣지 케이스 (필수)

1. **Autoload 누락 = 무성한 NPE**: 셋 중 하나라도 project.godot에서 빠지면 후속 phase에서 `EventBus.candy_depleted` 같은 호출이 "Identifier not declared"로 실패. → 이 phase의 검증 4번 항목으로 모든 autoload 인스턴스 존재 확인.
2. **forward type dependency**: 이 phase에서 `signal ant_saved(ant: Ant, ...)` 같이 `Ant` 타입을 쓰면 Phase 2 전까지 parser error. → **타입은 `Node`로 임시 선언**, Phase 2에서 좁히는 것을 deferred에 기록.
3. **`.godot/` 캐시 폴더**: Godot은 첫 import 시 `.godot/`를 자동 생성. `.gitignore`에 빠뜨리면 수백 파일이 첫 커밋에 들어감. → `.gitignore`에 `.godot/`, `*.tmp`, `*.translation`, `export_presets.cfg`, `.import/` 명시.
4. **Windows 경로 + Godot res://**: `res://` 절대경로 사용. Autoload 등록 시 백슬래시 금지. project.godot은 LF 줄바꿈이 안전 (Godot이 CRLF도 받지만 일관성 유지).
5. **TDD Guard 차단 + bypass 영구 잔존 위험** (Codex MEDIUM 대응): `scripts/core/*.gd` 신규 작성 시 `tests/` 미존재로 BLOCK. 우회는 `scripts/hooks/.tdd_bypass` 토큰 파일로 처리하되, **이 phase 외 잔존을 다음 3중 가드로 차단**:
   - **a. `.gitignore`**: `scripts/hooks/.tdd_bypass` 패턴 추가 → 실수로도 staging 불가
   - **b. exit criterion**: `execute.py complete 1` 호출 직전 `rm scripts/hooks/.tdd_bypass` 강제. 파일 존재 시 complete 거부 (검증 시나리오 6번)
   - **c. deferred 금지**: 이 항목은 Phase 1 내부에서 100% 종결. 절대 deferred로 미루지 않음
6. **Main.tscn 빈 화면 검정 보장**: 루트 `Node`(2D 자식 없음)는 viewport 클리어 색만 보임 → 기본 `display/window/clear_color` (회색)일 수 있음. PRD가 "검은 화면"을 요구. → project.godot에 `rendering/environment/defaults/default_clear_color=Color(0,0,0,1)` 명시.

## 검증 시나리오 (Godot 에디터)

1. **에디터 로드**: Godot 4.6으로 `project.godot` 열기. Output 패널에 "ERROR" 0개. Project Settings → Autoload 탭에 GameManager/EventBus/SkillRegistry 3개 표시.
2. **F5 실행**: 메인 씬 미설정 다이얼로그가 뜨지 **않아야** 함 (project.godot의 main_scene이 정의됨). 검은 화면 + 창 제목 "CandyAnts".
3. **콘솔 로그**: 실행 시 `[GameManager] ready` 같은 한 줄 출력 (`_ready()` 로그).
4. **Autoload sanity**: Godot 에디터 Script editor에서 `print(EventBus.candy_depleted)` 같은 expression 실행은 어렵지만, 다음을 GameManager `_ready()`에 넣어 검증:
   ```gdscript
   func _ready() -> void:
       print("[GameManager] ready")
       print("[GameManager] EventBus=", EventBus, " SkillRegistry=", SkillRegistry)
       var errors: Array[String] = SkillRegistry.validate_stage(null)
       assert(errors.is_empty(), "validate_stage(null) must return []")
       print("[GameManager] SkillRegistry.validate_stage(null) OK")
   ```
   → 콘솔에 3줄 출력되면 셋업 완료.
5. **에디터 종료 → 재오픈**: `.godot/` 캐시가 생기고도 `.gitignore`로 git status에 잡히지 않는지 확인.
6. **Exit gate — `.tdd_bypass` 제거 검증** (Codex MEDIUM 대응):
   ```bash
   rm -f scripts/hooks/.tdd_bypass
   test ! -e scripts/hooks/.tdd_bypass && echo "BYPASS_REMOVED" || (echo "FAIL: bypass still present"; exit 1)
   git status --porcelain scripts/hooks/.tdd_bypass    # 빈 출력이어야 함 (.gitignore로 untracked 표기도 안 됨)
   ```
   이 단계가 통과하지 않으면 `python scripts/execute.py mvp complete 1` 호출 금지.

## 비포함 (다음 Phase)
- StageData Resource 정의 → Phase 2
- Ant/Candy/Home/Terrain → Phase 2
- HUD → Phase 2
- 스킬 인스턴스 등록 → Phase 3 (Builder)
- 시그널 타입 힌트 좁히기(Node→Ant) → Phase 2 후 deferred

## 리스크
- Godot 4.6 설치 버전 확인 — `project.godot`의 `config/features=PackedStringArray("4.6", "GL Compatibility")` 명시. 4.5 이하에서 열면 마이그레이션 다이얼로그가 뜨면서 파일이 변형될 수 있음.
- 사용자가 4.6 설치 미확인 시 검증 1번에서 발견 → 그 시점에 사용자에게 보고 후 중단.
