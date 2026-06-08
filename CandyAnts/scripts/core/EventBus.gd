extends Node

signal candy_depleted
signal candy_piece_picked(remaining_hp: int)
signal candy_piece_lost(by_ant: Node)
signal candy_piece_recovered(by_ant: Node)  # 2026-06-03 — 바닥에 드롭된 사탕 재획득. lost→in_transit 보정.
signal ant_died(ant: Node, was_carrying: bool)
signal ant_saved(ant: Node, with_candy: bool)
signal stage_cleared(result: Dictionary)
signal stage_failed(result: Dictionary)
signal request_replay
signal request_next
signal request_menu                     # phase 12 legacy alias — StageDialog Menu 버튼만 emit (Δ14)
signal request_main_menu                # Phase 13 — Title/MainMenu/StageSelect → MainMenu 복귀
signal request_stage_select             # Phase 13 — MainMenu.StageSelectBtn → StageSelect 진입
signal request_play_stage(stage_id: int) # Phase 13 — MainMenu.Play/Continue + StageSelect 슬롯
signal request_title                    # Phase 13 — reserved (현재 발화자 없음, 향후 phase 추가용)
signal release_rate_changed(new_rate: int)
signal sfx_request(id: StringName)   # phase 12 sound hook — receiver는 phase 21 산출
signal bgm_request(track: StringName)  # phase 23 — 화면 컨텍스트 BGM 요청(menu/gameplay). receiver는 BgmPlayer.
signal bgm_stop()                      # phase 23 — BGM 정지(페이드 아웃). SceneFlow가 TITLE 진입 시 emit(타이틀 영상은 자체 사운드).

# Phase 5 — InputRouter가 emit, SkillToolbar 등이 구독.
# payload 형식: GameAction.is_positional(name)이 true면 {position_valid, screen_pos, world_pos}
# (TARGET_NEXT_ANT/TARGET_PREV_ANT는 from_world_pos 키 사용).
signal action_triggered(name: StringName, payload: Dictionary)
signal input_mode_changed(mode: StringName)  # "mouse" / "pad" / "touch" — Phase 7 InputModeTracker
