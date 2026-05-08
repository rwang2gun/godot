class_name StageData extends Resource

@export var id: int = 0
@export var display_name: String = ""
@export var scene: PackedScene = null
@export var total_ants: int = 10
@export var candy_hp: int = 10
@export var time_limit_seconds: float = 120.0
@export var available_skills: Array[String] = []
@export var skill_inventory: Dictionary = {}
@export var release_rate_initial: int = 50
@export var release_rate_min: int = 1
