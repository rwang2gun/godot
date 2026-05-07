---
name: stage7-miner
duration_estimate: 5400
---

# Phase 8: Stage 7 + Miner (빌드 0.7)

## 목표
Miner (대각선 아래 굴착) 추가. Stage 1~6 회귀 없음.

## 변경 대상
- `scripts/skills/MinerSkill.gd` (ID="miner", apply → WorkerState.new("miner"))
- `scripts/core/SkillRegistry.gd`: MinerSkill preload
- `scripts/ant/states/WorkerState.gd`: miner 분기 — 진행 방향+아래 셀(2개)을 매 N프레임마다 erase + 1셀 대각선 이동
- `scenes/stages/Stage07.tscn` (Miner 경사로로만 풀리는 레벨)
- `data/stages/stage07.tres`

## 검증 방법
1. Stage 1~6 회귀 확인
2. Stage 7: Miner 적용 시 대각선 굴착 진행 → indestructible/맵끝/허공 만나면 Walker 복귀
3. 다른 개미들이 Miner 경사로 따라 자연 이동

## 엣지 케이스 (필수)
- **Miner 진행 방향이 절벽이면 Walker 복귀 후 Faller**
- **이미 굴착된 영역 재진입해도 erase 정상 (no-op)**
- **Carrying 개미도 Miner 적용 가능**

## 표준 절차
plan/review/deferred는 `phases/mvp/README.md` 참조.
