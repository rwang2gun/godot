@echo off
REM CandyAnts RL 학습·검증 런처 — tools/solver/rl/rl.py 감싸는 셔틀.
REM 예: run_rl 12          (stage 12 학습)
REM     run_rl 12 -s 3     (3 seed)
REM     run_rl 12 --smoke  (빠른 스모크)
REM     run_rl --verify 11 (검증)
REM     run_rl --list      (현황)
set PYTHONUTF8=1
python "%~dp0tools\solver\rl\rl.py" %*
if errorlevel 1 pause
