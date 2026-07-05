#!/usr/bin/env python3
"""
Phase R (RL 솔버) — plan-구성 MDP 정의 (순수 / 엔진·torch 비의존).

에피소드 = plan 구성: 스텝마다 액션 1개 추가 or SUBMIT → 완성 plan을 엔진 롤아웃 1회로 평가(terminal
reward). 문법(R0 어휘)·보상·관측 인코딩의 단일 출처. plan SoT = auto-solver-plan.md §Phase R.

레이아웃 파싱은 model.parse_layout, 스테이지 메타는 solve.stage_meta를 read-only 재사용(중복 구현 금지).
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent            # tools/solver/rl
SOLVER = HERE.parent                              # tools/solver
ROOT = SOLVER.parents[1]                          # .../CandyAnts
for p in (str(SOLVER), str(ROOT / "scripts")):
    if p not in sys.path:
        sys.path.insert(0, p)

for _s in (sys.stdout, sys.stderr):               # cp949 무관 UTF-8(트랙 공통 gotcha)
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

import model  # noqa: E402  (tools/solver/model.py — parse_layout)
import solve  # noqa: E402  (tools/solver/solve.py — stage_meta)

_METAS_CACHE: dict | None = None


def skill_metas() -> dict:
    """SkillRegistry 메타(SolverMetaDump 브리지, D7 — 게임지식 하드코딩 0). 프로세스당 1회 Godot 부팅 캐시."""
    global _METAS_CACHE
    if _METAS_CACHE is None:
        _METAS_CACHE = solve.dump_capabilities()["skills"]
    return _METAS_CACHE

# ---------- 문법 어휘 (R0 — plan §Phase R MDP 정의) ----------
TRIGGER_VOCAB = ("ant_reaches_x", "picked_ge")
CMP_VOCAB = ("ge", "le")
SELECT_VOCAB = ("max_x", "min_x")
STATE_VOCAB = ("any", "walker", "carrying")
# r1.1 (2026-07-04, S12 FAIL 진단 반영): y_row 어휘 = any + **layout-파생 surface rows**(개미가 설 수
# 있는 행만 — solid 위 빈 셀). 18행 전수 → ~6개로 needle 축소. D7-충실: 레이아웃 관측 파생(해 힌트 아님).
GRAMMAR_VERSION = "r1.1"

# ---------- r2 문법 어휘 (plan §R2 P2/P3 — 전역 어휘 + per-stage 마스킹) ----------
# r2.1: 스테이지-불변 정책의 액션 어휘. skill head = 전역 스킬 사전(SkillRegistry 메타 파생, D7) +
# 인벤토리 마스크 / target_kind ∈ {ant, cell} 1급 판별자(sum-type, 무효 조합은 마스킹으로 표현 불가) /
# col·row head = campaign_manifest 등재 스테이지 전수 스캔 파생 전역 최대 격자 + 스테이지 범위 마스크 /
# 트리거에 at_frame 추가(S19 known 해 요구) — head = 양자화 격자(0 포함, 상한 = at_frame_cap 마스크).
GRAMMAR_R2 = "r2.1"
KIND_VOCAB = ("ant", "cell")
TRIGGER_VOCAB_R2 = ("ant_reaches_x", "picked_ge", "at_frame")
AT_FRAME_QUANT = 300          # at_frame head 양자화 간격(프레임) — plan §R2 P3(간격 상수는 impl 확정)
AT_FRAME_MAX = 7000           # head 크기 상한 = 판정 replay deadline pin(train.REPLAY_DEADLINE)과 정합
FRAME_BINS = AT_FRAME_MAX // AT_FRAME_QUANT + 1   # 24 bins: frame 0, 300, ..., 6900
# head 샘플링/슬롯 인코딩 순서(고정) — 조건부 활성: SUBMIT이면 skill만, 이후 kind→trigger→의존 head.
R2_HEAD_ORDER = ("skill", "kind", "trigger", "cmp", "param", "frame",
                 "select", "state", "col", "row")
R2_TRIGGER_HEADS = {"ant_reaches_x": ("cmp", "param"), "picked_ge": ("param",),
                    "at_frame": ("frame",)}


def _sha(obj) -> str:
    return hashlib.sha256(json.dumps(obj, sort_keys=True).encode("utf-8")).hexdigest()


def manifest_stage_ids() -> list[int]:
    """campaign_manifest.tres의 챕터 순서대로 평탄화한 stage id 리스트 — curriculum 순서 SoT
    (plan §R2 P4, plan-R1 HIGH-4: read-only 파싱, 하드코딩 0)."""
    text = (ROOT / "data" / "campaign_manifest.tres").read_text(encoding="utf-8")
    ids: list[int] = []
    for m in re.finditer(r'"stage_ids"\s*:\s*\[([^\]]*)\]', text):
        ids += [int(x) for x in re.findall(r"-?\d+", m.group(1))]
    if not ids:
        raise ValueError("campaign_manifest.tres에서 stage_ids를 못 읽음 — curriculum SoT 파싱 실패")
    return ids


_VOCAB_CACHE: dict | None = None


def global_vocab() -> dict:
    """r2 전역 어휘(P2) — 전역 최대 W/H/hp의 권위 = campaign_manifest 등재 스테이지 레이아웃 전수 스캔
    (plan-R2 MED-1, 하드코딩 0). digest = 전역 어휘/head-시맨틱 전부(스킬 사전 순서·트리거 어휘·격자
    어휘 크기·at_frame bin)의 해시 — transfer-ckpt fail-closed 일치 대상(plan-R3 HIGH-1)."""
    global _VOCAB_CACHE
    if _VOCAB_CACHE is None:
        skills = tuple(sorted(skill_metas().keys()))
        w_max = h_max = hp_max = 0
        for sid in manifest_stage_ids():
            lay = model.parse_layout(ROOT / "data" / "stage_layouts" / f"stage{sid:02d}_layout.tres")
            cells = set(lay["occupied"]) | set(lay["hazard"])
            for v in (lay["candy"], lay["home"]):
                if v:
                    cells.add(v)
            w_max = max(w_max, max(c for c, _ in cells) + 1)
            h_max = max(h_max, max(r for _, r in cells) + 1)
            hp_max = max(hp_max, int(solve.stage_meta(sid)["candy_hp"]))
        heads = {"skill": len(skills) + 1, "kind": len(KIND_VOCAB),
                 "trigger": len(TRIGGER_VOCAB_R2), "cmp": len(CMP_VOCAB),
                 "param": max(w_max, hp_max), "frame": FRAME_BINS,
                 "select": len(SELECT_VOCAB), "state": len(STATE_VOCAB),
                 "col": w_max, "row": h_max + 1}
        spec = {"grammar": GRAMMAR_R2, "skills": list(skills), "kinds": list(KIND_VOCAB),
                "triggers": list(TRIGGER_VOCAB_R2), "cmp": list(CMP_VOCAB),
                "select": list(SELECT_VOCAB), "state": list(STATE_VOCAB),
                "at_frame_quant": AT_FRAME_QUANT, "at_frame_max": AT_FRAME_MAX,
                "w_max": w_max, "h_max": h_max, "hp_max": hp_max, "heads": heads}
        _VOCAB_CACHE = {**spec, "digest": _sha(spec)}
    return _VOCAB_CACHE

# 보상 계수 (plan: 형태 확정·계수 튜닝 자유 — effective config로 manifest에 박제)
REWARD = {"cleared": 2.0, "saved": 1.0, "picked": 0.3, "lost": -0.2,
          "len_penalty": -0.02, "timeout_penalty": -0.1}

# R1 trace-shaped 보상 계수 (plan §R1: 형태 확정·계수 튜닝 자유, 총합 상한 < cleared 유지).
# S12 prefix 실측(plan §R1 grounding): goal 항이 #1을, retired 항이 #2를 구별 — 둘 다 필수.
SHAPING = {"goal": 0.5, "retired": 0.1}

# ---------- R3 obs 스키마 (trace-refinement MDP — plan §R3 R3_OBS_SCHEMA, 전량 pin) ----------
# 관측 확장분의 *전부*를 결정론 확정("impl 확정" 여지 0). verify-r3가 obs_schema_digest 불일치를
# fail-closed. r0/r1/r2 경로는 이 스키마를 부착하지 않음(--refine opt-in) — obs 차원·재현성 불변.
TRACE_CHANNELS = ("visit_walk", "loss", "visit_carry", "pickup_goal")   # C_trace=4 (고정 이름·순서)
C_TRACE = len(TRACE_CHANNELS)
TRACE_SCALARS = ("best_goal_dist", "retired_total", "retired_water", "retired_fall",
                 "picked_total", "saved", "verdict_code")               # 집계 스칼라(고정 순서)
N_TRACE_SCALAR = len(TRACE_SCALARS)
# verdict_code enum pin(R2-med1 — 숫자 매핑 고정), 정규화 /VERDICT_NORM.
VERDICT_CODE = {"absent": 0, "cleared": 1, "incomplete": 2, "timeout": 3, "error": 4}
VERDICT_NORM = 4
DENSITY_DENOM = 7000     # = replay_deadline(셀 총 방문 상한 상수) — visit_walk/carry per-cell 정규화 분모
# 스칼라 정규화 분모 = 레이아웃/스테이지 상수(result 파생 금지, R1-H1). digest는 규칙명만 인코딩(스테이지-무관).
SCALAR_DENOM = {"best_goal_dist": "W+H", "retired_total": "total_ants",
                "retired_water": "total_ants", "retired_fall": "total_ants",
                "picked_total": "hp", "saved": "hp", "verdict_code": "4"}
MARKER_DENOM = "total_ants"      # loss/pickup_goal 이벤트 마커 채널 정규화 분모(레이아웃 상수)
OBS_DTYPE = "float32"
OBS_ABSENT_RULE = "all_channels_scalars_zero_verdict_absent"


def _verdict_code_of(res: dict) -> int:
    if not res:
        return VERDICT_CODE["absent"]
    if "error" in res:
        return VERDICT_CODE["error"]
    if res.get("cleared"):
        return VERDICT_CODE["cleared"]
    if res.get("reason") == "deadline":
        return VERDICT_CODE["timeout"]
    return VERDICT_CODE["incomplete"]


def rasterize_channels(trace: dict, layout: dict, H: int, W: int, ants_total: int) -> list[float]:
    """공간 채널 [H×W×C_TRACE] flatten((r*W+c)*C_TRACE+ch). 결정론·좌표 rasterize(순수 — golden 결속
    대상, codex §R3 MED-3). absent(빈 trace) = 전 채널 0. off-grid는 버림 없이 격자 경계 clamp.
    밀도(visit_walk/carry) = per-cell 카운트/DENSITY_DENOM, 마커(loss/pickup_goal) = 카운트/ants_total, clip."""
    g = [0.0] * (H * W * C_TRACE)
    tr = trace or {}
    if not tr:
        return g

    def add(cx: int, cy: int, ch: int, v: float) -> None:
        c = min(max(int(cx), 0), W - 1)
        r = min(max(int(cy), 0), H - 1)
        g[(r * W + c) * C_TRACE + ch] += v

    home = layout.get("home")
    for si in sorted({int(k) for k in tr.keys()}):
        ss = model._samples(tr, si)
        if not ss:
            continue
        picked_seen = False
        for s in ss:
            cx, cy = s[1], s[2]
            carry = s[3]
            st = s[4] if len(s) > 4 else "other"
            if st == "walk":
                add(cx, cy, 0, 1.0)               # visit_walk 밀도
            elif st == "carry":
                add(cx, cy, 2, 1.0)               # visit_carry 밀도(귀로 loop)
            if st in ("dead", "lost"):
                add(cx, cy, 1, 1.0)               # loss 마커(기절사/익사 상태)
            if carry == 1 and not picked_seen:
                add(cx, cy, 3, 1.0)               # pickup 마커(첫 운반 진입)
                picked_seen = True
        if model._died_water(ss, layout):         # 드리프트 익사(dead/lost 상태 없이 물로) 마커
            add(ss[-1][1], ss[-1][2], 1, 1.0)
        cx, cy = ss[-1][1], ss[-1][2]
        if home is not None and abs(cx - home[0]) <= 1 and abs(cy - home[1]) <= 1:
            add(cx, cy, 3, 1.0)                   # goal 도달(귀가=saved) 마커
    for i in range(H * W):
        base = i * C_TRACE
        for ch in (0, 2):
            g[base + ch] = min(1.0, g[base + ch] / DENSITY_DENOM)
        for ch in (1, 3):
            g[base + ch] = min(1.0, g[base + ch] / ants_total)
    return g


def rasterize_scalars(trace: dict, res: dict, layout: dict, ants_total: int,
                      hp: int, D0: int) -> list[float]:
    """집계 스칼라(TRACE_SCALARS 순서, 순수 — golden 결속). absent = 전부 0. 분모 = 레이아웃/스테이지 상수."""
    if not res or not trace:
        return [0.0] * N_TRACE_SCALAR
    gd = model.best_goal_dist(trace, layout)
    ret = model.count_retired(trace, layout)
    picked = max(0, int(res.get("picked_total") or 0))
    saved = max(0, int(res.get("saved") or 0))
    return [min(gd, D0) / D0,
            ret["total"] / ants_total, ret["water"] / ants_total, ret["fall"] / ants_total,
            picked / hp, saved / hp,
            _verdict_code_of(res) / VERDICT_NORM]


def _obs_golden() -> str:
    """고정 합성 (layout, trace, res)로 rasterize 실행 → **실제 시맨틱(clamp·state→채널 매핑·pickup/goal
    마커·물사·정규화)을 digest에 결속**(codex §R3 MED-3: 이름/분모만 pin하면 rasterize 로직 변경이 digest를
    안 바꾼다). Godot 불요(model 순수 함수만). 시맨틱 변경 = golden 변경 = obs_schema_digest 변경."""
    layout = {"occupied": {(0, 2), (1, 2), (2, 2), (3, 2)}, "ladder": set(),
              "hazard": {(3, 3): "water"}, "candy": (2, 0), "home": (0, 0), "cell_size": 48}
    H, W, ants, hp, D0 = 4, 4, 3, 2, 8
    trace = {"0": [[0, 0, 2, 0, "walk"], [5, 1, 2, 0, "walk"], [9, 2, 2, 1, "carry"],
                   [12, 0, 0, 1, "carry"]],                      # 픽업 후 귀가(goal)
             "1": [[0, 0, 2, 0, "walk"], [3, 3, 3, 0, "lost"]],  # 상태 loss
             "2": [[0, 2, 2, 0, "walk"], [4, 3, 2, 0, "walk"]]}  # 물 아래(3,3) 드리프트 익사
    res = {"cleared": False, "reason": "deadline", "saved": 1, "picked_total": 2, "trace": trace}
    ch = rasterize_channels(trace, layout, H, W, ants)
    sc = rasterize_scalars(trace, res, layout, ants, hp, D0)
    return _sha([round(x, 6) for x in ch] + [round(x, 6) for x in sc])


def obs_schema() -> dict:
    """R3_OBS_SCHEMA 전체(채널 이름/순서·스칼라 순서·verdict enum·정규화 분모 규칙·dtype·absent 규칙
    + rasterize golden 벡터). digest = ckpt·산출물·verify-r3 대조 키(스테이지-무관 상수)."""
    spec = {"trace_channels": list(TRACE_CHANNELS), "trace_scalars": list(TRACE_SCALARS),
            "verdict_code": dict(VERDICT_CODE), "verdict_norm": VERDICT_NORM,
            "density_denom": DENSITY_DENOM, "marker_denom": MARKER_DENOM,
            "scalar_denom": dict(SCALAR_DENOM), "dtype": OBS_DTYPE,
            "absent_rule": OBS_ABSENT_RULE, "rasterize_golden": _obs_golden()}
    return {**spec, "digest": _sha(spec)}


OBS_SCHEMA_DIGEST = obs_schema()["digest"]


class StageMDP:
    """스테이지 1개에 대한 plan-구성 MDP: 관측 인코딩 / factored 액션 decode·encode / terminal 보상.

    grammar 인자(plan §R2 선결 계약): "r1.1"(기본 — 기존 경로 보존, stage11/12 pinned 산출물 영구 검증)
    / "r2.1"(전역 어휘 + per-stage 마스킹 + cell-target sum-type). r1.1 경로는 R2에서 무변경."""

    def __init__(self, stage_id: int, max_len: int = 6, grammar: str = GRAMMAR_VERSION,
                 at_frame_cap: int = 4500):
        self.stage_id = stage_id
        self.grammar_version = grammar
        self.stage_scene = f"res://scenes/stages/Stage{stage_id:02d}.tscn"
        meta = solve.stage_meta(stage_id)
        self.inventory: dict[str, int] = meta["inventory"]
        self.hp: int = meta["candy_hp"]                       # hp_stage(상수) — result.hp 미사용(R1-H1)
        self.ants_total: int = max(1, int(meta["total_ants"]))  # shaping 분모(스테이지 상수, R1 계약)
        self.layout = model.parse_layout(
            ROOT / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres")
        self.cs: int = self.layout["cell_size"]
        cells = set(self.layout["occupied"]) | set(self.layout["hazard"])
        for v in (self.layout["candy"], self.layout["home"]):
            if v:
                cells.add(v)
        self.W = max(c for c, _ in cells) + 1
        self.H = max(r for _, r in cells) + 1
        self.D0 = self.W + self.H                             # 셀 맨해튼 상한(레이아웃 상수) — shaping 분모
        # surface rows = 개미가 설 수 있는 행(빈 셀 (c,r) 아래 (c,r+1)이 solid). r1.1 y_row 어휘이자
        # r2 ant-row 마스크(같은 전역 row head를 kind별 다른 마스크로 공유, plan §R2 P2 행 head 이원화).
        occ = set(self.layout["occupied"])
        self.y_rows: list[int] = sorted({r for (c, r1) in occ
                                         for r in ((r1 - 1),) if r >= 0 and (c, r) not in occ})
        if grammar == GRAMMAR_R2:
            self._init_r2(max_len, at_frame_cap)
        elif grammar == GRAMMAR_VERSION:
            self._init_r1(max_len)
        else:
            raise ValueError(f"unknown grammar {grammar!r} (지원: {GRAMMAR_VERSION!r}, {GRAMMAR_R2!r})")
        # 관측 레이아웃(고정 스테이지 = 상수지만 일반화 대비 포함, plan §관측)
        self._grid = self._encode_grid()
        self._slot_dim = 1 + sum(self.heads[h] for h in self.head_names)
        if grammar == GRAMMAR_VERSION:
            self.obs_dim = len(self._grid) + len(self.skills) + self.max_len * self._slot_dim + 1
        else:
            # r2: grid는 CNN 입력(가변 H×W), flat 부는 전역 고정 차원 — 스테이지-불변(plan §R2 P2).
            self.flat_dim = len(self.skills) + self.max_len * self._slot_dim + 1
            # r3(--refine): flat에 trace 집계 스칼라 N개 append(공간 채널은 CNN grid에 concat).
            self.flat_dim_r3 = self.flat_dim + N_TRACE_SCALAR

    def _init_r1(self, max_len: int) -> None:
        # R1-스윕: 문법 = ant-target 스킬만(plan §R1-스윕 정직 선언). cell-target(sand_mound 등)은
        # 스킬 head에서 제외 — 메타 덤프 기반(D7, 하드코딩 0). 전부 cell-target이면 비표현 스테이지.
        metas = skill_metas()
        self.skills: list[str] = sorted(
            sid for sid in self.inventory
            if str((metas.get(sid) or {}).get("target", "")) == "ant")   # 결정론 순서
        if not self.skills:
            raise ValueError(
                f"stage {self.stage_id}: ant-target 스킬 0 (inventory={sorted(self.inventory)}) — "
                "R0/R1 문법 비표현(cell-target 어휘는 r2)")
        self.max_len = min(sum(self.inventory[s] for s in self.skills), max_len)
        # factored head 크기 — skill 마지막 인덱스 = SUBMIT.
        self.heads: dict[str, int] = {
            "skill": len(self.skills) + 1,
            "trigger": len(TRIGGER_VOCAB),
            "cmp": len(CMP_VOCAB),
            "param": max(self.W, self.hp),
            "y_row": len(self.y_rows) + 1,                    # 0 = any(밴드 없음), i+1 = y_rows[i] (r1.1)
            "select": len(SELECT_VOCAB),
            "state": len(STATE_VOCAB),
        }
        self.head_names = list(self.heads)
        self.SUBMIT = len(self.skills)

    def _init_r2(self, max_len: int, at_frame_cap: int) -> None:
        vocab = global_vocab()
        self.vocab_digest: str = vocab["digest"]
        if self.W > vocab["w_max"] or self.H > vocab["h_max"] or self.hp > vocab["hp_max"]:
            raise ValueError(
                f"stage {self.stage_id}: 레이아웃/hp가 전역 어휘 상한 초과 "
                f"(W {self.W}/{vocab['w_max']}, H {self.H}/{vocab['h_max']}, "
                f"hp {self.hp}/{vocab['hp_max']}) — silent 확장 금지, 어휘 버전 승격 필요(plan §R2 P2)")
        self.skills = list(vocab["skills"])                   # 전역 스킬 사전(결정론 정렬)
        metas = skill_metas()
        self._skill_kind: dict[str, str] = {
            s: str((metas.get(s) or {}).get("target", "")) for s in self.skills}
        if not any(self.inventory.get(s, 0) > 0 for s in self.skills):
            raise ValueError(f"stage {self.stage_id}: 어휘 표현 가능 인벤토리 0 "
                             f"(inventory={sorted(self.inventory)})")
        # r2: 슬롯 수 = 전역 고정(스테이지-불변 obs 차원). 실제 plan 길이는 인벤토리 마스크가 제한.
        self.max_len = int(max_len)
        self.at_frame_cap = int(at_frame_cap)
        self._frame_bins: list[int] = [b for b in range(FRAME_BINS)
                                       if b * AT_FRAME_QUANT <= self.at_frame_cap]
        self.heads = {h: vocab["heads"][h] for h in R2_HEAD_ORDER}
        self.head_names = list(R2_HEAD_ORDER)
        self.SUBMIT = len(self.skills)

    # ----- r2 마스킹 (plan §R2 P2/P3 — 무효 조합은 페널티가 아니라 표현 불가) -----
    def head_mask(self, head: str, t: int, used: dict[str, int], ctx: dict[str, int]) -> list[int]:
        """head별 허용 인덱스(r2 전용). ctx = 이 스텝에서 이미 샘플된 head 인덱스(skill/kind/trigger).
        used = partial의 스킬별 사용 수(인벤토리 동적 마스크)."""
        if head == "skill":
            ok = [i for i, s in enumerate(self.skills)
                  if used.get(s, 0) < self.inventory.get(s, 0)]
            # 스텝 0 SUBMIT 마스킹(빈-plan collapse attractor 차단, R0 교훈). 인벤토리 소진 시 SUBMIT만.
            if t > 0 or not ok:
                ok.append(self.SUBMIT)
            return ok
        if head == "kind":       # sum-type 판별자: 스킬 메타 target이 유일 유효값(plan-R1 HIGH-2)
            return [KIND_VOCAB.index(self._skill_kind[self.skills[ctx["skill"]]])]
        if head == "trigger":    # 트리거 직교 계약(plan-R2 MED-2): cell도 전 트리거 어휘 유효
            return list(range(len(TRIGGER_VOCAB_R2)))
        if head == "cmp":
            return list(range(len(CMP_VOCAB)))
        if head == "param":
            if TRIGGER_VOCAB_R2[ctx["trigger"]] == "ant_reaches_x":
                return list(range(self.W))                    # x-셀: 스테이지 폭 마스크
            return list(range(self.hp))                       # picked_ge n-1: 스테이지 hp 마스크
        if head == "frame":      # at_frame 양자화 격자(0 포함), 상한 = at_frame_cap(plan-R2 MED-1)
            return list(self._frame_bins)
        if head == "col":
            return list(range(self.W))
        if head == "row":        # 행 head 이원화: ant = any+surface rows / cell = 스테이지 전 행
            if KIND_VOCAB[ctx["kind"]] == "ant":
                return [0] + [r + 1 for r in self.y_rows]
            return [r + 1 for r in range(self.H)]
        if head in ("select", "state"):
            return list(range(self.heads[head]))
        raise KeyError(head)

    def active_heads(self, a: dict[str, int]) -> list[str]:
        """완성된 스텝 idx(skill != SUBMIT)에 대해 skill 이후 활성 head 순서(샘플링·SIL replay 공용)."""
        heads = ["kind", "trigger", *R2_TRIGGER_HEADS[TRIGGER_VOCAB_R2[a["trigger"]]]]
        heads += ["select", "state", "row"] if KIND_VOCAB[a["kind"]] == "ant" else ["col", "row"]
        return heads

    # ----- 관측 -----
    def _encode_grid(self) -> list[float]:
        # 채널: solid / ladder / hazard / candy / home (H×W×5 flatten)
        lay = self.layout
        g = [0.0] * (self.H * self.W * 5)

        def put(c: int, r: int, ch: int) -> None:
            if 0 <= c < self.W and 0 <= r < self.H:
                g[(r * self.W + c) * 5 + ch] = 1.0
        for (c, r) in lay["occupied"]:
            put(c, r, 0)
        for (c, r) in lay["ladder"]:
            put(c, r, 1)
        for (c, r) in lay["hazard"]:
            put(c, r, 2)
        if lay["candy"]:
            put(*lay["candy"], 3)
        if lay["home"]:
            put(*lay["home"], 4)
        return g

    def obs_flat_r2(self, partial: list[dict[str, int]]) -> list[float]:
        """r2 flat 관측(전역 고정 차원 = flat_dim): 전역 스킬 사전 순 잔여 인벤토리 + 슬롯 one-hot
        (활성 head만 — 비활성 head는 0) + 진행도. grid 부는 CNN 입력(self._grid, H×W×5)."""
        out: list[float] = []
        used: dict[str, int] = {}
        for a in partial:
            sid = self.skills[a["skill"]]
            used[sid] = used.get(sid, 0) + 1
        for sid in self.skills:
            cap = self.inventory.get(sid, 0)
            out.append(max(0.0, (cap - used.get(sid, 0)) / cap) if cap else 0.0)
        for i in range(self.max_len):
            if i < len(partial):
                a = partial[i]
                out.append(1.0)
                for h in self.head_names:
                    one = [0.0] * self.heads[h]
                    if h in a:
                        one[a[h]] = 1.0
                    out.extend(one)
            else:
                out.extend([0.0] * self._slot_dim)
        out.append(len(partial) / max(1, self.max_len))
        return out

    def obs(self, partial: list[dict[str, int]]) -> list[float]:
        """partial = head-인덱스 dict의 리스트(디코드 전 표현). (r1.1 전용 — r2는 obs_flat_r2+grid.)"""
        out = list(self._grid)
        used: dict[str, int] = {}
        for a in partial:
            sid = self.skills[a["skill"]]
            used[sid] = used.get(sid, 0) + 1
        for sid in self.skills:
            cap = self.inventory[sid]
            out.append(max(0.0, (cap - used.get(sid, 0)) / max(1, cap)))
        for i in range(self.max_len):
            if i < len(partial):
                a = partial[i]
                out.append(1.0)
                for h in self.head_names:
                    one = [0.0] * self.heads[h]
                    one[a[h]] = 1.0
                    out.extend(one)
            else:
                out.extend([0.0] * self._slot_dim)
        out.append(len(partial) / max(1, self.max_len))
        return out

    # ----- 액션 decode (head 인덱스 → PlanRunner 액션) -----
    def decode(self, a: dict[str, int]) -> dict:
        if self.grammar_version == GRAMMAR_R2:
            return self._decode_r2(a)
        skill = self.skills[a["skill"]]
        target: dict = {"mode": "ant", "select": SELECT_VOCAB[a["select"]],
                        "state": STATE_VOCAB[a["state"]]}
        if a["y_row"] > 0:
            row = self.y_rows[a["y_row"] - 1]       # r1.1: surface row 인덱스 → 행. 밴드=[row*cs,(row+1)*cs]
            target["y_min"] = float(row * self.cs)
            target["y_max"] = float((row + 1) * self.cs)
        ttype = TRIGGER_VOCAB[a["trigger"]]
        if ttype == "ant_reaches_x":
            trigger = {"type": ttype, "cmp": CMP_VOCAB[a["cmp"]],
                       "x": float(min(a["param"], self.W - 1) * self.cs + self.cs // 2)}  # 셀 센터
        else:                                       # picked_ge
            trigger = {"type": ttype, "n": (a["param"] % self.hp) + 1}
        return {"skill": skill, "target": target, "trigger": trigger}

    def decode_plan(self, partial: list[dict[str, int]]) -> list[dict]:
        return [self.decode(a) for a in partial]

    # ----- r2 decode/encode (JSON lowering 규칙 — plan §R2 P3, 라운드트립 = verify-r2 편입) -----
    def _decode_r2(self, a: dict[str, int]) -> dict:
        skill = self.skills[a["skill"]]
        kind = KIND_VOCAB[a["kind"]]
        ttype = TRIGGER_VOCAB_R2[a["trigger"]]
        if ttype == "ant_reaches_x":
            trigger = {"type": ttype, "cmp": CMP_VOCAB[a["cmp"]],
                       "x": float(min(a["param"], self.W - 1) * self.cs + self.cs // 2)}  # 셀 센터
        elif ttype == "picked_ge":
            trigger = {"type": ttype, "n": (a["param"] % self.hp) + 1}
        else:                                   # at_frame: bin → frame(양자화 격자 그대로)
            trigger = {"type": "at_frame", "frame": int(a["frame"]) * AT_FRAME_QUANT}
        if kind == "cell":
            col = min(a["col"], self.W - 1)
            row = max(1, min(a["row"], self.H))                 # cell row 도메인 = [1..H] (0=any는 ant 전용)
            return {"skill": skill, "target": {"mode": "cell", "cell": [col, row - 1]},
                    "trigger": trigger}
        target: dict = {"mode": "ant", "select": SELECT_VOCAB[a["select"]],
                        "state": STATE_VOCAB[a["state"]]}
        if a["row"] > 0:                        # r2 row head = 절대 행(전역) — 마스크가 surface로 제한
            r = a["row"] - 1
            target["y_min"] = float(r * self.cs)
            target["y_max"] = float((r + 1) * self.cs)
        return {"skill": skill, "target": target, "trigger": trigger}

    def _encode_r2(self, action: dict) -> dict[str, int]:
        skill_id = action["skill"]
        skill = self.skills.index(skill_id)                     # 어휘 밖 스킬 = ValueError(fail-closed)
        t = action.get("target", {})
        kind_s = str(t.get("mode", self._skill_kind.get(skill_id) or "ant"))
        trig = action.get("trigger", {})
        ttype = trig.get("type", "ant_reaches_x")
        a: dict[str, int] = {"skill": skill, "kind": KIND_VOCAB.index(kind_s),
                             "trigger": TRIGGER_VOCAB_R2.index(ttype)}
        if ttype == "ant_reaches_x":
            a["cmp"] = CMP_VOCAB.index(trig.get("cmp", "ge"))
            a["param"] = max(0, min(self.W - 1, round((float(trig["x"]) - self.cs / 2) / self.cs)))
        elif ttype == "picked_ge":
            a["param"] = max(0, min(self.hp - 1, int(trig.get("n", 1)) - 1))
        else:                                   # at_frame → 가장 가까운 bin (0은 정확 인코딩)
            a["frame"] = max(0, min(FRAME_BINS - 1,
                                    round(int(trig.get("frame", 0)) / AT_FRAME_QUANT)))
        if kind_s == "cell":
            c = t["cell"]
            a["col"] = max(0, min(self.W - 1, int(c[0])))
            a["row"] = max(1, min(self.H, int(c[1]) + 1))
        else:
            row = 0
            if "y_min" in t and "y_max" in t:
                lo, hi = float(t["y_min"]), float(t["y_max"])
                best, best_ov = 0, float("-inf")
                for r in self.y_rows:           # surface rows 중 겹침 최대, 동률=낮은 행(r1.1 규칙 계승)
                    ov = min(hi, (r + 1) * self.cs) - max(lo, r * self.cs)
                    if ov > best_ov:
                        best, best_ov = r, ov
                row = best + 1
            a["row"] = row
            a["select"] = SELECT_VOCAB.index(t.get("select", "max_x"))
            a["state"] = STATE_VOCAB.index(t.get("state", "walker"))
        return a

    # ----- 디제스트 (P1 체크포인트 fail-closed 계약 — plan §R2) -----
    def layout_digest(self) -> str:
        lay = self.layout
        return _sha({"cell_size": lay["cell_size"],
                     "occupied": sorted(lay["occupied"]), "ladder": sorted(lay["ladder"]),
                     "kinds": sorted((list(k), v) for k, v in lay.get("kinds", {}).items()),
                     "hazard": sorted((list(k), v) for k, v in lay["hazard"].items()),
                     "candy": lay["candy"], "home": lay["home"]})

    def mask_digest(self) -> str:
        """per-stage 마스크의 시맨틱 전부(r2) — exact resume 일치 요구 / transfer 면제(plan-R3 HIGH-1)."""
        return _sha({"stage_id": self.stage_id, "W": self.W, "H": self.H, "hp": self.hp,
                     "inventory": sorted(self.inventory.items()),
                     "surface_rows": self.y_rows, "frame_bins": self._frame_bins,
                     "max_len": self.max_len})

    # ----- 액션 encode (known 해 → 가장 가까운 격자, 커버리지 검사용) -----
    def encode_action(self, action: dict) -> dict[str, int]:
        if self.grammar_version == GRAMMAR_R2:
            return self._encode_r2(action)
        t = action.get("target", {})
        trig = action.get("trigger", {})
        skill = self.skills.index(action["skill"])
        ttype = trig.get("type", "ant_reaches_x")
        trigger = TRIGGER_VOCAB.index(ttype)
        cmp_i = CMP_VOCAB.index(trig.get("cmp", "ge")) if ttype == "ant_reaches_x" else 0
        if ttype == "ant_reaches_x":
            param = max(0, min(self.W - 1, round((float(trig["x"]) - self.cs / 2) / self.cs)))
        else:
            param = max(0, min(self.hp - 1, int(trig.get("n", 1)) - 1))
        # y밴드 → row: **surface rows 중** 겹침 최대, 동률이면 낮은 row(R3-M 결정론 규칙, r1.1 도메인 축소)
        y_row = 0
        if "y_min" in t and "y_max" in t:
            lo, hi = float(t["y_min"]), float(t["y_max"])
            best, best_ov = 0, float("-inf")
            for i, r in enumerate(self.y_rows):
                ov = min(hi, (r + 1) * self.cs) - max(lo, r * self.cs)
                if ov > best_ov:
                    best, best_ov = i, ov
            y_row = best + 1
        select = SELECT_VOCAB.index(t.get("select", "max_x"))
        state = STATE_VOCAB.index(t.get("state", "walker"))   # PlanRunner 기본 state=walker 정합
        return {"skill": skill, "trigger": trigger, "cmp": cmp_i, "param": param,
                "y_row": y_row, "select": select, "state": state}

    # ----- 보상 (terminal — plan §보상; 분모=hp_stage 상수, R1-H1) -----
    def reward(self, res: dict, plan_len: int) -> float:
        cleared = 1.0 if res.get("cleared") else 0.0
        saved = max(0, int(res.get("saved") or 0))
        picked = max(0, int(res.get("picked_total") or 0))
        lost = max(0, int(res.get("lost") or 0))
        r = (REWARD["cleared"] * cleared
             + (REWARD["saved"] * saved + REWARD["picked"] * picked + REWARD["lost"] * lost) / self.hp
             + REWARD["len_penalty"] * plan_len)
        if res.get("reason") == "deadline":
            r += REWARD["timeout_penalty"]
        return r

    # ----- R1 trace-shaped bonus (plan §R1 — 형태 확정; trace 파생은 model.py read-only 재사용) -----
    def shaped_bonus(self, res: dict) -> float:
        """`R_r1 = R_r0 + shaped_bonus`. 분모 = 스테이지/레이아웃 상수(D0=W+H, ants_total — result 파생
        분모 금지, R0-H1 교훈). fail-safe: trace 부재/빈 trace → goal 항 0(goal_d=D0)·retired 0."""
        tr = res.get("trace") or {}
        goal_d = model.best_goal_dist(tr, self.layout)        # 빈 trace → 1<<30 → min(...)=D0 → 항 0
        retired = model.count_retired(tr, self.layout)["total"] if tr else 0
        return (SHAPING["goal"] * (1.0 - min(goal_d, self.D0) / self.D0)
                - SHAPING["retired"] * (retired / self.ants_total))

    # ----- R3 trace obs (plan §R3 R3_OBS_SCHEMA — 순수 rasterize 함수 위임, golden 결속) -----
    def _verdict_code(self, res: dict) -> int:
        return _verdict_code_of(res)

    def trace_channels(self, res: dict) -> list[float]:
        """공간 채널 [H×W×C_trace] flatten. 순수 rasterize_channels 위임(obs_schema golden 결속 대상)."""
        return rasterize_channels((res or {}).get("trace") or {}, self.layout,
                                  self.H, self.W, self.ants_total)

    def trace_scalars(self, res: dict) -> list[float]:
        """집계 스칼라(TRACE_SCALARS 순서). 순수 rasterize_scalars 위임(golden 결속 대상)."""
        return rasterize_scalars((res or {}).get("trace") or {}, res, self.layout,
                                 self.ants_total, self.hp, self.D0)

    def obs_flat_r3(self, partial: list[dict[str, int]], res: dict,
                    blind: bool = False) -> list[float]:
        """r3 flat 관측 = r2 flat + trace 집계 스칼라. blind = 스칼라 전부 0(trace-blind 대조 격리)."""
        scal = [0.0] * N_TRACE_SCALAR if blind else self.trace_scalars(res)
        return self.obs_flat_r2(partial) + scal
