# TDD Guard 스텁. SpeedBtn은 PauseBtn 동형 atom wrapper — 배수 순환 로직은 Engine.time_scale
# 부수효과라 통합 씬(GameFlowTest 계열, time_scale 구동)에서 간접 확인. 표시 텍스트("N배속")·
# 버튼 크기는 시각 검증 영역(test_HUD.gd 동일 방침).
extends Node
