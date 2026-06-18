class_name SolverCapabilities extends Resource

# 전역 능력 명세 (auto-solver Phase 1, D7). 솔버가 게임 지식을 하드코딩하지 않도록,
# "엔진이 코드로만 아는 전역 사실"을 선언적으로 노출하는 단일 config. 스킬별 지식은
# 스킬 자신의 SOLVER_META(self-describing)에 있고, 여기엔 *스킬 무관 전역 기능*만 둔다.
#
# - pause/slow 유무: 난이도 모델이 반응-윈도우(실시간) vs 계획-복잡도(일시정지 가능)를 자동 선택(D6/D7).
#   현재 게임은 둘 다 없음 → 실시간 입력 전제.
# - input_methods: 입력 수단(난이도의 공간 조준·입력 행위 비용 반영, Phase 3).
# - T_human 티어(초): 반응-윈도우 폭을 인간 타당성으로 거르는 임계(Phase 3에서 캘리브레이션).
#   여기 값은 plan 미정 파라미터의 *기본값*이며, 사용자 라벨링으로 보정된다.
#
# 데이터 인스턴스: res://data/solver/capabilities.tres.

@export var has_pause: bool = false
@export var has_slow_motion: bool = false
@export var input_methods: Array[String] = ["mouse", "touch"]

# T_human 티어 — 예측 실행 정밀도(놀란-반응 아님). 윈도우 < 티어면 그만큼 어려움/기계전용.
@export var t_human_comfortable_s: float = 0.30
@export var t_human_hard_s: float = 0.15
@export var t_human_machine_only_s: float = 0.10
