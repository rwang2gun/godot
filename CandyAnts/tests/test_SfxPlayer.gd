# TDD Guard 스텁. 진짜 coverage는 tests/SfxReceiverTest.tscn 가 담당:
#   - scripts/ repo-도출 emit id 추출 → SfxPlayer.SFX_SPECS 직접 커버리지 (정규화 없음)
#   - 전 spec 리소스 로드 무결성(non-null + length>0, 개수는 SFX_SPECS.size() 동적)
#   - 각 raw id emit → last_played 일치 (동적 재생)
#   - StageSelect.gd sfx:locked→locked 정규화 회귀
#   - 미등록 id graceful skip
# 본 stub은 SfxPlayer.gd 수정 시 TDD guard 통과용 (run_test.py로 SfxReceiverTest.tscn 실행).
extends Node
