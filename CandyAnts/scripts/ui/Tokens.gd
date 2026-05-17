class_name Tokens
extends RefCounted

# Cream / Ink (UI_GUIDE §1.1)
const CREAM_50  := Color("#FBF8F1")
const CREAM_100 := Color("#F5EFE3")
const CREAM_200 := Color("#E9DFCB")
const CREAM_300 := Color("#D9C9AC")
const INK_900   := Color("#3A2A1C")
const INK_700   := Color("#5C4530")
const INK_500   := Color("#8C7660")

# Brand / Semantic (UI_GUIDE §1.2)
const PEACH_300 := Color("#FAD9C4")
const PEACH_500 := Color("#F2A48F")
const PEACH_700 := Color("#D17A60")
const MINT_300  := Color("#D4F0E5")
const MINT_500  := Color("#9ED9C2")
const MINT_700  := Color("#5EA88A")
const BERRY_300 := Color("#F7C9C4")
const BERRY_500 := Color("#E48579")
const BERRY_700 := Color("#B85546")
const LEMON_300 := Color("#FCEFC2")
const LEMON_500 := Color("#F0D77B")
const LEMON_700 := Color("#C9A93C")
const GRAPE_300 := Color("#DCCEE2")
const GRAPE_500 := Color("#B49AC5")
const GRAPE_700 := Color("#7E5A9A")

# Illustration 전용 documented constants (UI_GUIDE §1.2).
# Theme/atom 코드 분기 비사용. Theme inspector 3-way 검증 대상 아님.
# 현 handoff stage_bg.svg는 본 토큰 자체가 아닌 oklch_extras 변종(#A9CFA5/#D6E5F0 등)을 사용 —
# 본 상수들은 SoT 완전성(UI_GUIDE §1.2 mirror)을 위해 유지하는 documented constants.
const SKY_300   := Color("#CCDFEA")
const GRASS_300 := Color("#B0DCB4")

# Counter kind (UI_GUIDE §1.3) — phase 10 atom용 enum
enum CounterKind { CANDY_HP, IN_TRANSIT, SAVED, LOST, TIME }

const COUNTER_COLOR := {
	CounterKind.CANDY_HP:   PEACH_500,
	CounterKind.IN_TRANSIT: GRAPE_500,
	CounterKind.SAVED:      MINT_500,
	CounterKind.LOST:       BERRY_500,
	CounterKind.TIME:       LEMON_700,
}

# Tint kind (UI_GUIDE §3.2) — phase 10 Chip atom용.
# 5 tint = brand palette의 *_300 변종. border는 현 spec 기준 모두 ink_900.
enum TintKind { PEACH, GRAPE, MINT, BERRY, LEMON }

const TINT_BG := {
	TintKind.PEACH: PEACH_300,
	TintKind.GRAPE: GRAPE_300,
	TintKind.MINT:  MINT_300,
	TintKind.BERRY: BERRY_300,
	TintKind.LEMON: LEMON_300,
}

const TINT_BORDER := {
	TintKind.PEACH: INK_900,
	TintKind.GRAPE: INK_900,
	TintKind.MINT:  INK_900,
	TintKind.BERRY: INK_900,
	TintKind.LEMON: INK_900,
}
