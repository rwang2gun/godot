---
type: crisis
detect: [count_retired.fall]
severity: fatal
resolves_with_skills: [blocker]
resolves_with_factors: [backpath-offset]
learned_from: [stage14]
---

# 위기: 낙하사 (fall-death)

개미가 큰 낙하로 **기절사(stun death, DeadState)**한다. 익사와 달리 마른 바닥에 착지하며 죽는다(궤적에
`dead` 상태 샘플로 검출 — 낙하를 생존한 개미는 제외, 거짓양성 없음).

## 검출 신호 (diagnose)
- `count_retired().fall > 0` — 종단/중간 샘플에 `dead` 상태.

## 해결 (링크된 도구·요소 조회)
- 도구: [[blocker]] — 치명 낙하 직전 가장자리에 반전 벽(생존 발판). safe_fall 계열 도구도 후보.
- 요소: [[backpath-offset]] — 가장자리 거슬러 lead time 확보.
- 서브골: [[reverse]]

## 증거
[[stage14]].
