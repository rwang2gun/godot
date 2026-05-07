# PRD: CandyAnts

## 목표
레밍즈의 자율 군중 + 간접 통제 메카닉을 **사탕 왕복 운반** 게임으로 각색한 2D 사이드뷰 퍼즐.

## 핵심 기능
1. **자율 개미 AI** — Walker / Faller / Carrying / Worker / Saved / Dead 상태머신, 무뇌 전진 + 충돌 시 회전
2. **사탕 HP 자원** — 도달한 개미마다 HP -1, 운반 중 사망 시 영구 소실
3. **왕복 라운드트립** — 진입구(=Home)에서 스폰 → 사탕 픽업 → 180° 회전 → 귀환
4. **8종 스킬 (단계적 도입)** — Climber / Floater / Bomber / Blocker / Builder / Basher / Miner / Digger
5. **클리어/점수 분리** — binary 클리어(HP=0 + 운반자 귀가) + graded 점수(귀환 조각 / 총 HP)
6. **Release Rate 슬라이더** — 자기 페이싱 시간 조절
7. **운반 부하** — Carrying 상태는 0.78배 속도, 스킬 적용 가능

## MVP 제외 사항
- 페로몬 기반 귀환 경로 (단순 180°만)
- 다중 사탕 (레벨당 1개)
- 개미 종류별 차별화 (1마리 = 1 HP 고정)
- 죽은 운반자의 사탕 조각 회수
- 멀티플레이어
- 레벨 에디터
- 사운드/BGM (Phase 후반 폴리싱)
