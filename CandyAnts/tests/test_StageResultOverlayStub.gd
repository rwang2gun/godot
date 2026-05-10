extends Node

# TDD Guard 스텁 — 실제 coverage는 GameFlowTest 시나리오 A/B/C/D에서 검증.
# StageResultOverlayStub은 visible=false 진입, show_result()로 cleared/failed 분기,
# is_last_stage 또는 !cleared 시 Next disable, 첫 클릭 즉시 모든 버튼 disable, hide_overlay reset.
