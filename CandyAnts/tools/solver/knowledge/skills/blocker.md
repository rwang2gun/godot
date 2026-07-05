---
type: skill
skill: blocker
routing: reverse
category: cell-place
learned_from: [stage11, stage12, stage17]
---

# blocker — 반전 벽

낙하 가장자리에 벽을 세워 개미를 **반전**시킨다. 개미는 막히기 전엔 방향을 안 바꾸므로(사용자 통찰),
직전 grounded 타일에 벽을 두면 (a) 물 익사·추락사 회피 (b) 상승/하강 라우팅을 동시에 해결.

서브골: [[reverse]]

## 사용 시 고려 요소 (factors)
- [[water-edge-priority]] — 물로 떨어지는 가장자리를 **최우선** 배치(가장 치명적 실패).
- [[ceiling-awareness]] — blocker 상공에 천장(solid)이 있어야 위층 낙하 개미가 그 위로 떨어져 **재충돌·무한
  왕복**하는 걸 막는다. 천장 없는 가장자리에 두면 위층 낙하 개미가 착지 즉시 반전(S17 col17 실측 saved 0).
- [[backpath-offset]] — 가장자리에서 동선(grounded 타일)을 거슬러 off=0,1,2로 둘수록 발화 여유(lead time)↑.
  **단 형제 off 후보 무차별 시도가 롤아웃 낭비** → 학습된 "정답 off"로 pruning하면 전이 가치 발생(de-risk 레버).

## 타이밍
- `ant_reaches_x`@가장자리 x (이벤트 상대). 진행 방향으로 select(max_x/min_x)·cmp(ge/le) 결정.

## 상호작용
- [[climber]]와 조합 — blocker로 반전 후, carry-armed climber로 귀환 경로 확보(S13: blocker 1 + climber 5).

## 실패 모드
- 천장 없는 가장자리 → 위층 낙하 개미와 재충돌 무한루프([[reversal-trap]]).
- 잘못된 가장자리 → carry 개미가 갇혀 saved 0.

## 증거
[[stage11]](단일 반전), [[stage12]](3중 반전), [[stage17]](천장-인지 reverse).
