---
type: factor
applies_to: [blocker]
applies_routing: [reverse]
code: model._has_ceiling
learned_from: [stage17]
---

# 천장 인지 (ceiling-awareness)

반전 blocker는 **상공(같은 열, 더 위 행)에 천장(solid 타일)이 있는 셀**에 둬야 한다. 천장이 있으면 위층에서
낙하한 개미가 그 위로 떨어지지 못해, blocker가 위층 낙하 개미와 **재충돌하지 않는다**.

## 증거 (S17 실측)
- L2 col17 (상공 천장 無) → 위층 낙하 개미가 착지 즉시 반전돼 **무한 왕복, saved 0**.
- col≤16 (맨 위 플랫폼이 천장) → saved 5/5.

## 적용
- 같은 backpath 후보들 중 **천장 있는 안쪽 셀을 가중**(propose ceil_w). [[blocker]] 및 routing=reverse 일반.
- 최상층(상공에 층 없음)은 천장 無라도 무해 — 낙하 원본 층이 없음(타이브레이커로 처리).

관련: [[reversal-trap]], [[backpath-offset]]
