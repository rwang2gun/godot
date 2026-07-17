#!/usr/bin/env python3
"""
auto-solver — persistent Godot 환경 (RL 토대).

Godot를 1회 부팅해 PlanServerHarness(TCP 서버)로 띄우고, plan을 NDJSON으로 보내 결과를 받는다.
부팅 오버헤드를 N 롤아웃에 1회로 분산 → 단발 run_test.py(매 롤아웃 재부팅) 대비 throughput을 크게 높인다.
PlanRunner가 상태누수 0(매 run마다 reset)을 보장하므로, 한 프로세스로 여러 에피소드가 byte-identical하게
돈다(이 모듈 self-test가 그걸 검증). 이게 곧 RL 환경(reset=stage 지정 step, step=plan 평가)의 토대다.

사용:
    env = GodotEnv()
    res = env.step({"stage": "res://scenes/stages/Stage11.tscn", "deadline_frames": 7000, "actions": [...]})
    env.close()

self-test (spike 검증 — 정확도 byte-identical + 속도):
    GODOT_BIN=... python tools/solver/env.py
Exit: 0=검증 통과(persistent 결과끼리 + 단발과 일치) / 1=불일치 또는 에러.
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# 콘솔 코드페이지(cp949 등)와 무관하게 한글·기호(— ⚠ 등) print가 죽지 않도록 UTF-8 강제(try_solve.py 동일).
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

HERE = Path(__file__).resolve().parent          # tools/solver
ROOT = HERE.parents[1]                            # .../CandyAnts
sys.path.insert(0, str(ROOT / "scripts"))        # run_test.find_godot
sys.path.insert(0, str(HERE))                    # solve.run_plan (self-test 비교용)
from run_test import find_godot, suppress_crash_dialogs  # noqa: E402

HARNESS_SCENE = "res://tests/PlanServerHarness.tscn"


def _free_port() -> int:
    """OS에 빈 포트를 잡게 한 뒤 번호만 얻고 닫는다(Godot이 다시 bind). localhost·짧은 시간이라 race 무시 가능."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


class GodotEnv:
    """persistent Godot 헤드리스 환경. 부팅 1회 → step(plan)을 NDJSON으로 반복."""

    def __init__(self, port: int | None = None, fixed_fps: int = 60, boot_timeout: float = 40.0):
        suppress_crash_dialogs()          # Windows WER 모달 억제(자식 godot에 상속) — run_test.py 참조
        self.godot = find_godot()
        self.port = port or _free_port()
        env = os.environ.copy()
        env["CANDYANTS_PLAN_PORT"] = str(self.port)
        env["CANDYANTS_DETERMINISTIC"] = "1"
        # throwaway save 격리(run_test.py와 동일 의도) — pid 고유.
        self._save_path = Path(tempfile.gettempdir()) / f"candyants_env_save_{os.getpid()}_{self.port}.cfg"
        env["CANDYANTS_SAVE_PATH"] = str(self._save_path)
        # --fixed-fps: real-time sync 해제 → 메인루프가 최대 속도로 돈다(시뮬 wall-clock 가속의 핵심).
        cmd = [str(self.godot), "--headless", "--path", str(ROOT),
               "--fixed-fps", str(fixed_fps), HARNESS_SCENE]
        self.proc = subprocess.Popen(cmd, cwd=str(ROOT), env=env,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.sock = self._connect(boot_timeout)
        self._buf = b""

    def _connect(self, timeout: float) -> socket.socket:
        deadline = time.monotonic() + timeout
        last_err: Exception | None = None
        while time.monotonic() < deadline:
            if self.proc.poll() is not None:
                raise RuntimeError(f"Godot env exited during boot (code={self.proc.returncode})")
            try:
                s = socket.create_connection(("127.0.0.1", self.port), timeout=2.0)
                s.settimeout(180.0)
                return s
            except OSError as e:
                last_err = e
                time.sleep(0.1)
        self.proc.kill()
        raise RuntimeError(f"could not connect to Godot env on port {self.port}: {last_err}")

    def step(self, plan: dict) -> dict:
        self.sock.sendall((json.dumps(plan) + "\n").encode("utf-8"))
        return self._recv_line()

    def ping(self) -> dict:
        self.sock.sendall(b'{"cmd":"ping"}\n')
        return self._recv_line()

    def _recv_line(self) -> dict:
        while b"\n" not in self._buf:
            chunk = self.sock.recv(1 << 20)
            if not chunk:
                raise RuntimeError("Godot env closed connection unexpectedly")
            self._buf += chunk
        line, _, self._buf = self._buf.partition(b"\n")
        return json.loads(line.decode("utf-8"))

    def close(self) -> None:
        try:
            self.sock.sendall(b'{"cmd":"quit"}\n')
            try:
                self._recv_line()
            except Exception:
                pass
        except OSError:
            pass
        for fn in (self.sock.close,):
            try:
                fn()
            except OSError:
                pass
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        for suffix in ("", ".bak", ".tmp"):
            try:
                Path(str(self._save_path) + suffix).unlink()
            except FileNotFoundError:
                pass

    def __enter__(self) -> "GodotEnv":
        return self

    def __exit__(self, *_exc) -> None:
        self.close()


# ---------- self-test: spike 검증 (정확도 + 속도) ----------

# PlanReplayHarnessTest와 동일한 S11 blocker 플랜(검증된 클리어 플랜).
_PLAN_S11 = {
    "stage": "res://scenes/stages/Stage11.tscn",
    "deadline_frames": 7000,
    "actions": [
        {"skill": "blocker",
         "target": {"mode": "ant", "select": "max_x", "y_min": 520.0, "y_max": 99999.0, "dir": 0},
         "trigger": {"type": "ant_reaches_x", "cmp": "ge", "x": 960.0}},
    ],
}
_KEYS = ("cleared", "saved", "lost", "hp", "frame", "actions_fired", "picked_total")


def _digest(r: dict) -> dict:
    return {k: r.get(k) for k in _KEYS}


def _selftest() -> int:
    print("=== env.py self-test (persistent Godot 환경 spike) ===")

    # ① 단발 baseline (기존 경로, 매번 부팅) — 비교 기준 + 부팅 포함 시간.
    import solve  # noqa: E402  tools/solver/solve.py
    t0 = time.monotonic()
    single = solve.run_plan(_PLAN_S11["stage"], _PLAN_S11["actions"], _PLAN_S11["deadline_frames"], trace=False)
    t_single = time.monotonic() - t0
    if "error" in single:
        print("  [에러] 단발 baseline 실패:", single.get("error"))
        return 1
    print(f"  단발 baseline(매번 부팅): {_digest(single)}  wall={t_single:.2f}s")

    # ② persistent 환경: 같은 plan을 N회 step → 결과 byte-identical + 시간 측정.
    n = 6
    boot_t0 = time.monotonic()
    env = GodotEnv()
    boot_t = time.monotonic() - boot_t0
    print(f"  persistent 부팅+연결: {boot_t:.2f}s (포트 {env.port})")
    results: list[dict] = []
    times: list[float] = []
    try:
        for i in range(n):
            t = time.monotonic()
            r = env.step(_PLAN_S11)
            times.append(time.monotonic() - t)
            results.append(r)
            print(f"  step {i + 1}/{n}: {_digest(r)}  wall={times[-1]:.3f}s")
    finally:
        env.close()

    # ③ 검증.
    fails: list[str] = []
    base = _digest(results[0])
    for i, r in enumerate(results):
        if "error" in r:
            fails.append(f"step {i + 1} error: {r.get('error')}")
        elif _digest(r) != base:
            fails.append(f"step {i + 1} drift(상태누수): {_digest(r)} != {base}")
    if _digest(single) != base:
        fails.append(f"단발≠persistent: single={_digest(single)} persistent={base}")
    if not bool(results[0].get("cleared")):
        fails.append("persistent S11 미클리어(검증 플랜인데)")

    # ④ 속도 요약(단언 아님, 정보) — 첫 step은 stage 첫 로드라 따로 보고.
    warm = times[1:] if len(times) > 1 else times
    avg_warm = sum(warm) / len(warm)
    print()
    print(f"  [속도] 단발(부팅 포함) = {t_single:.2f}s/롤아웃")
    print(f"         persistent step1(첫 로드) = {times[0]:.3f}s")
    print(f"         persistent warm 평균 = {avg_warm:.3f}s/롤아웃  → 약 {t_single / avg_warm:.1f}배 빠름")

    if fails:
        print("\nSPIKE FAIL:")
        for f in fails:
            print("  -", f)
        return 1
    print(f"\nSPIKE PASS — persistent {n}회 + 단발 모두 byte-identical({base}), warm {avg_warm:.3f}s/롤아웃.")
    return 0


if __name__ == "__main__":
    raise SystemExit(_selftest())
