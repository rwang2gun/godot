# sprite-polish STATUS

## 목적
스테이지/엔티티 아트 폴리싱. 배경, 지형 타일, spawn 입구, 엔티티 sprite anchor·collision 정합 등 시각 품질 작업.

## 현재 상태 (2026-05-17 기준)

### Production 에셋
- 원경 배경: `assets/illustrations/stage_bg_far.png`
  - 공통 `scenes/world/StageBackground.tscn`에서 참조 (CanvasLayer layer=-100)
  - Stage01~03에 인스턴스 연결됨
- 지형 타일 (얇은 충돌 + 풍부한 visual 2-layer 구조):
  - surface: `assets/sprites/terrain/cookie_tile_surface.png` + `_flip.png`
  - background: `assets/sprites/terrain/cookie_tile_background.png` + `_flip.png`
  - 렌더러: `scripts/world/CookiePlatformVisual.gd` (정방향/좌우반전 교차 반복)
  - collision height: Stage01~03 모두 12px (top y=880 유지, center=886)
- Spawn 입구: `assets/sprites/spawners/ant_hole.png` (지면 함정형 단일 구멍)
  - `scenes/entities/Home.tscn` 연결, `spawn_position_offset = Vector2(0, -5)`
- Builder bridge tile: `assets/sprites/terrain/thin_cookie_bridge_tile.png` (32x16)
  - `scripts/world/Terrain.gd`, sprite position y=-13 (collision top에 텍스처 bottom 정렬)

### 보존된 reference 에셋 (삭제 안 함)
- `assets/illustrations/stage_bg.svg` — 초기 SVG 배경, fallback/색 토큰용
- `assets/illustrations/stage_bg_painted.png` — full-scene reference, tile crop source
- `assets/sprites/home/ant_house.png` — 초기 집 visual, future goal/home 장식용
- `assets/sprites/spawners/ant_nest.png` — 양방향 굴 시안

### 핵심 결정 사항
1. SVG 배경은 production 미사용 (placeholder 수준)
2. 배경/지형/spawn 3 레이어 분리 (한 장 baked 금지)
3. 충돌 레이어는 얇게 유지, visual은 풍부하게 (캐릭터 발 기준선 = collision top, visual은 그 위·아래로 깔림)
4. 모든 stage `StageBackground.tscn` 공통 사용 (스테이지별 변주는 deferred)
5. 좌우반전 segment 교차로 반복 타일 seam 완화

## 다음 작업
- 실제 플레이 화면 캡처 QA (헤드리스 로딩만 통과, 캡처 QA 미수행)
  - HUD와 배경 장식 겹침
  - 캐릭터/캔디/spawn hole 시각 정합 (특히 surface_edge_offset 미세조정)
  - Stage02/03 카메라 framing
  - `TextureRect.stretch_mode = 6` 다른 화면비 대응
- thin tile 12px collision height의 fall/step/bridge 판정 회귀 테스트
- PNG import 설정 최적화 (mipmap, compression)

## 블로커
- Codex 샌드박스의 사용자 AppData 쓰기 제한 → editor cache 저장 실패 메시지 (프로젝트 import는 통과). 헤드리스 게임 실행 시 signal 11 crash 별도 환경 이슈로 기록 (2026-05-10 이후 사용자가 sandbox 처리, phase 7부터 codex 자동 review 적용 — memory 참조)

## 세션 로그
- [2026-05-16-stage-art-polishing.md](2026-05-16-stage-art-polishing.md) — 배경 교체 → 타일/spawn/캐릭터 anchor 정합 → 2-layer 타일 분리. 다회차 (`2026-05-17` 세션 포함)
