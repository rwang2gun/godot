extends Node

# TDD Guard 스텁 — 실제 coverage는 GameFlowTest 시나리오 A(clear→Next), B(last→Next disabled→menu fallback),
# C(no_more_ants→fail→Next 차단→Replay), D(process freeze)에서 검증.
# SceneFlow 책임: stage load/unload (queue_free), freeze/unfreeze (process_mode),
# stage_cleared/stage_failed → overlay.show_result, request_replay/next/menu 처리.
# Next는 _last_result.cleared가 true일 때만 허용 (overlay disable과 이중 방어).
