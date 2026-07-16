# 미해결 스테이지 오프라인 테스트 러너 (2026-07-16) — 네트워크 불필요, 총 2~3h
#
# Arm A: S23 witness-prefix k=4 에스컬레이션 (k=3 무진척 → 자유슬롯 2→1로 축소; S14 k=3 성공 선례)
# Arm B: S25 분모수정(fcc3996) 후 동일-레시피 재시도 = A/B 판정 실험의 B arm
#        (2026-07-14 분석 §4 해결안 4 — blocker 파밍 신호 제거 후 학습 궤적 변화 관측)
# Arm C: (시간 여유 시) S9 attempt02 seeds 3,4,5 — 해 1/3 → 2/3 목표 (분석 §6 순위 5)
#
# 사용: Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass',
#        '-File','tools\solver\rl\experiments\offline_unresolved_run.ps1' -WindowStyle Hidden
# 중지: Stop-Process -Id (Get-Content tools\solver\rl\experiments\sweep_out\offline_run.pid)
# 진행 확인: sweep_out\offline_run_console.log · attempts.jsonl · stageNN.attemptKK.log

$ErrorActionPreference = "Continue"
$repo = "D:\Projects\godot\CandyAnts"
Set-Location $repo
$env:PYTHONIOENCODING = "utf-8"
if (-not $env:GODOT_BIN) {
    $env:GODOT_BIN = "C:\Users\code1\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64_console.exe"
}

$so = Join-Path $repo "tools\solver\rl\experiments\sweep_out"
New-Item -ItemType Directory -Force $so | Out-Null
$log = Join-Path $so "offline_run_console.log"
$PID | Out-File (Join-Path $so "offline_run.pid") -Encoding ascii

function Log($msg) {
    $line = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
    $line | Out-File $log -Append -Encoding utf8
}

$t0 = Get-Date
Log "=== offline_unresolved_run 시작 (Arm A: S23 pfx k=4 / Arm B: S25 post-fix / Arm C: S9 seeds3-5) ==="

# --- Arm A + B: 한 번의 스윕 호출 (S23은 prefix 오버라이드, S25는 기본 레시피) ---
Log "[Arm A+B] sweep --stages 23,25 --prefix-overrides 23:data/solutions/stage23.witness.json:4"
cmd /c "python tools\solver\rl\experiments\sweep_stages.py --stages 23,25 --seeds 0,1,2 --prefix-overrides ""23:data/solutions/stage23.witness.json:4"" >> ""$log"" 2>&1"
Log "[Arm A+B] 종료 rc=$LASTEXITCODE"

# --- Arm C: 경과 130분 미만이면 S9 seed 복권 (attempt02) ---
$elapsedMin = ((Get-Date) - $t0).TotalMinutes
if ($elapsedMin -lt 130) {
    Log "[Arm C] 경과 $([math]::Round($elapsedMin))분 — S9 seeds 3,4,5 착수"
    cmd /c "python tools\solver\rl\experiments\sweep_stages.py --stages 9 --seeds 3,4,5 >> ""$log"" 2>&1"
    Log "[Arm C] 종료 rc=$LASTEXITCODE"
} else {
    Log "[Arm C] 경과 $([math]::Round($elapsedMin))분 ≥ 130 — 시간 예산 초과, 생략"
}

$totalMin = [math]::Round(((Get-Date) - $t0).TotalMinutes)
Log "=== offline_unresolved_run 전체 종료 total=${totalMin}분 ==="
Remove-Item (Join-Path $so "offline_run.pid") -ErrorAction SilentlyContinue
