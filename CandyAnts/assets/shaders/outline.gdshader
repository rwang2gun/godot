shader_type canvas_item;
render_mode unshaded;

// 재사용 외곽선 글로우 (STAGE_GUIDE_PLAN §0.8.3-2).
// 개미 스프라이트(고해상도 PNG를 작게 축소 표시)·surface 타일에 적용. 외곽선 폭·색·펄스 알파를 uniform으로 노출.
// outline_width는 "텍스처 텍셀" 단위 — 화면 두께 = outline_width × 스프라이트 scale 이라, 축소 표시되는 개미는
// 호출부(AffordanceGlowController)가 화면 목표 두께 ÷ scale 로 환산해 큰 값을 넘긴다.
// 24방향 단일 링 샘플 → 두꺼운 폭에서도 별모양 틈 없이 외곽 밴드가 채워진다.
//
// 2-밴드(2026-06-07): inner_ratio>0 이면 캐릭터에 붙은 안쪽 띠를 inner_color(예: 흰색)로, 바깥을 outline_color로
// 칠해 어두운 캐릭터와 글로우의 경계를 분리한다. inner_ratio=0 이면 단일 밴드(기존 동작·surface 글로우).
// 주의: TAU·PI·E 는 Godot 셰이딩 언어 내장 상수 — 재정의 금지(컴파일 에러 'Redefinition of TAU').

uniform vec4 outline_color : source_color = vec4(0.94, 0.84, 0.48, 1.0); // 바깥 밴드(글로우)
uniform vec4 inner_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);      // 안쪽 띠(캐릭터 경계 분리)
uniform float outline_width : hint_range(0.0, 40.0) = 2.0;               // 전체 폭(텍셀)
uniform float inner_ratio : hint_range(0.0, 1.0) = 0.0;                  // 안쪽 흰 띠 비율(0=단일 밴드)
uniform float pulse_alpha : hint_range(0.0, 1.0) = 1.0;

const int DIRS = 24;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// 스프라이트 내부(불투명) 픽셀은 샘플링 생략 — 외곽선은 투명 영역에만 그린다.
	if (col.a >= 0.999) {
		COLOR = col;
	} else {
		vec2 tso = TEXTURE_PIXEL_SIZE * outline_width;                 // 바깥 링 반경
		vec2 tsi = TEXTURE_PIXEL_SIZE * (outline_width * inner_ratio); // 안쪽 링 반경
		float ao = 0.0;  // 바깥 링 max alpha (= outline_width 이내?)
		float ai = 0.0;  // 안쪽 링 max alpha (= inner 띠 이내?)
		for (int i = 0; i < DIRS; i++) {
			float ang = TAU * float(i) / float(DIRS);
			vec2 dir = vec2(cos(ang), sin(ang));
			ao = max(ao, texture(TEXTURE, UV + dir * tso).a);
			if (inner_ratio > 0.0) {
				ai = max(ai, texture(TEXTURE, UV + dir * tsi).a);
			}
		}
		float outline = clamp(ao - col.a, 0.0, 1.0);
		// 안쪽 띠(캐릭터에 가까움)=inner_color, 그 바깥=outline_color.
		float inner = clamp(ai - col.a, 0.0, 1.0);
		vec4 band = mix(outline_color, inner_color, inner);
		band.a *= outline * pulse_alpha;
		// 외곽선은 스프라이트 뒤로, 반투명 가장자리 픽셀은 그대로 블렌드.
		COLOR = mix(band, col, col.a);
	}
}
