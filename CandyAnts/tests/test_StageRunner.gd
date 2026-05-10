# TDD Guard 스텁. 진짜 coverage는 다음 통합 테스트에서 담당:
#   - tests/Stage02HeadlessTest.tscn / tests/Stage03HeadlessTest.tscn — stage_cleared/failed payload, 점수 가산
#   - tests/test_ScoreSystem.gd — phase 5 sweep, ScoreSystem.stop() 검증
#   - tests/GameFlowTest.tscn (phase 6) — Main/SceneFlow lifecycle, no_more_ants, Dictionary payload
extends Node
