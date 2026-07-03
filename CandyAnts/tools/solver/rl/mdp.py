#!/usr/bin/env python3
"""
Phase R (RL 솔버) — plan-구성 MDP 정의 (순수 / 엔진·torch 비의존).

에피소드 = plan 구성: 스텝마다 액션 1개 추가 or SUBMIT → 완성 plan을 엔진 롤아웃 1회로 평가(terminal
reward). 문법(R0 어휘)·보상·관측 인코딩의 단일 출처. plan SoT = auto-solver-plan.md §Phase R.

레이아웃 파싱은 model.parse_layout, 스테이지 메타는 solve.stage_meta를 read-only 재사용(중복 구현 금지).
"""
from __future__ import annotations

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

# ---------- 문법 어휘 (R0 — plan §Phase R MDP 정의) ----------
TRIGGER_VOCAB = ("ant_reaches_x", "picked_ge")
CMP_VOCAB = ("ge", "le")
SELECT_VOCAB = ("max_x", "min_x")
STATE_VOCAB = ("any", "walker", "carrying")
GRAMMAR_VERSION = "r0.1"

# 보상 계수 (plan: 형태 확정·계수 튜닝 자유 — effective config로 manifest에 박제)
REWARD = {"cleared": 2.0, "saved": 1.0, "picked": 0.3, "lost": -0.2,
          "len_penalty": -0.02, "timeout_penalty": -0.1}


class StageMDP:
    """스테이지 1개에 대한 plan-구성 MDP: 관측 인코딩 / factored 액션 decode·encode / terminal 보상."""

    def __init__(self, stage_id: int, max_len: int = 6):
        self.stage_id = stage_id
        self.stage_scene = f"res://scenes/stages/Stage{stage_id:02d}.tscn"
        meta = solve.stage_meta(stage_id)
        self.inventory: dict[str, int] = meta["inventory"]
        self.hp: int = meta["candy_hp"]                       # hp_stage(상수) — result.hp 미사용(R1-H1)
        self.layout = model.parse_layout(
            ROOT / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres")
        self.cs: int = self.layout["cell_size"]
        cells = set(self.layout["occupied"]) | set(self.layout["hazard"])
        for v in (self.layout["candy"], self.layout["home"]):
            if v:
                cells.add(v)
        self.W = max(c for c, _ in cells) + 1
        self.H = max(r for _, r in cells) + 1
        self.skills: list[str] = sorted(self.inventory)       # 결정론 순서
        self.max_len = min(sum(self.inventory.values()), max_len)
        # factored head 크기 — skill 마지막 인덱스 = SUBMIT.
        self.heads: dict[str, int] = {
            "skill": len(self.skills) + 1,
            "trigger": len(TRIGGER_VOCAB),
            "cmp": len(CMP_VOCAB),
            "param": max(self.W, self.hp),
            "y_row": self.H + 1,                              # 0 = any(밴드 없음), r+1 = row r
            "select": len(SELECT_VOCAB),
            "state": len(STATE_VOCAB),
        }
        self.head_names = list(self.heads)
        self.SUBMIT = len(self.skills)
        # 관측 레이아웃(고정 스테이지 = 상수지만 R1 일반화 대비 포함, plan §관측)
        self._grid = self._encode_grid()
        self._slot_dim = 1 + sum(self.heads[h] for h in self.head_names)
        self.obs_dim = len(self._grid) + len(self.skills) + self.max_len * self._slot_dim + 1

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

    def obs(self, partial: list[dict[str, int]]) -> list[float]:
        """partial = head-인덱스 dict의 리스트(디코드 전 표현)."""
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
        skill = self.skills[a["skill"]]
        target: dict = {"mode": "ant", "select": SELECT_VOCAB[a["select"]],
                        "state": STATE_VOCAB[a["state"]]}
        if a["y_row"] > 0:
            row = a["y_row"] - 1                    # 밴드 변환식(plan): [row*cs, (row+1)*cs]
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

    # ----- 액션 encode (known 해 → 가장 가까운 격자, 커버리지 검사용) -----
    def encode_action(self, action: dict) -> dict[str, int]:
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
        # y밴드 → row: 겹침 최대, 동률이면 낮은 row(R3-M 결정론 규칙)
        y_row = 0
        if "y_min" in t and "y_max" in t:
            lo, hi = float(t["y_min"]), float(t["y_max"])
            best, best_ov = 0, -1.0
            for r in range(self.H):
                ov = min(hi, (r + 1) * self.cs) - max(lo, r * self.cs)
                if ov > best_ov:
                    best, best_ov = r, ov
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
