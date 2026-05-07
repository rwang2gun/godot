# 아키텍처

## 디렉토리 구조
```
CandyAnts/
├── project.godot
├── scenes/
│   ├── Main.tscn
│   ├── stages/Stage01.tscn ...
│   ├── entities/Ant.tscn, Candy.tscn, Home.tscn, hazards/
│   └── ui/HUD.tscn, SkillToolbar.tscn, StageCompleteDialog.tscn
├── scripts/
│   ├── core/        GameManager / EventBus / SkillRegistry (Autoload)
│   │                StageRunner / ScoreSystem / AntSpawner
│   ├── ant/         Ant.gd, AntStateMachine.gd
│   │                states/  Walker / Faller / Carrying / Worker / Saved / Dead
│   ├── skills/      Skill.gd (베이스) + 각 스킬 1파일
│   ├── world/       Candy.gd, Home.gd, Terrain.gd, hazards/
│   └── ui/
├── data/
│   ├── stages/      stageNN.tres (StageData), progression.tres
│   └── skills/      skill_metadata.tres
└── assets/          sprites/, tiles/, audio/
```

## 패턴
- **Vertical Slice** — Stage 1을 최소 시스템으로 End-to-End 완성, 이후 누적 확장. 회귀 = 코어 침범 신호.
- **Plugin/Registry** — SkillRegistry가 `SKILL_SCRIPTS` 배열에 명시적 preload + `validate_stage()`로 ID 정합성 보장. (자기등록 `_static_init` 미사용)
- **Data-Driven Stage** — `stageNN.tres` 데이터 + `StageNN.tscn` 레이아웃. 스테이지 추가 = 데이터 추가, 코드 수정 0.
- **Event Bus** — Autoload 시그널 허브로 시스템 간 디커플링. ScoreSystem ↔ Candy ↔ Home은 시그널로만 연결.
- **State Machine (컴포지션)** — Ant는 StateMachine 자식 노드 보유. 스킬 부여는 상태 전이로 표현 (`change_state(WorkerState.new("builder"))`).

## 데이터 흐름

**개미 생애**:
```
[Trapdoor] → Walker → [Candy] → Carrying(HP-1, 180°) → [Home] → Saved(점수+1)
                ↓                       ↓
            [Hazard]                [Hazard]
                ↓                       ↓
              Dead              Dead + candy_piece_lost
```

**EventBus 핵심 시그널**:
```
candy_piece_picked  → ScoreSystem (in_transit +1)
candy_piece_lost    → ScoreSystem (lost +1)
ant_saved           → ScoreSystem (saved +1, in_transit -1)
candy_depleted      → StageRunner (클리어 조건 검사 트리거)
stage_cleared/failed → UI / GameManager
```

**ScoreSystem 4-카운터** (사탕 조각 수명):
```
original_hp / saved_pieces / in_transit_pieces / lost_pieces
불변식:  saved + in_transit + lost ≤ original_hp
클리어:  candy.hp == 0  AND  in_transit == 0
점수:    saved / original_hp
```

**Area2D 트리거 계약** (Godot 특수성 — 발화 책임은 Area2D 쪽):
| 엔티티 | layer | mask (Ant=3 포함) | monitoring |
|--------|-------|-------------------|------------|
| Candy  | 5     | 3                 | true       |
| Home   | 6     | 3                 | true       |
| Hazard | 4     | 3                 | true       |

Ant(CharacterBody2D)의 `collision_mask`는 Layer 1+2(벽 충돌)만. Area2D 감지는 Area2D 본인 책임.

> 상세 구현 가이드: `docs/references/ARCHITECTURE_v2_detailed.md`
