extends Node

# auto-solver Phase 0 — 결정론 스폰 스케줄 회귀 (codex R1-HIGH).
# release_rate=30은 비정수 interval(_interval_for(30) ≈ 1.4229s ≈ 85.38 물리프레임)을 만든다.
# 올바른 결정론 스폰은 k번째 개미를 **ceil(k × interval × fps)** 프레임에 낸다(분수-초 절대 데드라인 누적 →
# drift 0, early-fire 0). 정수 프레임을 round해 누적하던 구버전은 매 간격 ~0.38f 일찍 + 드리프트가 쌓여
# 시퀀스가 어긋난다. 본 테스트는 정확한 시퀀스 일치를 단언해 그 회귀를 영구 차단한다.
#
# 검출: _process는 물리 step 이후 실행되고 Engine.get_physics_frames()는 그 iteration의 물리 프레임 수와
# 같으므로(다음 물리 step 전까지 불변), 자식 수 증가가 관측된 프레임 = AntSpawner가 _physics_process에서
# add_child한 바로 그 프레임. → 노드 처리 순서와 무관하게 오프셋 없는 정확한 스폰 프레임을 얻는다.

const ANT_SCENE := preload("res://scenes/entities/Ant.tscn")
const RATE: int = 30
const N: int = 5
const FRAME_CAP: int = 2000

var _spawner: AntSpawner = null
var _container: Node = null
var _start_frame: int = 0
var _seen: int = 0
var _spawn_rel_frames: Array[int] = []
var _done: bool = false

func _ready() -> void:
	SimConfig.set_deterministic(true)
	_container = Node.new()
	_container.name = "SpawnContainer"
	add_child(_container)
	_spawner = AntSpawner.new()
	_spawner.ant_scene = ANT_SCENE
	_spawner.total = N
	_spawner.spawn_position = Vector2.ZERO
	add_child(_spawner)
	_spawner.set_release_rate(RATE)
	_start_frame = Engine.get_physics_frames()
	_spawner.start(_container)
	print("[DeterminismSpawnScheduleTest] start frame=%d rate=%d interval=%.5fs" % [
		_start_frame, RATE, _spawner._interval_for(RATE)])

func _process(_dt: float) -> void:
	if _done:
		return
	var count: int = _container.get_child_count()
	while _seen < count:
		_seen += 1
		_spawn_rel_frames.append(Engine.get_physics_frames() - _start_frame)
	if _seen >= N:
		_verify()
	elif Engine.get_physics_frames() - _start_frame > FRAME_CAP:
		_fail("only %d/%d spawns within %d frames (rel=%s)" % [_seen, N, FRAME_CAP, str(_spawn_rel_frames)])

func _verify() -> void:
	var interval: float = _spawner._interval_for(RATE)
	var fps: float = float(Engine.physics_ticks_per_second)
	var expected: Array[int] = []
	for k in range(1, N + 1):
		expected.append(int(ceil(float(k) * interval * fps)))
	if _spawn_rel_frames != expected:
		_fail("spawn schedule mismatch\n  actual  : %s\n  expected: %s (ceil of cumulative interval = no drift, no early-fire)" % [
			str(_spawn_rel_frames), str(expected)])
		return
	print("[DeterminismSpawnScheduleTest] PASS spawn frames=%s match ceil(k*interval*fps)" % str(expected))
	_done = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[DeterminismSpawnScheduleTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
