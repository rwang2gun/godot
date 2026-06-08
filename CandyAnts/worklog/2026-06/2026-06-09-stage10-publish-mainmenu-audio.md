# 2026-06-09

## 한 일
- **Stage10 "보물찾기" 정식 발행** — `menu_layout.tres` slot10 `available=true`, GameFlowTest Scenario B를 Stage10(마지막 스테이지) 엔드포인트로 갱신. Stage10 씬/tres/layout 최초 커밋.
- **Stage10 버그 3종 수정** (플레이 중 발견):
  1. **땅파기(digger) 1칸만 파고 멈춤** — 개미(18px)가 48px 셀 경계에 걸쳐 digger 적용 시, 한 칸 판 뒤 인접 컬럼 타일이 받쳐 낙하 못 함 → 다음 tick에 비운 아래칸 재검사 abort. `WorkerState._enter_digger`가 진입 시 개미를 자기 컬럼 정중앙으로 스냅하도록 수정.
  2. **표지판(digger/cutter) 배치 가이드 미표시** — Stage10 씬에 `AffordanceGlowController` 노드 누락(SIGN surface 글로우 담당). 열린 Godot 에디터가 .tscn 외부편집을 계속 revert해 발견이 늦어짐 → 에디터 종료 후 씬에 노드 명시 배선 + `StageRunner._ensure_guide_controllers` 런타임 안전망 추가(누락 시 자동 생성, 향후 스테이지 재발 방지).
  3. **스테이지 이름 미표시("스테이지 10" 폴백)** — `Strings.gd` 시트에 `stage.s10.name` 누락. "보물찾기!" 추가.
- **메인 메뉴 폴리싱** — 로고(Wordmark) 1.5배(540×270→810×405), 로고 아래 정적 마스코트 제거, victory 애니메이션 캐릭터를 버튼 위 좌·우 대칭 배치(중앙 x 기준 ±572, y=670), MidGap 조정으로 버튼을 레터박스에서 띄움.
- **오디오 튜닝** — footstep/footstep_sticky 볼륨 -16/-14 → -7/-7, BGM을 TITLE 진입 시 정지(타이틀 영상 자체 사운드와 충돌 방지, SceneFlow가 `bgm_stop` emit), 신규 SFX 리소스 11종 재임포트, `tools/audio_editor.html` 저작 툴 추적(.gitignore 예외).
- **codex 적대적 리뷰** — Stage10 버그수정 diff 대상, **verdict=approve, finding 0건**.

## 결정 / 변경
- **가이드 컨트롤러를 런타임 안전망으로 보강** — .tscn 명시 배선만으로는 새 스테이지 저작 시 누락 위험(Stage10이 실증). StageRunner가 없을 때만 생성하므로 기존 1~9 스테이지와 중복 없음. 에디터 revert 이슈와도 무관하게 동작.
- **digger 수정은 코어(WorkerState) 변경** — 그래서 커밋 전 codex 적대적 리뷰 실행(approve).
- **메인 메뉴는 중앙정렬(CenterContainer) 유지** — 버튼만 단독으로 올리려면 상단 앵커 재구조화 필요. 현재는 MidGap 조정으로 절충(콘텐츠가 상·하 레터박스 양쪽에서 멀어짐).

## 산출물
- 신규: `scenes/stages/Stage10.tscn`, `data/stages/stage10.tres`, `data/stage_layouts/stage10_layout.tres`, `SPEC.md`, `tools/audio_editor.html`
- 신규 테스트: `tests/DiggerColumnBoundaryTest`, `tests/StageGuideControllerPresenceTest`
- 수정: `scripts/ant/states/WorkerState.gd`, `scripts/core/StageRunner.gd`, `scripts/core/Strings.gd`, `scripts/ui/MainMenu.{tscn,gd}`, `scenes/ui/MainMenu.tscn`, `data/menu_layout.tres`, `scripts/core/{BgmPlayer,EventBus,SceneFlow,SfxPlayer}.gd`, `assets/audio/sfx/*.ogg`, `project.godot`, `.gitignore`
- 테스트 갱신: `SceneFlowStageScanTest`, `StringsTableTest`, `MenuLayoutResourceTest`, `StageSelectUnlockTest`, `GameFlowTest`, `BgmSceneFlowTest`, `StageIntroCardFallbackTest`

## 검증
- 배치 PASS: DiggerColumnBoundary / StageGuideControllerPresence(10 stages) / SceneFlowStageScan / StringsTable / MenuLayoutResource / StageSelectUnlock / BgmSceneFlow / GameFlow(A·B·C)
- digger 회귀: DiggerVerticalTunnel / CampaignS6Clear / CampaignS9Clear PASS

## 다음 진입점
- 다음 큰 작업은 **챕터 시스템**(`SPEC.md` — (챕터,스테이지) 2D 주소, ChapterManifest, SaveData v4, ChapterSelect 화면). 진입 시 `/agent-skills:plan`.
- 메인 메뉴: 로고 고정 + 버튼만 상단 앵커로 올리는 재구조화는 보류(사용자 요청 시).

## 미해결
- 메인 메뉴 좌측 victory 캐릭터 `flip_h=true`(미러) — 어색하면 정면으로 변경 검토.
