---
name: ui-stage-dialog
duration_estimate: 5400
verify: ""
---

# Phase 12: StageDialog (win/loss) + 트랜지션 + 사운드 hook

## 목표
스테이지 종료 모달(win/loss) + design handoff motion 시스템 적용 + 페이드 트랜지션 + post-MVP 사운드 hook 자리. **Title/Menu는 phase 12 범위**.

## 전제
- Phase 8~10 완료 (Theme + atoms + Motion + HUD/Toolbar 가동)
- `docs/UI_GUIDE.md` §4 (Motion 시그니처) + §5.3 (별점 알고리즘) + handoff `ui_kits/game/StageDialog.jsx`, `preview/dialog.html`, `preview/motion.html` 시각 SoT
- ScoreSystem이 `stage_cleared`/`stage_failed` emit 중 (phase 2~4)

## 변경 대상

### 신규
- `scenes/ui/StageDialog.tscn` — Modal Panel + 결과 헤더(Saved/Lost/Score/Star) + 3 버튼(Replay/Next/Menu)
- `scripts/ui/StageDialog.gd` — `EventBus.stage_cleared`/`stage_failed` 구독, 버튼 시그널 발화 (`request_replay`, `request_next`, `request_menu`)
- `scripts/core/SceneFlow.gd` — 스테이지 ↔ 다이얼로그 라우팅 (Phase 12에서 메뉴/타이틀까지 확장)

### 수정
- `scripts/core/EventBus.gd` — 신규 시그널 4종 추가
  ```gdscript
  signal request_replay
  signal request_next
  signal request_menu
  signal sfx_request(id: StringName)   # post-MVP sound hook
  ```
- `scripts/ui/HUD.gd` — phase 10에서 atom 호출 시 caPop 자동이지만, `stage_cleared` 수신 시 SkillToolbar disable 호출 추가 (phase 10 엣지 케이스)
- `scripts/core/GameManager.gd` — `request_replay`/`request_next`/`request_menu` 받아 SceneFlow에 위임

### 신규 (단일 SoT)
- `scripts/core/Scoring.gd` — `Scoring.compute_stars(saved, original_hp)` 정적 헬퍼. UI_GUIDE §5.3와 1:1 일치. **본 phase가 owner**, phase 12 SaveData가 동일 함수 호출 (별점 산출 로직 분산 금지).

### Motion 시그니처 (phase 9에서 freeze됨, 본 phase는 호출자만)
Motion 헬퍼는 phase 9에서 이미 `pause_safe: bool = false` 옵션 인자를 포함해 freeze된 상태. 본 phase는 Motion.gd 시그니처 변경 0 — `Motion.fade_in(card, 0.18, true)` 같은 호출만.

### 비-변경
- `scripts/skills/*.gd`, `scripts/world/*.gd` — 무관
- `scripts/input/*` — 무관 (모달은 atom CButton의 input 흐름 그대로 사용)

## StageDialog 레이아웃

```
StageDialog.tscn (CanvasLayer, layer = 50, PROCESS_MODE_ALWAYS)
├─ Backdrop (ColorRect, 전체 화면, Color(0.20, 0.13, 0.07, 0.55))
└─ Card (Panel + NinePatchRect 그림자, 380×440, 중앙 정렬, padding 18,22)
   ├─ Title (Label, Jua 22, ink_900) — "사탕을 무사히 옮겼어요!" / "사탕이 부족했어요"
   ├─ Subtitle (Label, Gaegu 13, ink_700) — EN mirror
   ├─ HeroScore (Label, Jua 36, ink_900) — "8 / 10 조각" (saved/original_hp)
   ├─ StarRow (HBoxContainer × 3)
   │  └─ Star (Polygon2D 또는 TextureRect, 44×44, lemon_500 fill or cream_200 dim, 3px ink)
   ├─ StatChips (HBoxContainer × 3)
   │  ├─ Chip[mint] "귀가 8"
   │  ├─ Chip[berry] "잃음 2"
   │  └─ Chip[lemon] "남은 시간 47s"
   └─ ButtonRow (HBoxContainer × 2 or 3)
      ├─ CButton[SECONDARY] "다시 하기"   → request_replay
      ├─ CButton[PRIMARY]   "다음 단계"   → request_next   (loss 시 hidden)
      └─ CButton[GHOST]     "메뉴로"     → request_menu  (phase 12 메뉴 전제, phase 11에선 stub 라우팅)
```

**Backdrop**: blur 셰이더는 v0.1에서 **off** (cost 회피). ColorRect 알파 0.55만으로 충분히 구분. blur는 post-MVP에서 옵션.

**모달 등장 motion**:
- Card: `Motion.caPop(card)` (220ms TRANS_BACK) — UI_GUIDE §4
- Backdrop: `Motion.fade_in(backdrop, 0.18)` 동시 발화

**버튼 클릭 → 모달 dismiss**:
- 클릭 시 `Motion.fade_out(self, 0.15)` → `await tween.finished` → `queue_free()` → 시그널 발화

## 별점 산출 — **단일 SoT: `Scoring.compute_stars`**

본 phase가 `scripts/core/Scoring.gd` owner. UI_GUIDE §5.3와 1:1 일치:

```gdscript
# scripts/core/Scoring.gd
class_name Scoring
extends RefCounted

const STAR_THRESHOLDS := [0.50, 0.80, 0.95]

static func compute_stars(saved: int, original_hp: int) -> int:
    if original_hp <= 0:
        return 0
    var ratio := float(saved) / float(original_hp)
    var stars := 0
    for threshold in STAR_THRESHOLDS:
        if ratio >= threshold:
            stars += 1
    return stars
```

호출자:
- StageDialog.gd `_on_stage_cleared`: `var stars := Scoring.compute_stars(saved, original_hp)` → `_set_stars(stars)` 호출하여 polygon fill 토글
- SaveData.record_clear (**phase 12**): 동일 함수 호출하여 `stage_progress[id].stars` 저장

> **분산 금지**: StageDialog/SaveData/그 외 어디서도 별점 임계값/계산식을 직접 박지 않는다. 항상 `Scoring.compute_stars` 호출.

## 검증 방법

### 자동 (헤드리스)
1. `python scripts/run_test.py tests/Stage02HeadlessTest.tscn` PASS — 모달이 자동 dismiss 후 진행 (테스트 헬퍼에 `bypass_dialog = true` 옵션 필요. 본 phase에서 추가)
2. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS
3. 신규 `tests/StageDialogStarsTest.gd` — `Scoring.compute_stars(8, 10) == 2`, `(10,10) == 3`, `(5,10) == 1`, `(4,10) == 0`, `(0,0) == 0` 검증. **StageDialog 또는 SaveData 어디서 호출해도 동일 결과** 검증 (단일 SoT 보장)

### 수동
1. Stage01 클리어 → StageDialog win 표시 → caPop motion 발화 → "다시 하기" → 같은 stage 리셋
2. Stage01 모든 ant 사망 → StageDialog loss → "다음 단계" 숨김 → "다시 하기" 정상
3. 카운터 +1 시 boop motion (phase 9/10 연계)
4. Pause 상태에서 stage_cleared 트리거 → 모달 등장 (PROCESS_MODE_ALWAYS), 게임은 여전히 pause
5. 페이드 인/아웃 — stage 시작 0.3s, 종료 0.5s. handoff motion.html과 곡선 비교
6. 모달 표시 중 ESC → request_menu 발화. phase 12 미구현이므로 SceneFlow가 stub 처리(현재 stage 재로드 또는 placeholder log).

## 엣지 케이스 (필수)

- **stage_cleared 발화 중복** — Candy.hp=0 + ant_saved 동시 발생 시 ScoreSystem이 1번만 emit (phase 2 산출물). 본 phase는 신뢰.
- **버튼 중복 클릭** — Replay/Next 버튼 첫 클릭 후 즉시 `set_disabled(true)`. fade_out 동안 추가 입력 무시.
- **Pause 호환** — Card는 PROCESS_MODE_ALWAYS. 모달 표시 중 pause toggle 가능하나, 모달 자체는 motion 정상 동작.
- **Stars 임계값 stage별 override** — v0.1에서 미지원. stage4~10 phase에서 필요해지면 `data/stages/stageNN.tres.star_thresholds: PackedFloat32Array` 추가 (UI_GUIDE §5.3 비고).
- **request_next when last stage** — 마지막 stage 클리어 시 "다음 단계" → request_menu로 fallback (SceneFlow에서 처리). phase 12 SaveData 도입 후 stage 진행도 기준 결정.
- **모달 등장 중 stage scene이 free** — SceneFlow가 dialog 띄울 때 stage scene을 즉시 free X. dialog dismiss → fade_out → stage scene free → 다음 scene 로드 순서.
- **fade_out 중 스킬 부여 시도** — phase 10에서 stage_cleared 수신 시 toolbar disable 처리. 본 phase는 신뢰.
- **사운드 hook 자리** — 모달 등장/버튼/카운터 변동 시 `EventBus.sfx_request(id: StringName)` emit (신규 시그널 1개). post-MVP에서 receiver 채움. 본 phase는 emit만, sound 파일 X.
- **SceneFlow 단독 검증** — `SceneFlow.transition_to(scene_path: String)` 단위 테스트. 트랜지션 도중 같은 메서드 재호출 시 두번째는 무시 (이중 전환 방지).

## 신규 EventBus 시그널 (본 phase 범위)
```gdscript
signal request_replay
signal request_next
signal request_menu
signal sfx_request(id: StringName)   # post-MVP sound hook
```

## 산출물 요약

```
scenes/ui/StageDialog.tscn
scripts/ui/StageDialog.gd
scripts/core/SceneFlow.gd
scripts/core/Scoring.gd          ← compute_stars 단일 SoT (owner)
scripts/core/EventBus.gd         ← 시그널 4개 추가
scripts/ui/HUD.gd                ← stage_cleared 시 toolbar disable 호출
scripts/core/GameManager.gd      ← request_* 시그널 라우팅
tests/StageDialogStarsTest.gd
```

> Motion.gd는 phase 9에서 이미 freeze된 시그니처 그대로 호출만 — 본 phase에서 Motion.gd 수정 0.

## 사운드 (post-MVP 표시)
- 본 phase에서 **`EventBus.sfx_request(id)` emit 자리만 만든다**. 실제 사운드 임포트/재생은 post-MVP phase 20.
- emit 위치: 모달 등장 (`sfx:dialog_open`), 버튼 boop (`sfx:btn_press`), 카운터 변동 (`sfx:counter_pop`), 별점 채워짐 (`sfx:star_fill`).

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md`. 시각/모션 명세는 `docs/UI_GUIDE.md` §4·§5.3 + handoff `preview/dialog.html`, `preview/motion.html` SoT.
