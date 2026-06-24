---
type: factor
kind: failure-mode
applies_to: [blocker]
code: model.count_trapped, model._has_ceiling
learned_from: [stage17]
---

# 반전 트랩 (reversal-trap)

반전 벽([[blocker]])이 **위층 낙하 개미와 재충돌해 무한 왕복**하는 실패 모드. 벽 상공이 뚫려 있으면 위층에서
떨어진 개미가 벽 위에 착지 → 즉시 반전 → 다시 충돌 → … saved 0.

## 검출
- `model.count_trapped`: carrying/전체 개미의 수평 방향-반전 횟수 과다(≥thresh)로 근사.

## 완화
- [[ceiling-awareness]] — 벽 상공에 천장(solid)이 있는 셀을 골라 위층 낙하 개미가 벽 위로 못 떨어지게 한다.

## 증거
[[stage17]] — col17(천장無) 무한왕복 saved 0 vs col≤16(천장有) saved 5/5.
