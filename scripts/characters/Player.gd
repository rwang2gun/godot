class_name Player
extends CharacterBase

## =====================================================================
##  Player (FS — Freedom Swordsman)
##  CharacterBase의 기본 스탯 사용. 검 보이기만 추가 처리.
## =====================================================================


func _ready() -> void:
	# FS는 기본 스탯 사용 (override 없음)

	# 포즈 매핑 (FS 전용 — skill/ult 키를 기존 포즈로 연결)
	pose_map = {
		"skill_cast":    "fs_skill",
		"ult_windup":    "fs_ult_spin",
		"ult_strike":    "fs_ult_spin",
		"charge_windup": "fs_charge_windup",
		"charge_slam":   "fs_charge_slam",
		"walk1":         "idle",          # 절차적 walk 사용 — 폴백용
	}

	super()

	# 검 보이기
	if parts.has("sword"):
		var sword: MeshInstance3D = parts["sword"]
		sword.visible = true
		sword.scale = Vector3.ONE
