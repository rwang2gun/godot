# TDD Guard 스텁. 진짜 coverage는 tests/MainMenuContinueGuardTest.tscn —
# Continue 버튼 가드 4 케이스(last=0/미존재/unlocked false/unlocked true). map-editor 트랙(2026-06-04):
# SceneFlow.STAGE_SCENES 자동 스캔 전환으로 MainMenu가 SceneFlow.ensure_stage_scan()을 호출하는 회귀도 (d) 케이스가 가드.
extends Node
