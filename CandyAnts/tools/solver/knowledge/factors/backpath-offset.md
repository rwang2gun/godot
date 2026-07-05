---
type: factor
applies_to: [blocker]
applies_routing: [reverse, safe_fall]
code: model.diagnose(edge_back), model.propose(off loop)
learned_from: [stage12, stage17]
---

# Backpath 오프셋 (backpath-offset)

반전 후보는 낙하 가장자리에서 **개미 동선의 grounded 타일을 거슬러**(off=0,1,2…) 생성한다. 공중 낙하 타일은
건너뛴다(계단형 하강에서도 실제 보행 타일에 정확히 놓임). 거슬러 갈수록 발화 여유(lead time)가 커진다.

## de-risk 발견 (2026-06-24) — **전이의 진짜 레버**
S12 실측: 솔버가 한 가장자리에서 off=0/1/2를 **차례로 롤아웃**한 뒤 하나를 채택 → 형제 후보가 롤아웃을
낭비한다(8롤 중 6롤이 형제 탐색). "일치 후보 boost"는 이 순서를 못 바꿔 무의미했다(NO-TRANSFER).
→ **학습된 "이 국소 패턴에선 off=k가 정답"을 prune 규칙으로 쓰면** 형제 2개를 건너뛰어 롤아웃이 준다.
이게 볼트가 솔버에 줄 수 있는 구체 가치(boost가 아니라 **pruning prior**).

## 적용
[[blocker]], routing=reverse/safe_fall. 미해결 질문: off 선택이 국소 패턴(가장자리 높이·천장 거리)에
어떻게 의존하는가 → 스테이지 누적으로 학습.

관련: [[ceiling-awareness]], [[water-edge-priority]]
