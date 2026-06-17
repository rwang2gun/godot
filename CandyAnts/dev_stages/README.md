# dev_stages/ — dev 테스트 레벨 (클러스터 콜로케이트)

게임 메커니즘/스킬을 수동·헤드리스로 검증하는 개발용 테스트 스테이지. 이전엔 3곳에 흩어져 있었다
(`scenes/stages/dev/`, `data/stages/dev/`, `data/stage_layouts/`). 이제 **레벨 1개 = 폴더 1개**로 모았다.

## 폴더 구조
```
dev_stages/<slug>/
  ├── <Scene>Test.tscn        # 실행 씬 (StageRunner + World + HUD)
  ├── <name>_test.tres        # StageData (개미 수·candy_hp·available_skills 등)
  └── dev_<name>_layout.tres  # StageLayoutData (타일/해저드 배치)
```
파일명은 이전과 동일(순수 relocation). 씬이 두 `.tres`를 `ext_resource`로 참조한다.

## 실행
```
python scripts/run_test.py dev_stages/<slug>/<Scene>Test.tscn
# 예: python scripts/run_test.py dev_stages/basher_wall/BasherWallTest.tscn
```
> 신규 클러스터 추가/이동 후엔 한 번 `python scripts/run_test.py --import`로 부트스트랩.

## 새 dev 레벨 추가 절차
1. `dev_stages/<slug>/` 폴더 생성, 그 안에 씬 + stage.tres + layout.tres 작성.
2. 씬의 `ext_resource path=`가 같은 폴더의 `.tres`를 가리키게.
3. 도메인 인덱스(`docs/DOMAIN_MAP.md` §3.2)에 한 줄 추가.

## 주의
- `tests/*.tscn` 헤드리스 단언 테스트가 여기 dev 씬을 `ext_resource`로 재사용한다. dev 씬을 **이동/리네임하면 `tests/`의 경로도 함께 갱신**할 것(현재 33개 테스트 씬이 의존).
- 씬 없이 `tests/*.gd`가 `preload`로만 쓰는 레이아웃(basher_edge_stop / cutter_edge_stop / cutter_over_hazard / earth_plant_separation)은 클러스터가 아니라 `data/stage_layouts/`에 남겨 둔다.
- 메인 스테이지(Stage01~03)는 레벨툴 애드온 경로 락 때문에 여기로 옮기지 않는다(`docs/DOMAIN_MAP.md` §3.1).

## 현재 클러스터 (21, 메커니즘 dev-test)
basher_wall · basher_digger_chain · digger_pillar · cutter_vine · bridge · bridge_over_overlap ·
bridge_over_water · bridge_reject · bridge_too_long · sand_mound · sand_bridge_overlap · static_ladder · water ·
water_after_candy · water_sticky_overlap · sticky · sticky_settle · settle · settle_race · settle_stuck · trait

> 레벨 재설계 rev2 캠페인 스테이지는 dev 초안이 아니라 **메인 슬롯(`scenes/stages/StageNN.tscn`)에 직접 통합**한다(경로 락 — 내용만 교체). S1 "첫 마실"은 stage01 슬롯 통합 완료. 절차/진척은 `docs/LEVEL_REDESIGN_STATUS.md` §3b·§6.
