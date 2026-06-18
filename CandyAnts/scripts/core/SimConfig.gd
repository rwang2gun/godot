extends Node

# 솔버 결정론 모드 플래그 — 단일 SoT (auto-solver Phase 0).
#
# 기본 false → 게임 본체·기존 헤드리스 테스트 동작 완전 불변(옵트인).
# true이면 게임플레이 시계(스폰 grace·스폰/리스폰 타이밍·스테이지 타임아웃)를 벽시계(Time.get_ticks_msec)·
# 기본 idle Timer 대신 **물리-프레임 카운트**(Engine.get_physics_frames)로 통일한다. 목적: 헤드리스
# --fixed-fps 재생에서 "같은 입력 → per-frame 동일 결과"를 보장(솔버 인-더-루프 시뮬의 전제).
#
# 왜 프레임 카운트인가:
#   - 벽시계(get_ticks_msec)는 --fixed-fps에서 CPU 속도에 좌우 → 같은 물리 프레임 사이의 실시간 경과가
#     매 실행 달라져 grace 컷오프가 비결정적이 된다.
#   - Engine.get_physics_frames()는 프로세스-전역 단조 증가 물리 프레임 수로, time_scale·CPU 속도 불변.
#   - 물리는 고정 timestep(physics_ticks_per_second, 기본 60)이라 time_scale=1에서 "초 × 60 프레임" 환산이
#     기존 벽시계 동작과 일치 → 게임 동작 불변(프레임화는 결정론만 추가, 의미 불변).
#
# 켜는 법: env CANDYANTS_DETERMINISTIC=1 (run_plan.py·DeterminismReplayTest) 또는 set_deterministic(true).
# 끄는 법: 미설정(기본) 또는 set_deterministic(false). 배치 in-process 반복 사이 상태 누수 차단용 토글 지원.

var deterministic: bool = false

func _ready() -> void:
	if OS.get_environment("CANDYANTS_DETERMINISTIC") == "1":
		deterministic = true
	print("[SimConfig] deterministic=", deterministic)

func set_deterministic(value: bool) -> void:
	deterministic = value

# 초 → 물리 프레임 환산. physics_ticks_per_second(기본 60)를 라이브로 읽어 프로젝트 설정 override에도 정합.
# round로 환산해 time_scale=1에서 벽시계 grace(예: 0.4s)와 동일 프레임 수(24)를 보장한다.
func seconds_to_frames(seconds: float) -> int:
	return int(round(seconds * float(Engine.physics_ticks_per_second)))
