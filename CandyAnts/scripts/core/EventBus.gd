extends Node

signal candy_depleted
signal candy_piece_picked(remaining_hp: int)
signal candy_piece_lost(by_ant: Node)
signal ant_died(ant: Node, was_carrying: bool)
signal ant_saved(ant: Node, with_candy: bool)
signal stage_cleared(score: float)
signal stage_failed(reason: String)
signal release_rate_changed(new_rate: int)
