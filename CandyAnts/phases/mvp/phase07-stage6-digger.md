---
name: stage6-digger
duration_estimate: 5400
---

# Phase 7: Stage 6 + Digger (빌드 0.6)

## 목표
Digger (수직 아래 굴착) 추가. Stage 1~5 회귀 없음.

## 변경 대상
- `scripts/skills/DiggerSkill.gd` (ID="digger", apply → WorkerState.new("digger"))
- `scripts/core/SkillRegistry.gd`: DiggerSkill preload
- `scripts/ant/states/WorkerState.gd`: digger 분기 — 발 아래 셀을 매 N프레임마다 1셀씩 erase + 자기 위치 1셀 하강 + 하강 중에는 Faller 전이 안 함
- `scenes/stages/Stage06.tscn` (위층에서 시작, Digger로 아래층 진입)
- `data/stages/stage06.tres`

## 검증 방법
1. Stage 1~5 회귀 확인
2. Stage 6: Digger 적용 시 수직 굴착 → 적당한 깊이에서 Walker 복귀 옵션 (or indestructible 만나면 강제 복귀)
3. Digger 종료 후 자연스러운 낙하 → Faller → 착지

## 엣지 케이스 (필수)
- **Digger 도중 indestructible 만나면 Walker 복귀**
- **Digger가 화면 밖(맵 경계) 도달 시 Walker 복귀**
- **Carrying 개미 Digger 가능 — 운반 유지하며 하강**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
