# TDD Guard 스텁. 진짜 coverage는 tests/BgmReceiverTest.tscn + tests/BgmSceneFlowTest.tscn 가 담당:
#   BgmReceiverTest (로직/계약):
#   - scripts/ repo-도출 bgm_request.emit track 추출 → BgmPlayer.BGM_SPECS 직접 커버리지 (정규화 없음)
#   - 무음 경계: _streams 비어 있음 + BGM_SPECS 경로 ResourceLoader.exists==false (에셋 의존 0 입증)
#   - 합성 스트림 주입 후 emit → current_track 일치 + 활성 player playing + 루프 플래그 on
#   - idempotent: 동일 track 재emit 시 play_generation 불변
#   - 전환/graceful/bgm_stop + rapid re-entry 후 fade(>0.4s) 최종상태(활성만 playing, stale stop)
#   BgmSceneFlowTest (실배선):
#   - boot "menu" emit 이전 BgmPlayer 구독 보장(last_requested로 입증) + 빈 _streams 무음 graceful
#   - 실전이 매핑/순서: 메뉴 3종→"menu", load_stage(published)→"gameplay"
# 본 stub은 BgmPlayer.gd 수정 시 TDD guard 통과용 (run_test.py로 위 .tscn 실행).
extends Node
