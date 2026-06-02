extends Node

const ICONS := [
	"res://assets/icons/skills/basher.png",
	"res://assets/icons/skills/cursors/basher.png",
	"res://assets/icons/skills/blocker.png",
	"res://assets/icons/skills/cursors/blocker.png",
	"res://assets/icons/skills/bridge.png",
	"res://assets/icons/skills/cursors/bridge.png",
	"res://assets/icons/skills/builder.png",
	"res://assets/icons/skills/cursors/builder.png",
	"res://assets/icons/skills/climber.png",
	"res://assets/icons/skills/cursors/climber.png",
	"res://assets/icons/skills/cutter.png",
	"res://assets/icons/skills/cursors/cutter.png",
	"res://assets/icons/skills/digger.png",
	"res://assets/icons/skills/cursors/digger.png",
	"res://assets/icons/skills/distributor.png",
	"res://assets/icons/skills/cursors/distributor.png",
	"res://assets/icons/skills/floater.png",
	"res://assets/icons/skills/cursors/floater.png",
	"res://assets/icons/skills/sand_mound.png",
	"res://assets/icons/skills/cursors/sand_mound.png",
]
const REGISTERED_IDS := [
	"basher",
	"blocker",
	"bridge",
	"builder",
	"climber",
	"cutter",
	"digger",
	"distributor",
	"floater",
	"sand_mound",
]

func _ready() -> void:
	var failures: Array[String] = []
	for path in ICONS:
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			failures.append("[load] " + path)
			continue
		var size := tex.get_size()
		if size.x <= 0 or size.y <= 0:
			failures.append("[zero-size] " + path)
			continue
		var img := tex.get_image()
		if img == null:
			failures.append("[image] " + path)
			continue
		var non_blank := 0
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.01:
					non_blank += 1
		var total := img.get_width() * img.get_height()
		if total <= 0 or float(non_blank) / float(total) < 0.05:
			failures.append("[blank] " + path)
	for id in REGISTERED_IDS:
		if SkillToolbar.ICONS.get(id) == null:
			failures.append("[toolbar-icon] missing " + id)
		if SkillToolbar.CURSOR_ICONS.get(id) == null:
			failures.append("[toolbar-cursor-icon] missing " + id)
		if not Strings.has_skill_label(id):
			failures.append("[toolbar-label] missing " + id)
	if failures.size() > 0:
		push_error("SkillIconPngSmokeTest FAIL - " + "\n".join(failures))
		get_tree().quit(1)
	else:
		print("[SkillIconPngSmokeTest] PASS - %d PNG icons verified" % ICONS.size())
		get_tree().quit(0)
