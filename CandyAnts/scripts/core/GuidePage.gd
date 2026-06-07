class_name GuidePage extends Resource

# 가이드 카드의 "한 페이지" 메타 (new-user-onboarding · guide-card-ui-restructure).
# 스테이지별로 페이지 구성이 다르므로(스테이지마다 직접 저작), StageGuideData.pages에 순서대로 담는다.
# 텍스트(제목/본문)는 스크린샷 위에 오버레이로 렌더된다. 카피 문자열은 Strings.gd 중앙화 규칙을 따라
# key만 담고, 실제 문자열은 Strings.t(key)로 조회한다. image_path는 res:// 절대 경로.
#
# 레이아웃 필드(text_*/scrim_*/image_*)는 tools/guide_card_editor.html이 내보내는 JSON과 1:1 대응.
# 좌표/폭은 이미지 영역(ImageWrap) 기준 정규화 비율(0~1).

# 페이지에 깔리는 스크린샷 (res://assets/guide/*.png). 비어 있으면 이미지 없이 텍스트만.
@export var image_path: String = ""

# 페이지 제목 카피 key (Strings). 이미지 위 오버레이 상단.
@export var title_key: String = ""

# 페이지 본문 카피 key (Strings). 제목 아래(구분선 사이) 오버레이.
@export var body_key: String = ""

@export_group("Text Layout")
# 텍스트 박스 좌상단 위치 (이미지 영역 기준 정규화 0~1).
@export var text_x: float = 0.04
@export var text_y: float = 0.04
# 텍스트 박스 폭 (이미지 영역 폭 기준 정규화 0~1).
@export var text_width: float = 0.92
# 정렬: "left" / "center" / "right".
@export var text_align: String = "left"

@export_group("Scrim")
# 가독성용 반투명 배경 패널.
@export var scrim_enabled: bool = true
# 배경색(불투명 기준). 실제 렌더는 scrim_opacity를 알파로 적용.
@export var scrim_color: Color = Color(0.20, 0.129, 0.071)
@export var scrim_opacity: float = 0.62

@export_group("Image Transform")
# 스크린샷 크롭/줌/이동 — 줌(1=원본 cover), 좌우/상하 이동(-1~1).
@export var image_zoom: float = 1.0
@export var image_pan_x: float = 0.0
@export var image_pan_y: float = 0.0
