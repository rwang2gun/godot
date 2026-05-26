# Phase map-editor/01 — TileTypeRegistry Spec

**Status**: spec draft (구현 0, 결정만). 작성 2026-05-25.
**선행 조건**: MVP phase 20 ship 완료 (orthogonal 검증 끝남 — 충돌 0건 확인 2026-05-25 본 세션).
**다음 단계**: 본 spec 사용자 승인 → `/agent-skills:plan`로 phase frontmatter + plan 상세 작성 → harness 등록 (`phases/map-editor/metadata.json`, `status.json`, `notion-phase-ids.json` 신설).
**Spec 작성 비용**: ~200줄, 코드 변경 0.

---

## 1. Objective & Why

### 1.1 무엇을
`scripts/world/StageLayoutBuilder.gd`에 하드코딩된 "tile_type → kind" 매핑과 `scripts/ant/states/WorkerState.gd`에 하드코딩된 `destroy_tile_at(..., ["earth"])` / `["plant"]` allowed_kinds를 **단일 const Dictionary 레지스트리**로 일원화한다.

### 1.2 왜
**현재**: 새 destructible 타일(돌·얼음·꿀 등) 추가 시 4곳을 수정해야 함.
- `StageLayoutBuilder.gd:16-21` — TILE_* 상수 추가
- `StageLayoutBuilder.gd:43-45` — `tile_type == TILE_PLANT_SOLID` 분기에 새 분기 추가
- `StageLayoutBuilder.gd:79-98 _add_cell` — 시각/충돌 분기 추가
- `WorkerState.gd:392/412/475` — `destroy_tile_at`의 `allowed_kinds` Array 갱신

**도입 후**: 새 tile_type 추가 = 레지스트리 1 항목 + 시각/충돌 dispatcher 1 분기 = **2곳** (4곳→2곳).

**부수 효과**: 향후 맵 에디터가 레지스트리 순회로 팔레트 메타데이터(display name, icon, destructible_by) dump 가능 — 별도 카탈로그 SoT 불필요.

### 1.3 명시 비목적 (Non-objective)
- **시각/충돌 dispatcher 자체의 일원화 X**. `_add_solid_visual` / `_add_slope_visual` / `_add_plant_visual` 메서드 분기는 그대로 둔다. 그건 dispatch 패턴이 자연스러우며 이번 spec의 본질이 아니다 (단순성 강제).
- **에디터 UI 자체 도입 X**. 본 phase는 에디터 *사전* 데이터 모델 정리. 에디터 v0는 별도 phase.
- **L0/L2 시각 레이어 분리 X**. 별도 후속 phase.
- **objects 통합 X**. 별도 phase (map-editor 트랙 2번째 phase 예정).
- **신규 tile_type 추가 X**. 본 phase는 기존 4종(`solid`/`slope_right`/`slope_left`/`plant`) 그대로 이식. 새 타일은 spec 검증 후 후속 phase에서.

---

## 2. Scope & Non-scope

### 2.1 In-scope (구현 대상)
| 영역 | 변경 |
|---|---|
| 신규 `scripts/core/TileTypeRegistry.gd` | const Dictionary 정의 + 조회 헬퍼 (`get_kind`, `get_destructible_by`, `is_destructible_by`, `all_tile_types`) |
| `scripts/world/StageLayoutBuilder.gd:43-45` | inline kind 분기 → `TileTypeRegistry.get_kind(tile_type)` 호출로 치환 |
| `scripts/ant/states/WorkerState.gd:392/412/475` | 하드코딩 `["earth"]` / `["plant"]` → `TileTypeRegistry.get_destructible_by_skill(skill_id)` 또는 동일 의미의 helper 호출 |
| (선택) `scripts/world/Terrain.gd:46` `destroy_tile_at` | `allowed_kinds` 시그니처 유지 (호출자가 helper 산출 결과 전달). 내부 변경 0 — 호환성 유지 |
| 신규 회귀 test 1~2개 | `tests/TileTypeRegistryTest.tscn/gd` — 레지스트리 조회 + helper 정확성 검증 |

### 2.2 Out-of-scope
- 시각/충돌 dispatcher 통합
- 신규 tile_type 추가
- 에디터 UI, 팔레트 노출
- objects 통합 (home/candy/hazard)
- L0/L2 시각 레이어 분리
- StageLayoutData 스키마 변경
- Bridge/Builder의 동적 add_tile 경로 (이건 `_cell_kind = "earth"` 하드코딩으로 이미 자연 처리됨, 변경 불필요)

---

## 3. Current State (코드 인용 — 1차 SoT)

### 3.1 tile_type 정의 — `StageLayoutBuilder.gd:16-21`
```gdscript
const TILE_SOLID := "solid"
const TILE_SLOPE_RIGHT := "slope_right"
const TILE_SLOPE_LEFT := "slope_left"
const TILE_PLANT_SOLID := "plant"
```

### 3.2 kind 매핑 — `StageLayoutBuilder.gd:43-45`
```gdscript
var kind: String = "plant" if tile_type == TILE_PLANT_SOLID else "earth"
generated.append({"cell": c, "body": body, "kind": kind})
```

### 3.3 시각/충돌 dispatcher — `StageLayoutBuilder.gd:79-98` (변경 X)
```gdscript
func _add_cell(cell: Vector2i, tile_type: String = TILE_SOLID) -> StaticBody2D:
    ...
    if tile_type == TILE_SLOPE_RIGHT or tile_type == TILE_SLOPE_LEFT:
        _add_slope_collision(...); _add_slope_visual(...)
    elif tile_type == TILE_PLANT_SOLID:
        _add_solid_collision(...); _add_plant_visual(...)
    else:
        _add_solid_collision(...); _add_solid_visual(...)
```

### 3.4 destroy 게이트 — `WorkerState.gd:392/412/475`
```gdscript
# Basher (line 392)
var ok: bool = terrain.destroy_tile_at(target, ["earth"])
# Digger (line 412)
var ok: bool = terrain.destroy_tile_at(target, ["earth"])
# Cutter (line 475)
var ok: bool = terrain.destroy_tile_at(target, ["plant"])
```

### 3.5 게이트 검사 — `Terrain.gd:46-65` (변경 X)
```gdscript
func destroy_tile_at(cell: Vector2i, allowed_kinds: Array[String] = ["earth"]) -> bool:
    var kind: String = get_cell_kind(cell)
    if kind == "" or not allowed_kinds.has(kind):
        return false
    ...
```

---

## 4. Form 결정 — Form A 추천

### 4.1 결정: **Form A (Script const Dictionary)**
```gdscript
class_name TileTypeRegistry
extends RefCounted

# 1차 SoT — 새 tile_type 추가 시 본 dict + StageLayoutBuilder._add_cell dispatch 1분기만 수정.
# Phase map-editor/01 — display_name / palette_icon은 에디터 v0(map-editor/03) 진입 시 추가.
# 본 phase는 kind + destructible_by 매핑만 일원화 (스코프 규율).
const TILE_TYPES := {
    "solid":       {"kind": "earth", "destructible_by": ["bash", "dig"]},
    "slope_right": {"kind": "earth", "destructible_by": ["bash", "dig"]},
    "slope_left":  {"kind": "earth", "destructible_by": ["bash", "dig"]},
    "plant":       {"kind": "plant", "destructible_by": ["cut"]},
}

static func get_kind(tile_type: String) -> String:
    # Q2 결정 (엄격) — 미등록 tile_type 호출 시 push_warning 발화 + 빈 문자열 반환.
    # silent corruption 차단, 디버그 용이성 확보. 호출자(StageLayoutBuilder)는 빈 문자열 받으면
    # tile 생성 자체를 skip하거나 fall-back 처리할 책임.
    if not TILE_TYPES.has(tile_type):
        push_warning("[TileTypeRegistry] unknown tile_type: %s" % tile_type)
        return ""
    return TILE_TYPES[tile_type]["kind"]

static func get_destructible_by(tile_type: String) -> Array:
    # Q2 결정 — 동일 정책. 미등록 시 push_warning + 빈 Array.
    if not TILE_TYPES.has(tile_type):
        push_warning("[TileTypeRegistry] unknown tile_type: %s" % tile_type)
        return []
    return TILE_TYPES[tile_type]["destructible_by"]

# Skill → kind 역인덱스. WorkerState가 호출 — Basher → ["earth"], Cutter → ["plant"].
# 단순 순회 (4 tile_type * 3 skill 정도면 O(n*m) 무관).
static func kinds_destructible_by(skill_id: String) -> Array[String]:
    var kinds: Array[String] = []
    for tile_type in TILE_TYPES.keys():
        var info: Dictionary = TILE_TYPES[tile_type]
        if skill_id in info["destructible_by"] and not info["kind"] in kinds:
            kinds.append(info["kind"])
    return kinds
```

### 4.2 Form B (.tres Resource 카탈로그) 채택 안 한 이유
- 현재 4종 tile_type에 4+ `.tres` 파일 + `TileTypeDef.gd` 신규 class = **보일러플레이트**
- `.tres` 발견 비용 (어디 두나, load 순서, 검증 누락 시 silent fail)
- Godot Resource 직렬화의 미묘한 함정 (export 필드 추가/제거 시 마이그레이션)
- 인스펙터 편집 가치는 에디터 v0 phase에서 진짜 필요할 때 도입 가능 — 그때까진 const dict가 더 단순

### 4.3 Form C (하이브리드) 채택 안 한 이유
- "한 곳에 모으자"는 본래 목적이 약화됨
- SoT가 dict + builder method 둘로 갈라짐
- 단순성 측면에서 Form A가 우세

### 4.4 마이그레이션 경로 (미래)
에디터 v0 phase에서 인스펙터 편집 요구가 진짜 발생하면 const dict → `.tres` 카탈로그로 마이그레이션 가능. 호출자(StageLayoutBuilder, WorkerState)는 `TileTypeRegistry.get_kind()` 같은 헬퍼만 보므로 시그니처 호환 유지하면 회귀 0건.

---

## 5. Acceptance Criteria

### 5.1 필수 (P0 — 본 phase 완료 조건)
1. **기존 stage 회귀 0건**: stage01~03 + 모든 `dev_*_test.tscn` 헤드리스 PASS.
2. **기존 헤드리스 회귀 0건**: phase 1~20에서 생성된 모든 `tests/*Test.tscn` PASS.
3. **`StageLayoutBuilder.gd:43-45`의 inline kind 분기 제거**: `TileTypeRegistry.get_kind(tile_type)` 호출로 치환. 결과 의미론 동일 (plant → "plant", 그 외 → "earth").
4. **`WorkerState.gd:392/412/475`의 하드코딩 `["earth"]`/`["plant"]` 제거**: `TileTypeRegistry.kinds_destructible_by(SKILL_BASH|SKILL_DIG|SKILL_CUT)` 호출로 치환. 결과 의미론 동일.
5. **`TileTypeRegistry.gd` 단위 test (`tests/TileTypeRegistryTest.tscn/gd`)**: 4가지 tile_type 각각의 `get_kind` / `get_destructible_by` 결과 검증 + `kinds_destructible_by(&"bash")` == `["earth"]`, `kinds_destructible_by(&"cut")` == `["plant"]` 검증.
6. **미등록 tile_type 엄격 처리** (Q2 결정): `TileTypeRegistry.get_kind("nonexistent")` == `""` 반환 + `push_warning` 발화. test 케이스 1건 (warning 메시지 패턴 검증은 어렵지만 반환값 + StageLayoutBuilder가 fall-back 처리하는지 검증).
7. **skill_id const 정착** (Q1 결정): `WorkerState`에 `const SKILL_BASH := &"bash"`, `SKILL_DIG := &"dig"`, `SKILL_CUT := &"cut"` 정의. WorkerState 내부의 모든 skill_id 비교를 const 참조로 치환. TileTypeRegistry의 `destructible_by` 필드도 StringName 배열(`[&"bash", &"dig"]`)로 정착.
8. **Terrain.add_tile:95 일원화** (Q3 결정): 현 하드코딩 `_cell_kind[cell] = "earth"`를 `_cell_kind[cell] = TileTypeRegistry.get_kind("solid")`로 치환. 동적 add_tile 경로도 레지스트리 SoT 경유 — Bridge/Builder가 만든 cell의 kind도 한 곳에서 결정.

### 5.2 권장 (P1 — clean 권장, defer 허용)
- TileTypeRegistry에 `display_name` / `palette_icon` 필드 추가 — 에디터 v0 phase 진입 시점에 추가 (본 phase 스코프 외).
- ~~WorkerState의 skill_id 문자열을 const 정착~~ — Q1 결정으로 §5.1 P0 #7로 승격.

### 5.3 명시 비기준 (Non-criteria)
- 시각/충돌 dispatcher 통합 — 본 phase 스코프 외, 회귀 위험만 늘림.
- 새 tile_type 추가 — 본 phase 스코프 외.
- ~~Bridge/Builder 동적 add_tile 경로의 kind 결정~~ — Q3 결정으로 §5.1 P0 #8로 승격.

---

## 6. Boundaries (CLAUDE.md 정합)

### 6.1 항상 할 것
- `TileTypeRegistry`는 `scripts/core/` 하위 (CLAUDE.md "신규 스크립트는 `scripts/{core,ant,skills,world,ui}/` 하위" 정책).
- 모든 회귀 test 사전 PASS 확인 후 commit (CLAUDE.md "검증, 추측 금지").
- Phase frontmatter doc (`phases/map-editor/phase01-tile-type-registry.md`) + plan (`phases/map-editor/plans/phase01-...-plan.md`)을 plan 단계에서 정식 작성.
- harness 트랙 초기화: `phases/map-editor/metadata.json`, `status.json`, `notion-phase-ids.json` (Notion 페이지 신규 생성) — plan 진입 직전.

### 6.2 먼저 물어볼 것 (모두 closed — 2026-05-25 사용자 결정 반영)
- ~~TileTypeRegistry를 `class_name`으로 등록할 것인가, autoload할 것인가?~~ → **`class_name TileTypeRegistry extends RefCounted` + static 호출** 확정 (memory `class_name autoload 회피` 패턴 정합).
- ~~skill_id 문자열을 String으로 유지할 것인가, StringName으로 정착할 것인가?~~ → **Q1 결정: 본 phase에서 StringName const 정착** (§5.1 P0 #7).
- ~~미등록 tile_type 호출 시 push_warning 발화할지 말지?~~ → **Q2 결정: push_warning 발화 (엄격)** (§5.1 P0 #6, §4.1 코드 반영).

### 6.3 절대 하지 말 것
- 시각/충돌 dispatcher 같이 통합 (스코프 폭발 + 회귀 위험 폭증).
- 신규 tile_type 추가 (본 phase는 기존 4종 그대로 이식).
- `Terrain.destroy_tile_at` 시그니처 변경 (호환성 유지 — 호출자만 변경).
- `_static_occupancy` / `_cell_kind` / `_static_bodies` registry 구조 변경 (Phase 18 ADR-010 freeze).
- Bridge/Builder의 add_tile 경로에서 새 분기 추가 (P1 권장 외 변경 금지).

---

## 7. Risks & Open Questions

### 7.1 알려진 위험
| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R-1 | `kinds_destructible_by` 순회가 매 destroy_tile_at 호출마다 발생 → 성능 | 낮음 (4 tile_type × 3 skill ≈ 12 비교/호출) | spec 단계에선 무시. 진짜 문제되면 plan 단계에서 캐시 도입. |
| R-2 | 미등록 tile_type 묵시 fall-back으로 silent corruption 가능 | 낮음 (완화됨) | **Q2 결정 — push_warning 발화로 silent corruption 차단.** acceptance #6에 명시. |
| R-3 | skill_id 문자열 typo (`"bash"` vs `"basher"`) silent fall | 낮음 (완화됨) | **Q1 결정 — StringName const 정착으로 typo 컴파일 타임 차단.** acceptance #7에 명시. |
| R-4 | TileTypeRegistry를 `class_name`으로 등록 시 `_static_init` 자기등록 패턴 사용 → CLAUDE.md "`_static_init` 자기등록 사용 금지" 위반 | 높음 | const dict는 `_static_init` 불필요. 정적 const는 컴파일 타임 결정. 위반 없음 확인. |

### 7.2 Open questions — 모두 closed (2026-05-25 사용자 결정)
- ~~Q1: skill_id 명시 const 정착 여부~~ → **본 phase에서 StringName const 정착** (§5.1 P0 #7)
- ~~Q2: 미등록 tile_type push_warning 정책~~ → **push_warning 발화 (엄격)** (§4.1 + §5.1 P0 #6)
- ~~Q3: TileTypeRegistry 호출 패턴~~ → **`class_name` + static 호출** (memory `class_name autoload 회피` 정합)
- ~~Q4: `Terrain.add_tile` 라인 95 일원화 여부~~ → **본 phase 포함** (§5.1 P0 #8)
- Q5 (트랙 셋업 타이밍): **Plan 단계 진입 직전 일괄** (§9, Phase 20 ship 후) — 사용자 결정.

---

## 8. 1차 SoT 참조 (plan 단계 docs 읽기 가이드)

- `CLAUDE.md` (project) — 신규 스크립트 위치 정책, 단순성/스코프 규율, validate/sync-status 워크플로우
- `docs/ARCHITECTURE.md` — Terrain/StageLayoutBuilder 구조, ADR-010 (StaticBody2D registry)
- `docs/ADR.md` — kind 분류 정책 (phase 18/19 결정)
- `phases/mvp/phase18-mechanic-destruction-earth.md` — `_cell_kind` registry 도입 phase
- `phases/mvp/phase19-mechanic-destruction-plant.md` — `kind="plant"` 추가 phase

---

## 9. Phase 트랙 초기화 (Q4 결정: Plan 단계 진입 직전 일괄)

본 spec은 `phases/map-editor/` 트랙의 첫 산출물. **Phase 20 ship 완료 → 본 spec 승인 → plan 진입 직전에 다음 6단계 일괄 셋업** (현재는 spec.md 1개만 존재):

1. `phases/map-editor/README.md` 작성 (트랙 가이드 — `phases/mvp/README.md` 패턴 답습)
2. `phases/map-editor/metadata.json` 신설 — `active_revision`, `phase_count`, `track_owner` 등
3. `phases/map-editor/status.json` 신설 — phase01 = `not_started`
4. `phases/map-editor/notion-phase-ids.json` 신설 — Notion DB에 map-editor 트랙용 페이지 생성 후 매핑 박제
5. `phases/map-editor/phase01-tile-type-registry.md` — phase frontmatter doc 작성 (본 spec을 SoT로 인용)
6. `phases/map-editor/plans/phase01-tile-type-registry-plan.md` — plan 상세 작성 (codex adversarial-review 사이클 진입)

**현재 작업 0** — Phase 20 ship 이후에 일괄 진행.

---

## 10. Spec 승인 체크리스트 — 2026-05-25 사용자 결정 반영

| 항목 | 상태 |
|---|---|
| Form A (const Dictionary) 채택 | ✅ 동의 |
| §2 In-scope / Out-of-scope 범위 | ✅ 동의 |
| §5 Acceptance criteria — **P0 8건** (Q1/Q3 결정으로 #7/#8 추가) | ✅ 동의 |
| Q1 skill_id StringName const 정착 | ✅ 본 phase 포함 (§5.1 #7) |
| Q2 미등록 tile_type push_warning | ✅ 엄격 발화 (§5.1 #6, §4.1) |
| Q3 Terrain.add_tile:95 일원화 | ✅ 본 phase 포함 (§5.1 #8) |
| Q4 트랙 초기화 타이밍 | ✅ Plan 단계 진입 직전 일괄 (§9) |
| §9 트랙 초기화 6단계 진행 | ✅ Phase 20 ship 후 진행 |

**Spec 상태**: ✅ **승인 완료**. 다음 액션: **Phase 20 ship 대기 → ship 후 §9 트랙 초기화 + `/agent-skills:plan` 진입**.
