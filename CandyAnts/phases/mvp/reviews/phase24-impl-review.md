# Phase 24 (bgm-assets) — Implementation adversarial review

## Self-Review Round 1

### 변경 요약
- `assets/audio/bgm/menu.ogg` (Children's March Theme, Cleyton Kauffman, CC0, OpenGameArt) + `gameplay.ogg` (Cozy Puzzle In-Game 1, MintoDog, CC0, OpenGameArt) + `CREDITS.txt`.
- `tests/BgmReceiverTest.gd` (c): 무음 경계 → **로드 무결성** 역전(`_streams.size()==BGM_SPECS.size()` + non-null AudioStream + length>0). (d)/(e) 로직은 합성 WAV 주입 유지(포맷-결정적 loop_mode 단언).
- `tests/BgmSceneFlowTest.gd` (11): 무음 → **asset-present 재생** 역전(boot "menu" → current_track=="menu" + play_generation≥1) + STAGE 진입 시 "gameplay" 전환 단언.
- `docs/ADR.md` ADR-013: 실제 트랙·출처·자족성 1줄 보강.
- BgmPlayer.gd **코드 무변경**(BGM_SPECS 경로가 이미 bgm/menu.ogg·gameplay.ogg).

### 점검
- [no-issue] **라이선스**: 둘 다 CC0 실측 확인(OpenGameArt 페이지 + zip readme "Creative Commons Zero (CC0)"). 표기 의무 없으나 CREDITS.txt에 출처·작곡·URL 기록.
- [no-issue] **로드 무결성 (c)**: 실제 ogg 2종 non-null + length>0 로드. 실측 PASS.
- [no-issue] **asset-present 실배선**: boot menu 재생 + STAGE→gameplay 전환. 실측 PASS. emit 시퀀스 `[menu,menu,menu,gameplay]` 유지.
- [no-issue] **격리 유지**: (d)는 WAV 주입으로 loop 격리(원본 미변형 + 복제 인스턴스) 검사 — ogg import 기본 loop 설정과 무관하게 결정적. BgmPlayer `_apply_loop`가 복제본에만 적용(ADR-013).
- [no-issue] **clean-clone 자족성**: `.import` + `.godot/imported` bgm 항목 제거 → `run_test.py --import`로 ogg에서 재생성 → BgmReceiverTest PASS(ogg-only 자족 실측). `git check-ignore`로 `.import` 미추적·`.ogg` 추적 확인.
- [no-issue] **size guard**: menu 2.5MB / gameplay 4MB(단일 5MB 미만), 합계 ~6.5MB(25MB 미만) — large_change_ok 불요.
- [low] **menu = 행진풍**(Children's March): 경쾌하나 메뉴치고 다소 에너제틱할 수 있음. gameplay(Cozy Puzzle)는 적합. 주관적 — 게임 청취 후 `BGM_SPECS` 한 줄로 교체 가능(원본 보관 불필요, 재다운로드).
- [no-issue] **cross-doc**: ADR-013 phase 24 반영, CREDITS, phase24 plan과 정합. 트래커는 plan stage에서 이미 처리(23·24 bgm, 25·26 input).

### 결론
자체 리뷰 clean → codex 적대적 리뷰.

## Codex Round 1

Target: working tree diff. Verdict: needs-attention.
- [high] ogg 루프/격리 회귀가 통과 가능(BgmReceiverTest.gd:54-75). 실제 ogg 로드 증명 후 _streams를 합성 WAV로 덮어쓰고 모든 재생/루프 단언을 수행 → `_apply_loop`의 AudioStreamOggVorbis 분기 제거/캐시 변형 회귀가 green 통과. BgmSceneFlowTest는 boot/전이 직후 current_track/play_generation만 봐서 ogg EOF 도달 시 무음(한 번 재생 후 정지)도 못 잡음. 유저 영향: 메뉴/게임플레이 음악이 1회 재생 후 무음.
  → 권고: WAV 교체 *이전에* ogg 전용 단언 추가 — 캐시 ogg loop=false 강제 → emit → 활성 스트림이 별도 AudioStreamOggVorbis + loop==true, 캐시는 loop==false 유지. WAV 주입은 crossfade/idempotent 결정적 검사에만.

## Self-Review Round 2 (Codex R1 HIGH 수정 검토)
수정: BgmReceiverTest에 **(c2) 실제 ogg 루프/격리** 블록 추가(WAV 주입 *이전*). menu/gameplay 각각 캐시 ogg `loop=false` 강제 → emit → 활성 player 스트림이 별도 `AudioStreamOggVorbis` + `loop==true` + 캐시 원본 `loop==false` 유지 단언. 이후 `bgm_stop`으로 상태 리셋하고 WAV 주입 로직(crossfade/idempotent/rapid)은 유지.
- [no-issue] `_apply_loop`의 ogg 분기를 **실제 ogg로 직접 운동** → 분기 제거/캐시 변형/EOF-무음 회귀를 (c2)가 FAIL로 잡음.
- [no-issue] 격리: 활성 ogg ≠ 캐시 인스턴스 + 캐시 loop 미변형 단언 → duplicate 격리를 ogg 경로에서도 증명.
- [no-issue] 상태 리셋(`bgm_stop`)으로 후속 (d) emit이 idempotent에 막히지 않고 처음부터 재생. 실측 PASS(8 단계 전부).
- [no-issue] BgmSceneFlowTest는 배선 검증 역할 유지(루프 가청 증명은 (c2)가 소유 — 리뷰 권고대로 역할 분리).
자체 리뷰 clean(HIGH 0) → codex 재리뷰.

## Codex Round 2

Target: working tree diff. **Verdict: approve.** No material findings.
> Round 1 HIGH 해소 확인: (c2)가 WAV 주입 이전에 실제 menu/gameplay ogg를 운동, 활성 AudioStreamOggVorbis의 duplicate 격리 + loop==true 증명, 후속 bgm_stop→WAV 경로에 CRITICAL/HIGH 없음. (codex sandbox 제약으로 테스트 직접 실행 불가 — static review. 테스트는 본 세션 헤드리스 PASS 실측.)

### 최종 상태
- BgmReceiverTest((c)(c2)(d)(e)) + BgmSceneFlowTest + 회귀 = PASS. clean-clone 자족성 실측(.import 제거→--import→PASS).
- Codex impl verdict **approve**, 자체 리뷰 clean. impl-stage 리뷰 루프 종료.
- BGM 시스템(P23) + 실제 CC0 음원(P24) = 가청 완성.
