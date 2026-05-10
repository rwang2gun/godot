extends Node

signal candy_depleted
signal candy_piece_picked(remaining_hp: int)
signal candy_piece_lost(by_ant: Node)
signal ant_died(ant: Node, was_carrying: bool)
signal ant_saved(ant: Node, with_candy: bool)
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
signal request_replay
signal request_next
signal request_menu
signal release_rate_changed(new_rate: int)

# Phase 5 — InputRouter가 emit, SkillToolbar 등이 구독.
# payload 형식: GameAction.is_positional(name)이 true면 {position_valid, screen_pos, world_pos}
# (TARGET_NEXT_ANT/TARGET_PREV_ANT는 from_world_pos 키 사용).
signal action_triggered(name: StringName, payload: Dictionary)
signal input_mode_changed(mode: StringName)  # "mouse" / "pad" / "touch" — Phase 7 InputModeTracker
