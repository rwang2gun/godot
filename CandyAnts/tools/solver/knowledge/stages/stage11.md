---
type: stage
stage: 11
inventory: { blocker: 1 }
candy_hp: 4
rollouts_solved: 2
---

# Stage 11

단일 [[blocker]] 반전으로 풀리는 입문 반전 레벨.

## 해법
- blocker 반전@물-가장자리 (select=max_x, trigger=ant_reaches_x ge). 1 액션, saved 4/4.

## 행사된 요소
- [[blocker]] / 서브골 [[reverse]]
- [[water-edge-priority]] — 가장자리가 물로 이어짐
- [[backpath-offset]] — off=0 (가장자리 셀 자신)

## 특징
가장 깨끗한 단일-반전 사례. CBR 전이의 **출발 전술 추출원**(s11.blocker_reverse_water_edge).
