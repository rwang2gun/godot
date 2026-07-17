#!/usr/bin/env python3
"""
auto-solver Phase 2 — 예측 기반 탐색 솔버 (closed-loop).

blind generate-and-test(끝점 점수만 보고 후보를 수백 개 던짐)를 폐기하고, **예측 기반 닫힌 루프**로 푼다:
  1) 베이스라인 관측: 무개입 플랜을 엔진으로 1회 돌려 개미 궤적(트레이스)을 *관측*한다(D10 — 엔진=진실).
  2) 진단: model.diagnose가 궤적에서 실패를 읽는다(물 진입 지점·candy 근접·픽업/저장 격차).
  3) 개입 제안: model.propose가 스킬 메타 routing(D11)으로 "어디에·언제" 다음 개입을 제안한다.
  4) 검증: 후보를 엔진으로 돌려(롤아웃) 진척하면 채택, 그 새 궤적으로 2)로 — 100%까지 반복.

성공 = saved 100%(D: 정합성). **롤아웃 상한 = 10/스테이지(사용자)**: 베이스라인 + 후보 검증을 합쳐 10회
안에 100% 미달이면 멈추고 사용자 재도전 승인을 받는다(무한 그라인드 금지). 예측이 제대로면 소수로 푼다.

Usage:
    GODOT_BIN=... python tools/solver/solve.py 11
    GODOT_BIN=... python tools/solver/solve.py 14 --max-rollouts 10
Exit: 0=100% 해결 / 2=체크포인트(상한 도달, 사용자 승인 필요) / 1=에러.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import model

ROOT = Path(__file__).resolve().parents[2]
RUN_TEST = ROOT / "scripts" / "run_test.py"
LA2_RESERVE = 8   # codex impl R5: 메인 평가 단계(D2 보호로 후보 수가 per-round cap을 초과할 수 있음)가 2-step
                  # lookahead(LA2) budget을 잠식하지 않게 떼어두는 롤아웃 예약(LA2 = frontier 2개 × cands ≤4 = 8).
                  # 보호 미발동(up_cell 없음 → cands ≤ max_n)이면 메인 단계가 이 상한에 안 닿아 inert(byte-identical).

# ---- Phase 5g: 탐험-우선 fallback 검색(plan §5g, ②탐험+③beam). Phase A와 별도 가산 예산 ----
# de-risk(2026-06-27): frontier-단일 best-first는 witness 필수 단계 blocker(frontier 비최대)를 misrank → 미해결.
# → 사용자 결정 ②+③ = **skill-class 다양성 보존 beam**(각 스킬군 최선을 beam에 유지 → 저-frontier blocker 분기 생존).
PHASE_B_BUDGET = 360  # Phase A(max_rollouts)와 **별도 가산** — clear 없이 Phase A 종료 시에만 소비(inert: solved
                      # 스테이지는 Phase A서 clear → Phase B 미진입, 예산 0 소비). beam depth×width 여유(de-risk:
                      # budget 220은 depth4서 소진[frontier 77 도달]·depth5[귀환] 미도달 → witness depth5 도달까지 상향).
BEAM_WIDTH = 10       # beam 폭(skill-diverse: per-skill 최선 보존 후 frontier-top으로 채움).
SEED_POOL_CAP = 8     # R2-MED-2: (base_sig,_class)별 frontier-top K seed 보존(pool noise 억제, 결정론 정렬).
REFINE_BUDGET = 160   # de-risk: beam은 picked=hp(전원 도달) "모양"엔 가나 정확한 cell 배치(개미 생존)를 못 맞춤
                      # (placement needle) → 최선 노드의 cell-target 배치를 ±R coordinate-ascent perturb로 정밀탐색
                      # (spike 국소탐색·analyze 윈도우 선례) + 확장. 사용자 결정 2026-06-28.
REFINE_RADIUS = 2     # cell perturb 반경(±R 셀, (dc,dr) 격자).


def _main_cap(rollouts: int, max_rollouts: int) -> int:
    """메인 평가 단계의 전역 rollouts 상한(codex impl R5·R7). 정상 per-round(`min(remaining,6)`)는 **항상 보존**
    (R7: 작은 cap에서 first-step frontier를 1개로 굶기지 않게 — 기존 동작 불변)하고, D2 보호가 그 이상으로 확장한
    부분만 `max_rollouts-LA2_RESERVE`까지 허용해 2-step lookahead budget을 떼어 둔다(둘 중 큰 상한)."""
    per_round = min(max_rollouts - rollouts, 6)
    return max(rollouts + per_round, max_rollouts - LA2_RESERVE)


def _selfcheck_la2_reserve() -> bool:
    """codex impl R7 [HIGH] regression(순수 단위, 엔진 불요): 메인 평가 상한이 ⓐ 보호 inactive 시 **정상 per-round
    (min(remaining,6))를 절대 안 줄이고**(first-step frontier 불변) ⓑ 큰 cap·이른 라운드에서 LA2_RESERVE를 떼어 둠."""
    for mr in (10, 12, 30, 40, 60):
        for ro in range(0, mr):
            per = min(mr - ro, 6)
            if _main_cap(ro, mr) < ro + per:                  # ⓐ 정상 per-round 보존(first-step pool 불변)
                print("[la2-reserve selfcheck] FAIL R7-ⓐ main_cap %d < per-round %d (mr=%d ro=%d)"
                      % (_main_cap(ro, mr), ro + per, mr, ro))
                return False
    if _main_cap(1, 40) != 40 - LA2_RESERVE:                  # ⓑ 큰 cap에서 보호 확장이 LA2 reserve 남김
        print("[la2-reserve selfcheck] FAIL R7-ⓑ 큰 cap LA2 reserve 미보장:", _main_cap(1, 40)); return False
    # prove-it: 옛 식 max(ro+1, mr-reserve)면 default 10·ro=1에서 max(2,2)=2 < per-round 7 = ⓐ 위반(vacuous 아님).
    if max(1 + 1, 10 - LA2_RESERVE) >= 1 + min(10 - 1, 6):
        print("[la2-reserve selfcheck] FAIL R7 prove-it vacuous(옛 식이 per-round 보존)"); return False
    # ⓒ codex R8 [HIGH](사용자 옵션 A): cap 충분(40)이면 D2 protected 8개 전부 평가 가능 + LA2 reserve 유지 /
    # cap 부족(default 10)이면 protected 8개 중 일부만(evaluable < 8) = silent inert 아닌 *수학적 cap 부족*임을 박제.
    PROT = 8                                                  # 보호 발동 후보 수 예(per_round 6 + 보호 extra 2)
    ev_big = max(0, min(_main_cap(1, 40), 40) - 1)            # 충분 cap: protected 전부 평가 + reserve
    if ev_big < PROT or _main_cap(1, 40) > 40 - LA2_RESERVE:
        print("[la2-reserve selfcheck] FAIL R8-ⓒ 충분 cap서 protected 미평가 or LA2 reserve 침범:", ev_big); return False
    ev_small = max(0, min(_main_cap(1, 10), 10) - 1)          # 부족 cap: protected 잘림(cap 경고 경로 도달)
    if ev_small >= PROT:
        print("[la2-reserve selfcheck] FAIL R8-ⓒ default cap이 protected 8개를 다 평가(cap 모순 미감지):", ev_small); return False
    print("[la2-reserve selfcheck] PASS — 정상 per-round 보존(R7-ⓐ) + 큰 cap LA2 reserve(R7-ⓑ) + "
          "cap 충분/부족 protected 평가 가능성(R8-ⓒ, 부족 시 명시 경고) 박제.")
    return True
PLAN_HARNESS = "tests/PlanReplayHarness.tscn"
META_DUMP = "tests/SolverMetaDump.tscn"


# ---------- D7 능력/메타 덤프 ----------

def dump_capabilities() -> dict:
    p = subprocess.run([sys.executable, str(RUN_TEST), META_DUMP],
                       capture_output=True, text=True, encoding="utf-8", errors="replace",
                       cwd=str(ROOT), env=os.environ.copy())
    for line in (p.stdout or "").splitlines():
        if line.startswith("SOLVER_CAPS "):
            return json.loads(line[len("SOLVER_CAPS "):])
    raise RuntimeError("SolverMetaDump no SOLVER_CAPS:\n" + (p.stdout or "")[-600:])


# ---------- 엔진 롤아웃 (PlanReplayHarness, D4 verdict) ----------

def _make_kill_on_close_job():
    """Windows Job Object(KILL_ON_JOB_CLOSE) 생성 — 자식+후손 전체의 수명을 **부모 PID와 무관하게**
    잡아둔다(codex 07-17 R8 MEDIUM: 중간 부모 run_test가 먼저 죽으면 taskkill/PID 기준 정리가 살아남은
    godot 손자를 못 잡는다). 반환 = job 핸들(int) 또는 None(생성 실패 — 호출자는 taskkill 폴백만 수행).
    핸들은 호출자가 CloseHandle로 닫아야 하며, 닫히는 순간 잡 소속 전 프로세스가 강제 종료된다."""
    if sys.platform != "win32":
        return None
    try:
        import ctypes
        from ctypes import wintypes

        class _BASIC(ctypes.Structure):
            _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64),
                        ("PerJobUserTimeLimit", ctypes.c_int64),
                        ("LimitFlags", wintypes.DWORD),
                        ("MinimumWorkingSetSize", ctypes.c_size_t),
                        ("MaximumWorkingSetSize", ctypes.c_size_t),
                        ("ActiveProcessLimit", wintypes.DWORD),
                        ("Affinity", ctypes.c_size_t),
                        ("PriorityClass", wintypes.DWORD),
                        ("SchedulingClass", wintypes.DWORD)]

        class _IO(ctypes.Structure):
            _fields_ = [(n, ctypes.c_uint64) for n in
                        ("ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
                         "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]

        class _EXT(ctypes.Structure):
            _fields_ = [("BasicLimitInformation", _BASIC), ("IoInfo", _IO),
                        ("ProcessMemoryLimit", ctypes.c_size_t),
                        ("JobMemoryLimit", ctypes.c_size_t),
                        ("PeakProcessMemoryUsed", ctypes.c_size_t),
                        ("PeakJobMemoryUsed", ctypes.c_size_t)]

        k32 = ctypes.windll.kernel32
        job = k32.CreateJobObjectW(None, None)
        if not job:
            return None
        info = _EXT()
        info.BasicLimitInformation.LimitFlags = 0x2000   # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not k32.SetInformationJobObject(job, 9,       # JobObjectExtendedLimitInformation
                                           ctypes.byref(info), ctypes.sizeof(info)):
            k32.CloseHandle(job)
            return None
        return job
    except Exception:
        return None


def _resume_process(pid: int) -> bool:
    """CREATE_SUSPENDED로 만든 프로세스의 (유일한) 주 스레드를 재개(Windows 전용). Popen은 CreateProcess의
    스레드 핸들을 즉시 닫으므로 Toolhelp 스냅샷으로 pid 소유 스레드를 찾아 ResumeThread한다."""
    import ctypes
    from ctypes import wintypes

    class _TE32(ctypes.Structure):
        _fields_ = [("dwSize", wintypes.DWORD), ("cntUsage", wintypes.DWORD),
                    ("th32ThreadID", wintypes.DWORD), ("th32OwnerProcessID", wintypes.DWORD),
                    ("tpBasePri", wintypes.LONG), ("tpDeltaPri", wintypes.LONG),
                    ("dwFlags", wintypes.DWORD)]

    k32 = ctypes.windll.kernel32
    snap = k32.CreateToolhelp32Snapshot(0x4, 0)          # TH32CS_SNAPTHREAD
    if snap == ctypes.c_void_p(-1).value:
        return False
    resumed = False
    try:
        te = _TE32()
        te.dwSize = ctypes.sizeof(_TE32)
        ok = k32.Thread32First(snap, ctypes.byref(te))
        while ok:
            if te.th32OwnerProcessID == pid:
                h = k32.OpenThread(0x0002, False, te.th32ThreadID)   # THREAD_SUSPEND_RESUME
                if h:
                    # ResumeThread 실패 = (DWORD)-1 → 기본 restype c_int로는 -1. 성공 = 이전
                    # suspend count(CREATE_SUSPENDED 주 스레드면 1) ≥ 0.
                    if k32.ResumeThread(h) != -1:
                        resumed = True
                    k32.CloseHandle(h)
            ok = k32.Thread32Next(snap, ctypes.byref(te))
    finally:
        k32.CloseHandle(snap)
    return resumed


def _kill_tree(proc: subprocess.Popen, job=None) -> None:
    """타임아웃된 리플레이 자식의 프로세스 트리를 **상한 시간 안에** 최선-노력 종료(codex 07-17 R7/R8
    MEDIUM). 원 결함이 '정리 경로의 영구 대기·고아 잔존'이므로 어떤 실패에도 블록/예외 없이 반환한다:
    - Windows: job(KILL_ON_JOB_CLOSE) 핸들이 있으면 TerminateJobObject — 중간 부모가 이미 죽었어도
      잡 소속 후손 전체가 죽는다(부모 PID 수명과 분리, R8). 실패/부재 시 taskkill /T /F(자체 timeout
      15s)+반환코드 검사 → 그마저 실패면 직계 proc.kill() 폴백(블록보다 낫다).
    - POSIX: start_new_session=True로 자식이 곧 그룹 리더(pgid == proc.pid)이므로 **getpgid 조회 없이**
      killpg(proc.pid) — 부모 선종료 후에도 그룹이 살아 있는 한 유효(R8).
    - 마지막 reap도 wait(timeout=10)으로 상한."""
    killed = False
    try:
        if sys.platform == "win32":
            if job:
                import ctypes
                killed = bool(ctypes.windll.kernel32.TerminateJobObject(job, 1))
            if not killed:
                r = subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                                   capture_output=True, timeout=15)
                if r.returncode != 0:
                    proc.kill()
        else:
            import signal
            os.killpg(proc.pid, signal.SIGKILL)         # start_new_session → pgid == proc.pid
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
    try:
        proc.wait(timeout=10)
    except Exception:
        pass


def run_plan(stage_scene: str, actions: list[dict], deadline: int, trace: bool = True,
             report_fired: bool = False, timeout: float | None = None) -> dict:
    """timeout(초, opt-in — 기본 None=종전과 byte-identical 무제한): deadline_frames는 시뮬 프레임
    한도라 Godot이 부팅/셧다운에서 행 걸리면 무력하다. wall-clock 초과 시 subprocess.run이 자식을
    죽이고 TimeoutExpired를 던지므로 error dict로 정규화해 호출자가 fail-closed 처리하게 한다
    (codex 2026-07-17 R6 MEDIUM — prefix 게이트가 락 쥔 채 영구 블록되는 조건 차단)."""
    plan = {"stage": stage_scene, "deadline_frames": deadline, "trace": trace, "actions": actions}
    if report_fired:                 # 각 blocker 액션의 uid별 충돌 카운트(bumps)를 결과에 실음
        plan["report_fired"] = True
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(plan, f)
        plan_path = f.name
    env = os.environ.copy()
    env["CANDYANTS_PLAN_PATH"] = plan_path
    env["CANDYANTS_DETERMINISTIC"] = "1"
    cmd = [sys.executable, str(RUN_TEST), PLAN_HARNESS, "--fixed-fps", "60"]
    try:
        if timeout is None:
            p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", cwd=str(ROOT), env=env)
        else:
            # timeout 경로는 Popen — subprocess.run의 타임아웃 kill은 직계 자식(run_test 파이썬)만
            # 죽여 행 걸린 godot 손자가 고아로 남는다. 트리 종료·reap 상한은 _kill_tree가 담당.
            # Windows: CREATE_SUSPENDED로 생성 → 잡 편입 → 재개(codex R9 — 편입이 실행보다 항상
            #   선행해 "편입 전 부모 선종료" 경쟁 원천 차단). 잡 준비/편입/재개 실패 = fail-closed
            #   (격리 없는 workload 실행 금지 — 원 결함 재발 경로를 열어두지 않는다).
            # POSIX: 새 세션(=새 프로세스 그룹, pgid == 자식 pid)으로 띄워 killpg 대상이 되게 한다.
            job = None
            if sys.platform == "win32":
                import ctypes
                job = _make_kill_on_close_job()
                if not job:
                    return {"error": "job object 생성 실패 — 격리 불가로 timeout-guarded 리플레이 거부"}
                # 셋업 전체(Popen·편입·재개)를 단일 소유권 경계로(codex R10): 어느 단계가 예외를
                # 던져도 finally가 생성분 정리(+미편입이면 taskkill 경로)·잡 CloseHandle을 보장하고,
                # 예외 전파 대신 error dict로 정규화한다. 성공 handoff 시에만 잡을 열어둔 채 진행.
                proc = None
                assigned = False
                handoff = False
                try:
                    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                            text=True, encoding="utf-8", errors="replace",
                                            cwd=str(ROOT), env=env,
                                            creationflags=0x00000004)  # CREATE_SUSPENDED
                    assigned = bool(ctypes.windll.kernel32.AssignProcessToJobObject(
                        job, int(proc._handle)))
                    handoff = assigned and _resume_process(proc.pid)
                except Exception:
                    handoff = False
                finally:
                    if not handoff:
                        if proc is not None:
                            _kill_tree(proc, job if assigned else None)   # suspended라 후손 없음
                        try:
                            ctypes.windll.kernel32.CloseHandle(job)
                        except Exception:
                            pass
                        job = None
                if not handoff:
                    return {"error": "job 편입/재개 실패 — 격리 불가로 timeout-guarded 리플레이 거부"}
            else:
                proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True, encoding="utf-8", errors="replace",
                                        cwd=str(ROOT), env=env, start_new_session=True)
            try:
                out, _err = proc.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                _kill_tree(proc, job)
                return {"error": f"replay timeout {timeout}s (wall-clock) — 엔진 행/부팅 실패 의심"}
            finally:
                if job:
                    try:
                        import ctypes
                        ctypes.windll.kernel32.CloseHandle(job)   # KILL_ON_CLOSE: 잔존 후손 일괄 종료
                    except Exception:
                        pass
            p = subprocess.CompletedProcess(cmd, proc.returncode, stdout=out, stderr=_err)
    finally:
        try:
            Path(plan_path).unlink()
        except OSError:
            pass
    for line in (p.stdout or "").splitlines():
        if line.startswith("SOLVER_RESULT "):
            try:
                return json.loads(line[len("SOLVER_RESULT "):])
            except json.JSONDecodeError:
                pass
    return {"error": "no SOLVER_RESULT", "stdout_tail": (p.stdout or "")[-400:]}


def is_full_clear(res: dict, hp: int) -> bool:
    return bool(res.get("cleared")) and int(res.get("saved", 0)) >= hp


def score(res: dict, layout: dict) -> tuple:
    """작을수록 좋음: saved 많음 > **리타이어 적음** > picked 많음 > 갇힘 적음 > **목표 접근**.
    **리타이어 최소가 picked보다 우선**(사용자 최우선 규칙): candy에서 멀어지더라도 전원 생존을 먼저
    확보해야 그 살아있는 상태에서 경로를 만들 수 있다(예: S14 치명 낙하 직전 blocker 반전 = 생존 발판).
    **목표 접근 = best_goal_dist**(픽업 전=candy, 픽업 후=home 셀 맨해튼) — best_min_y(항상 위로 보상)를
    대체해 candy가 아래(S14)면 하강을 보상한다.
    **전원 픽업 디딤돌 예외(2026-06-19, 사용자 통찰)**: remaining_hp==0(전 사탕 픽업)이면 picked를
    retired보다 우선한다. 전원 픽업은 '귀로만 남은' 강한 디딤돌인데(사탕과 충돌=방향전환 → 다음은 집으로
    가는 장애물을 climber로 대응), 그 상태의 잔존 retired(climber 미부여로 귀환 못해 사망)를 retired-우선
    으로 매기면 0픽업0사망(blocker 1개)에 기각돼 **climber를 얹을 trace에 도달조차 못 한다**(S14 정체
    근본 원인). 전원 픽업 전까지는 종전대로 retired 우선(생존 발판 먼저)."""
    saved = int(res.get("saved", 0))
    picked = int(res.get("picked_total", 0))
    retired = model.count_retired(res.get("trace", {}), layout)["total"]
    # 루프(블로커 충돌) 감지는 **saved==0일 때만 보정용**으로 참고한다(사용자 규칙): 집까지 도달한
    # 개미가 하나라도 있으면(saved>0) 블로커 충돌 횟수는 무시 — 그 가둠은 곧 풀릴(예: climber로) 정상
    # 과정일 수 있어 오판 방지. saved==0인데 carrying이 갇혔으면 = 잘못 놓인 블로커 → 그 변형을 기피.
    carry_tr = 0
    if saved == 0:
        carry_tr, _tot = model.count_trapped(res.get("trace", {}))
    goal_d = model.best_goal_dist(res.get("trace", {}), layout)
    if int(res.get("remaining_hp", -1)) == 0:        # 전원 픽업 = 귀로만 남은 디딤돌 → picked 우선(위 통찰)
        return (-saved, -picked, retired, carry_tr, goal_d)
    return (-saved, retired, -picked, carry_tr, goal_d)


def _fmt(res: dict, hp: int) -> str:
    return "saved=%s/%s reached=%s reason=%s frame=%s" % (
        res.get("saved"), hp, res.get("picked_total"), res.get("reason"), res.get("frame"))


# ---------- 스테이지 메타 ----------

def stage_meta(stage_id: int, tres_path=None) -> dict:
    """tres_path(옵션) = 캠페인 경로 밖 StageData(.tres) — dev_stages fixture용(워크로그 §14.4).
    기본 None = 기존 경로·동작 불변."""
    tres = (Path(tres_path) if tres_path
            else ROOT / "data" / "stages" / f"stage{stage_id:02d}.tres").read_text(encoding="utf-8")
    inv: dict[str, int] = {}
    b = re.search(r"skill_inventory\s*=\s*\{(.*?)\}", tres, re.S)
    if b:
        for m in re.finditer(r'"(\w+)"\s*:\s*(\d+)', b.group(1)):
            inv[m.group(1)] = int(m.group(2))
    notes: dict[str, str] = {}
    nb = re.search(r"skill_notes\s*=\s*\{(.*?)\}", tres, re.S)
    if nb:
        for m in re.finditer(r'"(\w+)"\s*:\s*"([^"]*)"', nb.group(1)):
            notes[m.group(1)] = m.group(2)
    def _int(name, dflt):
        m = re.search(name + r"\s*=\s*([\d.]+)", tres)
        return type(dflt)(float(m.group(1))) if m else dflt
    # 기본값 = 엔진 StageData.gd @export 기본과 반드시 일치(meta_defaults_probe가 강제) — total_ants
    # 기본 0은 mdp ants_total=max(1,0)=1로 shaping/blocker 분모를 10× 축소시킨 실증 버그
    # (2026-07-14 분석 §4.1: S25 bestR 2.280 재구성, S24/25만 .tres 필드 부재).
    return {"inventory": inv, "notes": notes, "candy_hp": _int("candy_hp", 10),
            "time_limit_seconds": _int("time_limit_seconds", 120.0), "total_ants": _int("total_ants", 10)}


# ---------- 닫힌 루프 ----------

def _action_sig(action: dict) -> str:
    """액션의 정규 시그니처(키 정렬 JSON). 다양-해 forbid 집합 매칭용 — try_solve.diverse_report의 plan
    시그니처와 **동일 직렬화**(json.dumps sort_keys=True)를 써야 정확히 일치한다."""
    return json.dumps(action, sort_keys=True)


def _merge_seeded(seeded: list, cands: list) -> list:
    """시드 후보를 propose 후보 풀에 머지 후 _w로 재정렬. action 동일 후보는 시드(보너스+source-tag)로
    치환(byte-identical action 보장 → OFF/ON 차이는 _w·source뿐, plan R1 HIGH-1 측정 계약).
    cands의 source 기본값은 'fallback'(seed_fn 미주입 시 전부 fallback으로 남음)."""
    by_label = {c["label"]: dict(c) for c in cands}
    for c in by_label.values():
        c.setdefault("source", "fallback")
    for s in seeded:
        by_label[s["label"]] = s            # 동일 label은 시드로 치환(보너스+source)
    out = list(by_label.values())
    out.sort(key=lambda c: -c["_w"])
    return out


def solve(stage_id: int, max_rollouts: int, seed_fn=None, stats: dict | None = None,
          save: bool = True, vault_fn=None, inv_override: dict | None = None,
          forbid=None) -> int:
    """닫힌-루프 탐색.
    ⛔ seed_fn·vault_fn = ARCHIVED (Phase 4 강제 종료 — ARCHIVE.md). 속도-전이(boost/pruning)는 falsify됐고
    기본 None이라 게이트에 inert(byte-identical). 보존하나 신규 경로에서 재활성 금지. stats dict 주입 시
    provenance/롤아웃 계측을 채운다(archived transfer-bench A/B·귀속 판정용, plan R1·R2)."""
    stage_scene = f"res://scenes/stages/Stage{stage_id:02d}.tscn"
    layout = model.parse_layout(ROOT / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres")
    meta = stage_meta(stage_id)
    inv, notes, hp = meta["inventory"], meta["notes"], int(meta["candy_hp"])
    if inv_override is not None:
        inv = {k: v for k, v in inv_override.items() if v > 0}   # 다양-해 탐색: 인벤토리 변형(수량/종류)
    # 다양-해 탐색: forbid된 액션 배제. **callable**(술어 `(action, base_plan)->bool`)이면 plan-level
    # solution-class forbid(Phase 5b diverse.py — base+[action]이 이미 발견된 class를 *정확히 완성*할 때만
    # 배제 = distinct class는 절대 억제 안 함, codex R2-HIGH), 아니면 시그니처 iterable(Item 1, 액션 dict/
    # 문자열). None이면 무영향(게이트 byte-identical).
    forbid_pred = forbid if callable(forbid) else None
    forbidden = (set() if forbid_pred is not None else
                 {(_action_sig(a) if isinstance(a, dict) else a) for a in forbid} if forbid else set())
    deadline = int(round(meta["time_limit_seconds"] * 60)) + 1500
    caps = dump_capabilities()
    metas = caps["skills"]

    print(f"=== solve stage{stage_id:02d} (예측 closed-loop{', SEEDED' if seed_fn else ''}) ===")
    print(f"  목표(candy hp)={hp}  도구(inventory)={inv}  notes={notes or '없음'}")
    print(f"  candy={layout['candy']} home={layout['home']} cap={max_rollouts} rollouts")

    rollouts = 0
    # provenance 계측(plan R1 HIGH-1·R2 HIGH-1): 후보 출처별 시도/성공 + 결정적(클리어) 액션 출처.
    prov = {"seeded_attempts": 0, "seeded_successes": 0, "fallback_attempts": 0,
            "fallback_successes": 0, "decisive_origin": None, "plan_sources": [],
            "vault_pruned": 0, "final_plan": None,
            # 반사실 귀속(re-review R1 HIGH-2): OFF가 롤아웃한 (action,cleared) 기록 + ON이 prune한 (base,action).
            # 벤치가 "prune된 후보가 OFF에서 미클리어였나"로 pruning 정당성을 반사실 검증.
            "tried_log": [], "pruned_log": []}

    def rollout(p: list[dict]) -> dict:
        nonlocal rollouts
        rollouts += 1
        return run_plan(stage_scene, p, deadline, trace=True)

    plan: list[dict] = []
    plan_sources: list[str] = []          # plan과 평행 — 채택 액션의 source-tag
    tried: set = set()

    # ① 베이스라인 관측.
    best = rollout(plan)
    if "error" in best:
        print("  [에러] 베이스라인 롤아웃 실패:", best.get("error"))
        return 1
    print(f"  baseline(무개입): {_fmt(best, hp)}")
    baseline_res = best                       # [5g] Phase B 시드용 원본 baseline(아래 best 재할당 후에도 보존)
    seed_pool: list[dict] = []                # [5g] Phase A harvest(read-only) — frontier 확장한 미채택 후보

    def _harvest(base_plan: list, base_res: dict, pairs: list) -> None:
        """[5g] read-only harvest: Phase A가 **이미 평가한** (cand,res) 중 frontier 확장분만 seed 풀에 append.
        추가 롤아웃 0·Phase A 결정/순서/채택에 영향 0(순수 관찰, plan §2 R3-HIGH-1 — byte-identical은 G-pre1 git diff)."""
        base_fr = model.frontier(base_res.get("trace", {}))
        for cand, res in pairs:
            if "error" in res:
                continue
            fr = model.frontier(res.get("trace", {}))
            if fr > base_fr:
                seed_pool.append({"base": list(base_plan), "action": cand["action"], "res": res,
                                  "frontier": fr, "score": score(res, layout), "_class": cand.get("_class", "")})

    if is_full_clear(best, hp):
        prov["final_plan"] = list(plan)      # 빈 플랜([])도 유효한 '무도구' 해 — diverse가 정직 보고하게 기록
        if stats is not None:
            stats.update(prov, rollouts=rollouts, cleared=True)
        return _save(stage_id, stage_scene, deadline, inv, plan, best, rollouts, hp, layout, meta["total_ants"], save=save)

    class _Clear(Exception):
        def __init__(self, p, r, srcs, decisive):
            self.plan, self.res, self.srcs, self.decisive = p, r, srcs, decisive

    def _propose(d, cap, base, src_res, use_vault=True):
        """propose + (seed_fn 있으면) 시드 머지 + (vault_fn 있고 use_vault면) 볼트 pruning. source-tag 부여.
        use_vault=False면 pruning 미적용(fail-open 재propose용). base = 현재 누적 plan(pruned_log 반사실 기준).
        src_res = diagnosis d를 만든 결과(트레이스) — retired/trapped를 **그 트레이스에서** 계산(R2 MEDIUM:
        LA2는 best가 아닌 res1 trace로 진단하므로 신호도 같은 trace에서 와야 위기가 올바르게 발화)."""
        # early 체인 게이트(model.propose `_has_early_arm`)는 **확정 plan**(closure)으로 판정 — speculative
        # base(LA2의 base2=plan+[c1])가 아니라. base2로 판정하면 LA2가 climber@early를 c1로 깔 때 early_armed가
        # 조기 발화해 boost가 2nd-step의 bridge(gap2 다리)를 max_n 밖으로 밀어내 **다중스킬 조합(climber+bridge)
        # 발견을 깨뜨린다**(stage20 실측: saved 1→0). 확정 plan에 early 무장이 든 뒤(=조합 발견 후)에만 체인
        # boost가 켜진다. forbid_pred(diverse)의 plan-aware base는 종전대로 base를 쓴다(아래 별도 인자).
        # ③ cell-up 같은-col 회피(T1)는 **speculative base**(LA2의 base2=plan+[c1] 포함)를 봐야 한다(plan-review
        # R3-H1) — early-chain closure(plan, 확정)와 직교한 별도 인자 cellup_base=base로 전달. 확정 plan만 보면
        # LA2 2nd-step이 같은-col 재스택(1/5 poison)을 제안할 수 있어 cellup_base에 base(speculative)를 넘긴다.
        cands = model.propose(layout, d, inv, metas, notes, exclude=tried, max_n=cap, plan=plan, cellup_base=base)
        if seed_fn:
            cands = _merge_seeded(seed_fn(layout, d, inv, metas), cands)[:cap]
        else:
            for c in cands:
                c.setdefault("source", "fallback")
        if forbidden:
            # 다양-해 탐색(Item 1): 이미 발견·보고된 해의 액션을 절대 배제(hard-filter) → 같은 인벤토리로
            # *다른* 배치/전략을 강제. exclude(tried)와 달리 ceiling/carry **면제도 무시**하는 절대 필터라
            # 모든 _propose 경로(main/sibling/LA2)에서 일관 적용된다. 후보가 0이 되면 솔버는 정직하게
            # 정지(= 더 이상 구별되는 해 없음) — 완전성 주장 아님(의도적 배제, 다양-해 보고 맥락).
            cands = [c for c in cands if _action_sig(c["action"]) not in forbidden]
        if forbid_pred is not None:
            # plan-level class forbid(diverse.py): `base+[action]`이 이미 발견된 solution-class를 *정확히
            # 완성*할 때만 배제(codex R2-HIGH — 슬롯 1개 공유하는 distinct class는 억제 안 함). base=현재 누적
            # plan을 넘겨 plan-aware. 모든 경로(main/sibling/LA2)에 일관 적용. 후보 0 → 정직 정지.
            cands = [c for c in cands if not forbid_pred(c["action"], base)]
        if vault_fn and use_vault:
            # 볼트가 위기→링크 도구/요소(retired/trapped 포함)로 형제 후보를 prune(de-risk 레버).
            tr = src_res.get("trace", {})
            retired = model.count_retired(tr, layout)
            ct, tt = model.count_trapped(tr)
            cands, pruned, pruned_acts = vault_fn(d, cands, retired, {"carry": ct, "total": tt})
            prov["vault_pruned"] += pruned
            for a in pruned_acts:
                prov["pruned_log"].append({"base": list(base), "action": a})
        return cands

    def eval_cands(base: list[dict], base_srcs: list[str], cands: list, tag: str, cap: int | None = None) -> list:
        """후보들을 base 플랜 위에 롤아웃. full clear면 _Clear로 즉시 탈출. 반환 (cand,res) 리스트.
        이미 base에 든 액션은 건너뛴다 — carry 후보는 exclude 면제(plan 누적 재평가)라, 채택돼 base에
        들어간 carry n이 다시 후보로 와도 중복 롤аут하지 않게 막는다(연쇄만 진행)."""
        # cap(codex impl R5): 이 호출이 도달 가능한 전역 rollouts 상한. main eval은 LA2 reserve를 남기도록
        # max_rollouts-LA2_RESERVE를 받고, baseline/LA2는 None(=max_rollouts). D2 보호가 후보를 per-round cap
        # 초과로 늘려도 main eval이 2-step lookahead(LA2) budget을 잠식하지 못하게(per-round cap contract 복원).
        limit = max_rollouts if cap is None else min(cap, max_rollouts)
        out: list = []
        for cand in cands:
            if rollouts >= limit:
                break
            if cand["action"] in base:        # 이미 채택된 액션 — 중복 롤아웃 방지
                continue
            tried.add(cand["label"])
            src = cand.get("source", "fallback")
            if src.startswith("seeded:"):
                prov["seeded_attempts"] += 1
            else:
                prov["fallback_attempts"] += 1
            res = rollout(base + [cand["action"]])
            ct, tt = model.count_trapped(res.get("trace", {}))
            print(f"  롤아웃 {rollouts}{tag}: +{cand['label']} [{src}] → {_fmt(res, hp)} trapped(carry/all)={ct}/{tt}")
            cleared_here = ("error" not in res) and is_full_clear(res, hp)
            prov["tried_log"].append({"base": list(base), "action": cand["action"], "cleared": bool(cleared_here)})
            if "error" in res:
                continue
            if is_full_clear(res, hp):
                if src.startswith("seeded:"):
                    prov["seeded_successes"] += 1
                else:
                    prov["fallback_successes"] += 1
                raise _Clear(base + [cand["action"]], res, base_srcs + [src], src)
            out.append((cand, res))
        return out

    # ②~④ 관측 → 진단 → 개입(라운드별 후보 평가 후 **최선** 채택) → 재관측 (상한까지).
    # 1-스텝이 정체하면 **2-스텝 lookahead**(사용자: S13/S14는 단일 개입이 일시적으로 악화[물 익사↑]된 뒤
    # 두 번째 개입으로 닫히므로 그리디로는 못 넘음 — 유망 first-step에서 재진단→second 평가).
    try:
        while rollouts < max_rollouts:
            diag = model.diagnose(best.get("trace", {}), layout, hp)
            per_round = min(max_rollouts - rollouts, 6)
            cands = _propose(diag, per_round, plan, best)
            # LA2 reserve(codex impl R5·R7): 메인 평가는 정상 per-round(min(remaining,6))를 항상 보존하고(R7),
            # D2 보호 확장분만 max_rollouts-LA2_RESERVE까지 허용해 lookahead budget을 떼어 둔다(_main_cap 참조).
            main_cap = _main_cap(rollouts, max_rollouts)
            # cap contract explicit(codex impl R8, 사용자 옵션 A): D2 보호가 정상 per-round를 넘겨 후보를 확장했는데
            # (보호 발동) cap이 부족해 그 protected tail이 main_cap에 안 들어가면 **silent inert 대신 명시 경고** —
            # cell-up witness가 평가 안 될 수 있음을 알린다(정상 per-round + protected + LA2_RESERVE는 작은 cap에
            # 동시에 안 들어가는 수학적 제약). D2 스테이지는 cap 충분(≥ baseline+protected+reserve)이어야 작동;
            # 부족하면 어차피 미해결 CHECKPOINT. 게이트 cap(40)은 충분해 경고 없음 → 동작·solve.json byte-identical.
            evaluable = max(0, min(main_cap, max_rollouts) - rollouts)
            if len(cands) > per_round and len(cands) > evaluable:
                print(f"  [cap 경고] D2 보호 후보 {len(cands)}개(정상 {per_round} + 보호 {len(cands) - per_round}) 중 "
                      f"{evaluable}개만 평가 가능 — cap={max_rollouts} 부족(LA2 reserve {LA2_RESERVE}). cell-up witness "
                      f"누락 가능, cap 상향 권장(D2는 충분 cap 필요).")
            evaluated = eval_cands(plan, plan_sources, cands, "", cap=main_cap) if cands else []
            # 완전성 보장(re-review R3 HIGH): vault-preferred 집합을 **먼저** 평가한다 — 그 안에서 full-clear가
            # 나면 eval_cands가 즉시 _Clear로 단축(이게 유일한 절약: 클리어 라운드 early-exit). 하지만 개선 채택·
            # 정체 판단 *전에* prune된 형제(off>=1)까지 **반드시** 평가해 ON이 OFF와 동일 후보 풀에서 결정하게
            # 한다 → ON ⊇ OFF(완전성). pruning은 더 이상 후보를 영구 삭제하지 않고 "평가 순서 우선"으로만 작동.
            if vault_fn:
                cands_sib = _propose(diag, min(max_rollouts - rollouts, 6), plan, best, use_vault=False)
                if cands_sib:
                    # codex impl R6 [MEDIUM]: 메인 단계의 완전성 pass도 **같은 main_cap** 적용 — 안 그러면 sibling
                    # 평가가 LA2 reserve를 잠식해 R5 cap contract 회귀(vault_fn은 ARCHIVED·항상 None이라 dead path지만
                    # 일관성·정확성 위해 동일 상한 적용). LA2 단계의 (LA2-complete)는 이미 reserve를 쓰는 단계라 무관.
                    evaluated = evaluated + eval_cands(plan, plan_sources, cands_sib, "(complete)", cap=main_cap)
            if not evaluated:
                print("  [정지] 제안할 개입 후보 없음(진단으로 더 둘 곳 없음).")
                break
            _harvest(plan, best, evaluated)          # [5g] read-only seed harvest(Phase A 거동 불변)
            cand, res = min(evaluated, key=lambda cr: score(cr[1], layout))
            if score(res, layout) < score(best, layout):
                plan = plan + [cand["action"]]
                plan_sources = plan_sources + [cand.get("source", "fallback")]
                best = res
                print(f"    채택(최선): +{cand['label']} → plan={[a.get('skill') for a in plan]}")
                continue
            # 1-스텝 정체 → 2-스텝 lookahead. **유망 first-step = goal_dist 최근접**(retired-우선 score가
            # 아니라!) — candy 근처까지 갔다가 익사한 스텝이 핵심 디딤돌이다(두 번째 스텝이 그 죽음을 고침).
            # retired-우선으로 뽑으면 안전하지만 막다른 top-trap에서 헛 lookahead한다(사용자 통찰 정합).
            print("  [1-스텝 정체] 2-스텝 lookahead 시도(frontier=goal_dist 최근접)")
            frontier = sorted(evaluated, key=lambda cr: model.best_goal_dist(cr[1].get("trace", {}), layout))[:2]
            combo = None
            for c1, res1 in frontier:
                if rollouts >= max_rollouts:
                    break
                diag1 = model.diagnose(res1.get("trace", {}), layout, hp)
                base2 = plan + [c1["action"]]
                srcs2 = plan_sources + [c1.get("source", "fallback")]
                cands2 = _propose(diag1, min(max_rollouts - rollouts, 4), base2, res1)
                ev2 = eval_cands(base2, srcs2, cands2, "(LA2)") if cands2 else []
                # 완전성(R3 HIGH): LA2 second-step도 prune된 형제 복원·평가 → second-step 풀도 ON ⊇ OFF.
                if vault_fn:
                    cands2_sib = _propose(diag1, min(max_rollouts - rollouts, 4), base2, res1, use_vault=False)
                    if cands2_sib:
                        ev2 = ev2 + eval_cands(base2, srcs2, cands2_sib, "(LA2-complete)")
                _harvest(base2, res1, ev2)           # [5g] LA2 평가 후보도 harvest(frontier 확장분)
                for c2, res2 in ev2:
                    if score(res2, layout) < score(best, layout) and (
                            combo is None or score(res2, layout) < score(combo[2], layout)):
                        combo = (c1, c2, res2)
            if combo is not None:
                c1, c2, res2 = combo
                plan = plan + [c1["action"], c2["action"]]
                plan_sources = plan_sources + [c1.get("source", "fallback"), c2.get("source", "fallback")]
                best = res2
                print(f"    채택(LA2): +{c1['label']}+{c2['label']} → plan={[a.get('skill') for a in plan]}")
                continue
            print("  [정지] 1-스텝·2-스텝 모두 진척을 못 냄.")
            break
    except _Clear as c:
        prov["decisive_origin"] = c.decisive
        prov["plan_sources"] = c.srcs
        prov["final_plan"] = c.plan
        if stats is not None:
            stats.update(prov, rollouts=rollouts, cleared=True)
        return _save(stage_id, stage_scene, deadline, inv, c.plan, c.res, rollouts, hp, layout, meta["total_ants"], save=save)

    # ---- Phase 5g Phase B: 탐험-우선 fallback best-first (plan §5g) — Phase A가 clear 없이 종료(break OR
    # max_rollouts 소진)했을 때만 발동. Phase A와 **별도 가산 예산**(PHASE_B_BUDGET). solved 스테이지는 Phase A서
    # _Clear → 여기 미도달 = inert(byte-identical, G-pre1).
    MAX_PLAN_LEN = sum(int(v) for v in inv.values())     # 종료 경계 (2): plan 길이 상한 = Σ inventory action
    phase_b_entered = False
    if not is_full_clear(best, hp):
        import heapq
        # seed pool 결정론 cap: (base_sig,_class)별 frontier-top SEED_POOL_CAP (R2-MED-2 pool noise 억제)
        groups: dict = {}
        for s in seed_pool:
            groups.setdefault((json.dumps(s["base"], sort_keys=True, ensure_ascii=False), s["_class"]), []).append(s)
        seeds = []
        for gkey in sorted(groups):
            seeds.extend(sorted(groups[gkey],
                                key=lambda s: (-s["frontier"], s["score"], _action_sig(s["action"])))[:SEED_POOL_CAP])
        has_floater = any(s["base"] == [] and s["action"].get("skill") == "floater" for s in seeds)
        print(f"\n[Phase B] 진입(Phase A clear 실패) — raw seed {len(seed_pool)} → capped {len(seeds)}, "
              f"budget {PHASE_B_BUDGET}롤, MAX_PLAN_LEN={MAX_PLAN_LEN}, floater@base[] 시드={has_floater}")
        phase_b_entered = True

        def _msig(p: list) -> tuple:                     # 순서무관 multiset sig (memo·tie-break)
            return tuple(sorted(_action_sig(a) for a in p))

        def _node(p: list, res: dict) -> dict:
            tr = res.get("trace", {})
            return {"plan": p, "res": res, "frontier": model.frontier(tr),
                    "saved": int(res.get("saved", 0)), "picked": int(res.get("picked_total", 0)),
                    "retired": model.count_retired(tr, layout)["total"],
                    "goal": model.best_goal_dist(tr, layout)}

        def _skill_of(node: dict) -> str:
            return node["plan"][-1].get("skill", "") if node["plan"] else "_base"

        # 정렬 키 = **회수가능 진척(stepping-stone) 우선** (de-risk: score의 saved-우선 myopia가 "saved=1 dead-end"를
        # "picked=7 살아있는 디딤돌"보다 우선시켜 witness 이탈 — S14 "전원 픽업 디딤돌"을 beam/saved 레벨로 일반화).
        # ① 도달-진척 `saved+picked` desc(candy 도달/귀환한 개미 수 = 회수가능 잠재), ② retired asc(살아있는 디딤돌
        # 우선), ③ goal_dist asc(목표 근접), ④ frontier desc(score-평평 plateau 탐험 tie-break), ⑤ 결정론 sig.
        def _rank(n: dict) -> tuple:
            return (-(n["saved"] + n["picked"]), n["retired"], n["goal"], -n["frontier"], str(_msig(n["plan"])))

        def _select_beam(nodes: list, K: int) -> list:
            """skill-class 다양성 beam(②+③ — de-risk: 단일 신호로는 blocker/witness 노드 탈락). dedup → **per-skill
            최선 보존**(저-순위 blocker 등 필수 분기 생존) → 잔여를 _rank-top으로 K까지 채움. 결정론."""
            seen: dict = {}
            for n in nodes:
                sg = _msig(n["plan"])
                if sg not in seen or _rank(n) < _rank(seen[sg]):
                    seen[sg] = n
            uniq = list(seen.values())
            by_skill: dict = {}
            for n in uniq:
                sk = _skill_of(n)
                cur = by_skill.get(sk)
                if cur is None or _rank(n) < _rank(cur):
                    by_skill[sk] = n
            selected = sorted(by_skill.values(), key=_rank)
            sel_sigs = {_msig(n["plan"]) for n in selected}
            for n in sorted((x for x in uniq if _msig(x["plan"]) not in sel_sigs), key=_rank):
                if len(selected) >= K:
                    break
                selected.append(n)
                sel_sigs.add(_msig(n["plan"]))
            return selected

        memo: set = set()
        # 초기 beam = baseline + harvested 시드(res 재사용=0롤), skill-diverse top BEAM_WIDTH
        init = [_node([], baseline_res)] + [_node(s["base"] + [s["action"]], s["res"]) for s in seeds]
        beam = _select_beam(init, BEAM_WIDTH)
        pb_budget = PHASE_B_BUDGET                        # 종료 경계 (1, 주): 별도 가산 롤아웃 cap
        pb_node = None
        pb_best = min(init, key=_rank)                    # Phase B 전체 최선 진척 노드(refine 시드)
        depth = 0
        while beam and pb_budget > 0 and depth < MAX_PLAN_LEN:   # 종료 경계 (2): depth ≤ MAX_PLAN_LEN
            depth += 1
            pool: list = []                              # 이 레벨의 frontier-확장 자식
            for node in beam:
                if pb_budget <= 0:
                    break
                if is_full_clear(node["res"], hp):
                    pb_node = node
                    break
                sg = _msig(node["plan"])
                if sg in memo:                            # 종료 경계 (3): canonical plan-sig memo(중복 expand 0)
                    continue
                memo.add(sg)
                if len(node["plan"]) >= MAX_PLAN_LEN:
                    continue
                diag = model.diagnose(node["res"].get("trace", {}), layout, hp)
                # branch-local: Phase A 전역 tried 미상속(R1-HIGH-3) — exclude=set()(fresh), memo가 loop 방지.
                cands = model.propose(layout, diag, inv, metas, notes, exclude=set(), max_n=6,
                                      plan=node["plan"], cellup_base=node["plan"])
                for cand in cands:
                    if pb_budget <= 0:
                        break
                    child = node["plan"] + [cand["action"]]
                    if _msig(child) in memo:
                        continue
                    res = run_plan(stage_scene, child, deadline, trace=True)
                    pb_budget -= 1
                    if "error" in res:
                        continue
                    cn = _node(child, res)
                    if _rank(cn) < _rank(pb_best):
                        pb_best = cn
                    if is_full_clear(res, hp):
                        pb_node = cn
                        break
                    # frontier 확장(탐험) OR _rank 개선(진척: 도달/회수/목표근접) 자식만 유지(헛 배회 억제 +
                    # 생산 노드 보존; 둘 다 아니면 정체 자식이라 drop).
                    if cn["frontier"] > node["frontier"] or _rank(cn) < _rank(node):
                        pool.append(cn)
                if pb_node is not None:
                    break
            if pb_node is not None:
                break
            if not pool:
                break
            beam = _select_beam(pool, BEAM_WIDTH)        # skill-diverse 다음 레벨 beam
            top = min(beam, key=_rank) if beam else None
            bskills = sorted({_skill_of(n) for n in beam})
            ts = (f"saved={top['saved']} picked={top['picked']} retired={top['retired']} goal={top['goal']} "
                  f"fr={top['frontier']}") if top else "—"
            print(f"[Phase B] depth {depth}: beam {len(beam)}(skills {bskills}), top[{ts}], budget 남음 {pb_budget}")
        used = PHASE_B_BUDGET - pb_budget
        # ---- 국소 placement 정밀탐색(refinement, 사용자 결정 2026-06-28) ----
        # beam은 picked=hp "모양"엔 도달하나 정확한 cell 배치(개미 생존)를 못 맞추는 placement-needle 해소:
        # 최선 노드 pb_best의 cell-target 배치를 ±REFINE_RADIUS coordinate-ascent perturb(생존 변형 탐색) 후
        # propose 확장으로 귀환/마무리 단계 시도(spike 국소탐색·analyze 윈도우 선례).
        if pb_node is None and not is_full_clear(pb_best["res"], hp):
            import copy
            rb = REFINE_BUDGET
            cur = pb_best
            refine_memo = set(memo)
            print(f"[Phase B] refine 진입 — 시드 best[saved={cur['saved']} picked={cur['picked']} "
                  f"retired={cur['retired']} goal={cur['goal']}], budget {rb}롤")
            cell_idxs = [i for i, a in enumerate(cur["plan"]) if (a.get("target") or {}).get("mode") == "cell"]
            improved = True
            while improved and rb > 0 and pb_node is None:        # (A) cell 배치 coordinate-ascent
                improved = False
                for i in cell_idxs:
                    bc = (cur["plan"][i].get("target") or {}).get("cell")
                    if not bc or rb <= 0:
                        continue
                    for dc in range(-REFINE_RADIUS, REFINE_RADIUS + 1):
                        for dr in range(-REFINE_RADIUS, REFINE_RADIUS + 1):
                            if (dc == 0 and dr == 0) or rb <= 0:
                                continue
                            np_ = copy.deepcopy(cur["plan"])
                            np_[i]["target"]["cell"] = [bc[0] + dc, bc[1] + dr]
                            sg = _msig(np_)
                            if sg in refine_memo:
                                continue
                            refine_memo.add(sg)
                            res = run_plan(stage_scene, np_, deadline, trace=True)
                            rb -= 1
                            if "error" in res:
                                continue
                            cn = _node(np_, res)
                            if is_full_clear(res, hp):
                                pb_node = cn
                                break
                            if _rank(cn) < _rank(cur):
                                cur, improved = cn, True
                        if pb_node is not None:
                            break
                    if pb_node is not None:
                        break
            if pb_node is None and rb > 0 and len(cur["plan"]) < MAX_PLAN_LEN:   # (B) 확장(귀환/마무리)
                diag = model.diagnose(cur["res"].get("trace", {}), layout, hp)
                cands = model.propose(layout, diag, inv, metas, notes, exclude=set(), max_n=8,
                                      plan=cur["plan"], cellup_base=cur["plan"])
                for cand in cands:
                    if rb <= 0:
                        break
                    child = cur["plan"] + [cand["action"]]
                    if _msig(child) in refine_memo:
                        continue
                    refine_memo.add(_msig(child))
                    res = run_plan(stage_scene, child, deadline, trace=True)
                    rb -= 1
                    if "error" in res:
                        continue
                    if is_full_clear(res, hp):
                        pb_node = _node(child, res)
                        break
                    cn = _node(child, res)
                    if _rank(cn) < _rank(cur):
                        cur = cn
            used += REFINE_BUDGET - rb
            if pb_node is None:
                print(f"[Phase B] refine 후 미해결 — best[saved={cur['saved']} picked={cur['picked']} "
                      f"retired={cur['retired']} goal={cur['goal']}], refine {REFINE_BUDGET - rb}롤")
        if pb_node is not None and is_full_clear(pb_node["res"], hp):
            sig_ms = sorted(a.get("skill") for a in pb_node["plan"])
            print(f"[Phase B] SOLVED — plan={[a.get('skill') for a in pb_node['plan']]} ({used}롤 소비)")
            print(f"[Phase B] 메커니즘 signature: phase_b_entered=True, floater@base[] 시드={has_floater}, "
                  f"multiset={sig_ms}")
            prov["final_plan"] = pb_node["plan"]
            prov["plan_sources"] = ["phase_b"] * len(pb_node["plan"])
            if stats is not None:
                stats.update(prov, rollouts=rollouts + used, cleared=True)
            return _save(stage_id, stage_scene, deadline, inv, pb_node["plan"], pb_node["res"],
                         rollouts + used, hp, layout, meta["total_ants"], save=save)
        print(f"[Phase B] 미해결 — {used}롤 소비, expand 노드 {len(memo)}, "
              f"최대 frontier {max((s['frontier'] for s in seeds), default=0)}")

    # 상한 도달 또는 정체 — 100% 미달 → 체크포인트. 최고 기록 시도의 리타이어 개미·사용 도구 수도 보고.
    prov["plan_sources"] = plan_sources
    prov["final_plan"] = plan
    if stats is not None:
        stats.update(prov, rollouts=rollouts, cleared=False)
    saved = int(best.get("saved", 0))
    rt = model.count_retired(best.get("trace", {}), layout)
    tools = len(plan)
    kind = "부분 성공" if saved > 0 else "실패"
    print(f"\nCHECKPOINT stage{stage_id:02d}: {kind} (saved={saved}/{hp}, rollouts={rollouts}/{max_rollouts}).")
    print(f"  최고 기록: {_fmt(best, hp)} | 리타이어={rt['total']}/{meta['total_ants']}"
          f"(낙하 {rt['fall']}, 물 {rt['water']}) | 사용 도구={tools}")
    print(f"  best plan: {[a.get('skill') for a in plan]}")
    print(f"  => 10 롤아웃 내 100% 미달성. 재도전(상한 상향) 여부를 사용자 승인 필요.")
    return 2


def _save(stage_id, stage_scene, deadline, inv, plan, res, rollouts, hp, layout, total_ants, save=True) -> int:
    rt = model.count_retired(res.get("trace", {}), layout)
    tools = len(plan)
    if not save:
        # 벤치(read-only A/B): 기존 게이트 산출물 stageNN.solve.json을 덮어쓰지 않는다.
        print(f"\nSOLVED(100%, no-save) stage{stage_id:02d}: saved={res.get('saved')}/{hp} | "
              f"사용 도구={tools} | rollouts={rollouts} | skills={[a.get('skill') for a in plan]}")
        return 0
    sol = {"stage": stage_scene, "deadline_frames": deadline, "inventory": inv,
           "expect": {"cleared": True, "saved": int(res.get("saved", 0))},
           "search_meta": {"rollouts": rollouts, "tool": "solve.py", "phase": 2, "method": "predictive",
                           "retired_ants": rt, "total_ants": total_ants, "tools_used": tools},
           "actions": plan, "result": {k: v for k, v in res.items() if k != "trace"}}
    sol_dir = ROOT / "data" / "solutions"
    sol_dir.mkdir(exist_ok=True)
    sol_path = sol_dir / f"stage{stage_id:02d}.solve.json"
    sol_path.write_text(json.dumps(sol, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSOLVED(100%) stage{stage_id:02d}: saved={res.get('saved')}/{hp} | "
          f"리타이어={rt['total']}/{total_ants}(낙하 {rt['fall']}, 물 {rt['water']}) | "
          f"사용 도구={tools} | rollouts={rollouts}")
    print(f"  skills={[a.get('skill') for a in plan]}")
    print(f"  plan saved -> {sol_path.relative_to(ROOT)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_id", type=int)
    ap.add_argument("--max-rollouts", type=int, default=10, help="롤아웃 상한(기본 10, 사용자 정책).")
    args = ap.parse_args()
    return solve(args.stage_id, args.max_rollouts)


if __name__ == "__main__":
    raise SystemExit(main())
