class_name CharacterEF
extends CharacterBase

## =====================================================================
##  CharacterEF — 격투가 (Element Fighter)
##  근접 콤보 4단, 어퍼컷/엘보 특수기
## =====================================================================


func _ready() -> void:
	# 스탯 override
	MAX_SPEED    = 6.5
	ACCELERATION = 16.0
	ATTACK_RANGE = 1.8
	COMBO_MAX    = 4

	# 포즈 매핑 (EF 전용)
	pose_map = {
		"idle": "ef_idle", "battle_idle": "ef_battle_idle",
		"combo1": "ef_combo1", "combo2": "ef_combo2",
		"combo3a": "ef_combo3", "combo3b": "ef_combo3", "combo4": "ef_combo4",
		"dash": "dash", "hurt": "hurt",
		"skill_cast": "ef_skill_windup",
		"ult_windup": "ef_ult_jump", "ult_strike": "ef_ult_slam",
		"shoulder_bash": "ef_uppercut", "walk1": "ef_idle",
	}

	super()


## 머티리얼 오버라이드 — 빨간 격투가
func _init_materials() -> void:
	mat_chest  = _make_mat(Color(0.7, 0.15, 0.1))
	mat_waist  = _make_mat(Color(0.5, 0.1, 0.05))
	mat_pelvis = _make_mat(Color(0.6, 0.12, 0.08))
	mat_skin   = _make_mat(Color(1.0, 0.86, 0.67))
	mat_hair   = _make_mat(Color(0.2, 0.2, 0.2))
	mat_right  = _make_mat(Color(0.85, 0.25, 0.15))
	mat_left   = _make_mat(Color(0.85, 0.25, 0.15))
