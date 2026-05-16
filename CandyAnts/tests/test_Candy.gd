# TDD Guard 스텁. 진짜 coverage는 tests/Stage02HeadlessTest.tscn / Stage03HeadlessTest.tscn
# (candy_piece_picked → ScoreSystem, candy_depleted → StageRunner clear 경로 통합 검증).
# 본 stub은 Candy.gd 수정(hp 비율 축소, monitoring set_deferred 등) 시 TDD guard 통과용.
extends Node
