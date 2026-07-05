# auto-solver — ARCHIVE (Phase 4 강제 종료, 2026-06-24)

> 이 문서는 **강제 종료된 Phase 4(전술 라이브러리 — 속도 위한 전이)** 메커니즘의 아카이브 매니페스트다.
> 사용자 결정(2026-06-24): dead 메커니즘은 **삭제하지 않고 아카이브로 보존**(음성-입증 이력 = 잘못된 가설을
> 엄밀하게 죽인 기록). plan SoT의 `## Phase 4 ... ⛔ [강제 종료]` 배너와 짝을 이룬다.

## 왜 종료됐나 (속도 가설 기각)
Phase 4의 핵심 가설 = "학습 전술 전이로 같은 해를 **더 적은 롤아웃**에"(=속도). 두 메커니즘 모두 실측 falsify:
1. **boost(seed)** — `propose()` 휴리스틱이 이미 같은 순서를 front-load → 롤아웃 0 감소(S12 OFF=ON=8롤,
   byte-identical, 결정적 액션=fallback = **NO-TRANSFER**).
2. **vault-pruning** — 겉보기 이득(S12 8→4·S13 26→22)은 **완전성 희생의 산물**. 완전성 강화 시 OFF보다 나빠짐
   (S12 9롤·S13 미클리어). 현 휴리스틱이 이미 후보를 올바르게 랭킹 → 재랭킹/prune의 **sound 속도 이득 0**.

**결론**: rigor가 환상을 제거(de-risk 성공 = 잘못된 하위목표 'pruning-for-speed' kill). 솔버 가치는 속도가
아니라 **다양-해 발견 + 풀이법 보고서**(→ Phase 5).

## 아카이브된 자산 (in-place 보존 — 라이브 코드와 얽혀 물리 이동 시 회귀 위험, 게이트 None-safe inert라 그대로 둠)
| 자산 | 위치 | 상태 |
|---|---|---|
| 전술 라이브러리(boost seed) | `tools/solver/tactics.py` | ARCHIVED. 유일 소비자=transfer-bench seed 모드 |
| seed 보너스 머지 | `solve.py` `_merge_seeded` + `solve(seed_fn=)` | ARCHIVED. `seed_fn=None` 기본=inert |
| 볼트 pruning(형제 후보 제거) | `solve.py` `solve(vault_fn=)` + `_propose` vault 분기 | ARCHIVED. `vault_fn=None` 기본=inert |
| 전이 측정 하니스(A/B + 귀속) | `try_solve.py` `transfer_bench` (`transfer-bench` 서브커맨드) | ARCHIVED. 역사 재현 전용 |

## 살아남은 자산 (Phase 5로 이관 — LIVE, archived 아님)
- **지식 볼트** `tools/solver/knowledge/` + `knowledge.py` — *해 설명 어휘*로 존속. `try_solve.py diverse_report`가
  `knowledge.load_vault`/`resolve`로 스테이지 위기 맥락을 보고서에 붙인다(속도 가속기 아님).

## 재활성 금지 / 게이트 안전
- 위 archived 훅(`seed_fn`/`vault_fn`)은 **기본 None → 베이스라인과 byte-identical**(selftest 16/16로 강제). 신규
  코드에서 import·재활성 금지. 속도-전이를 다시 시도하려면 ARCHIVE 해제가 아니라 plan에서 새 가설로 재기재 후
  plan-review를 거칠 것.
- 물리 이동(별도 archive/ 폴더로 파일 relocate) 대신 **in-place + 본 매니페스트**를 택한 이유: `vault_fn` pruning
  분기·`transfer_bench`는 라이브 `solve.py`/`try_solve.py`에 얽혀 있어 이동 시 import·회귀 surface가 생긴다. 이미
  inert(None-safe)라 이동 이득이 없고, 본 매니페스트 + 각 파일 상단 ⛔ARCHIVED 배너로 demarcation은 충분하다.
