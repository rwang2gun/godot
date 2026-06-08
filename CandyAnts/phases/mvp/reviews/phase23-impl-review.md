# Phase 23 (bgm-receiver) — Implementation adversarial review

## Self-Review Round 1

가혹 기준(CRITICAL/HIGH/MEDIUM/LOW + hypothetical + cross-doc + dead branch + tween race)으로 자체 검토.

### 추적: rapid re-entry tween 소유권
init `_active=0`. (d)에서 menu→(idempotent menu)→gameplay→__no_such__→bgm_stop, (e)에서 menu→gameplay→menu.
- 매 `_start_track`은 `_fade(next, 0)`에서 `_kill_tween(next)` 선행 → 직전 player의 stale fade(특히 bgm_stop이 남긴 tween)를 죽이고 fade in. `_fade_out_stop(prev)`의 stop 콜백은 `_active != idx`일 때만 실행 → 빠른 재진입으로 다시 활성이 된 player를 stop하지 않음.
- (e) 최종: `_active=1`(menu) playing, 비활성 player(0)는 마지막 `_fade_out_stop(0)` 콜백(0.4s 후 active=1≠0)으로 stop. **실측 PASS** — `_players[1-active].playing == false` 단언 통과.
→ tween 볼륨 싸움/오 stop 없음 (R1 MEDIUM-2 해소 확인).

### 점검 항목
- [no-issue] **idempotent**: 같은 track + 활성 playing → no-op, `play_generation` 불변. 메뉴 내 이동 무중단. 실측 PASS.
- [no-issue] **graceful**: 미매핑 track `push_warning` 후 `current_track` 미갱신. Phase 23 무음 경계 유지. 실측 PASS.
- [no-issue] **무음 경계 검증 가능성**(R1 HIGH-2): BgmReceiverTest (c)가 `_streams.is_empty()` + `ResourceLoader.exists()==false`를 주입 *이전에* 단언 → 실수 배치/stale import/오타 차단. 실측 PASS.
- [no-issue] **SceneFlow 실배선**(R1 MEDIUM-1): BgmSceneFlowTest가 `Main.tscn` 실구동으로 emit 순서 `[menu,menu,menu,gameplay]` + boot 이전 구독(`is_connected` + `last_requested=="menu"`) + 무음(`current_track==""`, `play_generation==0`) 단언. 실측 PASS.
- [no-issue] **autoload 순서**: EventBus(21) < BgmPlayer(23). `_ready`에서 EventBus/AudioServer 접근 안전. boot emit 이전 구독(테스트가 입증).
- [no-issue] **버스 폴백**: BGM 버스 미존재 시 Master 폴백(SfxPlayer 동형). default_bus_layout에 BGM bus/2 추가.
- [no-issue] **cross-doc**: ADR-013 추가, phase23/24 + README/metadata/notion-ids/post_mvp_range 정합(plan stage에서 원자 처리). EventBus 시그널 2종, project.godot autoload 1줄.
- [no-issue] **타입 안전**: `_apply_loop`는 ogg/mp3/wav 명시적 캐스트(베이스 AudioStream에 `.loop` 직접 접근 회피 — parse error 방지).
- [low] **MIN_DB=-40**: 완전 무음(-80) 아님 — fade-out 꼬리 미세 잔향 가능하나 stop()으로 종결. 폴리시 사안, 버그 아님. 게임 청취 후 조정 가능.
- [low] **bgm_stop reserved**: production 발화자 없음(테스트만). EventBus `request_title` reserved 패턴과 동형 — 향후 silence 컨텍스트용. dead가 아닌 reserved.
- [cosmetic] **"ObjectDB leaked at exit"**(BgmReceiverTest): `quit(0)` 즉시 종료 시 활성 tween/주입 스트림 미해제 경고. 헤드리스 강제 종료 타이밍 산물, 테스트 결정성·PASS 무영향.

### 범위 밖(별도 처리) — 선재 버그 발견
- **[pre-existing]** `PauseMenu._force_hide`가 `request_play_stage(stage_id: int)` 시그널에 0-인자로 연결 → `request_play_stage.emit(1)` 시 `Method expected 0 argument(s), but called with 1` 에러. BgmSceneFlowTest가 player 경로를 구동하며 노출됨. **BGM과 무관**(MainMenu Play/StageSelect 슬롯 경로의 선재 결함). 본 phase 미수정 — 별도 hot-fix/task로 처리.

### 결론
BGM 구현 자체에 CRITICAL/HIGH 0건. 자체 리뷰 clean → codex 적대적 리뷰로 진행.

## Codex Round 1

Target: working tree diff. Verdict: needs-attention (no CRITICAL/HIGH).
- [medium] BgmPlayer가 루프 강제 시 캐시된 AudioStream 리소스를 변형(BgmPlayer.gd:129-141). `_apply_loop`가 `_streams`에서 꺼낸 인스턴스(=`load()`/ResourceLoader 캐시 공유)에 직접 loop 플래그를 세팅 → loop가 BGM 재생의 전역 부작용. Phase 24+에서 같은 ogg를 비-루프 프리뷰/sting/fixture로 재사용하면 BgmPlayer가 그 소비자를 조용히 루프로 만듦. 현재 테스트는 주입 스트림에 loop가 설정됐는지만 보고 변형 격리는 안 봄.
  → 권고: 재생 스트림을 BgmPlayer가 소유 — loop 적용 전 duplicate, 복제본만 변형. 원본이 pre-play loop 설정을 유지하는지 테스트 추가.

## Self-Review Round 2 (Codex R1 MEDIUM 수정 검토)
수정: `_start_track`에서 `(_streams[track] as AudioStream).duplicate() as AudioStream`로 **재생용 복제본**을 만들어 `_apply_loop`를 복제본에만 적용. 원본 `_streams` 엔트리는 미변형.
- [no-issue] `duplicate(false)`는 ogg packet_sequence/wav data(COW)를 공유하고 loop 프로퍼티만 새 인스턴스로 분리 → 무거운 디코드 데이터 재할당 0, 루프 누출 0.
- [no-issue] 복제는 전이당 1회(화면 전환 빈도 낮음) → 무시 가능한 비용.
- [no-issue] 테스트 (d) 강화: 활성 player의 *할당된* 스트림이 `LOOP_FORWARD` + 원본 `_streams[&"menu"]`는 `LOOP_DISABLED` 유지 + 두 인스턴스 비동일 단언 → 격리를 실측 증명. 양 테스트 PASS.
- [no-issue] `_streams.has(track)` 가드가 `_start_track` 전에 있어 duplicate 대상 null 불가.
자체 리뷰 clean(HIGH 0) → codex 재리뷰.

## Codex Round 2

Target: working tree diff. **Verdict: approve.** No material findings.
> Round 1 공유 리소스 변형 이슈 해소 확인: 재생은 복제 스트림 사용, loop는 그 인스턴스에만 적용, 테스트가 원본 WAV 격리 + 인스턴스 비동일을 단언. (codex는 sandbox 제약으로 테스트 직접 실행 불가 — source-review only. 테스트는 본 세션에서 헤드리스 PASS 실측.)

### 최종 상태
- BgmReceiverTest + BgmSceneFlowTest + SceneFlow 5종 + SfxReceiver = **8/8 PASS** (회귀 0).
- Codex impl verdict **approve**, 자체 리뷰 clean. impl-stage 리뷰 루프 종료.
- 선재 버그(PauseMenu._force_hide arg mismatch)는 BGM 무관 — 별도 task로 분리(미수정).
