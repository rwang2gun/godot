---
name: ui-title-menu
duration_estimate: 5400
verify: ""
---

# Phase 12: 타이틀 / 메인 메뉴 / 스테이지 셀렉트 + SaveData

## 목표
게임 진입 흐름 완성: 타이틀 → 메인 메뉴 → 스테이지 셀렉트 → 스테이지 → StageDialog → (셀렉트로 복귀 또는 다음 스테이지). MVP 1회독 가능 + 진행도 저장.

## 전제
- Phase 8~11 완료 (Theme + atoms + Motion + HUD/Toolbar + StageDialog + SceneFlow)
- `docs/UI_GUIDE.md` §3.5·§3.6 (LogoPanel/StageSlotCard atom) + §5 (SaveData 스키마) + §6 (카피 가이드) 1차 SoT
- handoff에 **타이틀/메뉴 직접 명세 없음** — Atoms + 토큰 재사용 + 신규 atom 2종으로 일관성 유지
- 본 phase 시점 stage는 stage01~03만. 셀렉트 슬롯 10개 중 4~10은 placeholder(잠금) — stage4~10 phase에서 자연 해금

## 변경 대상

### 신규 atoms (UI_GUIDE §3.5·§3.6 명세 → 본 phase에서 작성)
- `scripts/ui/atoms/LogoPanel.gd` + `scenes/ui/atoms/LogoPanel.tscn` — wordmark + mascot 합성, idle bob
- `scripts/ui/atoms/StageSlotCard.gd` + `scenes/ui/atoms/StageSlotCard.tscn` — 200×140, 잠금/별점/스코어 표시

### 신규 씬 / 스크립트
- `scenes/ui/TitleScene.tscn` — 로고 + "Press Any Key/Button" + 배경 일러스트 + 모션
- `scripts/ui/TitleScene.gd` — 임의 입력 시 MainMenu로 전환
- `scenes/ui/MainMenu.tscn` — Play / Continue / StageSelect / Settings(stub) / Credits(stub) / Quit
- `scripts/ui/MainMenu.gd` — 6 버튼 → SceneFlow.transition_to
- `scenes/ui/StageSelect.tscn` — 10 슬롯 그리드(2×5) + 점수/별 표시 + 잠금 상태
- `scripts/ui/StageSelect.gd` — SaveData 읽어서 슬롯별 상태 set
- `scripts/core/SaveData.gd` (Autoload) — UI_GUIDE §5 스키마 그대로 박음
- `data/menu_layout.tres` — 10 슬롯 메타데이터 (stage_id → StageData path, 잠금 조건)
- `assets/icons/ui/{lock,unlock,arrow_left,arrow_right,settings,play,close}.svg` — 정적 SVG (Lucide CDN 대신 오프라인 보장)

### 수정
- `scripts/core/SceneFlow.gd` (phase 11 산출) — Title → Menu → Select → Stage → Dialog → Select 라우팅 케이스 추가
- `scripts/core/GameManager.gd` — SaveData Autoload 사용, 클리어 시 `SaveData.record_clear(stage_id, saved, original_hp)` 호출
- `project.godot` — main scene을 `Main.tscn` → `TitleScene.tscn`으로 변경 (또는 Main.tscn이 TitleScene을 처음 인스턴스화). Autoload에 `SaveData` 추가.

### 비-변경
- `tests/Stage*HeadlessTest.tscn` — stage 직접 로드 경로 유지 (테스트는 메뉴 우회)
- `scripts/skills/*` — 무관

## SaveData 스키마 (UI_GUIDE §5)

```gdscript
# scripts/core/SaveData.gd (Autoload)
extends Node

const SAVE_PATH := "user://save.cfg"
const CURRENT_SCHEMA := 1

var schema_version: int = CURRENT_SCHEMA
var last_played_stage: int = 1
var stage_progress: Dictionary = {}   # int → {cleared, best_saved, best_score, stars, attempts}
var created_at: String = ""
var last_saved_at: String = ""

func load_or_init() -> void: ...
func save() -> void: ...
func record_clear(stage_id: int, saved: int, original_hp: int) -> void:
    # 별점은 Scoring.compute_stars 호출 (단일 SoT). 자체 계산 금지.
    var stars := Scoring.compute_stars(saved, original_hp)
    var score := 0.0 if original_hp <= 0 else float(saved) / float(original_hp)
    var entry := stage_progress.get(stage_id, {"cleared": false, "best_saved": 0, "best_score": 0.0, "stars": 0, "attempts": 0})
    entry["cleared"] = true
    entry["best_saved"] = max(entry.get("best_saved", 0), saved)
    entry["best_score"] = max(entry.get("best_score", 0.0), score)
    entry["stars"]      = max(entry.get("stars", 0), stars)
    entry["attempts"]   = entry.get("attempts", 0) + 1
    stage_progress[stage_id] = entry
    last_played_stage = stage_id
    save()

func record_attempt(stage_id: int) -> void: ...
func is_unlocked(stage_id: int) -> bool: ...   # stage_id 1은 항상 unlocked, 2+는 (stage_id-1).cleared
func _migrate(cfg: ConfigFile, from_v: int, to_v: int) -> void: ...
```

**Migration hook 의무화** — UI_GUIDE §5.2:
```gdscript
func _migrate(cfg: ConfigFile, from_v: int, to_v: int) -> void:
    for v in range(from_v, to_v):
        match v:
            0: _migrate_0_to_1(cfg)
            # 1: _migrate_1_to_2(cfg)   # stage4~10 추가 시
    cfg.set_value("meta", "schema_version", to_v)
    cfg.save(SAVE_PATH)
```

stage4~10 phase에서 schema bump 필요 시 본 함수에 case 1줄 추가하면 끝. 본 phase는 v0 → v1 케이스만.

## 검증 방법

### 자동 (헤드리스)
1. `python scripts/run_test.py tests/Stage02HeadlessTest.tscn` PASS — stage 직접 로드 경로 유지
2. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS
3. 신규 `tests/SaveDataMigrationTest.gd` — v0(`schema_version` 없음) cfg → load → migrate → v1 schema 검증
4. 신규 `tests/SaveDataCorruptedTest.gd` — 일부 stage 키 손상 → 해당 stage만 reset, 나머지 유지 검증
5. 신규 `tests/StageSelectUnlockTest.gd` — stage1만 cleared 시 stage2 unlock, stage3 lock 검증

### 수동
1. 새 사용자 플로우: 타이틀 → 메인 메뉴 → "Play" → StageSelect → stage01 → 클리어 → 다이얼로그 → "다음 단계" → stage02 (잠금 해제됨) → 클리어 → 셀렉트 복귀
2. Continue 흐름: 마지막 플레이 stage로 직행
3. `user://save.cfg` 삭제 후 재진입 → 모두 잠금 + stage01만 가능
4. 파일 손상 (수동으로 cfg에 garbage 1줄 추가) → 무한 로딩이나 crash 없음, warn 후 fresh init
5. 패드만으로 모든 메뉴 네비게이션: 포커스 이동 + A 확정 + B 뒤로 + LB/RB 메뉴 사이클(있을 시)
6. 키보드만으로 모든 메뉴: Tab/Shift+Tab 포커스 + Enter 확정 + Esc 뒤로

## 엣지 케이스 (필수)

- **save.cfg 손상/누락** — assert 대신 warn + reset. Crash 0건. SaveDataCorruptedTest로 보장.
- **stage 클리어 도중 Quit** — 진행도 미저장 (스테이지 단위 저장 정책). `record_clear`만 저장 트리거. 진행 중 Quit은 `last_played_stage` 갱신만.
- **패드 포커스 잃음** — 메뉴 활성 시 첫 버튼에 자동 `grab_focus()`. SceneTree 진입 후 `await get_tree().process_frame` 기다린 다음 grab.
- **미해금 슬롯 클릭** — 무반응 + `EventBus.sfx_request(&"sfx:locked")` (phase 11 hook 재사용)
- **타이틀 input mode 전환** — Phase 7 InputModeTracker 재사용 → 힌트 텍스트 즉시 갱신 ("Press Any Key" ↔ "Press Any Button")
- **StageSelect 슬롯 hover/focus 동시 발생** — 마우스 hover와 패드 focus가 다른 슬롯이면 둘 다 시각 표시 OK (focus는 mint outline, hover는 y-2). 충돌 X.
- **TitleScene 자동 진입 막기** — 첫 입력만 받음. 실수로 mouse_motion 발화 시 무시. `_input` 에서 `event is InputEventKey or InputEventMouseButton or InputEventJoypadButton`만 트리거.
- **SaveData 저장 시점** — `record_clear` / `record_attempt` 호출 직후 즉시 `save()`. `_notification(NOTIFICATION_WM_CLOSE_REQUEST)`에서도 save (Quit 시 최종 저장).
- **Continue 버튼 disabled** — `last_played_stage`가 0이거나 stage_progress 비어있으면 Continue disabled.
- **별점 산출 위치 단일 SoT** — `scripts/core/Scoring.gd` (Phase 11이 owner) 의 `Scoring.compute_stars(saved, original_hp)`만 호출. SaveData.record_clear가 자체 임계값/계산식 박는 것 금지. Phase 11 StageDialog와 동일 함수 호출 → 분산 0.

## StageSelect 레이아웃

```
StageSelect.tscn (Control, fullscreen)
├─ Background (TextureRect stage_bg.svg)
├─ Header (HBoxContainer top)
│  ├─ CButton[GHOST] BackBtn ("← 메뉴")
│  └─ Label "스테이지 선택" (Jua 32, ink_900)
├─ SlotGrid (GridContainer columns=5, 2×5 = 10 슬롯)
│  └─ StageSlotCard × 10 (stage_id 1~10)
└─ Footer (HBoxContainer)
   └─ Total stars label "수확한 별 ★ 5 / 30"
```

## 산출물 요약

```
scenes/ui/{TitleScene,MainMenu,StageSelect}.tscn
scripts/ui/{TitleScene,MainMenu,StageSelect}.gd
scripts/ui/atoms/{LogoPanel,StageSlotCard}.gd + .tscn
scripts/core/SaveData.gd                    ← Autoload
scripts/core/SceneFlow.gd                   ← Title/Menu 케이스 추가
scripts/core/GameManager.gd                 ← SaveData 연동
data/menu_layout.tres
assets/icons/ui/*.svg                       ← 7 SVG 신규
project.godot                                ← main_scene + Autoload SaveData
tests/SaveDataMigrationTest.gd
tests/SaveDataCorruptedTest.gd
tests/StageSelectUnlockTest.gd
```

## Stage4~10 phase가 사용할 인터페이스 (계약)
- `SaveData.record_clear(stage_id, saved, original_hp)` — 클리어 기록
- `SaveData.is_unlocked(stage_id)` — 잠금 검사
- 새 stage 추가 시 `data/menu_layout.tres`에 슬롯 메타 추가 + (스키마 bump 필요 시) `_migrate` case 추가

## 비-범위 (post-MVP 표기)
- Settings 화면 실제 동작 (키 리매핑, 음량 등) — stub만 (placeholder + "준비 중")
- Credits 화면 — stub만
- 별점 stage별 override — stage4~10 phase에서 필요 시 v0.2로 도입 (UI_GUIDE §5.3 비고)
- BGM/SFX 실제 재생 — post-MVP phase 20

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md`. 명세 SoT는 `docs/UI_GUIDE.md` §5.
