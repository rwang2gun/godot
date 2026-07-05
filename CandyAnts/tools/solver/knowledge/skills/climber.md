---
type: skill
skill: climber
routing: up
category: ANT_ARMED
learned_from: [stage13, stage14]
---

# climber — 등반 무장

개미를 무장시켜 **수직 벽을 타고 오르게** 한다(바닥→벽→상단). 귀로의 턱·벽을 넘는 핵심 도구.

서브골: [[return]] (운반 개미 귀가), 상승 라우팅.

## 사용 시 고려 요소 (factors)
- [[carry-timing]] — **운반 개미 무장이 S14 귀환 핵심**. 픽업 후(`picked_ge n`) carrying 상태 개미(select=min_x,
  벽 근처부터)에 단계별 무장 → 5조각이면 carry1..5가 서로 다른 개미에 분배.
- 타이밍 변형: early(스폰 직후 개미별)·carry(픽업 후 운반 개미)·late(회수 완료 후 max_x).

## 상호작용
- [[blocker]]와 조합 — blocker로 반전·라우팅 후 climber로 귀환([[stage13]]).

## 실패 모드
- 비운반 개미에 무장 분산되면(잘못된 타이밍) candy 미도달·등반 무한루프.

## 증거
[[stage13]], [[stage14]].
