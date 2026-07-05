---
type: stage
stage: 12
inventory: { blocker: 3 }
candy_hp: 5
rollouts_solved: 8
---

# Stage 12

[[blocker]] 3중 반전으로 풀리는 다중-가장자리 레벨. [[stage11]] 전술의 반복 적용.

## 해법
- 3 blocker 반전(min_x le / max_x ge / min_x le). saved 5/5.

## 행사된 요소
- [[blocker]] / [[reverse]] · [[water-edge-priority]] · [[backpath-offset]]

## de-risk 관찰 (2026-06-24)
형제 off 후보(@0,12/@1,12/@2,12) 차례 시도가 8롤 중 6롤 차지 → [[backpath-offset]] pruning이 전이 레버.
