# 레밍즈 스테이지 디자인 분석 — 1991 원작

**작성 일자**: 2026-05-09
**대상**: Lemmings (1991, DMA Design) 120 레벨
**목적**: CandyAnts 레벨 디자인 가이드 (옵션 B 재구성 시 콘텐츠 생산 템플릿으로 활용)
**구조**: 하이브리드 — 디자인 패턴 + 난이도 곡선 + 대표 레벨 ~20개 깊이 분석

---

## 0. 기획 의도

원작 Lemmings는 120 레벨에 걸쳐 8개 스킬과 군중 제어 메카닉을 가르치고, 압박감과 퍼즐을 조합해서 플레이어를 점진적으로 마스터로 만든다. 본 분석은 **"무엇을 어떻게 가르치고 평가하는가"의 템플릿**을 추출해 CandyAnts 레벨 디자인의 입력 자료로 쓴다.

분석 축:
1. **스테이지 레벨 구조** — 한 레벨의 내부 구성요소 (지형, 시간, 인벤토리, 목표)
2. **난이도 티어 구조** — 120 레벨을 4 티어로 묶는 학습 곡선
3. **디자인 패턴** — 반복 등장하는 레벨 디자인 템플릿 12종
4. **대표 레벨 깊이 분석** — 티어별 5개씩 총 20개 사례

---

## 1. 한 스테이지의 레벨 구조 (Lemmings 1991 기준)

### 1.1 정적 구성요소 (레벨 데이터)

```
LEVEL := {
    name              : str       // "Just dig!"
    tier              : enum      // Fun / Tricky / Taxing / Mayhem
    level_number      : 1..30     // 티어 내 순번
    terrain           : pixel_map // 픽셀 단위 파괴 가능 지형
    spawn_point       : Point     // 트랩도어 위치
    exit_point        : Point     // 출구 위치 (1개)
    objects           : [Trap, Water, OneWayArrow, ...]
    lemming_total     : 1..100    // 보통 10·50·80·100
    rescue_required   : 1..100    // 보통 % 또는 절댓값
    time_limit_min    : 1..9      // 분 단위
    release_rate_init : 1..99     // 1=느림, 99=폭발
    skill_inventory   : {
        climber : 0..N
        floater : 0..N
        bomber  : 0..N
        blocker : 0..N
        builder : 0..N
        basher  : 0..N
        miner   : 0..N
        digger  : 0..N
    }
}
```

### 1.2 핵심 파라미터의 디자인 의미

| 파라미터 | 디자인적 역할 |
|---|---|
| **lemming_total** | 군중 관리 부하 결정 (10=싱글, 50=중간, 100=카오스) |
| **rescue_required** | 사망 허용 수 = (total − required). 0이면 100% 강제 |
| **time_limit** | 페이스 압박. 보통 여유 있게 5~9분, Mayhem은 1~3분 |
| **release_rate** | 초기 페이스. 낮으면 신중, 높으면 카오스. 플레이어 조절 가능 |
| **skill_inventory** | 가용 옵션. 0이면 미사용 강제. 1~2개면 "정밀 배치" 강요 |
| **terrain steel** | 영구 지형 = 우회 강요 |
| **objects.water** | 사망 hazard. Floater로 통과 가능한 경우와 불가능한 경우 분기 |

### 1.3 동적 구성요소 (런타임)

```
RUNTIME := {
    lemmings_alive  : [Lemming]   // 상태 머신: Walker/Faller/Climber/...
    terrain_dynamic : pixel_map   // 굴착·건설로 변경됨
    skill_used      : {skill: int}// 누적 사용량
    counters        : {
        out          : int  // 살아있는 레밍
        in           : int  // 구출된 레밍
        dead         : int  // 사망
    }
    state           : enum  // SPAWNING / ACTIVE / NUKED / VICTORY / FAILED
    time_remaining  : sec
}
```

### 1.4 클리어 / 실패 술어

```
victory := (in_count >= rescue_required) AND (lemmings_alive == 0 OR all_in_exit)
failure := (time_remaining <= 0) AND NOT victory
        OR (out + in + dead == total) AND (in_count < rescue_required)
```

---

## 2. 난이도 티어 구조 (4 × 30 = 120 레벨)

각 티어는 30 레벨, 같은 8 스킬을 다른 조합·강도로 재구성.

### 2.1 티어별 디자인 의도

| 티어 | 레벨 수 | 디자인 의도 | 평균 rescue% | 평균 time | skill 종류 |
|---|---|---|---|---|---|
| **Fun** | 30 | 각 스킬 학습 + 기본 퍼즐 노출 | 50~80% | 5~9분 | 1~4 종 |
| **Tricky** | 30 | 스킬 조합 + 시간 인식 + 자원 한정 도입 | 70~90% | 3~7분 | 3~6 종 |
| **Taxing** | 30 | 엄격 제약 + 희생 강요 + 군중 분리 | 70~95% | 2~6분 | 4~7 종 |
| **Mayhem** | 30 | 100% 빈번 + 극단 자원 부족 + 시간 압박 + 카오스 | 90~100% | 1~5분 | 5~8 종 |

### 2.2 학습 곡선 — 한 스킬이 티어를 거치며 변하는 방식

**예: Builder 스킬의 티어별 등장**

| 티어 | Builder 등장 양상 |
|---|---|
| Fun | Builder 5~10개 풍부, 단순 절벽 건너기 |
| Tricky | Builder 3~5개, "타이밍 맞춰 짓기 시작" 같은 제약 |
| Taxing | Builder 1~2개, 정확한 위치 강요 (1픽셀 단위 시작점) |
| Mayhem | Builder + 다른 스킬과 조합 (Basher로 자른 후 즉시 Builder, 등) |

### 2.3 스킬 등장 분포 (대략적, 티어별)

| 스킬 | Fun 등장 빈도 | Tricky | Taxing | Mayhem |
|---|---|---|---|---|
| Climber | 중 | 중 | 높음 | 높음 |
| Floater | 중 | 높음 | 높음 | 높음 |
| Bomber | 낮음 | 중 | 높음 | 매우 높음 |
| Blocker | 중 | 높음 | 매우 높음 | 매우 높음 |
| Builder | 매우 높음 | 매우 높음 | 높음 | 중 |
| Basher | 높음 | 매우 높음 | 매우 높음 | 매우 높음 |
| Miner | 중 | 높음 | 높음 | 높음 |
| Digger | 높음 | 높음 | 중 | 중 |

→ Builder/Digger는 Fun~Tricky 핵심, Bomber/Blocker는 Taxing~Mayhem에서 폭증.

---

## 3. 디자인 패턴 카탈로그 12종

각 패턴은 레벨 설계 템플릿. 한 레벨에 여러 패턴 결합 가능.

### Pattern 1 — 단일 스킬 도입 (Solo Skill Tutorial)
**특징**: 새 스킬 1개만 인벤토리에, 그 스킬 사용이 거의 강제됨. 풍부한 수량 제공.
**예시**: Fun 1 "Just dig!" — Digger 10개. 절벽 깎아 내려가는 단순 경로.
**티어 분포**: Fun에 집중 (1~5번)
**적용 가치**: 새 메카닉 도입 시 필수 — 플레이어가 메카닉 자체에 집중 가능

### Pattern 2 — 단일 스킬 반복 (Repetition Mastery)
**특징**: 한 스킬을 여러 번 같은 패턴으로 반복 적용. 정확도/타이밍 훈련.
**예시**: Fun 6 "Easy when you know how" — Builder 8개로 계단 8개 쌓기
**티어 분포**: Fun~Tricky
**적용 가치**: 메카닉 깊이 체득 단계. 단조롭지만 학습 효과 큼

### Pattern 3 — 순차 조합 (Sequential Combo)
**특징**: 스킬 A 사용 → 스킬 B 사용 → 스킬 C. 순서가 중요.
**예시**: Tricky 8 "Watch out, there's traps about" — Builder로 건너고 → Blocker로 정지 → Floater로 낙하
**티어 분포**: Tricky~Mayhem
**적용 가치**: 스킬 간 상호작용 학습. 플랜 수립 능력 훈련

### Pattern 4 — 시간 압박 (Time Pressure)
**특징**: 짧은 time_limit + 빠른 release_rate. 결정 미루기 불가능.
**예시**: Taxing 4 "If at first you don't succeed.." — 2분 제한, 빠른 페이스
**티어 분포**: Taxing~Mayhem
**적용 가치**: Pillar 2 (실시간 압박감) 강화 — 마이크로 루프 회전 ↑

### Pattern 5 — 자원 부족 (Skill Scarcity)
**특징**: 핵심 스킬 1~2개만 제공. 낭비 불가, 정확 배치 강요.
**예시**: Taxing 15 "Mary Poppins' land" — Floater 단 1개. 어떤 1마리에 줄지 결정
**티어 분포**: Taxing~Mayhem
**적용 가치**: 의사결정 무게 ↑. 플레이어 인지 부하 ↑

### Pattern 6 — 군중 분리 (Crowd Routing)
**특징**: 여러 경로 분기. Blocker로 분리, Builder로 다리, 두 갈래 동시 진행.
**예시**: Tricky 21 "Lemmings Lemmings everywhere" — 좌우 분기, Blocker로 군중 둘 다 활용
**티어 분포**: Tricky~Mayhem
**적용 가치**: Pillar 4 (군중 관리) 핵심

### Pattern 7 — 희생 강요 (Required Sacrifice)
**특징**: rescue_required < lemming_total. 일부 레밍은 죽여야 진행 가능 (Bomber로 길 만들기 등).
**예시**: Taxing 1 "Keep your hair on Mr. Lemming" — 80% 구출 필요, 20%는 Bomber로 길 뚫기
**티어 분포**: Taxing~Mayhem
**적용 가치**: 도덕적 갈등 + 'Oh No!' 모먼트의 변형. **CandyAnts에서는 사탕 HP 손실로 해석 가능**

### Pattern 8 — Blocker 활용 (Strategic Containment)
**특징**: Blocker로 행렬 정지·반전·분리. 군중 흐름 통제 핵심.
**예시**: Fun 16 "Tailor-made for blockers" — Blocker 4개로 군중 가두기 + 위로 빌더 작업
**티어 분포**: Fun (도입)~Mayhem (정밀)
**적용 가치**: 군중 제어 핵심 메카닉 — CandyAnts Blocker phase에 직접 참조

### Pattern 9 — 수직 진행 (Vertical Movement)
**특징**: Climber + Floater 트레잇 활용. 고도 변화가 퍼즐의 본체.
**예시**: Taxing 9 "Going up.." — Climber + Floater 조합, 높은 절벽 오르기
**티어 분포**: Tricky~Mayhem
**적용 가치**: Pillar 4 (라우팅 다양성) — 수평·수직 모두 활용

### Pattern 10 — 트랩 회피 (Hazard Avoidance)
**특징**: Water/Trap/OneWayArrow 등 환경 hazard. 경로 강제 + 사고 위험.
**예시**: Tricky 14 "Wasteland" — 화염 트랩 다수, 정확 타이밍 통과
**티어 분포**: Tricky~Mayhem
**적용 가치**: Pillar 5 ('Oh No!') 핵심 — 위기 모먼트 자연 발생

### Pattern 11 — 단일 솔루션 (One Way)
**특징**: 정석 풀이만 가능. 자유도 ↓ 정밀도 ↑.
**예시**: Mayhem 11 "Lock 'n' Load" — 한 가지 풀이만, 픽셀 정확도 요구
**티어 분포**: Mayhem (특히 후반)
**적용 가치**: 마스터리 검증 — Pillar 7 (창의적 풀이)과 정반대. **너무 많이 쓰면 Pillar 7 죽음**

### Pattern 12 — 카오스 / 마지막 1초 (Chaos / Last Second)
**특징**: 빠른 release + 많은 레밍 + 짧은 시간. 마지막 순간 극적 클리어.
**예시**: Mayhem 30 "Save Me" — 100 레밍, 100% 필요, 카오스 페이스
**티어 분포**: Mayhem (피날레)
**적용 가치**: Pillar 3 ('Save!' 모먼트) 극대화 — 게임 정체성 표현

---

## 4. 대표 레벨 깊이 분석 (총 20개, 티어별 5개)

### 4.1 Fun 티어 5개

#### Fun 1 — "Just dig!"
- **lemming**: 10, **rescue**: 50%, **time**: 1분, **skills**: Digger × 10
- **핵심 경험**: "스킬 부여 = 클릭"의 첫 학습. 실패 거의 불가능
- **사용 패턴**: 1 (단일 스킬 도입)
- **CandyAnts 적용**: Stage 1 stage1-core가 이미 이 역할 — 단, CandyAnts는 0 스킬로 더 단순화

#### Fun 5 — "I've lost my marbles"
- **lemming**: 50, **rescue**: 60%, **time**: 6분, **skills**: 모든 스킬 적당량
- **핵심 경험**: 8 스킬 다 노출. 자유 실험 환경
- **사용 패턴**: 2 (반복) + 3 (조합) 약하게
- **CandyAnts 적용**: 마지막 튜토리얼 스테이지 (모든 스킬 노출 후 자유 실험)

#### Fun 8 — "We all fall down"
- **lemming**: 50, **rescue**: 70%, **time**: 5분, **skills**: Floater × 50
- **핵심 경험**: 모든 레밍을 Floater로 만들기 (트레잇 영구성 학습)
- **사용 패턴**: 2 (반복)
- **CandyAnts 적용**: 트레잇 vs 액션 구분 학습 — Climber/Floater 도입 phase에 적합

#### Fun 16 — "Tailor-made for blockers"
- **lemming**: 80, **rescue**: 50%, **time**: 5분, **skills**: Builder + Blocker
- **핵심 경험**: Blocker로 군중 가두고 일부만 작업
- **사용 패턴**: 6 (군중 분리) + 8 (Blocker 활용) 도입
- **CandyAnts 적용**: Blocker phase의 핵심 학습 레벨 템플릿

#### Fun 22 — "Origins and Lemmings"
- **lemming**: 50, **rescue**: 60%, **time**: 6분, **skills**: 5~6 종
- **핵심 경험**: 복잡 지형 + 멀티 스킬. Fun 후반의 통합 평가
- **사용 패턴**: 3 (순차 조합)
- **CandyAnts 적용**: 각 phase 마지막 stage 패턴 — "이번 phase 메카닉 통합 평가"

### 4.2 Tricky 티어 5개

#### Tricky 1 — "This should be a doddle!"
- **lemming**: 80, **rescue**: 50%, **time**: 5분, **skills**: 다양
- **핵심 경험**: Tricky 입문 — 자유도는 비슷하나 인벤토리 살짝 줄어듦
- **사용 패턴**: 5 약함 (자원 부족 도입)
- **CandyAnts 적용**: 난이도 티어 전환 레벨 — "이제부터 진짜"

#### Tricky 8 — "Watch out, there's traps about"
- **lemming**: 50, **rescue**: 80%, **time**: 5분, **skills**: Builder, Blocker, Floater
- **핵심 경험**: 트랩 회피 + 스킬 순차
- **사용 패턴**: 3 (순차) + 10 (트랩)
- **CandyAnts 적용**: Hazard phase의 핵심 레벨

#### Tricky 14 — "Wasteland"
- **lemming**: 50, **rescue**: 80%, **time**: 6분, **skills**: 멀티 hazard 통과용
- **핵심 경험**: 화염 트랩 다수, 정확 타이밍
- **사용 패턴**: 4 (시간) + 10 (트랩)
- **CandyAnts 적용**: 후반 Hazard phase에서 적용

#### Tricky 21 — "Lemmings Lemmings everywhere"
- **lemming**: 80, **rescue**: 80%, **time**: 5분, **skills**: 다양
- **핵심 경험**: 양쪽 출구·양쪽 분리, 군중 라우팅
- **사용 패턴**: 6 (군중 분리)
- **CandyAnts 적용**: Multi-path 레벨 — Home이 1개라 변형 필요 (출구 1개 + 양쪽 진입로)

#### Tricky 30 — "Pillars of Hercules"
- **lemming**: 80, **rescue**: 90%, **time**: 5분, **skills**: Climber 강조
- **핵심 경험**: Climber 트레잇 다수 활용
- **사용 패턴**: 9 (수직)
- **CandyAnts 적용**: Climber phase 정수 레벨

### 4.3 Taxing 티어 5개

#### Taxing 1 — "Keep your hair on Mr. Lemming"
- **lemming**: 50, **rescue**: 80%, **time**: 5분, **skills**: 다양 + Bomber
- **핵심 경험**: 일부 레밍을 희생해서 길 만들기 (Bomber 활용)
- **사용 패턴**: 7 (희생)
- **CandyAnts 적용**: **사탕 HP 손실 = 희생 메카닉**. ADR-002와 직결되는 정수 레벨

#### Taxing 4 — "If at first you don't succeed.."
- **lemming**: 60, **rescue**: 83%, **time**: 2분, **skills**: 제한적
- **핵심 경험**: 짧은 시간 + 정확한 작업
- **사용 패턴**: 4 (시간) + 11 (단일 솔루션)
- **CandyAnts 적용**: 챌린지 모드 / 30분+ 플레이어 후반 콘텐츠

#### Taxing 9 — "Going up.."
- **lemming**: 80, **rescue**: 80%, **time**: 5분, **skills**: Climber, Floater, Builder
- **핵심 경험**: 수직 상승 라우팅
- **사용 패턴**: 9 (수직) + 3 (순차)
- **CandyAnts 적용**: Climber/Floater 통합 phase 평가

#### Taxing 15 — "Mary Poppins' land"
- **lemming**: 80, **rescue**: 90%, **time**: 6분, **skills**: Floater 1개 + 기타
- **핵심 경험**: Floater 1개라는 극단 자원 부족
- **사용 패턴**: 5 (자원 부족)
- **CandyAnts 적용**: 후반 챌린지 — "어느 1마리에게 Floater를?"

#### Taxing 25 — "Steel Works"
- **lemming**: 100, **rescue**: 90%, **time**: 5분, **skills**: 다양
- **핵심 경험**: indestructible (강철) 지형 회피
- **사용 패턴**: 11 (단일 솔루션) + 6 (라우팅)
- **CandyAnts 적용**: 영구 지형 도입 시 — TileMap에 destructible/indestructible 분리

### 4.4 Mayhem 티어 5개

#### Mayhem 1 — "Steel Works"
- **lemming**: 100, **rescue**: 100%, **time**: 4분, **skills**: 매우 제한적
- **핵심 경험**: Taxing 25 변형 + 100% 강제
- **사용 패턴**: 11 + 12 (카오스)
- **CandyAnts 적용**: Mayhem 티어 전체가 챌린지 모드의 영감

#### Mayhem 7 — "It's hero time!"
- **lemming**: 80, **rescue**: 100%, **time**: 5분, **skills**: 1~2개로 매우 제한
- **핵심 경험**: 단 한 명의 히어로(Climber+Floater)가 전체 길을 만들어야 함
- **사용 패턴**: 5 (극단 자원 부족) + 7 (히어로 희생 X 보호)
- **CandyAnts 적용**: 운반자 1명 보호 컨셉 — Lifeguard 메카닉 연상

#### Mayhem 11 — "Lock 'n' Load"
- **lemming**: 80, **rescue**: 100%, **time**: 5분, **skills**: 정확 분배
- **핵심 경험**: 픽셀 정확 빌더 시작점 강요
- **사용 패턴**: 11 (단일 솔루션)
- **CandyAnts 적용**: 후반 마스터리 챌린지 — 단, **너무 많으면 Pillar 7 죽음**

#### Mayhem 21 — "All or Nothing"
- **lemming**: 80, **rescue**: 100%, **time**: 4분, **skills**: 정밀
- **핵심 경험**: 완벽한 100% 강요. 한 명 잃어도 실패
- **사용 패턴**: 11 + 12
- **CandyAnts 적용**: 챌린지 모드 — 본 게임은 보통 80~90% 권장

#### Mayhem 30 — "Save Me"
- **lemming**: 100, **rescue**: 100%, **time**: 1~2분, **skills**: 풀 카오스
- **핵심 경험**: 게임 마지막 — 모든 메카닉 + 극한 압박. 'Save!' 모먼트 최대화
- **사용 패턴**: 12 (카오스) + 11 (단일 솔루션)
- **CandyAnts 적용**: Stage 10 bomber-polish의 마지막 스테이지 영감 — 게임 정체성 결정

---

## 5. CandyAnts 적용 가이드

### 5.1 티어 매핑 안

원작 4 티어 × 30 = 120 레벨은 너무 큰 스코프. **MVP는 3 티어 × 5~8 = 15~24 레벨** 추천:

| CandyAnts 티어 | 레벨 수 | 디자인 의도 | 원작 매핑 |
|---|---|---|---|
| **Sweet** (튜토리얼) | 5~8 | 각 스킬 도입 + 기본 퍼즐 | Fun 1~15 (간추림) |
| **Sticky** (중급) | 5~8 | 스킬 조합 + 시간 인식 + 사탕 HP 손실 도입 | Tricky 전반 + Taxing 일부 |
| **Crunchy** (고급) | 5~8 | 자원 부족 + 군중 분리 + 100% 챌린지 | Taxing 후반 + Mayhem 일부 |

→ **총 15~24 레벨 MVP**. 그 외는 level editor로 생산 (옵션 B 정합).

### 5.2 phase 14~20 재구성 영감

옵션 B (스킬·스테이지 분리) 따르면, 7개 stage phase를 **메카닉 phase + 메카닉별 데모 1~2 stage**로 압축 가능:

| 신규 phase | 메카닉 | 데모 스테이지 | 원작 영감 |
|---|---|---|---|
| **mechanic-traits** | Climber + Floater (트레잇) | Sweet 2개 (각 스킬 도입) | Fun 8 "We all fall down" + Pillars of Hercules |
| **mechanic-hazards-water** | Hazard 시스템 + Water | Sticky 1~2개 | Tricky 8/14 (트랩 패턴) |
| **mechanic-destruction** | Basher + Miner + Digger (지형 파괴 3종 통합) | Sticky 2~3개 | Fun 1 "Just dig!" + 조합 레벨 |
| **mechanic-bomber-blocker** | Bomber + Blocker (희생·통제) | Crunchy 2~3개 | Fun 16 "Tailor-made" + Taxing 1 |
| **polish-final** | Release Rate + 100% 챌린지 + 사운드 hook | Crunchy 1~2개 | Mayhem 30 "Save Me" |

→ 5 phase로 압축. **기존 7 phase 대비 -30%**. 콘텐츠는 level editor로 추가 생산.

### 5.3 학습 곡선 권장

3 티어를 다음 비율로 구성:

```
Sweet:    플레이어 자력 클리어 100% (실패 거의 없음)
Sticky:   60~70% 자력 클리어, 30~40% 1~2회 재시도
Crunchy:  20~40% 자력 클리어, 챌린지 모드 도입
```

각 티어 마지막 레벨은 **"통합 평가"** 성격 — 그 티어의 모든 메카닉 한 번에 묶음 (Fun 22 "Origins and Lemmings" 패턴).

### 5.4 패턴별 권장 빈도

CandyAnts 15~24 레벨 풀에서 각 패턴이 등장할 빈도:

| 패턴 | 권장 빈도 | 이유 |
|---|---|---|
| 1 (단일 도입) | 5~8회 (각 스킬당 1회) | 메카닉 학습 필수 |
| 2 (반복) | 3~5회 | 체득 단계 |
| 3 (순차 조합) | 4~6회 | 후반 절반 |
| 4 (시간 압박) | 2~3회 | 챌린지 모드 중심 |
| 5 (자원 부족) | 2~4회 | 의사결정 무게 |
| 6 (군중 분리) | 2~3회 | Pillar 4 강화 |
| 7 (희생) | 2~3회 | **사탕 HP 손실 메카닉 정수** — ADR-002와 직결 |
| 8 (Blocker) | 2~3회 | Blocker phase 핵심 |
| 9 (수직) | 1~2회 | Climber phase |
| 10 (트랩) | 2~3회 | Hazard phase |
| 11 (단일 솔루션) | 1~2회만 | Pillar 7 보호 위해 절제 |
| 12 (카오스) | 1회 (피날레) | 게임 정체성 |

### 5.5 사탕 HP 메카닉의 디자인 가치

원작의 Pattern 7 (희생)이 CandyAnts에서 **HP 손실 = 영구 사탕 조각 손실**로 자연스럽게 변환됨. 원작은 "레밍이 죽어도 클리어 % 손실"이지만, CandyAnts는 "사탕 조각이 영원히 사라짐" — 더 직관적이고 감정 무게 큼.

이를 활용한 레벨 디자인:
- **80% 클리어 가능 레벨** = 사탕 80HP 중 16HP 손실 허용 = "2명의 운반자가 죽어도 OK"
- **100% 챌린지** = "한 조각도 잃지 마"
- 플레이어가 의도적으로 운반자 사망을 활용 (Bomber로 길 뚫기) 시 **lost 카운터 명시적 증가** → ADR-002 4-카운터의 디자인 정당성

---

## 6. 핵심 인사이트 요약

1. **원작 Lemmings는 8 스킬을 120 레벨에 걸쳐 12개 디자인 패턴으로 변주**. 스킬 추가가 아닌 **패턴 조합**이 콘텐츠 다양성의 본체.

2. **티어별 학습 곡선이 명확** — Fun=학습, Tricky=조합, Taxing=제약, Mayhem=극단. CandyAnts는 3 티어로 압축 가능 (Sweet/Sticky/Crunchy).

3. **CandyAnts MVP는 15~24 레벨로 충분**. 그 이상은 level editor로 생산. 옵션 B (메카닉·스테이지 분리)에 정합.

4. **사탕 HP 손실 메카닉이 원작 Pattern 7 (희생)을 더 강하게 표현**. ADR-002 4-카운터의 디자인 정당성은 본 분석에서 확인됨.

5. **Pattern 11 (단일 솔루션)은 절제** — Mayhem에서만 등장하는 이유는 Pillar 7 (창의적 풀이)을 죽이기 때문. CandyAnts에서는 2회 이하 권장.

6. **티어 마지막 레벨은 "통합 평가"** — 그 티어의 모든 메카닉 한 번에. CandyAnts 각 메카닉 phase 마지막 스테이지가 이 역할.

7. **Mayhem 30 "Save Me" 같은 피날레 1개는 필수** — 게임 정체성 결정. CandyAnts polish-final phase에 동등한 스테이지 필요.

---

## 7. 참조 / 추가 조사 권장

본 문서는 텍스트 기반 패턴 분석. 정확도 검증 위한 추가 자료:
- Lemmings (1991) DOS gameplay 영상 (특히 Mayhem 티어 완주 영상)
- NeoLemmix 공식 위키 — 레벨 통계 데이터베이스
- Lemmings Universe 팬 사이트 — 각 레벨 솔루션 + 디자인 분석 글
- Mike Dailly (DMA Design 공동 창립자) 인터뷰 — 디자인 의도

CandyAnts 첫 5~8 레벨 디자인 시 **Fun 1, 5, 8, 16, 22** 5개 레벨을 1차 영감 자료로 권장.
