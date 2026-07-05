---
type: factor
applies_to: [climber]
applies_routing: [up]
code: model.propose (carry 분기), solve (carry_base 우선순위)
learned_from: [stage13, stage14]
---

# 운반 타이밍 (carry-timing)

[[climber]]는 **픽업 후 운반 개미에 무장**해야 귀환에 쓰인다. 비운반 개미에 일찍 분산되면 등반 무한루프가 된다.

## 규칙
- trigger=`picked_ge n` (n번째 픽업 시점), target=select=`min_x`+state=`carrying` (벽 근처 운반 개미부터).
- candy hp=k면 carry1..k가 서로 다른 운반 개미에 분배(무장 개미는 climb로 빠짐).
- 귀로 단계(전 사탕 회수)면 climber를 최우선(`carry_base` 220), 아니면 후순위(blocker 우선).

## 적용
[[climber]]. 위기 [[carry-trapped]]의 1차 대응. 서브골 [[return]].

관련: [[reverse]]
