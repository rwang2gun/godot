---
type: crisis
detect: [count_trapped.carry]
severity: high
resolves_with_skills: [climber]
resolves_with_factors: [carry-timing]
learned_from: [stage13, stage14]
---

# 위기: 운반 개미 귀환 막힘 (carry-trapped)

사탕을 집은(carrying) 개미가 귀로의 벽·턱에 막혀 **집으로 못 돌아간다**(블로커와 왕복 등). 픽업은 됐으나
saved로 이어지지 않는 S14형 증상.

## 검출 신호 (diagnose)
- `count_trapped().carry > 0` — carrying 상태로 방향 반전 과다(=갇힘).
- 보조: `picked_total >= candy_hp` 인데 saved < hp (전원 픽업·귀로만 남음).

## 해결 (링크된 도구·요소 조회)
- 도구: [[climber]] — 운반 개미를 벽 등반으로 귀가시킴.
- 요소: [[carry-timing]] — 픽업 후(picked_ge n) carrying 개미(min_x)에 단계별 무장.
- 서브골: [[return]]

## 증거
[[stage13]](blocker+climber 5), [[stage14]](carry 무장 귀환 핵심).
