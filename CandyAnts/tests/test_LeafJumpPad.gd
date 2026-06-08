# TDD Guard 스텁. LeafJumpPad는 Terrain·ants 그룹·state_machine 의존이 커서 _ready 하니스 단위
# 검증이 부적합 — 진짜 coverage는 점프대 배치(SkillToolbar._place_leaf_jump_pad) →
# 개미 진입 시 LeafChargeState 트리거(_try_trigger) 흐름의 씬 동작으로 검증한다.
# skill_activate SFX emit은 tests/SfxReceiverTest.tscn 가 scripts/ repo-스캔으로 자동 커버
# (emit id → SFX_SPECS 직접 매핑 + 동적 재생). 정식 Phase화 시 전용 헤드리스 씬 테스트로 승격 예정.
extends Node
