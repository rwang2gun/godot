# Playtest Handoff — 2026-05-16 (Phase 9 완료 직후)

> 다음 세션에서 실제 플레이 테스트하며 보완할 항목 정리.
> 위치: `phases/mvp/PLAYTEST_HANDOFF_2026-05-16.md`
> 작성 시점: Phase 9 (ui-theme-assets) 완료 + 사후 entity 시각 미세조정 진행 중.

---

## 1. 이번 세션 작업 요약

### 1.1 Phase 9 (ui-theme-assets) 완료 — commit `1b9bc69`

11 라운드 (plan 6 + impl 5 self+5 codex) 끝에 통과한 본 phase의 핵심 산출:

- **`theme/candyants.tres`** — Godot 4.6 Theme 리소스. Button(4 state) / Panel / LineEdit / CheckButton + Jua-Regular 20px ink_900 default.
- **`scripts/ui/Tokens.gd`** — 24 Color 상수(cream/ink/peach/mint/berry/lemon/grape/sky/grass) + CounterKind enum + COUNTER_COLOR 매핑. phase 10 atoms 진입 전 freeze.
- **`scripts/ui/Motion.gd`** — 5 함수 시그니처 freeze (`caPop`/`boop`/`idle_bob`/`fade_in`/`fade_out`).
- **`scripts/tools/normalize_svg.py`** — Option A 5장 정규화 (logo×3 + sprites/home + illustrations/stage_bg). `--scan`/`--scan-handoff-all`/`--check`/`--self-test` 게이트.
- **`scripts/tools/check_font_license.py`** — Jua/Gaegu/OFL 키워드 게이트.
- **`assets/fonts/{Jua-Regular,Gaegu-Bold}.ttf + LICENSE.txt`** — OFL 1.1 (Google Fonts).
- **정규화 SVG 5장 + skill icons 8장 검증 + project.godot gui/theme/custom 등록**.
- **2 신규 테스트**: `tests/SvgImportSmokeTest.gd` (13 SVG sanity), `tests/MotionPauseSafeTest.gd` (pause_safe).

### 1.2 SoT 문서 갱신 (Phase 9 누적)

- **`docs/UI_GUIDE.md`** §0.5(운영 모델 신설 — 1인 개발 + AI 자산), §1.3 phase 번호, §2.4 SpinBox composition note, §2.5 v2 4종 import key (Godot 4.6 실제), §2.6 resolve_order 6항 분기 (0/1/1'/2/3/4), §8 v2 시각 회귀, phase 번호 8군데 갱신.
- **`scripts/tools/svg_color_map.json`** — `_about.owner` phase 9, `_about.resolve_order` 6항 split, `_about.tokens_ref` alpha-conditional. `alpha_variants` dead entry `ink_700/0.35` 제거.
- **`scripts/execute.py`** — WHITELIST_PATTERNS에 `theme/**` 추가.

### 1.3 Phase 9 후 사후 entity 시각 미세조정 (미커밋)

플레이 테스트 직전 단계로 entity sprite 크기/배치 보완 진행 중:

1. **Ant 스케일 2x** — `scale 0.08 → 0.16`, sprite `y offset -14 → -33` (발 baseline을 collision 바닥 y=+5에 재정렬). 렌더 대략 26×38 → **52×76**.
2. **Candy 스케일 ~5.5x + 정적화** — `autoplay` 제거, `frame=0` 고정, `scale 0.09 → 0.5` (Ant의 약 2배 선형). 렌더 대략 22×27 → **125×151**.
3. **Candy hp 비율 축소** — `Candy.gd._update_scale()`: ant가 사탕 1조각 가져갈 때마다 `scale = _base_scale × (hp/original_hp)`. hp=0 도달 시 `visible=false` + `monitoring=false` + `EventBus.candy_depleted.emit()`.
4. **Candy bottom-center anchor** — `Sprite.position = (0, -75)`. 스프라이트 하단이 node origin에 닿도록. `_update_scale()`도 `position = _base_offset × ratio`로 축소 시 같이 따라가 바닥 고정 유지.

회귀: `Stage03HeadlessTest` + `BlockerOverlapTest` 모두 PASS. 시뮬레이션 로직 무변경.

### 1.4 미커밋 파일 (다음 세션 시작 시 처리)

```
 M project.godot           ← Phase 9 산출이 일부 반영된 상태
 M scenes/entities/Ant.tscn       ← 스케일 2x + 발 정렬
 M scenes/entities/Candy.tscn     ← 스케일 + bottom anchor + autoplay 제거
 M scripts/world/Candy.gd         ← hp 비율 축소 + bottom anchor
```

→ 다음 세션 초반 결정: 본 변경을 `feat(visual): scale-up entities + candy hp-ratio shrink + bottom anchor` 같은 단일 커밋으로 묶을지, 플레이 테스트 후 추가 보완본까지 합쳐서 한 번에 갈지.

---

## 2. 현재 게임 상태 (플레이 가능 범위)

### 2.1 작동 중인 기능 (Phase 1~9 누적)

- **Stage01~03** (Phase 2~4) — 기본 walker / builder(stage2 다리) / blocker(stage3 차단) 메카닉
- **Phase 5 InputRouter** — 패드/키보드/마우스 통합 input 라우팅 + cursor cache
- **Phase 6 SceneFlow** — game flow 라우터 (RESTART_STAGE, active-stage SoT)
- **Phase 7 input-pad-cursor** — 패드 D-Pad 커서 + InputHintLabel
- **Phase 8 pause/step-frame** — pause_toggle + step_frame + InputModeTracker
- **Phase 9 Theme/Tokens/Motion + 폰트** — 본 phase, UI 시각 1차 적용 (HUD label 폰트/색 자동 적용)

### 2.2 시각 자산 상태

- **Ant**: chibi 잠옷 캐릭터 PNG 시트 9 애니메이션 (idle/walk/carry/fall/blocker/climb/dig/build/victory). State → animation 매핑 자동.
- **Candy**: chibi 일러스트 6프레임 PNG, 본 세션에서 정적 1프레임 + hp 비율 scale 동작으로 변경.
- **Home**: 정규화된 SVG (정적). 본 phase에서 import만, 실제 swap은 phase 11 예정.
- **Skill Icons**: 8장 SVG normalize 완료, phase 10/11 toolbar에서 사용 예정.
- **Logo / stage_bg**: 정규화 SVG, 타이틀 화면(phase 13)/배경에서 사용.

### 2.3 시뮬레이션 로직

- Walker / Carrying / Faller / Worker(blocker/builder) / Saved / Dead state machine
- ScoreSystem 4-카운터 (original_hp / saved / in_transit / lost)
- Candy → BlockerHitbox → Home 전 경로 결정론적
- Pause 중에도 스킬 부여 가능 (StepFrame 1tick 전진)
- 모든 input action은 InputRouter 경유, gate 검증 통과

---

## 3. 플레이 테스트 시 확인 항목

다음 세션에서 실제 게임을 띄워 다음 항목을 시각/UX 관점에서 점검:

### 3.1 Entity 시각 (이번 세션 변경분 검증)

1. **Ant 크기** — 52×76px이 게임 화면에서 적절한가? 너무 크거나 작은가? 다른 ant들과 겹칠 때 가독성?
2. **Ant 발 정렬** — `y offset -33`로 발이 정확히 바닥에 닿는지, 점프/낙하 시 어색하지 않은지.
3. **Ant flip_h** — 좌우 방향 전환 시 자연스러운지 (블로커 부딪힐 때 등).
4. **Ant 애니메이션 전환** — Walker→walk, Carrying→carry, Faller→fall, Worker[blocker]→blocker, Worker[builder]→build. 전환 순간 끊김?
5. **Candy 초기 크기** — Ant 2배(125×151)가 시각적으로 적절한가? 더 크게 / 작게?
6. **Candy bottom anchor** — 바닥에 닿아 있는가, 떠 있는가?
7. **Candy hp 비율 축소** — 매 ant 픽업마다 작아지는 느낌이 자연스러운가? 선형 축소가 너무 빠르거나 느리지 않은가? (필요 시 `pow(ratio, 0.5)` ease-out으로 보정 가능)
8. **Candy hp=0** — 사라짐 연출이 너무 갑작인가? 페이드 아웃 같은 transition 필요?

### 3.2 Theme/Font (Phase 9 결과 검증)

9. **HUD label 폰트** — Jua-Regular 20px ink_900이 가독성 OK한가? Korean glyph (사탕/잠시/등반/낙하산 등) 깨짐 없는가?
10. **Stage01 layout** — Theme 적용 후 placeholder UI 노드가 깨지지 않고 잘 보이는가?
11. **Theme inspector** — 에디터에서 Button×4 state, Panel preview 확인.

### 3.3 시뮬레이션 (회귀 확인)

12. **Stage01~03 클리어 가능성** — 자동 테스트는 PASS지만 실제 플레이 시 페이싱 OK한가?
13. **Pause/Step-frame** — Space로 pause, `.`로 step. 시각 frozen + 입력 게이트 정확.
14. **Pad/KB/Mouse** — 모든 입력 경로 동작. 커서 표시 (Phase 7 InputHintLabel).
15. **Restart stage** — Ctrl+R로 재시작 후 sprite 상태 초기화 확인.

### 3.4 잠재 이슈 (미해결 / 추측)

16. **다중 ant 동시 spawn** — 여러 마리가 같은 location에 겹칠 때 sprite z-ordering 어색?
17. **Worker 상태 종료** — builder/blocker가 work 끝나고 walker로 복귀할 때 sprite 전환 매끄러운가?
18. **Saved 시 즉시 queue_free** — celebrate 애니 안 보이고 바로 사라짐. 향후 victory anim 잠깐 재생 후 free 검토.
19. **Dead 시 즉시 queue_free** — fall 마지막 프레임 freeze tint 같은 표현 검토.
20. **Camera/viewport** — 1920×1080 stretch_mode=canvas_items + aspect=expand. 다른 해상도에서 entity scale 적절한가?

---

## 4. Phase 10 진입 전 정리 사항

다음 세션 플레이 테스트 → 보완 → Phase 10 진입 순서. 진입 전 처리할 잔여:

### 4.1 Phase 9 sweep 항목 (codex round 5 LOW + 미완 deferred)

- **R5-L1** — `svg_color_map.json` item `(4)` 문구 "alpha-absent fallthrough"는 branch (1')에서도 도달 가능. metadata wording cleanup.
- **R1-L2** — Tokens.gd ↔ svg_color_map.json ↔ UI_GUIDE 토큰 SoT consistency check 도구 추가 (sweep, 권장).
- **R2-M2** — style block strip이 element/id selector 도입 시 strict-fail로 전환할지 결정.
- **R2-M3** — `normalize_svg.py --audit-dead-map` 도구 추가 검토 (post-MVP sweep).
- **R6-M2 잔재** — UI_GUIDE의 phase 번호 shift 일부 (§3.5/§3.6/§5/§349/§415/§449~451의 stage-dialog/title-menu phase 번호 +1 shift).

### 4.2 Phase 10 (ui-atoms-foundation) 준비

- atoms (CButton·Chip·Counter·SkillSlot·LogoPanel·StageSlotCard) 신설.
- Tokens.gd freeze된 상수들이 atom에서 사용됨 (COUNTER_COLOR 등).
- Motion.gd freeze된 시그니처를 atom이 호출 (CButton boop, Counter caPop).
- Atom의 override 허용 정책 결정 (phase 10 plan에서).
- UI_GUIDE §3 atom 카탈로그가 SoT.

### 4.3 진입 명령

다음 세션이 플레이 테스트 보완 완료 시점에서:

```bash
python scripts/execute.py mvp next   # Phase 10 진입
```

또는 status.json만 확인:

```bash
python scripts/execute.py mvp status
```

---

## 5. 핵심 SoT 참조 (다음 세션 시작 시 읽을 것)

| 문서 | 역할 |
|---|---|
| `CLAUDE.md` | 프로젝트 헌법 — Phase 시작 전 강제 read |
| `docs/PRD.md` / `docs/ARCHITECTURE.md` / `docs/ADR.md` | 코어 spec (UI phase에선 짧게) |
| `docs/UI_GUIDE.md` | UI 1차 SoT — phase 10~13 진입 시 강제 read. §0.5 운영 모델, §3 atom 카탈로그가 phase 10 핵심 |
| `phases/mvp/PRE_PHASE9_SPRITE_STATE.md` | mixed-canon 정책 (entity=PNG, UI/chrome=SVG) |
| `phases/mvp/phase09-ui-theme-assets.md` v4 | Phase 9 spec final |
| `phases/mvp/plans/phase09-plan.md` v8 | Phase 9 impl plan final |
| `phases/mvp/reviews/phase09-impl-review.md` | 5 self + 5 codex round 사이클 기록 |
| 본 문서 (`PLAYTEST_HANDOFF_2026-05-16.md`) | **다음 세션 시작점** — 본 문서 → playtest → 보완 → phase 10 |

---

## 6. 빠른 명령 reference

### 자동 검증 9건 (Phase 9 강제 PASS)

```bash
cd D:/claude/godot/CandyAnts

# 시뮬레이션 회귀
python scripts/run_test.py tests/Stage03HeadlessTest.tscn
python scripts/run_test.py tests/BlockerOverlapTest.tscn

# Phase 9 신규
python scripts/run_test.py tests/SvgImportSmokeTest.tscn   # 13 SVG sanity + import 4종 키
python scripts/run_test.py tests/MotionPauseSafeTest.tscn  # pause_safe 동작

# 정규화 도구
python scripts/tools/normalize_svg.py --self-test
python scripts/tools/normalize_svg.py --scan-handoff-all
python scripts/tools/normalize_svg.py --check
python scripts/tools/check_font_license.py
```

### 게임 실행 (에디터 또는 직접)

```bash
# 에디터
"D:/Godot_v4.6.2-stable_win64_console.exe" --path "D:/claude/godot/CandyAnts" --editor

# 실행 (헤드 모드)
"D:/Godot_v4.6.2-stable_win64_console.exe" --path "D:/claude/godot/CandyAnts" scenes/Main.tscn
```

### Harness 상태

```bash
python scripts/execute.py mvp status      # 현재 phase 확인
python scripts/execute.py mvp validate    # frontmatter + metadata 검증
```

### Discord notify

```bash
python scripts/notify.py "메시지"
```

---

## 7. 메모 — 본 세션 11 라운드 사이클 교훈

Plan 6 round + impl 5 self+5 codex = 총 16 라운드. 대부분 **doc-sync 잔재**가 매 round HIGH로 등장. 1인 개발 + AI 자산 운영 모델 도입 시 4 문서(plan / phase doc / UI_GUIDE / svg_color_map.json) 일치를 grep으로 점검하면 다음 phase는 라운드 수 절감 가능.

자세한 lesson은 [`candyants_phase9_lessons.md`](C:/Users/code1412/.claude/projects/D--claude-godot/memory/candyants_phase9_lessons.md) 메모리 참조.
