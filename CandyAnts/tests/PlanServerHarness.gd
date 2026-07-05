extends Node

# auto-solver — persistent 플랜 서버 하니스 (헤드리스, RL 환경 토대).
#
# PlanReplayHarness는 plan 1개 실행 후 quit한다(매 롤아웃마다 Godot 재부팅 → RL throughput 병목).
# 이 하니스는 살아서 TCP로 plan을 계속 받아 PlanRunner로 실행하고 결과를 NDJSON으로 돌려준다 →
# Godot 부팅 1회로 N 에피소드(롤아웃)를 진행해 부팅 오버헤드를 분산한다.
#
# 프로토콜 (localhost TCP, newline-delimited JSON; 요청·응답 각 1줄):
#   요청: plan dict(PlanRunner 스키마) | {"cmd":"quit"} | {"cmd":"ping"}
#   응답: SOLVER_RESULT dict        | {"bye":true}   | {"pong":true}
# 포트: env CANDYANTS_PLAN_PORT(파이썬 env.py가 지정). 미설정 시 DEFAULT_PORT.
# 부팅 마커: stdout "PLAN_SERVER_LISTENING <port>" (디버깅용; env.py는 connect 재시도로 핸드셰이크).
#
# 상태누수 0은 PlanRunner가 보장한다(_teardown/_reset_state; PlanReplayHarnessTest ②④가 byte-identical
# 증명). 여기선 매 plan마다 새 PlanRunner를 add_child→run→finished→queue_free(검증된 _run 패턴)하고,
# 한 번에 하나만 실행한다(_busy 가드 = PlanRunner 단일 활성 런 전제 유지).

const DEFAULT_PORT := 47800

var _server: TCPServer = null
var _peer: StreamPeerTCP = null
var _rx: PackedByteArray = PackedByteArray()
var _runner: PlanRunner = null
var _busy: bool = false

func _ready() -> void:
	var port := DEFAULT_PORT
	var env_port: String = OS.get_environment("CANDYANTS_PLAN_PORT")
	if env_port != "":
		port = int(env_port)
	_server = TCPServer.new()
	var err: int = _server.listen(port, "127.0.0.1")
	if err != OK:
		print("PLAN_SERVER_ERROR listen failed port=%d err=%d" % [port, err])
		get_tree().quit(2)
		return
	print("PLAN_SERVER_LISTENING %d" % port)

func _process(_dt: float) -> void:
	if _server == null:
		return
	# 클라이언트 1개 수락.
	if _peer == null:
		if _server.is_connection_available():
			_peer = _server.take_connection()
		else:
			return
	_peer.poll()
	var st: int = _peer.get_status()
	if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
		# 클라이언트 종료 → 좀비 프로세스 방지로 서버도 종료.
		get_tree().quit(0)
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return
	# 수신 누적(busy 중에도 버퍼는 채운다).
	var avail: int = _peer.get_available_bytes()
	if avail > 0:
		var chunk: Array = _peer.get_data(avail)
		if int(chunk[0]) == OK:
			_rx.append_array(chunk[1])
	# 단일 활성 런: busy면 다음 메시지를 처리하지 않는다.
	if _busy:
		return
	var nl: int = _rx.find(10)  # '\n'
	if nl == -1:
		return
	var line: PackedByteArray = _rx.slice(0, nl)
	_rx = _rx.slice(nl + 1)
	_handle(line.get_string_from_utf8())

func _handle(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		_send({"error": "bad request (not a JSON object)"})
		return
	var d: Dictionary = msg
	var cmd: String = str(d.get("cmd", ""))
	if cmd == "quit":
		_send({"bye": true})
		get_tree().quit(0)
		return
	if cmd == "ping":
		_send({"pong": true})
		return
	# 그 외 = plan → PlanRunner 실행. finished는 _process(다음 프레임들)에서 emit된다.
	_busy = true
	_runner = PlanRunner.new()
	add_child(_runner)
	# CONNECT_ONE_SHOT: 콜백 후 자동 해제 → 다음 plan은 새 PlanRunner+새 연결로 깔끔.
	_runner.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	_runner.run(d)

func _on_finished(result: Dictionary) -> void:
	_send(result)
	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()
	_runner = null
	_busy = false

func _send(d: Dictionary) -> void:
	if _peer == null:
		return
	var payload: PackedByteArray = (JSON.stringify(d) + "\n").to_utf8_buffer()
	_peer.put_data(payload)
