# Web 빌드 (HTML5 / WebAssembly)

CandyAnts를 Godot 4.6.x 헤드리스로 Web(HTML5) export 하는 절차.
**Windows 11 로컬 환경** 기준으로 검증됨 (2026-06-05, Godot 4.6.2-stable).

브라우저에서 바로 실행되는 빌드라 **맥 없이도 아이패드 사파리에서 플레이 가능** — iOS 네이티브(.ipa)는
macOS + Xcode가 필요하지만, Web 빌드는 호스팅 URL만 있으면 어떤 기기 브라우저에서도 돈다.
사파리 "홈 화면에 추가"로 PWA처럼 전체화면 실행도 됨 (`index.apple-touch-icon.png` 자동 포함).

`variant/thread_support=false` 로 빌드하면 **SharedArrayBuffer / COOP·COEP 헤더가 불필요** →
itch.io · GitHub Pages · 단순 정적 서버 어디서나 호스팅 가능 (사파리 호환성도 가장 좋음). 권장.

## 1. Godot 엔진 + export 템플릿

이 머신의 Godot 콘솔 바이너리는 **중첩 폴더** 안에 있다 (zip을 폴더명 그대로 풀어둠):

```
C:\Users\code1\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe
```

export 템플릿(엔진 버전과 정확히 일치해야 함)을 받아 버전 폴더에 설치한다:

```bash
# tpz 다운로드 (~1.25GB, 전 플랫폼 묶음 — Web만 따로 받는 경로는 없음)
curl -L -o templates.tpz \
  "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz"

# %APPDATA%\Godot\export_templates\<version.txt>\ 에 templates/* 평탄화 설치
#   version.txt 내용 = "4.6.2.stable"  → 폴더명이 정확히 이것이어야 Godot이 인식
DEST="C:/Users/code1/AppData/Roaming/Godot/export_templates/4.6.2.stable"
mkdir -p "$DEST" && (cd "$DEST" && unzip -o -j ../../../templates.tpz "templates/*")
```

설치 확인: `$DEST` 안에 `web_release.zip` · `web_nothreads_release.zip` · `version.txt` 등이 보이면 OK.
(thread 끈 빌드는 `web_nothreads_release.zip` 을 사용한다.)

## 2. export_presets.cfg (gitignore 대상 — 아래 내용으로 생성)

이 프로젝트는 `export_presets.cfg` 를 `.gitignore` 하므로 빌드 전에 직접 만든다:

```ini
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
export_path="build/web/index.html"

[preset.0.options]
variant/thread_support=false          ; 특수 HTTP 헤더 없이 호스팅 (사파리/itch.io 권장)
vram_texture_compression/for_mobile=false
html/export_icon=true
html/canvas_resize_policy=2            ; 캔버스를 뷰포트에 맞춰 리사이즈 (아이패드 화면 대응)
html/focus_canvas_on_start=true
progressive_web_app/ensure_cross_origin_isolation_headers=true
```

> 전체 옵션 키가 채워진 실제 파일은 빌드 시 Godot이 자동 보완한다. 위는 핵심 키만 발췌.

## 3. 빌드

```bash
export GODOT_BIN="C:/Users/code1/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe"
"$GODOT_BIN" --headless --path . --import                                  # 에셋 import (최초 1회)
mkdir -p build/web
"$GODOT_BIN" --headless --path . --export-release "Web" build/web/index.html
```

산출물: `build/web/` (~79MB)
- `index.html` / `index.js` / `index.wasm`(~37MB) / `index.pck`(~43MB)
- `index.apple-touch-icon.png` — 아이패드 홈 화면 아이콘

## 4. 로컬 확인

thread 끈 빌드는 특수 헤더가 필요 없어 단순 정적 서버로 충분하다:

```bash
cd build/web && python -m http.server 8060 --bind 127.0.0.1
# 브라우저: http://127.0.0.1:8060/index.html
```

PC 브라우저에서 마우스 드래그가 되면 아이패드 터치 드래그(스킬 드래그앤드롭)도 거의 확실히 동작한다
— Godot `emulate_mouse_from_touch`(기본 true)가 터치를 마우스 이벤트로 변환하기 때문.

## 5. 아이패드에 올리기 (itch.io 예시)

1. `build/web` 폴더 전체를 zip으로 압축
2. itch.io → Upload → "This file will be played in the browser" 체크, zip 업로드
3. 생성된 URL을 아이패드 사파리에서 열기 → 공유 → "홈 화면에 추가"

## 비고 / 한계

- **`.pck`에 `tests/*` 씬이 모두 포함되어 용량이 큼** (~43MB). 슬림하게 빌드하려면
  `export_presets.cfg` 의 `[preset.0]` 에 아래를 추가:
  ```ini
  exclude_filter="tests/*,dev_stages/*"
  ```
- thread 빌드(`thread_support=true`)를 쓰면 성능은 오르지만 서버가 COOP·COEP 헤더
  (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`)를
  내려줘야 하고 사파리 호환이 까다로워진다. 아이용 배포엔 비권장.
- **iOS 네이티브(.ipa)** 는 macOS + Xcode 필요 — 이 길 대신 Web 빌드를 쓴다.
- export 시 `index.html`을 직접 더블클릭하면 CORS로 안 뜬다 — 반드시 HTTP 서버 경유.
