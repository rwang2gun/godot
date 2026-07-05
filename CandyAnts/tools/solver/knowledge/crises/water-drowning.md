---
type: crisis
detect: [reverse_target.to_water, count_retired.water]
severity: fatal
resolves_with_skills: [blocker]
resolves_with_factors: [water-edge-priority, ceiling-awareness, backpath-offset]
learned_from: [stage11, stage12, stage14]
---

# 위기: 물 익사 (water-drowning)

개미가 발판 끝을 밟고 **물(hazard)로 떨어져 익사**한다. 가장 흔하고 치명적인 실패.

## 검출 신호 (diagnose)
- `reverse_targets[].to_water == true` — 물로 이어지는 낙하 가장자리.
- `count_retired().water > 0` — 실제 익사한 개미.

## 해결 (링크된 도구·요소 조회)
- 도구: [[blocker]] — 익사 직전 grounded 가장자리에 반전 벽.
- 요소: [[water-edge-priority]](물 가장자리 최우선) · [[ceiling-awareness]](재충돌 회피) · [[backpath-offset]](발화 여유·pruning).
- 서브골: [[reverse]]

## 증거
[[stage11]], [[stage12]], [[stage14]](낙하 드리프트로 바닥 놓치고 익사).
