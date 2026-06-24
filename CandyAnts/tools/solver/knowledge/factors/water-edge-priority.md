---
type: factor
applies_to: [blocker]
applies_routing: [reverse, safe_fall]
code: model.diagnose (물 우선 정렬), model.propose (water_w)
learned_from: [stage11, stage14]
---

# 물 가장자리 우선 (water-edge-priority)

물 익사로 이어지는 낙하 가장자리를 **다른 가장자리보다 먼저** 막는다 — 가장 치명적 실패라 진척에 직결.

## 코드 근거
- `model.diagnose`: reverse_targets를 **물 익사 우선**으로 정렬(리타이어 직전 grounded 타일 1순위).
- `model.propose`: 물 가장자리 후보에 `water_w=4` 가중.

## 적용
[[blocker]], routing=reverse/safe_fall. 위기 [[water-drowning]]의 1차 대응.

관련: [[ceiling-awareness]], [[backpath-offset]]
