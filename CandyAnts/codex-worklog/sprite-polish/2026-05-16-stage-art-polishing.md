---
name: codex-art-polishing
date: 2026-05-16
phase_scope: phase09 follow-up
sot: docs/UI_GUIDE.md
related_phase: phases/mvp/phase09-ui-theme-assets.md
status: implemented
---

# Phase 9 Follow-up: Codex Art Polishing

## 목적
Phase 9에서 들어간 `assets/illustrations/stage_bg.svg`는 Godot 임포트와 배경 연결 검증용으로는 충분했지만, 실제 캐릭터/캔디 PNG 스프라이트와 나란히 놓았을 때 퀄리티 차이가 컸다.

특히 현재 캐릭터 리소스는 고해상도 chibi/anime 렌더 스타일이고, 캔디 리소스도 보석 같은 페인터리 질감이 있다. 반면 기존 SVG 배경은 단순 벡터 placeholder에 가까워서 게임 화면의 전체 밀도를 낮추는 문제가 있었다.

본 follow-up은 배경 리소스를 재사용 가능한 씬 구조로 묶고, 이후 더 높은 품질의 페인터리 PNG 배경으로 교체한 작업 내역을 기록한다.

## 작업 요약

### 1. 기존 상태 확인
- 기존 production 배경 후보: `assets/illustrations/stage_bg.svg`
- 기존 스테이지 구성:
  - `scenes/stages/Stage01.tscn`
  - `scenes/stages/Stage02.tscn`
  - `scenes/stages/Stage03.tscn`
- 스테이지들은 단색 갈색 `Polygon2D` 발판만 사용하고 있었고, 별도의 배경 씬/레이어는 없었다.
- `stage_bg.svg.import`는 이미 Godot 4.6 texture import 설정을 갖고 있었다.

### 2. 재사용 가능한 배경 씬 추가
신규 씬:
- `scenes/world/StageBackground.tscn`

구성:
- root: `CanvasLayer`
- child: `TextureRect`
- `CanvasLayer.layer = -100`
- `TextureRect`는 full-rect anchor로 화면 전체를 채움
- `expand_mode = 1`
- `stretch_mode = 6`

설계 의도:
- 배경이 카메라 이동이나 스테이지 월드 좌표에 끌려 다니지 않도록 UI/화면 레이어로 분리
- 스테이지마다 동일한 배경 구조를 인스턴스해서 재사용
- 이후 스테이지별 배경 변주가 필요하면 `StageBackground.tscn` 내부 텍스처 교체 또는 파생 씬으로 확장 가능

### 3. Stage01~03에 배경 씬 연결
수정 파일:
- `scenes/stages/Stage01.tscn`
- `scenes/stages/Stage02.tscn`
- `scenes/stages/Stage03.tscn`

각 스테이지에 다음을 추가했다.
- `res://scenes/world/StageBackground.tscn` PackedScene ext_resource
- root 아래 `StageBackground` instance

노드 배치는 `World` 노드 직후에 두었다. `StageBackground` 자체가 `CanvasLayer`라 스테이지 월드의 물리/렌더 순서와 분리된다.

### 4. 1차 연결: 기존 SVG 배경 사용
초기 `StageBackground.tscn`은 아래 텍스처를 사용했다.

```gdscript
res://assets/illustrations/stage_bg.svg
```

이 단계의 목적은 새 리소스 제작 전, Godot 씬 구조와 재사용 방식이 정상 동작하는지 확인하는 것이었다.

### 5. 품질 이슈 판단
사용자 피드백:
- "배경은 잘 들어갔는데 캐릭터 이미지에 비해서 퀄리티가 안좋은 것 같아"

확인한 전경 리소스:
- `assets/sprites/characters/ant_pajama_girl/walk/walk_00.png`
- `assets/sprites/characters/ant_pajama_girl/idle/idle_00.png`
- `assets/sprites/candy/candy_00.png`

판단:
- 캐릭터와 캔디는 부드러운 페인터리 렌더, 하이라이트, 질감, 입체감이 있음
- 기존 SVG 배경은 단순 도형/그라데이션 중심이라 전경 리소스와 시각 밀도 차이가 큼
- 배경은 전경을 방해하지 않아야 하지만, 현재 수준은 "절제"라기보다 "placeholder"에 가까움

### 6. 고품질 페인터리 배경 생성
사용 도구:
- Codex built-in `imagegen`
- 사용한 스킬: `imagegen`

생성 프롬프트 요지:
- CandyAnts용 고품질 2D 게임 배경
- 16:9 horizontal composition
- polished anime/chibi game sprite와 어울리는 soft painterly rendering
- candy-themed environment
- gentle pastel sky, whipped cream/candy hills, cookie-and-chocolate ground
- pink gemstone candy accents
- no characters, no text, no UI, no logos
- center gameplay area는 작은 어두운 ant 캐릭터가 잘 보이도록 차분하게 유지
- 배경은 foreground보다 부드러운 edge를 사용해 캐릭터 가독성을 유지

원본 생성 위치:
- `C:\Users\code1412\.codex\generated_images\019e30b4-2847-7bb0-a03e-f4f7ed0ac849\ig_0c48fb451be8a014016a08678f11c881918eee23c0096d90a5.png`

프로젝트 반영 위치:
- `assets/illustrations/stage_bg_painted.png`

원본은 삭제하지 않고, 프로젝트에는 복사본을 둔다.

### 7. 배경 씬 텍스처 교체
수정 파일:
- `scenes/world/StageBackground.tscn`

변경 전:

```gdscript
res://assets/illustrations/stage_bg.svg
```

변경 후:

```gdscript
res://assets/illustrations/stage_bg_painted.png
```

기존 `Stage01/02/03`는 이미 `StageBackground`를 인스턴스하고 있으므로, 스테이지 파일을 다시 수정하지 않고도 새 PNG 배경이 전체 스테이지에 적용된다.

### 8. 기존 placeholder 발판 시각 숨김
사용자 화면 확인 결과, 새 배경의 앞쪽 cookie/chocolate platform이 기존 스테이지의 단색 갈색 `Polygon2D` 발판 시각 노드에 가려지는 문제가 있었다.

문제 원인:
- `StaticBody2D` 충돌체 자체가 아니라 그 자식 `Polygon2D`가 큰 갈색 사각형으로 렌더됨
- 이 사각형이 화면 하단 대부분을 덮어 새 배경의 전경 디테일을 가림

수정:
- 충돌체와 게임플레이 좌표는 유지
- placeholder visual-only `Polygon2D` 노드만 `visible = false` 처리

수정 노드:
- `scenes/stages/Stage01.tscn`
  - `World/Ground/GroundSprite`
- `scenes/stages/Stage02.tscn`
  - `World/LeftPlatform/Sprite`
  - `World/RightPlatform/Sprite`
  - `World/ChasmFloor/Sprite`
- `scenes/stages/Stage03.tscn`
  - `World/MainPlatform/Sprite`

후속 주의:
- Stage02/03은 물리 발판 구조가 배경에 baked된 단일 platform과 완전히 일치하지 않는다.
- 따라서 장기적으로는 스테이지별 platform visual sprite 또는 tile을 별도로 만들어야 한다.
- 이번 수정은 "큰 갈색 placeholder가 배경 앞단을 덮는 문제"를 우선 해소하는 임시 production fix다.

### 9. 개미집 시작 포인트 에셋 추가
사용자 피드백:
- 배경 속 왼쪽 candy house는 잘 보이지만, 실제 `Home` 시작 포인트/저장 지점으로 쓸 독립 에셋이 필요함
- 기존 `Home.tscn`은 32x32 갈색 `Polygon2D` placeholder라 배경/캐릭터 퀄리티와 맞지 않음

기존 상태:
- `scenes/entities/Home.tscn`
  - root: `Area2D`
  - collision: `RectangleShape2D(32, 32)`
  - visual: 갈색 `Polygon2D`
- `scripts/world/Home.gd`
  - `spawn_position_offset = Vector2(48, -32)`
  - 저장 판정과 스폰 위치 로직은 정상 동작 중이므로 시각만 교체하는 방향으로 진행

신규 에셋 생성:
- Codex built-in `imagegen`
- flat `#00ff00` chroma-key background로 생성
- 로컬 helper `remove_chroma_key.py`로 투명 PNG 변환
- 투명 변환 후 실제 오브젝트 bbox 기준으로 crop하여 과한 투명 여백 제거

생성 프롬프트 요지:
- cute ant-house starting point
- candy-themed chibi puzzle game
- cookie-biscuit house, chocolate icing roof
- candy cane arch doorway, round window
- warm painterly anime/chibi game art style
- no characters, no text, no UI
- isolated object with generous padding
- flat chroma-key background for removal

원본 생성 위치:
- `C:\Users\code1412\.codex\generated_images\019e30b4-2847-7bb0-a03e-f4f7ed0ac849\ig_0c48fb451be8a014016a086a0a9d88819184ca60c915d4b278.png`

프로젝트 반영:
- chroma-key source copy: `assets/sprites/home/ant_house_chromakey.png`
- high-resolution transparent source: `assets/sprites/home/ant_house_source.png`
- final transparent asset: `assets/sprites/home/ant_house.png`

투명 제거 결과:
- key color: `#04f917`
- transparent pixels: `918424/1573044`
- partially transparent pixels: `4706/1573044`

crop 결과:
- 원본 final transparent size: `1402x1122`
- alpha bbox: `(150, 62, 1242, 989)`
- padding 32 적용 crop box: `(118, 30, 1274, 1021)`
- 최종 크기: `1156x991`

runtime resize:
- high-resolution cropped transparent source는 `ant_house_source.png`로 보존
- 실제 `Home.tscn`에서 참조하는 `ant_house.png`는 표시 크기에 맞춰 `208x178`로 resize
- 이유: 큰 원본을 런타임 Sprite2D에 직접 물렸을 때 headless 실행 확인 중 Godot signal 11 crash가 발생했으며, 실게임 표시 크기 기준으로도 고해상도 원본을 직접 참조할 필요가 없음

`Home.tscn` 수정:
- `assets/sprites/home/ant_house.png`를 `Texture2D` ext_resource로 추가
- 기존 `Polygon2D` visual을 `Sprite2D`로 교체
- sprite scale: 기본값 `Vector2(1, 1)` (`ant_house.png` 자체가 runtime 표시 크기)
- sprite position: `Vector2(0, -89)`
- collision shape size: `Vector2(72, 96)`
- collision shape position: `Vector2(48, -48)`

좌표 의도:
- `Home` 원점은 집 바닥 중앙 근처로 유지
- 기존 `spawn_position_offset = Vector2(48, -32)`가 문 앞/문 내부 근처를 가리키도록 맞춤
- 충돌 영역도 문 주변에 맞춰 저장 지점으로 인식되도록 이동

## 산출물

신규 파일:
- `scenes/world/StageBackground.tscn`
- `assets/illustrations/stage_bg_painted.png`
- `assets/sprites/home/ant_house.png`
- `assets/sprites/home/ant_house_chromakey.png`
- `assets/sprites/home/ant_house_source.png`

Godot가 생성한 임포트 메타:
- `assets/illustrations/stage_bg_painted.png.import`
- `assets/sprites/home/ant_house.png.import`
- `assets/sprites/home/ant_house_chromakey.png.import`
- `assets/sprites/home/ant_house_source.png.import`

수정 파일:
- `scenes/stages/Stage01.tscn`
- `scenes/stages/Stage02.tscn`
- `scenes/stages/Stage03.tscn`
- `scenes/world/StageBackground.tscn`
- `scenes/entities/Home.tscn`

참고로 기존 SVG 배경은 삭제하지 않았다.
- `assets/illustrations/stage_bg.svg`

이 파일은 fallback/reference/색 토큰 검증용으로 남길 수 있다.

## 검증

### Godot headless editor load
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- 신규 `stage_bg_painted.png` reimport 수행 확인
- `assets/illustrations/stage_bg_painted.png.import` 생성 확인
- 스테이지/배경 씬 리소스 로딩 실패 없음
- placeholder 발판 시각 숨김 후에도 씬 로딩 실패 없음
- 신규 `ant_house.png` / `ant_house_chromakey.png` reimport 수행 확인
- `Home.tscn`의 `Texture2D` 리소스 참조 로딩 실패 없음

추가 확인:
- `scripts/run_test.py tests/Stage03HeadlessTest.tscn` 실행 시 Godot signal 11 crash 발생
- 단독 `res://scenes/entities/Home.tscn` headless 실행도 signal 11 crash 발생
- 이후 기존 테스트인 `tests/InputModeTrackerTest.tscn` 및 기존 `scenes/entities/Candy.tscn` 단독 headless 실행도 동일하게 signal 11 crash 발생
- 따라서 해당 crash는 이번 `Home` asset 변경 단독 회귀라기보다 현재 Codex/Godot headless runtime 환경 문제로 기록
- 에디터 headless import/load(`--editor --quit`)는 exit code 0으로 통과

주의:
- 출력에 `C:/Users/code1412/AppData/Roaming/Godot`, `C:/Users/code1412/AppData/Local/Godot` 관련 editor cache 저장 실패가 표시됨
- 이는 Codex 샌드박스가 사용자 AppData 경로 쓰기를 막아서 발생한 편집기 캐시 오류로 판단
- 프로젝트 리소스 임포트와 씬 로딩 자체는 완료됨

### 수동 이미지 확인
`assets/illustrations/stage_bg_painted.png`를 확인했다.

관찰:
- 캐릭터 스프라이트와 더 가까운 anime/chibi game art 톤
- 배경 중앙부는 비교적 밝고 차분해 gameplay area로 사용 가능
- 좌우에는 candy house, lollipop, candy crystal 등 장식 밀도가 있어 화면 풍성함을 보강
- 하단에는 cookie/chocolate platform이 있어 기존 갈색 Polygon2D 발판과 시각적으로 더 잘 맞음

`assets/sprites/home/ant_house.png`도 확인했다.

관찰:
- 배경 속 candy house와 같은 계열의 cookie/chocolate/candy cane 언어를 사용
- 투명 배경으로 분리되어 `Home.tscn` Sprite2D로 직접 사용 가능
- 문 위치가 기존 `spawn_position_offset` 방향과 대체로 일치
- 기존 32x32 갈색 사각형보다 시작 포인트 식별성이 크게 개선됨

## 남은 과제

### 1. 실제 게임 화면 캡처 QA
헤드리스 로딩은 통과했지만, 실제 플레이 화면 캡처 기반 QA는 아직 별도 수행하지 않았다.

확인할 항목:
- HUD와 배경 장식이 겹쳐 보이지 않는지
- 캐릭터가 밝은 중앙부에서 충분히 읽히는지
- Stage02/03처럼 카메라 위치가 다른 스테이지에서도 배경 framing이 자연스러운지
- `TextureRect.stretch_mode = 6`이 목표 해상도와 다른 화면비에서도 적절히 동작하는지
- `Home` sprite scale/position이 Stage01~03에서 모두 적절한지
- `Home` collision shape가 문 주변 저장 판정으로 충분히 자연스러운지

### 2. 지형 비주얼 정리
현재 물리 발판은 여전히 `Polygon2D` 단색 갈색이다.

후속 개선 후보:
- cookie/chocolate ground tile sprite 제작
- platform별 top/bottom texture 분리
- collision shape는 그대로 두고 visual-only tile 또는 Polygon2D material 교체
- Stage02 chasm, Stage03 main platform에 맞는 edge decoration 추가

### 3. 스테이지별 배경 변주
현재 Stage01~03은 동일 배경을 공유한다.

후속 개선 후보:
- Stage01: 기본 candy valley
- Stage02: chasm/bridge 강조 배경
- Stage03: reverse route 또는 candy mine 방향 변주
- `StageBackground.tscn`에 exported texture script를 붙이거나 stage별 inherited scene으로 분기

### 4. PNG 임포트 설정 최적화
현재 Godot 기본 PNG import는 `compress/mode=0`, `mipmaps/generate=false`로 생성됐다.

검토 후보:
- 카메라/화면 스케일 변동이 크면 mipmap 활성화
- 메모리 절감이 필요하면 compression policy 별도 결정
- 배경은 큰 이미지이므로 target platform별 VRAM/로드 시간 확인 필요

## 결정 사항
- 단순 SVG 배경은 production main background로 쓰지 않는다.
- `StageBackground.tscn`은 모든 MVP 스테이지의 공통 배경 entry point로 사용한다.
- 현재 production background texture는 `assets/illustrations/stage_bg_far.png`이다.
- 현재 production home/start texture는 `assets/sprites/home/ant_house.png`이다.
- 기존 `stage_bg.svg`는 삭제하지 않고 reference/fallback으로 보존한다.

## 2026-05-16 추가 수정: 배경/바닥/집 분리

사용자 피드백:
- 새 `Home` 개미집을 얹으니 배경 안에 baked 된 집과 실제 `Home`이 이중으로 보임
- 배경 안에 바닥까지 baked 되어 있어서, Stage02처럼 끊어진 플랫폼/다리 구간을 읽기 어려움
- 바닥 타일과 배경을 분리해야 함

### 문제 원인
- `stage_bg_painted.png`는 원경, 왼쪽 집, 전경 바닥이 한 이미지에 모두 포함된 full scene illustration이었다.
- 이후 실제 게임 오브젝트로 `Home.tscn` 개미집과 충돌 플랫폼을 얹으면서 baked foreground와 runtime foreground가 중복됐다.
- 특히 Stage02는 실제 충돌체가 `LeftPlatform`/`RightPlatform`으로 끊겨 있는데, 배경에는 연속 바닥처럼 보이는 영역이 있어 다리 제작 위치가 직관적이지 않았다.

### 수정 1: 원경 전용 배경으로 교체
신규 배경:
- `assets/illustrations/stage_bg_far.png`

생성 의도:
- background only
- no foreground platform
- no walkable floor
- no house / no door
- lower 25%는 별도 platform tile이 올라갈 수 있도록 비교적 비워둠
- distant candy hills, whipped cream hills, clouds, crystals 위주

수정:
- `scenes/world/StageBackground.tscn`
  - texture 변경: `stage_bg_painted.png` → `stage_bg_far.png`

보존:
- `assets/illustrations/stage_bg_painted.png`는 삭제하지 않고 이전 full-scene reference로 남김

### 수정 2: 충돌 플랫폼용 별도 비주얼 추가
신규 스크립트:
- `scripts/world/CookiePlatformVisual.gd`

역할:
- `StaticBody2D` 충돌체와 동일한 크기의 visible platform을 `_draw()`로 그림
- 쿠키색 상단 타일, 초콜릿 하부, 타일 seam, 드립, 하단 음영을 표시
- 실제 충돌은 기존 `CollisionShape2D`가 담당하고, 본 스크립트는 visual-only

적용:
- `scenes/stages/Stage01.tscn`
  - `World/Ground/PlatformVisual`
  - `platform_size = Vector2(1920, 200)`
- `scenes/stages/Stage02.tscn`
  - `World/LeftPlatform/PlatformVisual`
  - `World/RightPlatform/PlatformVisual`
  - 둘 다 `platform_size = Vector2(880, 216)`
  - 중앙 gap 160px이 시각적으로 드러남
- `scenes/stages/Stage03.tscn`
  - `World/MainPlatform/PlatformVisual`
  - `platform_size = Vector2(1220, 216)`

기존 placeholder `Polygon2D`는 계속 `visible = false` 유지.

### 수정 3: 빌더 Terrain 타일 색상 조정
수정 파일:
- `scripts/world/Terrain.gd`

변경:
- 기존 builder tile 색상: green `Color(0.4, 0.7, 0.3, 1)`
- 변경 후:
  - top: `#D99A4A`
  - underside: `#5D3328`

의도:
- Stage02에서 빌더가 놓는 다리 타일이 기존 초록 임시 타일이 아니라 쿠키/초콜릿 플랫폼과 같은 계열로 보이도록 함
- 다리 제작 구간과 완성된 다리가 배경과 분리되어 읽히도록 함

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `CookiePlatformVisual` class 등록 확인
- `Terrain` script 재등록 확인
- `stage_bg_far.png` reimport 확인
- 스테이지 씬 리소스 참조/스크립트 parse error 없음

주의:
- 기존과 동일하게 AppData editor cache 저장 실패 메시지는 출력됨
- 이는 Codex 샌드박스의 사용자 AppData 쓰기 제한으로 판단하며, 프로젝트 리소스 임포트/스크립트 로딩은 완료됨

## 2026-05-16 추가 수정: 전경 타일 고퀄리티 대응

사용자 피드백:
- 원경 배경은 좋아졌지만, 앞쪽 바닥 타일이 단색 절차형 도형이라 배경/캐릭터 퀄리티와 맞지 않음

### 수정 방향
새로 생성한 full-scene reference였던 `stage_bg_painted.png`에는 고퀄리티 쿠키/초콜릿 플랫폼 질감이 있었으므로, 이를 삭제하지 않고 terrain source로 재활용했다.

신규 terrain texture:
- `assets/sprites/terrain/cookie_platform_segment.png`
  - `stage_bg_painted.png`의 중앙 플랫폼 영역에서 crop
  - platform visual이 반복 렌더링할 320x220 segment
- `assets/sprites/terrain/cookie_bridge_tile.png`
  - 동일 source에서 crop 후 32x32로 resize
  - builder bridge tile이 16x16 표시 크기로 사용

### 수정 1: CookiePlatformVisual 텍스처 반복 렌더링
수정 파일:
- `scripts/world/CookiePlatformVisual.gd`

변경 전:
- `_draw()`에서 단색 rect, 선, 간단한 drip을 절차적으로 그림

변경 후:
- `cookie_platform_segment.png`를 `load()`로 읽고, platform width에 맞춰 반복 렌더링
- `draw_texture_rect_region()`으로 마지막 partial segment도 잘라서 그림

주의:
- 초기 구현은 `preload("res://assets/sprites/terrain/cookie_platform_segment.png")`를 사용했으나, Godot 첫 임포트/스크립트 컴파일 순서에서 PNG resource loader가 아직 준비되지 않은 타이밍에 parse error가 발생할 수 있었다.
- 따라서 런타임 `load()`로 전환했다.

### 수정 2: Builder Terrain tile 텍스처화
수정 파일:
- `scripts/world/Terrain.gd`

변경 전:
- builder tile visual은 `Polygon2D` 단색 쿠키색 + 하부 초콜릿색

변경 후:
- `Sprite2D`에 `cookie_bridge_tile.png`를 적용
- source 32x32를 `scale = Vector2(0.5, 0.5)`로 표시해 기존 16x16 collision cell과 맞춤
- 이 참조도 `preload()` 대신 `load()` 사용

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `cookie_bridge_tile.png` / `cookie_platform_segment.png` import 확인
- `CookiePlatformVisual` / `Terrain` script class update 확인
- PNG `preload()` parse error 제거 확인

## 2026-05-16 추가 수정: 타일/오브젝트/캐릭터 기준선 보정

사용자 피드백:
- 고퀄 플랫폼 텍스처를 넣은 뒤에도 캐릭터와 오브젝트가 타일 위에 자연스럽게 앉지 않음
- 텍스처의 실제 쿠키 앞 모서리와 충돌 상단선이 어긋나서, 캐릭터가 타일 이미지의 위쪽 경계에 붙어 있는 것처럼 보임

### 수정 방향
플랫폼 충돌체의 상단선을 "캐릭터 발/오브젝트 바닥 기준선"으로 유지하되, 플랫폼 텍스처 내부의 쿠키 앞 모서리가 그 선에 오도록 비주얼만 위로 당겼다.

수정 파일:
- `scripts/world/CookiePlatformVisual.gd`
- `scenes/stages/Stage01.tscn`
- `scenes/stages/Stage02.tscn`
- `scenes/stages/Stage03.tscn`

### 수정 1: 플랫폼 텍스처 기준선 추가
`CookiePlatformVisual.gd`에 다음 export를 추가했다.

```gdscript
@export var surface_edge_offset: float = 48.0
```

렌더링 시 destination y를 다음처럼 보정한다.

```gdscript
Vector2(cursor_x, -half.y - surface_edge_offset)
```

의도:
- 충돌체 top은 그대로 유지
- 텍스처만 48px 위로 이동
- `cookie_platform_segment.png` 안의 쿠키 앞 모서리가 실제 walkable/collision line에 가까워짐

### 수정 2: Stage01 좌표 보정
- `Ground/PlatformVisual.surface_edge_offset = 48.0`
- `Home.position`: `Vector2(200, 880)` → `Vector2(180, 880)`
- `Candy.position`: `Vector2(1700, 880)` → `Vector2(1700, 894)`
- `Spawner.spawn_position`: `Vector2(248, 875)` → `Vector2(262, 875)`

의도:
- 집을 왼쪽 여백 쪽으로 조금 빼서 첫 ant와 문이 겹치는 느낌 완화
- candy는 플랫폼 위에 떠 보이지 않도록 조금 내림
- spawn은 문 밖/플랫폼 위에서 시작하도록 조정

### 수정 3: Stage02 좌표 보정
- `LeftPlatform/PlatformVisual.surface_edge_offset = 48.0`
- `RightPlatform/PlatformVisual.surface_edge_offset = 48.0`
- `Home.position`: `Vector2(300, 880)` → `Vector2(240, 880)`
- `Candy.position`: `Vector2(1620, 880)` → `Vector2(1620, 894)`
- `Spawner.spawn_position`: `Vector2(348, 875)` → `Vector2(322, 875)`

의도:
- 집/스폰이 왼쪽 플랫폼 위에서 더 자연스럽게 시작
- 오른쪽 candy도 플랫폼 접지감 보강
- 중앙 gap은 기존 충돌체 위치를 유지하므로 다리 구간 가독성 유지

### 수정 4: Stage03 좌표 보정
- `MainPlatform/PlatformVisual.surface_edge_offset = 48.0`
- `Home.position`: `Vector2(1700, 880)` → `Vector2(1710, 880)`
- `Candy.position`: `Vector2(700, 880)` → `Vector2(700, 894)`
- `Spawner.spawn_position`: `Vector2(1652, 875)` → `Vector2(1662, 875)`

의도:
- Stage03의 reverse route에서도 집/스폰 기준선을 동일하게 유지
- candy 접지감 보강

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `CookiePlatformVisual.gd` parse/load 성공
- Stage01~03 scene resource load 성공

남은 확인:
- 실제 플레이 화면에서 ant foot baseline, house bottom, candy bottom을 한 번 더 눈으로 확인해야 함
- 필요 시 `surface_edge_offset`만 stage 공통으로 4~8px 단위 미세 조정하면 됨

## 2026-05-16 추가 수정: Candy 피벗/충돌/배치 보정

사용자 피드백:
- 캔디가 플랫폼 위에 자연스럽게 놓이지 않고, 개미 보행선과 과하게 겹쳐 보임

### 문제 원인
`scripts/world/Candy.gd`는 candy sprite가 bottom-center anchor처럼 동작한다고 가정한다.

```gdscript
_base_offset = _sprite.position
_sprite.position = _base_offset * ratio
```

즉 HP 감소로 scale이 줄어들 때도 sprite 하단이 node origin에 고정되어야 한다. 하지만 기존 `Candy.tscn`은 다음 값이었다.

```gdscript
Sprite.position = Vector2(0, -48)
Sprite.scale = Vector2(0.5, 0.5)
```

원본 candy frame은 약 `249x257`이고, scale `0.5` 기준 렌더 높이는 약 `128px`이다. 이때 sprite bottom은 `-48 + 64 = +16`이 되어 node origin보다 16px 아래로 내려간다. 그래서 stage에서 candy node를 바닥선에 맞추면 실제 보석은 플랫폼 안으로 박히고, y를 내려서 보정하면 개미와 더 많이 겹쳤다.

### 수정
수정 파일:
- `scenes/entities/Candy.tscn`
- `scenes/stages/Stage01.tscn`
- `scenes/stages/Stage02.tscn`
- `scenes/stages/Stage03.tscn`

`Candy.tscn`:
- `Sprite.position`: `Vector2(0, -48)` → `Vector2(0, -64)`
- `CollisionShape2D.position`: `Vector2(0, 0)` → `Vector2(0, -44)`
- `RectangleShape2D.size`: `Vector2(24, 16)` → `Vector2(88, 88)`

의도:
- sprite bottom이 node origin 근처에 오도록 조정
- node origin을 candy의 바닥 접점으로 사용
- 충돌 영역은 작은 24x16 marker가 아니라 보석 본체 중심부를 덮도록 확대

Stage candy y:
- Stage01: `Vector2(1700, 894)` → `Vector2(1700, 880)`
- Stage02: `Vector2(1620, 894)` → `Vector2(1620, 880)`
- Stage03: `Vector2(700, 894)` → `Vector2(700, 880)`

의도:
- 모든 stage에서 candy node origin을 platform collision top/baseline에 맞춤
- 이후 candy visual anchor는 `Candy.tscn` 내부에서 일관되게 관리

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `Candy.tscn` resource load 성공
- Stage01~03 scene resource load 성공

## 2026-05-16 추가 수정: 얇은 타일 구조와 양방향 개미굴 입구

사용자 피드백:
- 두꺼운 일러스트 플랫폼 구조는 복층 레벨 디자인에 맞지 않음
- Builder가 만드는 다리처럼 얇은 타일 구조가 더 읽기 좋음
- 기존 개미집은 예쁘지만 "스폰 입구"라기보다 집처럼 보여, 양방향 스폰 대응이 어색함
- 처음 의도는 개미굴/터널 입구였음

### 결정
- 전경 지형은 두꺼운 플랫폼 일러스트가 아니라 얇은 쿠키 판 구조로 전환
- 기존 `Home` visual은 현재 stage에서는 개미굴 입구로 교체
- 집 에셋(`assets/sprites/home/ant_house.png`)은 삭제하지 않고 향후 goal/home 장식으로 보존
- 스폰은 중앙/양방향 출구가 있는 낮은 굴 visual과 연결

### 신규 얇은 타일 에셋
기존 고퀄 플랫폼 source에서 얇은 상단 판만 잘라 terrain tile로 재구성했다.

신규 파일:
- `assets/sprites/terrain/thin_cookie_floor_segment.png`
  - 크기: `320x76`
  - 얇은 쿠키 보행판 visual
- `assets/sprites/terrain/thin_cookie_bridge_tile.png`
  - 크기: `32x16`
  - Builder가 놓는 다리 tile visual

수정:
- `scripts/world/CookiePlatformVisual.gd`
  - texture source: `cookie_platform_segment.png` → `thin_cookie_floor_segment.png`
  - `surface_edge_offset` 제거
  - platform collision top과 thin tile top이 직접 맞도록 렌더링
- `scripts/world/Terrain.gd`
  - builder tile texture: `cookie_bridge_tile.png` → `thin_cookie_bridge_tile.png`
  - `Sprite2D.scale = Vector2(0.5, 0.5)` 제거
  - texture 자체가 32x16이며, 기존 16x16 collision보다 약간 넓게 보여 다리 조각이 더 읽히도록 함

### 신규 개미굴 입구 에셋
사용 도구:
- Codex built-in `imagegen`
- chroma-key `#00ff00` 생성 후 `remove_chroma_key.py`로 투명화
- crop 후 runtime size로 축소

생성 프롬프트 요지:
- low ant burrow / tunnel entrance
- cookie crumbs and chocolate soil mound
- two dark tunnel openings facing left and right
- candy pebble accents
- spawn entrance, not a house
- painterly anime/chibi candy game style

신규 파일:
- `assets/sprites/spawners/ant_nest_chromakey.png`
- `assets/sprites/spawners/ant_nest_source.png`
- `assets/sprites/spawners/ant_nest.png`

처리 결과:
- chroma key: `#08f916`
- transparent pixels: `1102690/1572864`
- partially transparent pixels: `2629/1572864`
- alpha bbox: `(65, 225, 1454, 764)`
- cropped source size: `1437x587`
- runtime size: `176x72`

### Home visual을 개미굴로 교체
수정 파일:
- `scenes/entities/Home.tscn`
- `scripts/world/Home.gd`

변경:
- `Home.tscn` texture: `assets/sprites/home/ant_house.png` → `assets/sprites/spawners/ant_nest.png`
- `Sprite.position`: `Vector2(0, -89)` → `Vector2(0, -36)`
- `CollisionShape2D.size`: `Vector2(72, 96)` → `Vector2(120, 48)`
- `CollisionShape2D.position`: `Vector2(48, -48)` → `Vector2(0, -24)`
- `Home.spawn_position_offset`: `Vector2(48, -32)` → `Vector2(0, -16)`

의도:
- 낮은 굴 visual의 bottom이 tile baseline에 맞음
- 저장 판정 영역도 굴 중앙/입구 주변을 덮음
- StageRunner가 future stage에서 `Spawner.spawn_position == Vector2.ZERO`일 때 굴 중앙 위쪽에서 스폰하도록 기본값 정리

### Stage01~03 얇은 플랫폼 전환
기존 플랫폼 top y=880은 유지하고, collision body 높이만 얇게 변경했다.

Stage01:
- `Ground.position`: `Vector2(960, 980)` → `Vector2(960, 892)`
- `ground_shape.size`: `Vector2(1920, 200)` → `Vector2(1920, 24)`
- `PlatformVisual.platform_size`: `Vector2(1920, 200)` → `Vector2(1920, 24)`
- `Spawner.spawn_position`: `Vector2(262, 875)` → `Vector2(180, 875)`

Stage02:
- `platform_shape.size`: `Vector2(880, 216)` → `Vector2(880, 24)`
- `LeftPlatform.position`: `Vector2(440, 988)` → `Vector2(440, 892)`
- `RightPlatform.position`: `Vector2(1480, 988)` → `Vector2(1480, 892)`
- 각 `PlatformVisual.platform_size`: `Vector2(880, 216)` → `Vector2(880, 24)`
- `Spawner.spawn_position`: `Vector2(322, 875)` → `Vector2(240, 875)`

Stage03:
- `platform_shape.size`: `Vector2(1220, 216)` → `Vector2(1220, 24)`
- `MainPlatform.position`: `Vector2(1210, 988)` → `Vector2(1210, 892)`
- `PlatformVisual.platform_size`: `Vector2(1220, 216)` → `Vector2(1220, 24)`
- `Spawner.spawn_position`: `Vector2(1662, 875)` → `Vector2(1710, 875)`

의도:
- top collision y=880은 그대로 유지해 기존 ant/candy/home 기준선을 크게 흔들지 않음
- 지형의 두께를 줄여 복층 구조를 만들 공간 확보
- Stage02의 gap과 builder bridge 필요 위치를 더 명확하게 표시

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `ant_nest.png`, `ant_nest_chromakey.png`, `ant_nest_source.png` import 확인
- `thin_cookie_floor_segment.png`, `thin_cookie_bridge_tile.png` import 확인
- `CookiePlatformVisual`, `Home`, `Terrain` class update 확인
- Stage01~03 scene resource load 성공

남은 확인:
- 실제 플레이 화면에서 굴의 좌우 입구와 양방향 스폰 방향이 직관적으로 읽히는지 확인
- thin tile collision height `24px`가 추후 fall/step/bridge 판정과 잘 맞는지 회귀 테스트 필요

## 2026-05-16 추가 수정: 타일 추가 슬림화

사용자 피드백:
- 얇은 타일 구조로 바꿨지만 아직 시각적으로 두꺼움
- 복층 레벨을 만들려면 더 가벼운 판처럼 보여야 함

### 수정
기존 `thin_cookie_floor_segment.png`는 `320x76`으로, 아직 쿠키 블록 하부가 많이 포함되어 있었다. 이를 더 얇게 다시 crop했다.

변경:
- `assets/sprites/terrain/thin_cookie_floor_segment.png`
  - `320x76` → `320x36`
  - 상단 판과 아주 얕은 쿠키 립만 남김
- `assets/sprites/terrain/thin_cookie_bridge_tile.png`
  - `32x16` → `32x10`
  - Builder bridge visual도 더 얇은 판으로 통일

Stage collision:
- Stage01 `ground_shape.size`: `Vector2(1920, 24)` → `Vector2(1920, 12)`
- Stage01 `Ground.position`: `Vector2(960, 892)` → `Vector2(960, 886)`
- Stage01 `PlatformVisual.platform_size`: `Vector2(1920, 24)` → `Vector2(1920, 12)`
- Stage02 `platform_shape.size`: `Vector2(880, 24)` → `Vector2(880, 12)`
- Stage02 `LeftPlatform/RightPlatform.position.y`: `892` → `886`
- Stage02 `PlatformVisual.platform_size`: `Vector2(880, 24)` → `Vector2(880, 12)`
- Stage03 `platform_shape.size`: `Vector2(1220, 24)` → `Vector2(1220, 12)`
- Stage03 `MainPlatform.position.y`: `892` → `886`
- Stage03 `PlatformVisual.platform_size`: `Vector2(1220, 24)` → `Vector2(1220, 12)`

의도:
- platform top y=880은 유지
- collision center만 `top + height/2`에 맞춰 올림
- 캐릭터/캔디/굴 기준선은 그대로 두고 지형 두께만 줄임

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- slimmed `thin_cookie_floor_segment.png` / `thin_cookie_bridge_tile.png` reimport 확인
- Stage01~03 scene resource load 성공

## 2026-05-16 추가 수정: 스폰 입구를 단일 지면 구멍으로 변경

사용자 피드백:
- 양방향 개미굴도 여전히 오브젝트 덩어리처럼 보여, 중앙에서 생성되는 느낌이 의미 있게 읽히지 않음
- 원하는 것은 집/굴 mound가 아니라, 땅에 있는 함정 같은 단일 개미구멍
- 개미가 "집 중앙"이 아니라 "바닥 구멍"에서 생성되는 것으로 보여야 함

### 신규 에셋
사용 도구:
- Codex built-in `imagegen`
- chroma-key `#00ff00` 생성 후 `remove_chroma_key.py`로 투명화
- crop 후 runtime size로 축소

생성 프롬프트 요지:
- single small ant hole in the ground
- trap/pit opening on a cookie floor
- low dark oval hole facing upward
- thin crumb rim and tiny cookie crumbs
- no mound, no house, no tunnel building, no multiple entrances
- simple spawn hole embedded in the floor

신규 파일:
- `assets/sprites/spawners/ant_hole_chromakey.png`
- `assets/sprites/spawners/ant_hole_source.png`
- `assets/sprites/spawners/ant_hole.png`

처리 결과:
- chroma key: `#04f822`
- transparent pixels: `1446028/1572864`
- partially transparent pixels: `1499/1572864`
- alpha bbox: `(346, 452, 1198, 686)`
- cropped source size: `900x282`
- runtime size: `96x30`

### Home visual/스폰 기준 수정
수정 파일:
- `scenes/entities/Home.tscn`
- `scripts/world/Home.gd`

변경:
- `Home.tscn` texture: `assets/sprites/spawners/ant_nest.png` → `assets/sprites/spawners/ant_hole.png`
- `Sprite.position`: `Vector2(0, -36)` → `Vector2(0, -15)`
- `CollisionShape2D.size`: `Vector2(120, 48)` → `Vector2(64, 24)`
- `CollisionShape2D.position`: `Vector2(0, -24)` → `Vector2(0, -12)`
- `Home.spawn_position_offset`: `Vector2(0, -16)` → `Vector2(0, -5)`

의도:
- visual이 바닥선 위에 낮게 붙음
- 중앙 생성도 "구멍에서 나오는 것"으로 읽히게 함
- 저장/귀환 판정 영역도 구멍 주변의 작은 영역으로 축소
- 기존 `ant_nest.png`와 `ant_house.png`는 삭제하지 않고 reference/future use로 보존

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `ant_hole.png`, `ant_hole_chromakey.png`, `ant_hole_source.png` import 확인
- `Home` class update 확인
- `Home.tscn` resource load 성공

## 2026-05-16 추가 수정: 타일 배경/충돌 타일 레이어 기준 정리

사용자 레퍼런스:
- 캐릭터가 타일 이미지의 최상단에 서는 구조가 아니라, 타일 배경이 캐릭터 뒤쪽에 깔리고 실제 충돌 타일은 그 아래 얇은 레이어로 분리된 구조
- 즉 "타일 배경"과 "충돌 타일"을 시각적으로/개념적으로 분리해야 함

### 문제
이전 구현은 `CookiePlatformVisual`이 플랫폼 충돌체의 top y부터 텍스처를 그렸다.

결과:
- 캐릭터가 타일 이미지의 맨 위 테두리에 서는 느낌
- 타일 배경이 캐릭터 뒤로 들어가지 못함
- Builder bridge도 같은 기준선으로 읽히지 않음

### 수정
수정 파일:
- `scripts/world/CookiePlatformVisual.gd`
- `scripts/world/Terrain.gd`

`CookiePlatformVisual.gd`:
- `platform_size`는 여전히 충돌 타일 크기
- local collision top: `-platform_size.y / 2`
- `thin_cookie_floor_segment.png`는 collision top 위쪽에 배치
- 텍스처 하단이 collision top에 맞도록 변경

핵심 코드:

```gdscript
var collision_top_y: float = -half.y
var dst: Rect2 = Rect2(
    Vector2(cursor_x, collision_top_y - source_size.y),
    Vector2(draw_w, source_size.y)
)
```

의도:
- collision tile은 얇은 판정 레이어로 남김
- tile background는 그 위쪽, 캐릭터 뒤에 깔림
- 캐릭터 발 기준선은 collision top

`Terrain.gd`:
- Builder가 놓는 `thin_cookie_bridge_tile.png`도 16px collision cell의 top에 texture bottom이 닿도록 이동

```gdscript
sprite.position = Vector2(0, -13)
```

의도:
- builder bridge도 기본 플랫폼과 같은 "배경 타일 위 + 충돌 타일 아래" 구조로 읽힘

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `CookiePlatformVisual` class update 확인
- `Terrain` class update 확인
- Stage scene resource load 성공

## 2026-05-16 추가 수정: 얇은 충돌 유지 + 풍부한 타일 이미지 복원

사용자 피드백:
- 충돌 구조가 얇아진 것은 좋지만, 보이는 타일 이미지까지 너무 얇아져 아쉬움
- 얇은 판정 구조는 유지하면서 타일 부분에도 충분한 이미지 정보가 있으면 좋겠음

### 수정
collision은 12px thin tile 구조로 유지하고, visual texture만 다시 더 풍부한 crop으로 교체했다.

변경:
- `assets/sprites/terrain/thin_cookie_floor_segment.png`
  - `320x36` → `320x76`
  - 상단 쿠키 표면 + 쿠키 립 + 약간의 하부 질감 복원
- `assets/sprites/terrain/thin_cookie_bridge_tile.png`
  - `32x10` → `32x16`
  - builder bridge도 너무 납작하지 않게 조정

중요:
- Stage01~03 collision height는 여전히 `12px`
- `CookiePlatformVisual`은 visual texture bottom을 collision top에 맞추므로, visual은 캐릭터 뒤쪽으로 풍부하게 깔리고 실제 판정은 얇게 유지됨

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `thin_cookie_floor_segment.png` / `thin_cookie_bridge_tile.png` reimport 확인
- Stage scene resource load 성공

## 2026-05-16 추가 수정: 반복 타일 이음새 완화

사용자 스크린샷 확인:
- 타일 구조 자체는 가까워졌지만, `thin_cookie_floor_segment.png`가 반복되는 지점이 세로 경계로 뚜렷하게 보임
- 이는 source segment 좌우 끝의 명도/패턴이 다르기 때문

### 수정
신규 파일:
- `assets/sprites/terrain/thin_cookie_floor_segment_flip.png`

내용:
- `thin_cookie_floor_segment.png`의 좌우 반전 버전

수정 파일:
- `scripts/world/CookiePlatformVisual.gd`

변경:
- 플랫폼 segment를 항상 같은 방향으로 반복하지 않고, 정방향/좌우반전을 번갈아 렌더링

의도:
- 정방향 오른쪽 edge 다음에는 flip texture의 왼쪽 edge가 오는데, 이는 원본 오른쪽 edge라 서로 자연스럽게 맞음
- 다음 seam도 flip 오른쪽 edge(원본 왼쪽 edge)와 정방향 왼쪽 edge가 맞음
- 별도 복잡한 shader 없이 세그먼트 경계감을 줄임

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `thin_cookie_floor_segment_flip.png` import 확인
- `CookiePlatformVisual.gd` load 성공

## 2026-05-17 추가 수정: 타일 표면과 타일 배경 분리

사용자 피드백:
- `thin_cookie_floor_segment.png` 한 장 안에 걸을 수 있는 타일 표면과 그 아래 쿠키 배경/립이 같이 들어 있음
- 이 구조에서는 구멍, 캐릭터, 목표물과의 깊이 관계를 따로 조절하기 어려움
- 타일과 타일의 배경을 분리해야 함

### 수정 방향
기존 한 장짜리 tile texture를 두 레이어로 분리했다.

레이어:
- tile surface: gameplay baseline 위쪽에 깔리는 얇은 보행 표면
- tile background: gameplay baseline 아래쪽에 깔리는 쿠키 립/배경 장식

신규 파일:
- `assets/sprites/terrain/cookie_tile_surface.png`
- `assets/sprites/terrain/cookie_tile_surface_flip.png`
- `assets/sprites/terrain/cookie_tile_background.png`
- `assets/sprites/terrain/cookie_tile_background_flip.png`

생성 방식:
- source: `assets/sprites/terrain/thin_cookie_floor_segment.png`
- surface crop: `y=0..24`
- background crop: `y=24..end`
- 각각 좌우반전 variant 생성

### 렌더러 수정
수정 파일:
- `scripts/world/CookiePlatformVisual.gd`

변경 전:
- `thin_cookie_floor_segment.png` / flip 한 쌍을 한 번에 그림

변경 후:
- surface texture와 background texture를 별도로 load
- 같은 x segment에서 background를 먼저 그리고, surface를 나중에 그림
- 정방향/좌우반전 반복 방식은 유지

배치 기준:
- `collision_top_y = -platform_size.y / 2`
- surface:
  - `y = collision_top_y - surface_height`
  - collision top 위에 배치
- background:
  - `y = collision_top_y`
  - collision top 아래에 배치

의도:
- gameplay collision은 얇은 판정 레이어로 유지
- 보행 표면과 아래 쿠키 장식을 별도 asset으로 관리
- 이후 필요 시 background layer만 숨기거나, 복층용/절벽용/다리용으로 교체 가능

### 검증
실행:

```powershell
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- `cookie_tile_surface.png`
- `cookie_tile_surface_flip.png`
- `cookie_tile_background.png`
- `cookie_tile_background_flip.png`
- 위 4개 import 확인
- `CookiePlatformVisual.gd` load 성공
