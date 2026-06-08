# SPEC: 챕터 시스템 (Chapter System)

> 상태: **확정 (2026-06-08)** — D-1/D-2/레벨툴 범위 사용자 확정. 다음 단계: `/agent-skills:plan`으로 작업 분해 → phase 빌드.
> 작성: 2026-06-08. 근거 조사: SceneFlow.gd / SaveData.gd / MenuLayout.gd / StageSelect.gd / EventBus.gd / addons/candyants_level_tool.
>
> **확정 결정**: D-1 = 옵션 A(인코딩 정수 `chapter*100+stage`) · D-2 = D-2a(파일명 유지 + id만 재번호) · 레벨툴 챕터 인지화 = **follow-up**(이번 범위 제외, 수동 id 입력 유지).

---

## 1. Objective (목표)

CandyAnts 캠페인을 **평면 스테이지 나열(1..N)** 에서 **챕터 단위 2차원 구조((챕터, 스테이지))** 로 전환한다.

- 각 챕터는 스테이지 번호가 **1부터 재시작**한다 (챕터1 = 스테이지 1~10).
- 챕터의 **마지막 스테이지**(챕터1=10)를 클리어하면, 평면 stage 11로 자동 진행하지 **않고** → **챕터 선택 화면(ChapterSelect)** 으로 복귀한다(다음 챕터 진입 지점).
- **이번 범위는 챕터 경계 라우팅 + 구조뿐**. 챕터2 콘텐츠(레벨)는 만들지 않는다 — 챕터 선택 화면에 "잠김/준비 중" 항목으로만 노출.

**대상**: 플레이어(캠페인 진행자). 1인 개발 + AI 자산 운영 모델(UI_GUIDE §0.5).

**비목표 (이번 범위 아님)**:
- 챕터2~N의 실제 스테이지 레벨 저작
- 챕터별 테마/배경/BGM 차별화
- 챕터 완료 보상/연출 (스토리 컷신 등)

---

## 2. Key Design Decisions (★ 사용자 확인 필요)

이 절의 결정들이 구현 전체를 좌우한다. **D-1이 가장 foundational**하다.

### D-1. 스테이지 주소 인코딩 스킴 ★★★

사용자 결정 = "진짜 (챕터, 스테이지) 2차원 주소". 이를 코드로 구현하는 방법:

| 옵션 | 내용 | 블라스트 반경 |
|---|---|---|
| **A. 인코딩 정수 `global_id = chapter*100 + stage` (권고)** | ch1s1=101, ch1s10=110, ch2s1=201. `stage = id%100`, `chapter = id/100`. 정체성은 2D(챕터 명시·스테이지 챕터별 1부터)이되, **저장·시그널 계층은 기존 `stage_id:int` 그대로** 흘려보냄 → EventBus 시그니처/result dict/SaveData 키 형태 불변. | 중 |
| B. 복합 타입 `StageRef{chapter:int, stage:int}` (Vector2i 등) | 모든 `stage_id:int` 시그널·result·save 키·테스트를 2D로 재작성. | 대 (스펙 폭증) |

**✅ 확정: A.** 근거 — `stage_id:int`가 EventBus(`stage_cleared`/`request_play_stage`)·result dict 8키·SaveData cfg 섹션·StageData.id·`Stage%02d` 네이밍·레벨툴 SpinBox에 광범위하게 박혀 있다. 옵션 B는 이 모두를 재작성해 위험·라운드가 폭증한다. 옵션 A는 "챕터가 1급 차원이고 스테이지가 챕터별 1부터"라는 사용자 의도(진짜 2D)를 **충족하면서** 와이어 포맷을 보존한다. `StageRef`는 인코딩/디코딩 헬퍼(`StageRef.encode(ch, st)` / `.chapter_of(id)` / `.stage_of(id)`)로만 제공.

> **챕터당 스테이지 상한 = 99** (`*100` 인코딩). 현 챕터1=10스테이지에 충분. 초과 필요 시 `*1000`으로 상향(스킴만 바꾸면 됨).

### D-2. 기존 10개 스테이지의 재주소화 ★★

옵션 A 채택 시, 기존 챕터1 스테이지(현 id 1..10)는 **global_id 101..110** 으로 재번호된다. 영향:

- `data/stages/stageNN.tres`의 `id` 필드 1..10 → 101..110.
- **씬/파일명**: 두 가지 하위 옵션
  - **D-2a (권고): 파일명 유지 + id만 변경.** `Stage01.tscn`~`Stage10.tscn` 파일명은 그대로 두고 내부 `StageData.id`만 101..110으로. SceneFlow 스캔 패턴을 "파일명→id 매핑"으로 일반화(아래 D-4). **레벨툴 Stage01~03 경로락을 건드리지 않음**(CLAUDE.md 준수). 가장 적은 파일 churn.
  - D-2b: 파일을 챕터 폴더로 이동(`scenes/stages/chapter01/Stage01.tscn`). 레벨툴·UID·경로락 전부 갱신 필요 → 위험 큼.
- **SaveData 마이그레이션 v3→v4**: 기존 플레이어 세이브의 `stage_progress` 키 1..10 → 101..110 리맵 + `last_played_stage` 리맵. (D-5)

**✅ 확정: D-2a** (파일명 유지, id만 재번호).

> ⚠ **중요한 함의 — 파일명 번호 ≠ global_id 디커플링**: 현재 SceneFlow 스캔은 `Stage%02d` 파일명의 숫자 N을 곧 `STAGE_SCENES[N]`의 id로 쓴다(파일번호 = id 가정). D-2a에서 `Stage01.tscn`의 내부 `StageData.id`가 101이 되면 이 가정이 깨진다. 따라서 **id↔씬경로 매핑은 ChapterManifest(D-4)가 SoT**가 되어야 한다 — 파일명 숫자에서 id를 유추하지 말 것. (스캔은 "파일 존재 확인"용으로 격하, 캠페인 노출·진행은 매니페스트가 결정.)

### D-3. 챕터 경계 언락 규칙

- 챕터 내 진행: 스테이지 N 클리어 → N+1 언락 (기존 규칙의 챕터-로컬 버전).
- 챕터 1번 스테이지 언락: **이전 챕터의 마지막 스테이지 클리어 시** 해당 챕터 전체(또는 1스테이지) 언락.
- **이번 범위**: 챕터2는 콘텐츠가 없으므로 ChapterSelect에 "준비 중"으로만. 챕터1 클리어가 챕터2를 "준비 중→해금"으로 바꾸는 게이트만 데이터로 표현(콘텐츠 없으면 잠김 유지).

### D-4. 챕터/스테이지 매니페스트 SoT

현 `menu_layout.tres`(평면 10슬롯, `is_valid()`가 1..10 연속 강제)를 **챕터 인지 구조**로 교체:

- **신규 리소스 `ChapterManifest`**(`data/chapters.tres` 등): `chapters: Array[ChapterEntry]`, 각 `ChapterEntry = {chapter_id:int, display_name, available:bool, stages: Array[{stage_id(global), display_name, available}]}`.
- SceneFlow의 `STAGE_SCENES`(파일 존재 스캔)는 유지하되 published/last 계산을 **챕터별**로: `PUBLISHED = 매니페스트.available 챕터 ∩ available 스테이지 ∩ 씬 존재`. `LAST_STAGE_ID` → **챕터별 마지막** 개념(`chapter_last_stage(chapter)`).
- 기존 `MenuLayout`/`menu_layout.tres`는 챕터1 매니페스트로 이관하거나 ChapterManifest가 흡수.

### D-5. SaveData 스키마 v3→v4

- `_migrate_3_to_4`: 기존 `stage_progress` int 키(1..10)를 인코딩 id(101..110)로 리맵. `last_played_stage`도 리맵. 미래 챕터는 자연히 2xx, 3xx.
- 하위호환: future schema(>4)·손상 cfg는 기존 fail-safe(.bak/fresh) 정책 유지.
- `is_unlocked(global_id)`: 챕터-로컬 이전 스테이지 cleared 검사 + 챕터 경계 규칙(D-3).

### D-6. ChapterSelect 화면 + 라우팅

- 신규 `ScreenState.CHAPTER_SELECT` + `scenes/ui/ChapterSelect.tscn` + `go_to_chapter_select()`.
- 네비 흐름: MainMenu → **ChapterSelect**(챕터 그리드) → 챕터 선택 → StageSelect(그 챕터의 스테이지 그리드) → Stage.
- `load_next_stage()`: 같은 챕터 내 다음 published 있으면 진행; **챕터의 마지막이면 `go_to_chapter_select()`** (= 사용자 선택 UX). 전체 마지막 챕터의 마지막이면 동일하게 ChapterSelect 복귀.
- 마지막-스테이지 술어(`_on_stage_result`의 `is_last`): "챕터의 마지막 스테이지"로 재정의 → StageDialog Next 버튼 비활성/연출.

---

## 3. Commands (검증 명령)

- 헤드리스 단위/통합 테스트: `python scripts/run_test.py tests/<SceneName>.tscn`
- 전체 회귀(큐레이트 세트): 관련 스위트 순차 실행(아래 §6).
- Godot 바이너리: `GODOT_BIN` → PATH → 후보 자동 탐색(`scripts/run_test.py`).
- 신규 .tscn/.svg/.tres 추가 시: `godot --headless --import` 부트스트랩 후 테스트.

---

## 4. Project Structure (영향 파일)

**코어 (수정)**
- `scripts/core/SceneFlow.gd` — ScreenState 확장, 챕터 인지 스캔/published/last, `load_next_stage` 챕터 경계 분기, `go_to_chapter_select`.
- `scripts/core/SaveData.gd` — schema v4, `_migrate_3_to_4`, `is_unlocked` 챕터-로컬화.
- `scripts/core/StageData.gd` — (옵션 A면 id 의미만 변경; 필요 시 chapter 헬퍼).

**신규**
- `scripts/core/StageRef.gd` — 인코딩/디코딩 헬퍼(static).
- `scripts/core/ChapterManifest.gd` + `data/chapters.tres` — 챕터/스테이지 SoT.
- `scripts/ui/ChapterSelect.gd` + `scenes/ui/ChapterSelect.tscn` (+ atoms: ChapterCard).

**수정 (UI/데이터)**
- `scripts/ui/StageSelect.gd` / `MenuLayout.gd` / `data/menu_layout.tres` — 챕터 파라미터화(특정 챕터의 스테이지만 표시).
- `scripts/ui/MainMenu.gd` — Play/Continue 진입점이 ChapterSelect 또는 마지막 플레이 챕터로.
- `data/stages/stage*.tres` — id 재번호(D-2a).
- `addons/candyants_level_tool/level_tool_dock.gd` — 인코딩 id 인지(저작 시 챕터·스테이지 입력 → global_id). **별도 검토** (저작 도구라 이번 범위에서 최소 변경 또는 follow-up).

**문서**
- `docs/ARCHITECTURE.md` / `docs/ADR.md`(신규 ADR: 챕터 주소 모델) / `docs/DOMAIN_MAP.md`.

---

## 5. Code Style (규약 — 기존 답습)

- GDScript, Godot 4.6, 2D side-view. 좌표 +Y 아래.
- 경고=에러 정책: 타입 명시(`var x: Dictionary = ...`).
- 신규 스크립트는 `scripts/{core,ant,skills,world,ui}/` 하위.
- 단일 SoT 원칙: 챕터/스테이지 published 계산은 ChapterManifest 한 곳. 인코딩/디코딩은 StageRef 한 곳(중복 `id/100` 인라인 금지).
- fail-closed: 매니페스트 누락/무효 시 캠페인 닫음(기존 SceneFlow 정책 답습).

---

## 6. Testing Strategy (테스트 전략)

**프루빗(prove-it)** — 핵심 동작은 먼저 실패하는 테스트로 고정:
- `StageRefTest` — encode/decode 라운드트립, chapter_of/stage_of, 경계(id=100/101/110/200).
- `ChapterManifestTest` — 구조 검증, available 게이트, 챕터별 last 계산.
- `SaveDataMigrationV4Test` — v3 세이브(1..10 키) → v4(101..110) 리맵 + last_played 리맵 + 하위호환.
- `SceneFlowChapterRoutingTest` — 챕터 내 N→N+1 진행 / **챕터 마지막 클리어 → ChapterSelect 복귀**(평면 +1 금지) / next 미존재 분기.
- `ChapterSelectUnlockTest` — 챕터 잠금/해금 상태, 챕터2 "준비 중", 챕터1 클리어 게이트.
- `StageSelectChapterScopedTest` — StageSelect가 선택된 챕터의 스테이지만 표시.

**회귀(0 회귀 목표)** — 기존 스위트 갱신:
- SceneFlowStageScan / SceneFlowLastStagePredicate / MenuLayoutResource / StageSelectUnlock / GameFlow(시나리오 B = 챕터 경계) / CampaignS1~S10 Clear / MainMenuContinueGuard / StageIntroCardFallback.
- 이들은 평면 id·`LAST_STAGE_ID==N`·10슬롯을 단언 → 챕터 모델로 일괄 갱신.

**검증 게이트**: 각 phase는 `run_test.py` 실 PASS(exit 0)로 종료. headless stdout 버퍼링 주의 — exit code가 권위.

---

## 7. Boundaries (경계)

**항상 (Always)**
- 기존 챕터1(현 10스테이지)이 회귀 없이 동작. 기존 플레이어 세이브 진행도 보존(v3→v4 무손실).
- 단일 SoT(ChapterManifest / StageRef) 유지. 인코딩 규칙 인라인 중복 금지.
- 레벨툴 Stage01~03 경로락 존중(D-2a).
- phase 완료 직전 `/codex:adversarial-review` (plan stage 3-round cap / impl stage clean-until 정책).

**먼저 확인 (Ask First)**
- D-1(인코딩 vs 복합 타입), D-2(파일명 유지 vs 챕터 폴더) — **본 스펙 확정 시점에 확정**.
- 레벨툴(`level_tool_dock.gd`)을 이번 범위에서 챕터 인지로 바꿀지, follow-up으로 뺄지.
- 챕터2 "준비 중" 표기/잠금 UX 디테일(연출 수준).

**절대 안 함 (Never)**
- 챕터2~N 실제 레벨 콘텐츠 저작(이번 범위 아님).
- 기존 세이브를 마이그레이션 없이 깨뜨리는 변경.
- 옵션 B(복합 타입) 강행으로 모든 `stage_id:int` 시그널을 사용자 확인 없이 재작성.
- 이해 못 한 코드 삭제·요청 외 인접 리팩터.

---

## 8. Open Questions

**확정됨 (2026-06-08)**
1. ✅ **D-1**: 옵션 A(`chapter*100+stage` 인코딩 정수).
2. ✅ **D-2**: D-2a(파일명 유지 + id만 재번호).
3. ✅ **챕터당 스테이지 상한**: 99(`*100`). 초과 시 `*1000` 상향.
4. ✅ **레벨툴**: follow-up(이번 범위 제외).

**plan 단계에서 확정 (권고 기본값 명시)**
5. **MainMenu "Play/Continue" 진입점** — 권고: Play=ChapterSelect 진입 / Continue=마지막 플레이 스테이지가 속한 챕터의 StageSelect(또는 직접 재개). plan에서 기존 MainMenu 흐름 보고 확정.
6. **챕터1 매니페스트 이관** — 기존 `menu_layout.tres`(10슬롯)를 ChapterManifest 챕터1 항목으로 흡수할지, 병존할지. plan에서 결정.
