class_name LogoPanel
extends Control

# Phase 13 atom — UI_GUIDE §3.5. wordmark + mascot 합성, mascot에 idle_bob.

@export var wordmark: Texture2D:
	set(value):
		wordmark = value
		if is_inside_tree():
			_apply_textures()

@export var mascot: Texture2D:
	set(value):
		mascot = value
		if is_inside_tree():
			_apply_textures()

@export var bob_enabled: bool = true
@export var bob_amplitude: float = 1.03
@export var bob_period: float = 1.6

@onready var _wordmark_node: TextureRect = $VBox/Wordmark
@onready var _mascot_node: TextureRect = $VBox/Mascot

var _bob_tween: Tween = null

func _ready() -> void:
	_apply_textures()
	if bob_enabled:
		_bob_tween = Motion.idle_bob(_mascot_node, bob_amplitude, bob_period)

func _apply_textures() -> void:
	if _wordmark_node != null and wordmark != null:
		_wordmark_node.texture = wordmark
	if _mascot_node != null and mascot != null:
		_mascot_node.texture = mascot

func get_bob_tween() -> Tween:
	return _bob_tween
