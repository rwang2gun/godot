---
name: map-editor-worklog-notes
date: 2026-05-17
track: map-editor
status: implemented
---

# Level Tool Worklog Notes

## 핸드오프
- 사용자가 `codex-worklog` 구조를 확인한 뒤, 현재 레벨 툴 작업도 이 폴더에 기록하고 싶다고 요청했다.
- 이후 사용자가 Codex가 작업 시작/종료 시 알아서 기록하도록 프로젝트 규칙에 추가해달라고 요청했다.
- 기존 `map-editor/` 트랙에는 1차 레벨 에디터 기반 작업 로그와 `STATUS.md`가 이미 존재했다.

## 산출물
- 루트 `CLAUDE.md`의 개발 프로세스에 Codex 장기 작업 기록 규칙을 추가했다.
- `codex-worklog/README.md`에 작업 전후 운용 루틴을 추가했다.
- `codex-worklog/map-editor/STATUS.md`의 세션 로그 목록에 이번 규칙 정리 로그를 추가했다.

## 결정
- 맵 에디터처럼 gameplay phase와 독립적인 long-running tooling 작업은 `phases/mvp/`가 아니라 `codex-worklog/map-editor/`를 SoT 트레일로 사용한다.
- 현재 상태와 다음 작업은 `STATUS.md`에 유지하고, 실제 Codex 산출물 단위는 날짜별 세션 로그로 남긴다.
- 이 운용은 루트 `CLAUDE.md`에 프로젝트 규칙으로 명시한다.

## 통합 노트
- 프로젝트 규칙 위치: `CLAUDE.md`
- worklog 운용 설명: `codex-worklog/README.md`
- 레벨 툴 트랙 SoT: `codex-worklog/map-editor/STATUS.md`

## 남은 과제
- 다음 실제 레벨 툴 구현은 `map-editor/STATUS.md`에 적힌 grid preview 컨트롤 추가부터 이어간다.
- 이후 grid preview, 클릭/드래그 편집, Home/Candy/Spawner 배치 모드가 구현될 때마다 같은 track에 세션 로그를 추가한다.
