#!/usr/bin/env python3
"""solution_registry — 스테이지별 '정리된 해' 레지스트리 (2026-07-11 사용자 계약).

계약:
  - **중복 기준 = 실행-결과 동치**: 결정론 리플레이의 개미 궤적(trace)+판정(saved/frame) digest가
    같으면 같은 해. 트리거 표현이 달라도(S1: xle17/any vs pick>=2/carrying vs xle18+y밴드 — 전부
    frame 1587 동일 실행) 엔진에서 같은 일이 일어나면 중복, 배치가 실제로 다르면(S5 sand_mound
    (13,8)/(18,8)/(15,9)) 복수 해. trace 부재 런은 플랜-정규화 키(plan_key)로 보수적 폴백(과분할 허용).
  - **레벨 변경 시 파기**: 레지스트리는 레벨 컨텐츠 digest(stage .tres + layout .tres + .tscn)에
    바인딩. 기록 시점에 digest가 다르면 기존 해 전부 파기하고 새 레벨 기준으로 재시작.
  - **신규만 기록**: 이미 정리된 해와 중복이면 seeds/runs 카운트만 갱신(사이드카·log 미기록).

파일: data/solutions/found/stageNN.solutions.json (스테이지당 1개, 원자적 교체).
뷰어(found_viewer)는 레지스트리가 있는 스테이지는 레지스트리를 권위로 쓰고, 없는 스테이지만
레거시 사이드카/log를 읽는다.

CLI:  python tools/solver/solution_registry.py --migrate   # 레거시 found 기록+replay_cache로부터
      레지스트리 일괄 생성(현재 레벨 digest로 스탬프 — 레벨이 그 후 안 바뀌었다는 전제의 1회 이행).
"""
from __future__ import annotations

import contextlib
import hashlib
import json
import os
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FOUND_DIR = REPO / "data" / "solutions" / "found"
CELL = 48


class RegistryCorruptError(RuntimeError):
    """레지스트리 파일이 존재하나 읽기/파싱 불가 — '없음'과 구분해 fail-closed(조용한 재생성 금지)."""


class LevelUnverifiableError(RuntimeError):
    """현재 레벨 digest 산출 불가(레벨 파일 부재 등) — 레벨 정체성을 검증할 수 없는 상태에서
    레지스트리를 생성/변경하면 오염이므로 기록을 거부(codex R5-M2 fail-closed)."""


# ---------- 플랜 정규화 (트리거 표현 무관 보조 키) ----------

def canon_action(a: dict, cs: int = CELL) -> tuple:
    """액션 동치 서명 — 좌표는 셀 양자화, frame은 60f(1s) 버킷. 실행-동치보다 거친 보조 키."""
    t = a.get("target", {}) or {}
    tr = a.get("trigger", {}) or {}
    if t.get("mode") == "cell":
        tgt: tuple = ("cell", tuple(t.get("cell") or ()))
    else:
        band = None
        if t.get("y_min") is not None and t.get("y_max") is not None:
            band = (int(float(t["y_min"]) // cs), int(float(t["y_max"]) // cs))
        tgt = ("ant", t.get("select"), t.get("state") or "any", band)
    typ = tr.get("type")
    if typ == "ant_reaches_x":
        trg: tuple = (typ, tr.get("cmp"), int(float(tr.get("x") or 0) // cs))
    elif typ == "picked_ge":
        trg = (typ, tr.get("n"))
    elif typ in ("at_frame", "at_frame_exact"):
        trg = (typ, int(float(tr.get("frame") or 0) // 60))
    else:
        trg = (typ, json.dumps({k: v for k, v in tr.items() if k != "type"},
                               sort_keys=True, ensure_ascii=False))
    return (a.get("skill"), tgt, trg)


def plan_key(actions: list[dict]) -> str:
    """플랜의 정규화 키(액션 순서 무관) — trace 부재 시 중복 판정 폴백."""
    sigs = sorted(repr(canon_action(a)) for a in (actions or []))
    return hashlib.sha256("\n".join(sigs).encode("utf-8")).hexdigest()[:16]


def valid_event_record(rec) -> bool:
    """이벤트 레코드(발견 기록) 구조 검증 — 뷰어·migrate **공유**(codex R20-M1·R21-M1/M2).
    `type() is int`로 bool 배제. 중첩 action 필드는 canon_action이 실제로 소화 가능한지
    **시험 평가**로 판정(스칼라 target/trigger·비수치 frame 등 parse-valid 손상을 사전 거부 —
    나중 plan_key 호출 지점에서 전체 파이프라인이 죽는 것 차단)."""
    if not isinstance(rec, dict):
        return False
    if type(rec.get("stage_id")) is not int:
        return False
    seed = rec.get("seed")
    if seed is not None and type(seed) is not int:
        return False
    if not isinstance(rec.get("ts", ""), str):
        return False
    actions = rec.get("actions", [])
    if not isinstance(actions, list) or not all(isinstance(a, dict) for a in actions):
        return False
    try:
        plan_key(actions)
    except Exception:                          # noqa: BLE001 — canon 불가 = 구조 손상
        return False
    return True


def event_id(rec: dict) -> str:
    """이벤트의 안정 정체성 — migrate 멱등 원장 키(codex R21-M3·R22-M1).
    ① 레코드에 train.py가 생성 시 부여한 고유 `event`(uuid hex16)가 있으면 그대로(무충돌 SoT).
    ② 레거시 폴백 = **무손실** 필드 digest: stage_id/seed/ts + stage 씬 + deadline + **raw
    actions 전체**(plan_key의 60f 버킷·셀 양자화는 같은 초의 다른 발견을 충돌시킴 — at_frame
    60 vs 119가 같은 ID가 되어 검증된 해 하나가 조용히 누락). 레거시에서 같은 초·동일 raw
    플랜의 진짜 별개 런은 이중 기재와 구별 불가(한계 명시) — v2 레코드부터는 ①이 해소."""
    ev = rec.get("event")
    if isinstance(ev, str) and _is_hex16(ev):
        return ev
    payload = json.dumps({"stage_id": rec.get("stage_id"), "seed": rec.get("seed"),
                          "ts": str(rec.get("ts") or ""), "stage": rec.get("stage"),
                          "deadline": rec.get("deadline_frames"),
                          "actions": rec.get("actions") or []},
                         sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


# ---------- 실행-결과 동치 키 ----------

def exec_digest(res: dict) -> str | None:
    """롤아웃/리플레이 결과의 실행 동치 digest — trace(스폰인덱스 정규화) + saved + frame.
    trace가 없으면 None(호출측이 plan_key 폴백)."""
    trace = res.get("trace")
    if not trace:
        return None
    norm = {str(k): trace[k] for k in sorted(trace, key=lambda x: int(x))}
    payload = json.dumps({"trace": norm, "saved": res.get("saved"),
                          "frame": res.get("frame")},
                         sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


# ---------- 엔진 런타임 digest (게임플레이 의미론 — 스테이지 콘텐츠와 상보) ----------

_RUNTIME_DIGEST_CACHE: dict[str, str] = {}


_GODOT_IDENTITY_CACHE: list = []      # [str|None] 1칸 — 프로세스당 1회 계산(바이너리 해시 비용)


def _godot_identity() -> str | None:
    """리플레이가 실제 사용할 Godot 실행파일 정체성 = resolved 경로 + **바이너리 내용 sha16**
    (codex R10-H2: 같은 경로에 엔진을 교체/업그레이드해도 결속이 잡게 — 경로만으로는 불충분).
    해석 불가 = None(엔진 없는 머신의 오프라인 빌드 — 캐시 결속이 None을 포함해 엔진-존재
    시점 캐시와 자동 불일치=fail-closed 미스)."""
    if _GODOT_IDENTITY_CACHE:
        return _GODOT_IDENTITY_CACHE[0]
    try:
        import sys as _sys
        sp = str(REPO / "scripts")
        if sp not in _sys.path:
            _sys.path.insert(0, sp)
        from run_test import find_godot
        p = Path(find_godot()).resolve()
        h = hashlib.sha256()
        with open(p, "rb") as f:              # 스트리밍(수백 MB 바이너리 메모리 폭식 방지)
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        out: str | None = f"{p}:{h.hexdigest()[:16]}"
    except (Exception, SystemExit):   # find_godot는 실패를 sys.exit로 보고(codex R9 —
        out = None                    # SystemExit은 Exception 밖; 오프라인 빌드 종료 차단)
    _GODOT_IDENTITY_CACHE.append(out)
    return out


def runtime_digest(root: Path = REPO) -> str:
    """엔진측 게임플레이 의미론 digest(codex §17-R6): 스테이지 씬이 ext_resource로 전이 로드하는
    스크립트/엔티티 씬(StageRunner/AntSpawner/Terrain/hazard 등)의 변경을 잡는다. 정밀한
    per-stage 전이 폐쇄 대신 **coarse 과대포함**(scripts/**/*.gd + scenes/**(stages 제외 —
    per-stage는 level_digest 트리오 담당) + tests/Plan{Server,Replay}Harness.* + data/solver/**
    + project.godot) — 과잉 무효화는 무해(스윕 재실행=dup, 캐시=재생성 가능)하고 누락이 해악.
    프로세스당 root별 1회 계산 캐시."""
    key = str(root)
    if key in _RUNTIME_DIGEST_CACHE:
        return _RUNTIME_DIGEST_CACHE[key]
    # tests 하니스 2종 모두 — PlanServerHarness(RL 학습 롤아웃) + PlanReplayHarness(뷰어/selftest
    # 리플레이가 solve.run_plan으로 띄우는 씬; codex R7 — SOLVER_RESULT 방출 의미론 보유).
    # 리플레이 실행 스택의 Python측(codex R8): solve.py(run_plan 직렬화·결과 파싱) +
    # run_test.py(godot 기동·인자) — 이들 변경도 캐시/지문 무효화 대상.
    groups = [("scripts", "**/*.gd"), ("scenes", "**/*.tscn"), ("scenes", "**/*.tres"),
              ("tests", "PlanServerHarness.*"), ("tests", "PlanReplayHarness.*"),
              ("tools/solver", "solve.py"), ("scripts", "run_test.py"),
              ("data/solver", "**/*")]
    files: list[Path] = []
    for base, pat in groups:
        d = root / base
        if d.exists():
            files += [p for p in d.glob(pat) if p.is_file()]
    pg = root / "project.godot"
    if pg.exists():
        files.append(pg)
    h = hashlib.sha256()
    for p in sorted(files, key=lambda x: str(x.relative_to(root)).replace("\\", "/")):
        rel = str(p.relative_to(root)).replace("\\", "/")
        if rel.startswith("scenes/stages/"):   # per-stage 콘텐츠는 level_digest가 담당
            continue
        h.update(rel.encode("utf-8") + b"\0" + p.read_bytes() + b"\0")
    # 엔진 실행파일 정체성(codex R8): 엔진 업그레이드가 이전-엔진 캐시를 재사용 못 하게 결속.
    # 캐시는 머신-로컬(gitignore) 아티팩트라 경로 결속의 cross-PC 비용 없음.
    h.update(f"godot:{_godot_identity()}".encode("utf-8"))
    out = h.hexdigest()[:16]
    _RUNTIME_DIGEST_CACHE[key] = out
    return out


# ---------- 리플레이 캐시 키 (found_viewer·migrate 단일 출처) ----------

REPLAY_CACHE_SCHEMA = 4       # 캐시 payload 의미 변경 시 증가 — 옛 캐시 전량 자동 미스
#                               (v3: runtime_digest 결속, codex R6 / v4: 리플레이 파이썬 스택
#                                solve.py·run_test.py + godot 실행파일 정체성 결속, codex R8)


def cache_binding(stage_id) -> dict:
    """캐시 payload `_cache` 결속(schema+level+runtime) — 뷰어·migrate 단일 출처."""
    return {"schema": REPLAY_CACHE_SCHEMA,
            "level_digest": level_digest(stage_id) if isinstance(stage_id, int) else None,
            "runtime_digest": runtime_digest()}


def valid_replay_payload(payload, binding: dict | None = None) -> bool:
    """리플레이 payload 유효성 — 뷰어(attach_replays 읽기/신규)와 migrate가 공유하는 단일
    검증기(codex R13: 소비자별 가드 드리프트 차단). ① dict ② `error` **키 부재**(null 값 포함
    거부, R12) ③ cleared 불리언 ④ binding 지정 시 `_cache` 정확 일치."""
    if not isinstance(payload, dict) or "error" in payload:
        return False
    if not isinstance(payload.get("cleared"), bool):
        return False
    if binding is not None and payload.get("_cache") != binding:
        return False
    return True


def replay_cache_key(rec: dict) -> str:
    """리플레이 캐시 키 — **현재 레벨 digest + 엔진 runtime digest + 스키마 버전 결속**
    (codex R1-M2·R6). 레벨 또는 게임플레이 스크립트가 바뀌면 같은 플랜이라도 키가 달라져
    옛 의미론의 궤적/지표가 재사용될 수 없다. 레벨 digest 산출 불가(파일 부재)면 None이 키에
    들어가되, 캐시 읽기/쓰기 자체는 호출측이 fail-closed 생략(R5-M2)."""
    sid = rec.get("stage_id")
    payload = json.dumps({"schema": REPLAY_CACHE_SCHEMA,
                          "level_digest": level_digest(sid) if isinstance(sid, int) else None,
                          "runtime_digest": runtime_digest(),
                          "stage": rec.get("stage"),
                          "deadline": rec.get("deadline_frames") or 6000,
                          "actions": rec.get("actions") or []},
                         sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


# ---------- 레벨 digest (파기 트리거) ----------

def level_digest(stage_id: int) -> str | None:
    """레벨 컨텐츠 digest — 스테이지 .tres + layout .tres + .tscn 바이트 결합 sha256.
    (_exec_config_digest stage_resource_digest와 같은 트리오. 파일 없으면 None = 바인딩 불가.)"""
    files = [REPO / "data" / "stages" / f"stage{stage_id:02d}.tres",
             REPO / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres",
             REPO / "scenes" / "stages" / f"Stage{stage_id:02d}.tscn"]
    h = hashlib.sha256()
    for p in files:
        if not p.exists():
            return None
        h.update(p.read_bytes())
    return h.hexdigest()[:16]


# ---------- 레지스트리 I/O ----------

def registry_path(stage_id: int, found_dir: Path = FOUND_DIR) -> Path:
    return found_dir / f"stage{stage_id:02d}.solutions.json"


def _is_hex16(v) -> bool:
    """sha256 절단 digest 정규형([0-9a-f]{16}) — 같은 길이의 비-hex 손상값을 걸러낸다
    (codex R3-H1: 'x'*16 같은 값이 통과하면 '레벨 변경' 오인 파기가 재발)."""
    return isinstance(v, str) and len(v) == 16 and all(c in "0123456789abcdef" for c in v)


def _schema_error(reg, stage_id: int) -> str | None:
    """파싱은 됐으나 구조가 깨진 레지스트리 검출(codex R2-H1: level_digest가 빠진 채 solutions만
    남은 손상본은 '레벨 변경'으로 오인돼 파기된다). 위반 사유 문자열, 정상이면 None."""
    if not isinstance(reg, dict):
        return f"최상위가 dict 아님({type(reg).__name__})"
    if reg.get("stage_id") != stage_id:
        return f"stage_id 불일치(기대={stage_id}, 내용={reg.get('stage_id')!r})"
    if "level_digest" not in reg:
        return "level_digest 키 부재"
    ld = reg["level_digest"]
    if ld is not None and not _is_hex16(ld):
        return f"level_digest 형식 위반({ld!r})"
    sols = reg.get("solutions")
    if not isinstance(sols, list):
        return f"solutions가 list 아님({type(sols).__name__})"
    for i, sol in enumerate(sols):
        if not isinstance(sol, dict):
            return f"solutions[{i}]가 dict 아님"
        if not _is_hex16(sol.get("plan_key")):
            return f"solutions[{i}].plan_key 부재/형식 위반"
        if not isinstance(sol.get("actions"), list):
            return f"solutions[{i}].actions 부재/형식 위반"
        if not isinstance(sol.get("seeds"), list):
            return f"solutions[{i}].seeds 부재/형식 위반"
        ed = sol.get("exec_digest")
        if ed is not None and not _is_hex16(ed):
            return f"solutions[{i}].exec_digest 형식 위반"
        ev = sol.get("events")                 # 선택 필드(migrate 멱등 원장, R21-M3)
        if ev is not None and not (isinstance(ev, list) and all(_is_hex16(x) for x in ev)):
            return f"solutions[{i}].events 형식 위반"
    return None


def load_registry(stage_id: int, found_dir: Path = FOUND_DIR) -> dict | None:
    """레지스트리 로드. 없음 = None / 손상·읽기실패·스키마 위반 = RegistryCorruptError
    (codex R1-H1·R2-H1: 손상을 None이나 '레벨 변경'으로 뭉개면 조용히 갈아엎어진다)."""
    p = registry_path(stage_id, found_dir)
    if not p.exists():
        return None
    try:
        reg = json.loads(p.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:   # 비-UTF8도 손상(R17)
        raise RegistryCorruptError(f"{p.name}: {exc}") from exc
    err = _schema_error(reg, stage_id)
    if err is not None:
        raise RegistryCorruptError(f"{p.name}: 스키마 위반 — {err}")
    return reg


def _quarantine(stage_id: int, found_dir: Path) -> Path | None:
    """손상 레지스트리를 타임스탬프 이름으로 보존-이동(복구용). 이동 실패 시 None(원본 잔존).
    같은 초 내 재격리는 카운터로 유일화(선행 격리본 덮어쓰기 방지) — _stage_lock 내부에서만
    호출되므로 존재-검사에 프로세스 간 레이스 없음."""
    p = registry_path(stage_id, found_dir)
    base = f"{p.stem}.corrupt-{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}"
    dst = p.with_name(f"{base}.json")
    i = 0
    while dst.exists():
        i += 1
        dst = p.with_name(f"{base}-{i}.json")
    try:
        os.replace(p, dst)
        return dst
    except OSError:
        return None


if os.name == "nt":
    import msvcrt

    def _try_lock(f) -> bool:
        try:
            msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            return True
        except OSError:
            return False

    def _unlock(f) -> None:
        f.seek(0)
        msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
else:
    import fcntl

    def _try_lock(f) -> bool:
        try:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            return True
        except OSError:
            return False

    def _unlock(f) -> None:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)


@contextlib.contextmanager
def _stage_lock(stage_id: int, found_dir: Path, timeout: float = 10.0):
    """스테이지별 프로세스 간 잠금 — read-modify-replace 직렬화(codex R1-H1: 병행 학습 2개가
    같은 스테이지를 기록하면 마지막 replace가 상대 갱신을 지움). OS-수준 잠금(msvcrt/fcntl)이라
    프로세스 사망 시 자동 해제 — 락파일 삭제·stale-break가 불필요(삭제-레이스 원천 배제).
    락파일(.solutions.lock)은 잔존하는 무해 아티팩트(gitignore 대상)."""
    lock = found_dir / f"stage{stage_id:02d}.solutions.lock"
    found_dir.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + timeout
    with open(lock, "a+b") as f:
        f.seek(0)
        while not _try_lock(f):
            if time.monotonic() > deadline:
                raise TimeoutError(f"registry lock timeout: {lock.name}")
            time.sleep(0.05)
            f.seek(0)
        try:
            yield
        finally:
            _unlock(f)


def _save(reg: dict, found_dir: Path) -> None:
    p = registry_path(reg["stage_id"], found_dir)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(f"{p.name}.tmp{os.getpid()}")   # 라이터-고유 tmp(공유 tmp 경합 차단)
    tmp.write_text(json.dumps(reg, indent=1, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, p)


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def record_clear(rec: dict, res: dict, found_dir: Path = FOUND_DIR,
                 event: str | None = None) -> str:
    """클리어 해 1건을 레지스트리에 반영. 반환 = "new"(신규 해) / "dup"(중복 — 카운트만 갱신)
    / "reset"(레벨 변경 감지 → 기존 해 파기 후 신규 등록).

    event(선택) = migrate 멱등 원장 키(event_id, codex R21-M3): 지정 시 해별 `events` 목록을
    **락 안에서** 원자 검사 — 이미 등재된 이벤트면 runs/seeds/ts를 일절 갱신하지 않고 "dup"
    반환(반복 이행이 카운트를 오염시키지 않음). 라이브 학습 경로(train.py)는 미지정(매 발견 카운트).

    rec = train.py found 레코드(stage_id/seed/actions/saved/frame/... 포함),
    res = 해당 클리어의 롤아웃 결과(trace 포함 시 실행-동치 키, 아니면 plan_key 폴백).

    동시성/손상 안전(codex R1-H1): load→mutate→replace 전 구간을 스테이지 락으로 직렬화.
    손상 레지스트리는 quarantine(.corrupt-<ts>.json 보존-이동) 후 RegistryCorruptError를 올린다
    — 이번 기록은 실패(호출측 WARN)하되 기존 데이터는 절대 조용히 갈아엎지 않는다. 다음 기록은
    빈 레지스트리에서 재시작(손상본은 복구용 잔존)."""
    sid = int(rec["stage_id"])
    with _stage_lock(sid, found_dir):
        return _record_clear_locked(rec, res, sid, found_dir, event)


def _record_clear_locked(rec: dict, res: dict, sid: int, found_dir: Path,
                         event: str | None = None) -> str:
    cur_digest = level_digest(sid)
    if cur_digest is None:                     # 레벨 정체성 검증 불가 → 기록 거부(R5-M2)
        raise LevelUnverifiableError(
            f"stage{sid:02d} 레벨 digest 산출 불가(레벨 파일 부재?) — 기록 거부")
    try:
        reg = load_registry(sid, found_dir)
    except RegistryCorruptError as exc:
        dst = _quarantine(sid, found_dir)
        raise RegistryCorruptError(
            f"stage{sid:02d} 레지스트리 손상 — "
            f"{'보존-이동 ' + dst.name if dst else '이동 실패(원본 잔존)'}; 이번 기록은 미반영") from exc
    outcome = "new"
    if reg is None or reg.get("level_digest") != cur_digest:   # cur_digest 비-None 보장(위 가드)
        if reg is not None:
            outcome = "reset"  # 레벨 변경 → 기존 해 파기(사용자 계약)
        reg = {"stage_id": sid, "stage": rec.get("stage"), "level_digest": cur_digest,
               "updated": _now(), "solutions": []}

    ed = exec_digest(res)
    pk = plan_key(rec.get("actions") or [])
    seed = rec.get("seed")
    for sol in reg["solutions"]:
        same = (ed is not None and sol.get("exec_digest") == ed) or \
               (ed is None and sol.get("exec_digest") is None and sol.get("plan_key") == pk)
        if same:
            if event is not None and event in (sol.get("events") or []):
                return "dup"                   # 이미 이행된 이벤트(원장 적중) — 무갱신(R21-M3)
            if seed is not None and seed not in sol["seeds"]:
                sol["seeds"].append(seed)
                sol["seeds"].sort()
            sol["runs"] = int(sol.get("runs") or 0) + 1
            sol["last_ts"] = rec.get("ts") or _now()
            if event is not None:
                sol.setdefault("events", []).append(event)
            reg["updated"] = _now()
            _save(reg, found_dir)
            return "dup" if outcome == "new" else outcome

    reg["solutions"].append({
        "exec_digest": ed,
        "plan_key": pk,
        "actions": rec.get("actions") or [],
        "saved": rec.get("saved"), "frame": rec.get("frame"), "hp": rec.get("hp"),
        "seeds": [seed] if seed is not None else [],
        "runs": 1,
        "first_ts": rec.get("ts") or _now(), "last_ts": rec.get("ts") or _now(),
        "grammar": rec.get("grammar"), "episodes": rec.get("episodes"),
        "deadline_frames": rec.get("deadline_frames"),
        "inventory": rec.get("inventory") or {},
        "stage": rec.get("stage"),
        **({"events": [event]} if event is not None else {}),
        # witness-prefix curriculum 출처(2026-07-13, opt-in에서만 rec에 존재): 힌트-유래 해를
        # '순수 RL 발견'과 레지스트리 차원에서 구별(정직 provenance). 무힌트 rec = 키 부재 = 종전 구성.
        **({"hint": dict(rec["hint"])} if rec.get("hint") else {}),
    })
    reg["updated"] = _now()
    _save(reg, found_dir)
    return outcome


# ---------- 레거시 이행 ----------

def migrate(found_dir: Path = FOUND_DIR, stage_max: int = 25) -> None:
    """레거시 *.found.json + log.jsonl (+ replay_cache trace)로 레지스트리 일괄 생성.
    현재 레벨 digest로 스탬프 — '그 해들이 현재 레벨에서 발견됐다'는 전제의 1회 이행 도구.
    replay_cache에 trace가 있으면 실행-동치 키, 없으면 plan_key 폴백."""
    records: list[dict] = []
    for p in sorted(found_dir.glob("*.found.json")):
        try:
            records.append(json.loads(p.read_text(encoding="utf-8")))
        except (json.JSONDecodeError, UnicodeDecodeError, OSError):
            pass
    log = found_dir / "log.jsonl"
    if log.exists():
        # 라인 단위 독립 디코딩(codex R19): 손상 라인만 스킵 — 유효 사이드카/캐시 이행은 계속
        try:
            raw = log.read_bytes()
        except OSError as exc:
            print(f"migrate: WARN log.jsonl 읽기 실패 스킵: {exc}")
            raw = b""
        for bline in raw.splitlines():
            try:
                records.append(json.loads(bline.decode("utf-8")))
            except (json.JSONDecodeError, UnicodeDecodeError):
                pass
    cache_dir = found_dir / "replay_cache"
    # 이벤트 정체성 dedup(codex R20-M2): train.py는 같은 발견을 사이드카+log에 **이중 기재** —
    # 그대로 record_clear에 넘기면 runs가 2배 카운트. event_id(stage,seed,ts,plan_key)로 1회화.
    seen_events: set[str] = set()
    deduped: list[dict] = []
    n_invalid = 0
    for rec in records:
        # 공유 검증기(codex R21-M2): 문자열 seed·비-str ts·bool stage_id·중첩 action 손상이
        # record_clear/정렬/plan_key에 도달하는 것 차단 — 뷰어 _valid_record와 동일 출처
        if not valid_event_record(rec):
            n_invalid += 1
            continue
        ev = event_id(rec)
        if ev in seen_events:
            continue
        seen_events.add(ev)
        deduped.append(rec)
    deduped.sort(key=lambda r: str(r.get("ts", "")))
    if n_invalid:
        print(f"migrate: WARN 구조 위반 레코드 {n_invalid}건 스킵")
    n_new = n_dup = n_skip = 0
    for rec in deduped:
        sid = rec.get("stage_id")
        if not isinstance(sid, int) or not (1 <= sid <= stage_max):
            continue
        # 레지스트리 = "현재 레벨에서 검증된 해"만 — 현재 레벨로 리플레이된 캐시(cleared)가 있는
        # 기록만 이행. 캐시 없는 옛 기록은 스킵(log.jsonl 히스토리에 잔존, 필요 시 --replay 후 재이행).
        # 키 = replay_cache_key(레벨 digest 결속, found_viewer와 단일 출처) — 스키마 개정 전
        # 레거시 키의 캐시는 자동 미스(= 스킵)라 옛 레벨 궤적이 이행에 쓰일 수 없다.
        cpath = cache_dir / f"stage{sid:02d}_{replay_cache_key(rec)}.json"
        if not cpath.exists():
            n_skip += 1
            continue
        try:
            res = json.loads(cpath.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError, OSError):
            n_skip += 1
            continue
        # 공유 검증기(codex R13): error 키/결속 불일치 payload가 권위 해로 승격되는 것 차단
        if not valid_replay_payload(res, cache_binding(sid)) \
                or res.get("cleared") is not True or not res.get("trace"):
            n_skip += 1
            continue
        # 재실행 멱등(codex R20-M2·R21-M3): ts 고수위 대신 **영속 이벤트-원장** — record_clear가
        # 락 안에서 해별 events 목록을 원자 검사(늦게 캐시-적격이 된 이전 이벤트도 유실 없이
        # 카운트, seed 간 혼동 없음). 이미 이행된 이벤트는 무갱신 "dup".
        out = record_clear(rec, res, found_dir, event=event_id(rec))
        if out in ("new", "reset"):
            n_new += 1
        else:
            n_dup += 1
    print(f"migrate: 신규 {n_new} · 중복 흡수 {n_dup} · 스킵(캐시 부재/미클리어) {n_skip}")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--migrate", action="store_true", help="레거시 기록 → 레지스트리 일괄 이행")
    ap.add_argument("--found-dir", type=Path, default=FOUND_DIR)
    args = ap.parse_args()
    if args.migrate:
        migrate(args.found_dir)
    else:
        ap.print_help()
