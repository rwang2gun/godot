@echo off
REM CandyAnts 레벨 에디터 런처 — 이 프로젝트를 Godot 에디터로 연다.
REM 에디터가 뜨면 하단 패널 "CandyAnts Level" 또는 Project > Tools > CandyAnts Level Tool 사용.
echo Launching CandyAnts in Godot editor (level tool)...
python "%~dp0scripts\run_editor.py" %*
if errorlevel 1 pause
