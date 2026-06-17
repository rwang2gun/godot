# 캠페인 Ch1 (Stage 11~18) 테스트 드라이버 수정 — 진행 상황

작성일: 2026-06-18 · 상태: **진행 중** (S11 완료, S12 부분, 나머지 미착수) · 미커밋

---

## 1. 배경과 결론

사용자가 stage 11~18을 **직접 플레이로 완전 클리어**했다(아래 §증거). 그런데 헤드리스
자동 클리어 드라이버(`tests/CampaignSxxClearTest`)가 "클리어 실패"로 나왔다.

**결론: 레벨은 정상이며, 드라이버가 stale했던 것이다.** 맵 에디터로 레벨을 재설계한 뒤
드라이버를 갱신하지 않아, 드라이버가 *옛 레벨*의 스킬·좌표를 하드코딩한 채 남아 있었다.

### 증거
- **`save.cfg`** (`%APPDATA%/Godot/app_userdata/CandyAnts/save.cfg`): stage 11~18 전부
  `cleared=true`, `stars=3`, `best_score=1.0`, attempts 1~7회(= 실제 손플레이 흔적).
- **스킬 인벤토리 불일치**(결정적): `stage11.tres`는 `skill_inventory={blocker:1}`인데
  옛 `CampaignS11ClearTest`는 `ClimberSkill`을 5개 적용 → 레벨에 없는 스킬을 쓰고 있었다.
- 옛 드라이버는 `blocker@x=696` 같은 **하드코딩 좌표**가 현재 지형과 어긋나 스킬이
  아예 발동하지 못했다(S12·S14).

---

## 2. 각 레벨 데이터 (SoT)

좌표는 셀(col,row), cell_size=48. spawn≈home(집에서 나와 사탕 줍고 귀환). 양옆은 물 함정.

| id | 이름 | hp | total | skill_inventory | spawn=집 | candy | dir | 구조 / 자연동선(스킬0) |
|----|------|----|----|------------------|----------|-------|-----|----|
| 11 | 물놀이 금지 | 4 | 5 | blocker:1 | 상단 col6 | 하단 col16 | 우(기본) | 상단표면+col10사다리+하단표면+양끝물. 우향→col16끝 낙하→candy 지나쳐→col22 물 |
| 12 | 사다리 오르기 | 5 | 8 | blocker:3 | 하단 col6 | 상단 col16 | **좌(-1)** | 4층 수직(아래 §S12). 좌향→왼쪽 물 |
| 13 | 달콤한 냄새 | 5 | 6 | blocker:1, climber:5 | col1 (y384) | col12 (y336) | 기본 | **기존 PASS** (현재 레벨과 우연히 일치) |
| 14 | 밑으로 밑으로 | 5 | 8 | blocker:3, climber:5 | 최상단 col1 | 우하단 col22 | 우(기본) | 위→아래. 우향 상단→오른쪽 끝에서 물 |
| 15 | 눈 딱 감고 낙하 | 5 | 7 | climber:5, floater:2 | 최상단 col1 | 우하단 col22 | 우(기본) | 낙하. 우향→col13(x662) 협곡서 정체 |
| 16 | 번지 점프 | 5 | 9 | blocker:3, floater:1 | 하단 col6 | 상단 col14 | **좌(-1)** | 다층. 좌향→왼쪽 물 |
| 17 | 돌고 도는 길 | 5 | 9 | blocker:4 | 하단 col5 | 최상단 col14 | **좌(-1)** | 긴 수직. 좌향→왼쪽 물 |
| 18 | 동굴 탐험 | 5 | 8 | blocker:2, climber:5, floater:1 | 중간 col1 (y328) | 중간 col16 (y288) | 우(기본) | 복합. 우향→col6 구멍으로 추락(y712 물) |

> **`spawn_direction` 필드**: layout.tres에 `spawn_direction = -1`이면 좌향 출발(S12·16·17),
> 없으면 기본 우향(S11·14·15·18). 옛 드라이버가 방향을 잘못 가정한 원인.

---

## 3. 솔루션 패턴 (S11에서 확립, S12에서 재확인)

1. **관찰**: 스킬 0으로 개미 자연 동선 추적(`_Obs` 드라이버 패턴, §9).
2. 자연 동선에서 **개미가 어디서 물/협곡에 빠지는지** + candy 위치 대비 파악.
3. 그 이탈 지점 직전에 스킬(blocker/climber/floater) 배치.
4. `python scripts/run_test.py tests/CampaignSxxClearTest.tscn`으로 PASS 확인. 안 되면 좌표 조정.

### 검증된 코어 사실
- **빈손 개미도 사다리(`sand_mound`)를 자동 등반**한다 (S12 실험서 확인 — 중간2층 y472까지 올라감).
- **운반 개미도 사다리를 자동 통행**한다 (S11서 확인 — 하단 candy 픽업 후 사다리로 상단 복귀).
- 모든 레벨의 자연 동선은 `saved=0 / no_more_ants` → **음성 케이스(스킬 없으면 실패)는 자동 성립**.

---

## 4. 진행 상황

| Stage | 상태 | 비고 |
|-------|------|------|
| 11 | ✅ **완료 PASS** | `tests/CampaignS11ClearTest.gd` 재작성. blocker 1개 하단 물 직전(col20, x960). `saved=4/4`. |
| 13 | ✅ 기존 PASS | 손 안 댐. 현재 레벨과 우연히 일치. |
| 12 | 🔶 **진행 중(현재 FAIL)** | `tests/CampaignS12ClearTest.gd` 좌향차단 blocker 1개까지. 빈손 등반 확인. 층간 차단 blocker 2개 미배치(§S12). |
| 14 | ⬜ 미착수 | 관찰 동선만 확보. climber로 안전 하강 필요. |
| 15 | ⬜ 미착수 | climber+floater. col13 협곡 통과 필요. |
| 16 | ⬜ 미착수 | S12와 유사 다층(좌향). blocker+floater. |
| 17 | ⬜ 미착수 | 긴 수직(좌향). blocker:4. |
| 18 | ⬜ 미착수 | 복합. blocker+climber+floater. |

---

## 5. S11 솔루션 상세 (완료 — 참고 템플릿)

```
지형: 상단표면(row9,col3-16) + col10 사다리 + 하단표면(row12,col3-21) + 양끝 물(col<3, col>21).
home=상단 col6, candy=하단 col16(hp4), spawn=상단 col6.
자연: 상단 우향 → col16끝 낙하(col18 착지) → candy(col16,착지 왼쪽) 지나침 → 하단 우향 → col22 물.
솔루션(드라이버): 하단(y>520)의 최전방 walker가 x>=960(col20) 도달 시 blocker 1개.
  → 후속 개미 반전(좌향) → candy(col16) 픽업 → 운반 상태로 사다리(col10) 통행 → 상단 home 귀환.
결과: saved=4/4 PASS. (blocker가 된 1마리는 희생, hp4=나머지 4마리.)
```

---

## 6. S12 진행 상세 (미완성)

```
구조(4층 수직, spawn_direction=-1 좌향):
  상단 row4  (col6~18) ← candy(col16)        ▲ col13 사다리(row5~6)
  중간1 row7 (col5~18)                        ▲ col8  사다리(row8~9)
  중간2 row10(col4~18)                        ▲ col12 사다리(row11~12)
  하단 row13 (col0~18) ← spawn/home(col6)     양옆 물(col<0, col>18)

진행: 하단 spawn 좌향 차단 blocker 1개(col5, x264) → 개미 우향 → col12 사다리로
  중간2(row10, y472)까지 빈손 등반 확인 ✓.  그러나 중간2에서 계속 우향 → col18끝 →
  col19 물 추락(y649~654)으로 전멸. saved=0.

다음 할 일: 중간2/중간1에서 개미를 col8/col13 사다리 쪽으로 유도(우향 이탈 차단)하는
  blocker 2,3을 배치. 후보 — 중간2의 col18 직전, 중간1의 col18 직전에 blocker.
  (blocker 총 3개 인벤토리와 일치: 하단1 + 중간2 + 중간1.)
  스크린샷상 사용자는 각 발판 우측 끝에 길막기를 세웠음 — 그 위치를 셀로 변환해 적용.
```

---

## 7. 다음 작업 순서 (권장)

1. **S12 완성**: 중간2·중간1 우향차단 blocker 2개 추가 → PASS.
2. **S16·S17**: S12와 동형(다층·좌향, blocker 위주). S12 솔루션 재사용.
3. **S14·S18**: climber로 벽/구멍 하강. 모든 개미에 climber 부여 + 필요시 blocker(S13 PASS 패턴 참고).
4. **S15**: climber로 등반 후 floater로 낙하/협곡 강하.
5. 6개 전부 PASS 후 전체 회귀(`run_test.py`로 S11~S18 + 인접 스위트) 확인.
6. 커밋: `fix(test): ch1 stage11~18 클리어 드라이버를 재설계된 레벨에 맞게 갱신`.

---

## 8. 참고 — 스킬 동작 미확인 항목
- `ClimberSkill` / `FloaterSkill`의 정확한 적용 조건·지속(S14·15·18 작업 전 `scripts/skills/` 확인 권장).
- 다층 사다리에서 개미가 **어느 사다리로 갈지** 방향 제어(중간 발판에서 좌/우 유도) — blocker로만 가능한지,
  아니면 사용자가 스크린샷에서 보여준 정확한 길막기 좌표가 필요한지.

---

## 9. 재현 — 관찰 드라이버

스킬 0 + 개미 위치 로깅으로 자연 동선을 추적하는 임시 드라이버. (작업 후 삭제했으니 필요시 재생성.)
패턴: `Node` 스크립트가 `EventBus.stage_cleared/failed` 연결, `_physics_process`에서 매 N프레임
`get_tree().get_nodes_in_group("ants")`의 `global_position` 로깅, group count 감소 = 물/기절 소멸.
`.tscn`은 `[해당 Stage 씬 인스턴스 + 드라이버 스크립트]` 2노드.

## 10. 파일 상태
- 수정(미커밋): `tests/CampaignS11ClearTest.gd`(PASS), `tests/CampaignS12ClearTest.gd`(WIP, 현재 FAIL).
- 삭제: 임시 `tests/_Obs*.gd`, `tests/_ObsS*.tscn`.
- 미변경: `CampaignS13ClearTest`(PASS 유지), S14~S18 드라이버(아직 옛 가정 — 추후 재작성).
