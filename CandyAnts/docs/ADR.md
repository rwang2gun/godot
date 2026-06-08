# ADR

### ADR-001: 2D side-view 렌더링
- **결정**: Godot 2D (Node2D / TileMap / CharacterBody2D / Area2D / Camera2D) 기반 사이드뷰
- **이유**: 레밍즈 메카닉의 핵심(픽셀 정밀 지형 파괴, 사이드뷰 중력)이 2D에서 압도적으로 단순. MVP 도달 속도 우선.
- **트레이드오프**: 의인화 개미의 시각적 매력 ↓, BattlePrototype과 코드 자산 공유 불가

### ADR-002: 사탕 = HP 자원 + 4-카운터 ScoreSystem
- **결정**: 사탕에 정수 HP 부여. ScoreSystem이 `original_hp / saved / in_transit / lost` 4개를 추적
- **이유**: 운반 중 사망으로 인한 영구 손실을 first-class로 표현. 클리어/실패 술어를 모호하지 않게 정의.
- **트레이드오프**: 단순 % 카운팅 대비 구현 복잡도 ↑, UI에 Lost 카운터 노출 필요

### ADR-003: 명시적 SkillRegistry preload (자기등록 폐기)
- **결정**: `SKILL_SCRIPTS` 배열에 모든 스킬을 명시적 preload + `validate_stage()`로 검증
- **이유**: Godot의 `_static_init`은 스크립트 로드 시점에만 실행 → 자기등록 신뢰 불가. 미등록 스킬 ID가 조용히 실패하는 것 차단.
- **트레이드오프**: 새 스킬 추가 시 코어 1줄 수정 필요 ("0줄 수정" 약속 포기)

### ADR-004: Home = 진입구 (동일 노드)
- **결정**: 진입구와 도착지를 같은 위치/노드로 통합
- **이유**: 레벨 디자인 단순화, 왕복 게임 메카닉의 자연스러운 표현
- **트레이드오프**: 비대칭 출입 레벨(진입구 ≠ 도착지) 패턴 포기

### ADR-005: 단순 180° 귀환 (페로몬 미사용)
- **결정**: 사탕 픽업 시 단순 방향 반전, 왔던 길로 귀환
- **이유**: MVP 단순성. AI 복잡도 최소화. 레밍즈 원작의 "예측 가능한 행동" 철학 계승.
- **트레이드오프**: "개미답지 않음" — 실제 개미의 페로몬 추적 행동 미구현

### ADR-006: Carrying 0.78배 속도, 스킬 적용 가능
- **결정**: 운반 중 개미는 Walker 속도의 75-80% (기본 0.78). 운반 중에도 스킬 부여 가능.
- **이유**: 명확히 느리지만 답답하지 않음. 속도 페널티 + 사망 위험 결합으로 후반부 긴장감. 스킬 가능성은 귀환로 확보 유연성.
- **트레이드오프**: 운반자가 길에서 적체 가능 (Release Rate 압박 부각)

### ADR-007: 셀 단위 지형 파괴 (BitMap 보류)
- **결정**: MVP는 cell 단위 파괴. 16~32 px cell grid 위에서 cell-keyed registry로 정적/동적 floor 동시 관리 (실제 구현은 ADR-010 참조). 파괴 가능/불가 구분은 cell kind 필드(`"earth"` 등)로 분리.
- **이유**: 빠른 구현. Godot 표준 도구 활용. 픽셀 정밀도가 후속 단계에서 필요해질 때 BitMap으로 교체 가능 (Skill 인터페이스 유지).
- **트레이드오프**: 지형 파괴의 픽셀 정밀도 ↓, 아트 표현력 제한
- **이력**: 초안에서 TileMap 레이어 분리 방식 명시. phase 16 이후 StageLayoutData `tile_map` Dictionary + Terrain `_placed`/`_static_*` Dictionary 기반으로 자연 진화 → phase 18에서 destruction이 들어오며 StaticBody2D registry 방식으로 정식화 (ADR-010 참조).

### ADR-008: 빌드 누적형 개발 (Stage 1부터 플레이 가능)
- **결정**: 각 빌드는 이전 빌드를 깨지 않은 상태에서 새 시스템만 추가. Stage 1은 스킬 0개로 풀 수 있는 튜토리얼.
- **이유**: 매 빌드마다 검증 가능. 회귀 = 코어 침범 신호. Phase 누적 = AI에게 일관된 진행 가능.
- **트레이드오프**: 인터페이스를 미리 잡아둬야 함 (SkillRegistry 등 빈 셸 우선 구현)

### ADR-009: docs/ 3-문서 구조 (PRD / ARCHITECTURE / ADR)
- **결정**: 마크다운 3개 파일로 프로젝트 전체를 AI에게 전달. 상세 자료는 `docs/references/`에 별도 보관.
- **이유**: AI 컨텍스트 효율성. 핵심을 짧게, 변동 적게. 코드가 진짜 SoT.
- **트레이드오프**: 상세 정보가 docs/와 references/로 이중화될 수 있음 (관리 부담)

### ADR-010: Terrain destruction = StaticBody2D cell-keyed registry (Phase 18)
- **결정**: phase 18 destruction 도입 시점에 ADR-007의 cell-grid 정신을 유지하면서 실제 구현은 `Terrain._static_bodies`(Vector2i → StaticBody2D, 정적 stage cell) + `Terrain._placed`(Vector2i → StaticBody2D, 동적 cell) + `Terrain._cell_kind`(Vector2i → String "earth"/"plant"/"") 3 registry로 정식화. `register_static_body(cell, body, kind)` / `get_cell_kind(cell)` / `destroy_tile_at(cell, allowed_kinds)` API 신설.
- **이유**: phase 16 이후 StageLayoutData가 TileMap 노드 없이 Dictionary `tile_map`을 사용하고 StageLayoutBuilder가 StaticBody2D 노드를 직접 생성하는 방식으로 자연 진화함. phase 18에서 동적 파괴를 도입할 때 cell-keyed body registry가 atomic destroy(dynamic + static 둘 다 queue_free + registry 4종 erase) 와 cell kind 분리(cross-mechanic 침범 차단)에 가장 단순한 자료구조였음. TileMap layer 분리로 회귀 시 phase 16~17 dev stage 전부 마이그레이션 필요.
- **트레이드오프**: ADR-007이 시사한 TileMap 레이어 분리 abstraction 포기. cell 종류 분류는 string 기반 kind 필드(타입 안전성 ↓)로 처리. plant kind는 phase 19 진입 시 추가.
- **관련**: ADR-007 (cell grid 결정), ADR-003 (SkillRegistry 명시적 preload — 신규 skill BasherSkill/DiggerSkill 추가 시 1줄 등록).

### ADR-011: 절차적 SFX 합성 (외부 오디오 에셋 0) (Phase 21) — ⚠️ ADR-012로 SUPERSEDED
> Phase 22에서 절차 합성을 Kenney CC0 파일 로드로 교체 (ADR-012). 본 ADR이 설계한 **인터페이스(emit 계약·clean id·repo-도출 테스트·풀/버스)는 그대로 유지**되고, `SFX_SPECS`의 값만 톤 스펙 → 파일 경로로 바뀜 — ADR-011의 "교체 가능 인터페이스" 약속이 실현된 사례.
- **결정**: `EventBus.sfx_request(id)` receiver(`SfxPlayer` autoload)는 외부 오디오 파일을 import하지 않고, 시작 시 각 id의 `AudioStreamWAV`를 **코드로 절차 합성**(sine/square/noise + per-segment ADSR)하여 캐시·재생한다. `SFX_SPECS` Dictionary(clean id → 톤 스펙)가 SoT. 재생은 `AudioStreamPlayer` 풀 8개 round-robin, `SFX` 오디오 버스(미존재 시 Master 폴백).
- **이유**: Phase 12/20에서 emit hook(14 unique id × 22 call site)만 깔리고 `assets/audio/`가 비어 있었음. 절차 합성은 (1) 에셋 파이프라인/라이선스 0 의존으로 즉시 가청 피드백 확보, (2) 헤드리스/dummy 오디오 드라이버에서 결정적 검증 가능, (3) 추후 실제 녹음 교체 시 `SFX_SPECS`만 stream load로 바꾸면 되는 인터페이스 유지.
- **계약**: id는 clean(콜론/prefix 없음)만 허용 — `SfxPlayer`는 **런타임 정규화를 하지 않는다**. emit 측이 clean id를 보내는 책임(과거 `sfx:locked` → `locked`로 통일). 테스트(`SfxReceiverTest`)는 `scripts/` 스캔으로 emit id를 repo-도출하여 SFX_SPECS 직접 커버리지 + 글로벌 prefix 가드로 회귀 차단.
- **트레이드오프**: 사운드 음색이 합성 톤 수준(실제 녹음 대비 표현력 ↓). BGM/믹싱/볼륨 설정 UI는 본 ADR 범위 밖(후속 phase). 미매핑 id는 `push_warning` 후 무음 skip(조용한 실패 — 단 repo-도출 테스트가 미매핑을 빌드 타임에 잡음).
- **관련**: ADR-009 (docs 3-문서 — 코드가 SoT), Phase 20 polish (sfx hook emit 도입), ADR-012 (후속 교체).

### ADR-012: SFX 절차합성 → Kenney CC0 에셋 교체 (Phase 22)
- **결정**: ADR-011의 절차 합성을 폐기하고, `SfxPlayer`가 **Kenney CC0 실제 효과음 파일**(`assets/audio/sfx/<id>.ogg`)을 `load()`로 로드해 재생한다. `SFX_SPECS`는 clean id → 톤 스펙 Dictionary에서 **clean id → 리소스 경로** Dictionary로 바뀐다. `_build_stream`/절차 합성 코드는 제거. emit 14곳·`EventBus.sfx_request` 계약·14 id·풀(8)/`SFX` 버스(Master 폴백)·미매핑 graceful skip·`SfxReceiverTest` 구조는 **불변** (검사 (c)만 "합성 무결성" → "리소스 로드 무결성"으로 의미 교체).
- **이유**: 절차 합성 톤이 "옛날 게임" 인상(레트로 삑삑이). Kenney 4팩(UI Audio / Interface / Impact / Music Jingles, 전부 CC0, 표기 의무 없음)으로 14종을 실제 녹음 수준으로 교체. ADR-011이 의도한 "교체 가능 인터페이스" 실현 — 게임 로직 0줄 수정.
- **에셋 관리**: 원본 367 파일은 `assets/audio/kenney_*/`에 로컬 보관하되 `.gitignore`로 리포 제외. 게임이 쓰는 **14개만** `assets/audio/sfx/`로 선별 복사해 `.ogg`를 커밋(`.import`는 프로젝트 관례대로 `*.import` gitignore — 추적 `.import` 0개). fresh clone은 커밋된 `.ogg`만으로 `run_test.py --import`가 `.import`+`.godot/imported`를 재생성해 자족 동작(원본 팩 불요, 실측 검증). 출처·id 매핑은 `assets/audio/sfx/CREDITS.txt`.
- **트레이드오프**: 일부 id는 정확한 음원 부재로 근사치(`water_splash` ← Interface `drop`, `sticky_glue` ← Impact `impactSoft_heavy`). 어느 jingle이 승리/실패에 맞는지는 헤드리스로 청취 불가 → 게임 플레이로 확인 후 `SFX_SPECS` 한 줄 수정으로 조정. BGM은 여전히 범위 밖(후속 phase, OpenGameArt CC0 루프).
- **관련**: ADR-011 (supersede 대상), Phase 21 (receiver 신설), `phases/mvp/phase22-sfx-assets.md`.
