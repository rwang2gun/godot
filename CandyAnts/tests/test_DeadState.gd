# TDD Guard 스텁. 진짜 coverage는 tests/StunFallTest.tscn —
# 5칸+ 낙하 기절(DeadState) 진입 + 운반 candy_piece_lost 정산 +
# 스테이지 종료까지 DeadState 유지(2026-06-04 영속화, queue_free 금지) 검증.
extends Node
