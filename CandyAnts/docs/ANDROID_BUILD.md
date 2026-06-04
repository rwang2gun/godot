# Android 빌드 (디버그 APK)

CandyAnts를 Godot 4.6.x 헤드리스로 Android 디버그 APK로 export 하는 절차.
원격/CI 리눅스 환경 기준으로 검증됨 (Ubuntu 24.04, JDK 21).

표준 export(= "Use Gradle Build" 끔)는 전체 Android NDK/Gradle 없이
**서명 도구(apksigner/zipalign)** 와 **prebuilt export 템플릿** 만으로 빌드된다.

## 1. 도구 준비

```bash
# 서명 도구 (Android SDK 매니저 대신 apt로 조달 — dl.google.com 불필요)
apt-get install -y apksigner zipalign adb

# Godot이 기대하는 SDK 레이아웃을 apt 바이너리로 합성
SDK=/opt/android-sdk
mkdir -p "$SDK/build-tools/34.0.0" "$SDK/platform-tools"
ln -sf "$(command -v apksigner)" "$SDK/build-tools/34.0.0/apksigner"
ln -sf "$(command -v zipalign)"  "$SDK/build-tools/34.0.0/zipalign"
ln -sf "$(command -v adb)"       "$SDK/platform-tools/adb"

# 디버그 keystore (Godot 표준값: alias=androiddebugkey, pass=android)
keytool -keyalg RSA -genkeypair -alias androiddebugkey \
  -keypass android -keystore "$HOME/.android/debug.keystore" -storepass android \
  -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

## 2. Godot 엔진 + export 템플릿

```bash
V=4.6.3-stable
# 엔진
curl -L -o godot.zip "https://github.com/godotengine/godot/releases/download/${V}/Godot_v${V}_linux.x86_64.zip"
unzip godot.zip && ln -sf "$PWD/Godot_v${V}_linux.x86_64" /usr/local/bin/godot
# export 템플릿 → ~/.local/share/godot/export_templates/<version.txt>/
curl -L -o templates.tpz "https://github.com/godotengine/godot/releases/download/${V}/Godot_v${V}_export_templates.tpz"
unzip templates.tpz -d /tmp/tpl
mkdir -p "$HOME/.local/share/godot/export_templates"
mv /tmp/tpl/templates "$HOME/.local/share/godot/export_templates/$(cat /tmp/tpl/templates/version.txt)"
```

## 3. 에디터 설정 (`~/.config/godot/editor_settings-4.6.tres`)

`godot --headless --import --path .` 를 한 번 돌리면 기본 설정 파일이 생성된다.
아래 키들을 우리 값으로 맞춘다:

```
export/android/android_sdk_path = "/opt/android-sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-21-openjdk-amd64"
export/android/debug_keystore = "/root/.android/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
```

## 4. 프로젝트 설정 (커밋됨)

`project.godot` 의 `[rendering]` 에 아래가 있어야 한다 — 없으면 Android export 검증이
**빈 에러 메시지로 실패**한다 (`should_import_etc2_astc()` 게이트):

```
textures/vram_compression/import_etc2_astc=true
```

## 5. export_presets.cfg (gitignore 대상 — 아래 내용으로 생성)

이 프로젝트는 `export_presets.cfg` 를 `.gitignore` 하므로 빌드 전에 직접 만든다:

```ini
[preset.0]
name="Android"
platform="Android"
runnable=true
export_path="build/android/CandyAnts.apk"
export_filter="all_resources"

[preset.0.options]
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
version/code=1
version/name="1.0"
package/unique_name="org.candyants.game"
package/name="CandyAnts"
package/signed=true
permissions/internet=true
```

## 6. 빌드

```bash
godot --headless --import --path .                              # 에셋 import (최초 1회)
mkdir -p build/android
godot --headless --export-debug "Android" build/android/CandyAnts.apk --path .
apksigner verify --print-certs build/android/CandyAnts.apk      # 서명 확인
```

산출물: `build/android/CandyAnts.apk` (~96MB, arm64-v8a + armeabi-v7a 포함).
폰에서 "출처를 알 수 없는 앱 설치" 허용 후 설치.

## 비고 / 한계

- **iOS** 는 macOS + Xcode 가 필요해 리눅스 환경에서 `.ipa` 생성 불가 (Xcode 프로젝트 export 까지만 가능).
- 릴리스 APK/AAB(플레이스토어) 는 별도 release keystore 필요.
- `export -debug` 중 `cannot connect to daemon at tcp:5037` 는 무해 (에디터가 연결된 기기를 찾는 메시지).
