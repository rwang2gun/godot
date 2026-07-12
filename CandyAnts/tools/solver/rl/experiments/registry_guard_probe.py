#!/usr/bin/env python3
"""§17 사후 codex 리뷰(R1) 수정 회귀 probe — Godot 불요, tmp 디렉터리 격리.

검증 항목(codex R1 next-steps 대응):
  P1  손상 레지스트리: record_clear가 조용히 갈아엎지 않고 quarantine+RegistryCorruptError
      (기존 데이터 보존), 이후 기록은 빈 레지스트리에서 재시작.
  P2  동시성: 병렬 프로세스 N개가 같은 스테이지에 서로 다른 해를 기록해도 유실 0
      (락 직렬화 — read-modify-replace 경합 차단).
  P3  리플레이 캐시 레벨-결속: level digest가 다르면 캐시 키가 달라지고,
      키가 우연히 맞아도 payload _cache 결속 불일치는 미스로 취급.
  P4  스윕 성공 판정: 크래시/집계줄 부재/rc=2는 실패, rc∈{0,1}+집계줄만 성공.
  P5  부분해 최고-진척: 나중의 더 약한 런이 이전 최고를 가리지 못함
      (전-이력 로드 + 스테이지별 리플레이-best 선정).
  P1b parse-valid 손상(R2-H1): JSON은 유효하나 스키마 위반(level_digest 부재 등)도
      quarantine+RegistryCorruptError — '레벨 변경' 오인 파기 차단.
  P4b 레거시 state 재검증(R2-M1): 구버전 러너의 false-done(크래시인데 done=true) 엔트리는
      스킵되지 않고 재시도 대상.
  P5b 클래스-내 리플레이 변별(R2-M2): plan_key가 같은(양자화 동치) 두 raw 플랜의 리플레이가
      다를 때 — 리플레이 선부착 순서라 더 나은 raw 플랜이 클래스 대표가 됨.
  (R3 추가) P1b: 같은 길이 비-hex digest 검출+quarantine·재격리 이름 유일화 /
  P4b: 캠페인 지문(정규화 seeds+RECIPE) 불일치·지문 없는 레거시 엔트리 재시도 /
  P6: 뷰어 파일명↔내용 stage_id 결속(불일치 미표시·covered 미오염).
  (R4 추가) P4b: 스테이지 레벨 digest 결속(변경/산출불가/레거시 무-digest = 재시도) —
  지문에 train.py 소스 sha 포함(트레이너 개정 시 전량 재시도) /
  P6: 숫자 별칭(stage001/099/000) 거부 + canonical 정상 통과.

사용: python tools/solver/rl/experiments/registry_guard_probe.py  (전부 PASS면 exit 0)
"""
from __future__ import annotations

import json
import multiprocessing
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent))   # tools/solver
sys.path.insert(0, str(HERE))                 # experiments (sweep_stages)

import found_viewer                            # noqa: E402
import solution_registry as sr                 # noqa: E402
import sweep_stages                            # noqa: E402

FAILS: list[str] = []


def check(name: str, cond: bool, detail: str = "") -> None:
    print(f"  {'PASS' if cond else 'FAIL'}  {name}" + (f" — {detail}" if detail else ""))
    if not cond:
        FAILS.append(name)


def _rec(seed: int, actions: list | None = None) -> dict:
    return {"stage_id": 99, "stage": "res://scenes/stages/Stage99.tscn", "seed": seed,
            "saved": 5, "frame": 1000 + seed, "hp": 5,
            "actions": actions or [{"skill": "blocker", "target": {"select": "max_x"},
                                    "trigger": {"type": "ant_reaches_x", "cmp": "ge",
                                                "x": 100 + seed * 48}}]}


def _res(seed: int) -> dict:
    return {"cleared": True, "saved": 5, "frame": 1000 + seed,
            "trace": {"0": [[seed, 0]], "1": [[seed, 1]]}}


FAKE_LD = "c" * 16   # 프로브 스테이지 99는 레벨 파일이 없어 digest None → 기록이 fail-closed
#                      거부되므로(R5-M2), 기록 경로 테스트는 digest를 모킹한다.


def _patch_ld():
    orig = sr.level_digest
    sr.level_digest = lambda sid: FAKE_LD      # noqa: E731
    return orig


def p1_corrupt_quarantine() -> None:
    print("P1 손상 레지스트리 quarantine")
    orig = _patch_ld()
    try:
        _p1_body()
    finally:
        sr.level_digest = orig


def _p1_body() -> None:
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        sr.record_clear(_rec(0), _res(0), d)
        p = sr.registry_path(99, d)
        good = p.read_text(encoding="utf-8")
        p.write_text("{truncated", encoding="utf-8")   # 손상 시뮬레이션
        raised = False
        try:
            sr.record_clear(_rec(1), _res(1), d)
        except sr.RegistryCorruptError:
            raised = True
        check("손상 시 RegistryCorruptError", raised)
        corrupts = list(d.glob("*.corrupt-*.json"))
        check("손상본 보존(quarantine)", len(corrupts) == 1 and
              corrupts[0].read_text(encoding="utf-8") == "{truncated")
        check("손상본이 새 레지스트리로 조용히 대체되지 않음", not p.exists())
        # 이후 기록은 빈 레지스트리에서 재시작(신규 등록)
        out = sr.record_clear(_rec(2), _res(2), d)
        reg = json.loads(p.read_text(encoding="utf-8"))
        check("후속 기록 재시작", out == "new" and len(reg["solutions"]) == 1)
        check("원본 해는 quarantine에 잔존", json.loads(good)["solutions"][0]["seeds"] == [0])


def p1b_parse_valid_corruption() -> None:
    print("P1b parse-valid 손상(스키마 위반) quarantine")
    orig = _patch_ld()
    try:
        _p1b_body()
    finally:
        sr.level_digest = orig


def _p1b_body() -> None:
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        sr.record_clear(_rec(0), _res(0), d)
        p = sr.registry_path(99, d)
        reg = json.loads(p.read_text(encoding="utf-8"))
        del reg["level_digest"]                 # 유효 JSON이나 스키마 위반(R2-H1 시나리오)
        p.write_text(json.dumps(reg), encoding="utf-8")
        raised = False
        try:
            sr.record_clear(_rec(1), _res(1), d)
        except sr.RegistryCorruptError:
            raised = True
        check("스키마 위반 시 RegistryCorruptError", raised)
        corrupts = list(d.glob("*.corrupt-*.json"))
        check("손상본 보존 + 기존 해 잔존", len(corrupts) == 1 and
              len(json.loads(corrupts[0].read_text(encoding="utf-8"))["solutions"]) == 1)
        check("'레벨 변경' 오인 파기 없음", not p.exists())
        # 대표 위반 유형 커버: solutions 비-list / stage_id 불일치 / seeds 부재 / 비-hex digest
        check("solutions 비-list 검출",
              sr._schema_error({"stage_id": 99, "level_digest": None, "solutions": "x"}, 99)
              is not None)
        check("stage_id 불일치 검출",
              sr._schema_error({"stage_id": 7, "level_digest": None, "solutions": []}, 99)
              is not None)
        check("seeds 부재 검출",
              sr._schema_error({"stage_id": 99, "level_digest": None,
                                "solutions": [{"plan_key": "0" * 16, "actions": []}]}, 99)
              is not None)
        check("같은 길이 비-hex level_digest 검출(R3-H1)",
              sr._schema_error({"stage_id": 99, "level_digest": "x" * 16, "solutions": []}, 99)
              is not None)
        check("비-hex plan_key 검출",
              sr._schema_error({"stage_id": 99, "level_digest": None,
                                "solutions": [{"plan_key": "KEY!", "actions": [],
                                               "seeds": []}]}, 99) is not None)
        # 비-hex digest가 통과해 '레벨 변경' 오인 파기로 이어지지 않음(quarantine 경로)
        reg2 = {"stage_id": 99, "level_digest": "Z" * 16,
                "solutions": [{"plan_key": "0" * 16, "actions": [], "seeds": [0],
                               "exec_digest": None, "runs": 1}]}
        p.write_text(json.dumps(reg2), encoding="utf-8")
        raised2 = False
        try:
            sr.record_clear(_rec(3), _res(3), d)
        except sr.RegistryCorruptError:
            raised2 = True
        check("비-hex digest → 파기 아닌 quarantine", raised2 and not p.exists())
        check("재격리 시 선행 격리본 보존(이름 유일화)",
              len(list(d.glob("*.corrupt-*.json"))) == 2)
        # 비-UTF8 레지스트리(R17): UnicodeDecodeError도 quarantine 경로
        p.write_bytes(b"\xff\xfe\x00broken")
        raised3 = False
        try:
            sr.record_clear(_rec(4), _res(4), d)
        except sr.RegistryCorruptError:
            raised3 = True
        check("비-UTF8 레지스트리 → quarantine+RegistryCorruptError",
              raised3 and not p.exists() and len(list(d.glob("*.corrupt-*.json"))) == 3)
        out3 = sr.record_clear(_rec(5), _res(5), d)
        check("비-UTF8 격리 후 후속 기록 재시작", out3 == "new" and p.exists())


def _worker(args: tuple) -> None:
    d, seed = args
    sr.level_digest = lambda sid: FAKE_LD      # noqa: E731 — spawn 워커별 재적용
    sr.record_clear(_rec(seed), _res(seed), Path(d))


def p2_concurrency() -> None:
    print("P2 병렬 기록 유실 0 (락 직렬화)")
    with tempfile.TemporaryDirectory() as td:
        n = 8
        with multiprocessing.Pool(4) as pool:
            pool.map(_worker, [(td, s) for s in range(n)])
        reg = json.loads(sr.registry_path(99, Path(td)).read_text(encoding="utf-8"))
        sols = reg["solutions"]
        check(f"해 {n}개 전부 존재", len(sols) == n, f"got {len(sols)}")
        check("runs 총합 일치", sum(s["runs"] for s in sols) == n)
        # OS-수준 잠금: 락파일 잔존은 정상(자동 해제) — 부분쓰기 tmp 잔존만 없어야 함
        check("tmp 잔존 없음", not list(Path(td).glob("*.tmp*")))


def p3_cache_binding() -> None:
    print("P3 리플레이 캐시 레벨-결속")
    rec = _rec(0)
    orig = sr.level_digest
    try:
        sr.level_digest = lambda sid: "digestAAAA"      # noqa: E731
        key_a = sr.replay_cache_key(rec)
        bind_a = found_viewer._cache_binding(rec)
        sr.level_digest = lambda sid: "digestBBBB"      # noqa: E731
        key_b = sr.replay_cache_key(rec)
        check("digest 변경 → 캐시 키 변경", key_a != key_b)
        # 키가 우연히 맞아도 payload 결속 불일치 = 미스
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            cache = d / "replay_cache"
            cache.mkdir()
            stale = {"cleared": False, "saved": 1, "_cache": bind_a}   # A레벨 산출물
            (cache / f"stage99_{sr.replay_cache_key(rec)}.json").write_text(
                json.dumps(stale), encoding="utf-8")
            r = dict(rec)
            found_viewer.attach_replays([r], d, do_replay=False)       # 현재 digest=B
            check("결속 불일치 캐시는 미스", "_replay" not in r)
            fresh = {"cleared": False, "saved": 2, "_cache": found_viewer._cache_binding(rec)}
            (cache / f"stage99_{sr.replay_cache_key(rec)}.json").write_text(
                json.dumps(fresh), encoding="utf-8")
            r2 = dict(rec)
            found_viewer.attach_replays([r2], d, do_replay=False)
            check("결속 일치 캐시는 히트", (r2.get("_replay") or {}).get("saved") == 2)
    finally:
        sr.level_digest = orig


def p4_sweep_outcome() -> None:
    print("P4 스윕 성공 판정")
    check("완주+클리어(rc=0)", sweep_stages.run_ok(0, "=== 집계: 3/3 seed 클리어 ..."))
    check("완주+무클리어(rc=1)", sweep_stages.run_ok(1, "=== 집계: 0/3 seed 클리어 ..."))
    check("설정오류(rc=2) 거부", not sweep_stages.run_ok(2, "=== 집계: ..."))
    check("크래시(집계줄 부재) 거부", not sweep_stages.run_ok(1, "Traceback (most recent...)"))
    check("빈 로그 거부", not sweep_stages.run_ok(0, ""))


def p4b_legacy_state() -> None:
    print("P4b 레거시 state 재검증 + 캠페인 지문·레벨 digest 결속")
    fp = sweep_stages.campaign_fingerprint("0,1,2")
    ld = "a" * 16
    good = {"done": True, "rc": 1, "summary": "=== 집계: 0/3 ...", "fingerprint": fp,
            "level_digest": ld}
    crash_done = dict(good, summary="Traceback (most recent call last): ...")
    check("false-done(크래시) 엔트리 재시도", not sweep_stages.state_entry_ok(crash_done, fp, ld))
    check("정상 완주 엔트리 스킵 유지", sweep_stages.state_entry_ok(good, fp, ld))
    check("필드 결손 엔트리 재시도", not sweep_stages.state_entry_ok({"done": True}, fp, ld))
    check("done=false 재시도", not sweep_stages.state_entry_ok(dict(good, done=False), fp, ld))
    # R3-M2: seeds/레시피/트레이너 결속
    check("지문 없는 레거시 엔트리 재시도", not sweep_stages.state_entry_ok(
        {"done": True, "rc": 1, "summary": "=== 집계: 0/3 ...", "level_digest": ld}, fp, ld))
    fp_seed0 = sweep_stages.campaign_fingerprint("0")
    check("seeds 변경(0→0,1,2) 시 재시도", not sweep_stages.state_entry_ok(
        dict(good, fingerprint=fp_seed0), fp, ld))
    check("seeds 순서/중복 정규화(0,1,2==2,1,0,0)",
          sweep_stages.campaign_fingerprint("2,1,0,0") == fp)
    # R4-M1: 스테이지 콘텐츠 결속
    check("레벨 digest 변경 시 재시도", not sweep_stages.state_entry_ok(good, fp, "b" * 16))
    check("레벨 digest 산출 불가(None) 시 스킵 불가",
          not sweep_stages.state_entry_ok(good, fp, None))
    check("엔트리에 digest 없는 레거시 재시도", not sweep_stages.state_entry_ok(
        {k: v for k, v in good.items() if k != "level_digest"}, fp, ld))


def p6_viewer_filename_binding() -> None:
    print("P6 뷰어 파일명↔내용 stage_id 결속(R3-M1)")
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        # stage01 파일에 stage_id=2 내용 — 스킵돼야 하고 covered에 2가 오염되면 안 됨
        reg = {"stage_id": 2, "stage": "res://scenes/stages/Stage02.tscn",
               "level_digest": None, "updated": "", "solutions": []}
        (d / "stage01.solutions.json").write_text(json.dumps(reg), encoding="utf-8")
        (d / "weird.solutions.json").write_text(json.dumps(reg), encoding="utf-8")
        # R4-M2: 숫자 별칭(비-canonical 0패딩)도 covered 오염 금지
        for alias, sid in (("stage001", 1), ("stage099", 99), ("stage000", 0)):
            areg = {"stage_id": sid, "stage": f"res://scenes/stages/Stage{sid:02d}.tscn",
                    "level_digest": None, "updated": "", "solutions": []}
            (d / f"{alias}.solutions.json").write_text(json.dumps(areg), encoding="utf-8")
        # 비-UTF8 canonical 레지스트리(R18): 뷰어가 크래시 없이 warn-skip
        (d / "stage02.solutions.json").write_bytes(b"\xff\xfe\x00broken")
        recs, covered, stale = found_viewer.load_registries(d, None)
        check("불일치·별칭·비-UTF8 레지스트리 미표시(크래시 없음)", not recs)
        check("covered 미오염", not covered and not stale)
        # 비-UTF8 jsonl 라인(R19): 손상 라인만 스킵, 유효 레코드 생존(전체 로더 생존)
        valid_line = json.dumps({"stage_id": 3, "seed": 0, "ts": "t1", "actions": []})
        (d / "log.jsonl").write_bytes(b"\xff\xfebroken\n" + valid_line.encode("utf-8") + b"\n")
        (d / "partials.jsonl").write_bytes(b"\xff\xfebroken\n" + valid_line.encode("utf-8") + b"\n")
        check("손상 log.jsonl 라인 스킵 + 유효 레코드 생존",
              len(found_viewer.load_found(d)) == 1)
        check("손상 partials.jsonl 라인 스킵 + 유효 레코드 생존",
              len(found_viewer.load_partials(d)) == 1)
        # parse-valid 구조 위반 라인(R20-M1): null/[]/스칼라/비-int stage_id/비-list actions
        bad_lines = ["null", "[]", "1", json.dumps({"stage_id": "abc"}),
                     json.dumps({"stage_id": 3, "actions": "x"}),
                     json.dumps({"stage_id": 3, "actions": [1, 2]}),
                     # R21-M1: 중첩 action 손상(스칼라 target / 비수치 frame / 스칼라 trigger)
                     json.dumps({"stage_id": 3, "actions": [{"target": 1}]}),
                     json.dumps({"stage_id": 3, "actions": [
                         {"trigger": {"type": "at_frame", "frame": "abc"}}]}),
                     json.dumps({"stage_id": 3, "actions": [{"trigger": 5}]}),
                     # R21-M2 유형: bool stage_id / 문자열 seed / 비-str ts
                     json.dumps({"stage_id": True, "actions": []}),
                     json.dumps({"stage_id": 3, "seed": "0", "actions": []}),
                     json.dumps({"stage_id": 3, "ts": 123, "actions": []})]
        (d / "log.jsonl").write_text("\n".join(bad_lines + [valid_line]) + "\n",
                                     encoding="utf-8")
        check("구조 위반 라인 전부 스킵 + 유효 생존(크래시 없음)",
              len(found_viewer.load_found(d)) == 1)
        # canonical 이름 + 실제 현재 digest는 정상 통과(별칭 거부가 정상 경로를 깨지 않음)
        real_ld = sr.level_digest(1)           # 실 repo stage01 파일 기준
        okreg = {"stage_id": 1, "stage": "res://scenes/stages/Stage01.tscn",
                 "level_digest": real_ld, "updated": "", "solutions": []}
        (d / "stage01.solutions.json").write_text(json.dumps(okreg), encoding="utf-8")
        recs2, covered2, stale2 = found_viewer.load_registries(d, None)
        check("canonical 정상 통과", covered2 == {1} and not stale2)


def p7_unverifiable_fail_closed() -> None:
    print("P7 레벨 digest 검증-불가 fail-closed(R5-M2)")
    # ① 기록: 현재 digest 산출 불가(레벨 파일 부재 = stage 99 실경로) → 기록 거부·레지스트리 미생성
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        raised = False
        try:
            sr.record_clear(_rec(0), _res(0), d)   # 모킹 없음 → level_digest(99)=None
        except sr.LevelUnverifiableError:
            raised = True
        check("digest None 기록 거부", raised)
        check("레지스트리 미생성(오염 없음)", not sr.registry_path(99, d).exists())
    # ② 뷰어: 저장 digest None 레지스트리 = 검증-불가 → stale 처리(해 미표시)
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        reg = {"stage_id": 1, "stage": "res://scenes/stages/Stage01.tscn",
               "level_digest": None, "updated": "",
               "solutions": [{"plan_key": "0" * 16, "actions": [], "seeds": [0],
                              "exec_digest": None, "runs": 1}]}
        (d / "stage01.solutions.json").write_text(json.dumps(reg), encoding="utf-8")
        recs, covered, stale = found_viewer.load_registries(d, None)
        check("저장 digest None → 미표시+파기-대기 표기", not recs and stale == {1})
    # ③ 캐시: 현재 digest None 레코드는 캐시 읽기/쓰기 생략(None==None 우연 일치 차단)
    orig = sr.level_digest
    try:
        sr.level_digest = lambda sid: None      # noqa: E731
        rec = _rec(0)
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            cache = d / "replay_cache"
            cache.mkdir()
            stale_payload = {"cleared": True, "saved": 9,
                             "_cache": {"schema": sr.REPLAY_CACHE_SCHEMA, "level_digest": None}}
            (cache / f"stage99_{sr.replay_cache_key(rec)}.json").write_text(
                json.dumps(stale_payload), encoding="utf-8")
            r = dict(rec)
            found_viewer.attach_replays([r], d, do_replay=False)
            check("digest None 캐시 미사용(None==None 불인정)", "_replay" not in r)
    finally:
        sr.level_digest = orig
    # ④ partial: 저장/현재 digest 부재 = 제외 — main 내부 클로저라 동작 근사(_partial_level_ok
    #    로직과 동일 조건)를 직접 검증하는 대신 뷰어 전체 빌드에서 배제됨을 스모크로 확인 생략
    #    (①~③이 기록·표시·캐시 3면을 커버).


def p5b_same_class_replay_divergence() -> None:
    print("P5b 클래스-내 리플레이 변별(리플레이 선부착)")
    plan_a = [{"skill": "blocker", "target": {"select": "max_x"},
               "trigger": {"type": "at_frame", "frame": 60}}]    # 60//60=1 버킷
    plan_b = [{"skill": "blocker", "target": {"select": "max_x"},
               "trigger": {"type": "at_frame", "frame": 119}}]   # 119//60=1 → 동일 plan_key
    assert sr.plan_key(plan_a) == sr.plan_key(plan_b), "전제: 양자화 동치"
    base = {"stage_id": 7, "stage": "res://scenes/stages/Stage07.tscn"}
    rec_a = dict(base, seed=0, ts="2026-07-12T01:00:00Z", best_reward=5.0, actions=plan_a)
    rec_b = dict(base, seed=1, ts="2026-07-12T02:00:00Z", best_reward=0.1, actions=plan_b)
    orig = sr.level_digest
    try:
        sr.level_digest = lambda sid: "digestCCCC"      # noqa: E731
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            cache = d / "replay_cache"
            cache.mkdir()
            for rec, saved in ((rec_a, 0), (rec_b, 3)):  # B가 리플레이 우위(보상은 A 우위)
                res = {"cleared": False, "saved": saved, "picked_total": saved,
                       "_cache": found_viewer._cache_binding(rec)}
                (cache / f"stage07_{sr.replay_cache_key(rec)}.json").write_text(
                    json.dumps(res), encoding="utf-8")
            recs = [rec_a, rec_b]
            found_viewer.attach_replays(recs, d, do_replay=False)   # main과 동일: 부착 선행
            groups = found_viewer.dedup_by_class(recs, found_viewer._partial_better)
            check("동일 클래스 1그룹", len(groups) == 1)
            check("대표 = 리플레이 우위 raw 플랜(보상 열위여도)",
                  groups and groups[0]["ts"] == rec_b["ts"],
                  f"picked {groups[0]['ts'] if groups else 'none'}")
    finally:
        sr.level_digest = orig


def p5_partial_best() -> None:
    print("P5 부분해 최고-진척 보존")
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        older_better = {"stage_id": 7, "seed": 0, "ts": "2026-07-10T00:00:00Z",
                        "best_reward": 2.0, "actions": _rec(0)["actions"],
                        "stage": "res://scenes/stages/Stage07.tscn"}
        newer_weaker = {"stage_id": 7, "seed": 0, "ts": "2026-07-12T00:00:00Z",
                        "best_reward": 0.5, "actions": _rec(1)["actions"],
                        "stage": "res://scenes/stages/Stage07.tscn"}
        with open(d / "partials.jsonl", "w", encoding="utf-8") as f:
            f.write(json.dumps(older_better) + "\n" + json.dumps(newer_weaker) + "\n")
        # 사이드카 = 최신 런 스냅샷(약한 런이 덮어씀) — 그래도 이력에서 최고가 선정돼야 함
        (d / "stage07_seed0.partial.json").write_text(json.dumps(newer_weaker),
                                                      encoding="utf-8")
        recs = found_viewer.load_partials(d)
        check("전 이력 로드(최신-only 아님)", len(recs) == 2, f"got {len(recs)}")
        groups = found_viewer.dedup_by_class(recs, found_viewer._partial_better)
        # 리플레이 지표 부여(older가 실제 진척 우위) 후 스테이지 대표 선정
        for g in groups:
            g["_replay"] = ({"saved": 3, "picked_total": 5}
                            if g["ts"] == older_better["ts"] else
                            {"saved": 0, "picked_total": 1})
        best = found_viewer._best_per_stage(groups, found_viewer._partial_better)
        check("스테이지 대표 = 이전의 더 강한 진척", len(best) == 1 and
              best[0]["ts"] == older_better["ts"])


def p9_runtime_digest_binding() -> None:
    print("P9 엔진 runtime digest 결속(R6)")
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        (root / "scripts" / "core").mkdir(parents=True)
        (root / "scenes" / "stages").mkdir(parents=True)
        gd = root / "scripts" / "core" / "StageRunner.gd"
        gd.write_text("extends Node\n", encoding="utf-8")
        (root / "project.godot").write_text("[application]\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d1 = sr.runtime_digest(root)
        # 게임플레이 스크립트 변경(.tscn 무변경) → digest 변경
        gd.write_text("extends Node\nvar changed = true\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d2 = sr.runtime_digest(root)
        check("게임플레이 .gd 변경 → runtime digest 변경", d1 != d2)
        # per-stage 씬 변경은 runtime digest 불변(level_digest 담당 영역)
        (root / "scenes" / "stages" / "Stage01.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d3 = sr.runtime_digest(root)
        check("scenes/stages 변경은 runtime digest 불변(level_digest 소관)", d3 == d2)
        # 리플레이 하니스 변경(R7): 뷰어 리플레이 경로(PlanReplayHarness)도 결속
        (root / "tests").mkdir()
        (root / "tests" / "PlanReplayHarness.gd").write_text("extends Node\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d4 = sr.runtime_digest(root)
        check("PlanReplayHarness.gd 추가/변경 → runtime digest 변경", d4 != d3)
        (root / "tests" / "PlanReplayHarness.tscn").write_text("[gd_scene]\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d5 = sr.runtime_digest(root)
        check("PlanReplayHarness.tscn 변경 → runtime digest 변경", d5 != d4)
        # 리플레이 파이썬 스택(R8): solve.py / run_test.py 변경도 결속
        (root / "tools" / "solver").mkdir(parents=True)
        (root / "tools" / "solver" / "solve.py").write_text("# v1\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d6 = sr.runtime_digest(root)
        check("solve.py 변경 → runtime digest 변경", d6 != d5)
        (root / "scripts" / "run_test.py").write_text("# v1\n", encoding="utf-8")
        sr._RUNTIME_DIGEST_CACHE.clear()
        d7 = sr.runtime_digest(root)
        check("run_test.py 변경 → runtime digest 변경", d7 != d6)
        # 같은-경로 엔진 교체(R10-H2): 바이너리 내용이 identity에 결속
        sr._godot_identity()                   # run_test 선-import 보장
        import run_test
        fake_godot = root / "godot.exe"
        fake_godot.write_bytes(b"ENGINE-V1")
        orig_fg = run_test.find_godot
        try:
            run_test.find_godot = lambda: str(fake_godot)
            sr._GODOT_IDENTITY_CACHE.clear()
            sr._RUNTIME_DIGEST_CACHE.clear()
            g1 = sr.runtime_digest(root)
            fake_godot.write_bytes(b"ENGINE-V2")   # 경로 불변·내용만 교체
            sr._GODOT_IDENTITY_CACHE.clear()
            sr._RUNTIME_DIGEST_CACHE.clear()
            check("같은 경로 엔진 교체 → runtime digest 변경", sr.runtime_digest(root) != g1)
        finally:
            run_test.find_godot = orig_fg
            sr._GODOT_IDENTITY_CACHE.clear()
            sr._RUNTIME_DIGEST_CACHE.clear()
    # 엔진 부재(R9): find_godot의 sys.exit(SystemExit)가 오프라인 빌드를 죽이지 않아야 함
    sr._godot_identity()                       # run_test 선-import 보장(패치 대상 확보)
    import run_test
    orig_fg = run_test.find_godot
    try:
        def _exit(*a, **k):
            raise SystemExit(1)
        run_test.find_godot = _exit
        sr._GODOT_IDENTITY_CACHE.clear()
        check("Godot 해석 불가(SystemExit) → identity None(오프라인 생존)",
              sr._godot_identity() is None)
    finally:
        run_test.find_godot = orig_fg
        sr._GODOT_IDENTITY_CACHE.clear()
    # 캐시 키·스윕 지문이 runtime digest에 결속(변경 → 전량 무효화)
    rec = _rec(0)
    orig = sr.runtime_digest
    try:
        sr.runtime_digest = lambda root=None: "d" * 16    # noqa: E731
        k1 = sr.replay_cache_key(rec)
        f1 = sweep_stages.campaign_fingerprint("0,1,2")
        sr.runtime_digest = lambda root=None: "e" * 16    # noqa: E731
        check("runtime 변경 → 캐시 키 변경", sr.replay_cache_key(rec) != k1)
        check("runtime 변경 → 스윕 지문 변경",
              sweep_stages.campaign_fingerprint("0,1,2") != f1)
        # 옛 runtime으로 쓰인 캐시 payload는 키가 우연히 맞아도 결속 불일치 = 미스(R8 negative)
        orig_ld = sr.level_digest
        try:
            sr.level_digest = lambda sid: "f" * 16        # noqa: E731
            with tempfile.TemporaryDirectory() as td:
                d = Path(td)
                cache = d / "replay_cache"
                cache.mkdir()
                old_binding = {"schema": sr.REPLAY_CACHE_SCHEMA,
                               "level_digest": "f" * 16, "runtime_digest": "d" * 16}
                stale = {"cleared": True, "saved": 9, "_cache": old_binding}
                (cache / f"stage99_{sr.replay_cache_key(rec)}.json").write_text(
                    json.dumps(stale), encoding="utf-8")   # 현재 runtime="e"*16 키로 저장 강제
                r = dict(rec)
                found_viewer.attach_replays([r], d, do_replay=False)
                check("옛 runtime payload = 캐시 미스", "_replay" not in r)
        finally:
            sr.level_digest = orig_ld
    finally:
        sr.runtime_digest = orig


def p8_persist_failure_escalation() -> None:
    print("P8 영속화 실패 → rc=3 격상(R5-H1)")
    sys.path.insert(0, str(HERE.parent))       # tools/solver/rl — train.py
    import types
    import train                                # noqa: E402 (torch 등 무거운 import — P8 한정)
    train._PERSIST_FAILURES.clear()
    check("실패 없음 → rc 0/1 유지",
          train._final_rc(True) == 0 and train._final_rc(False) == 1)
    # 주입: 레지스트리 기록 실패 → _record_found가 삼키되 회계에 남김
    orig = sr.record_clear
    try:
        def _boom(*a, **k):
            raise OSError("injected registry write failure")
        sr.record_clear = _boom
        mdp_stub = types.SimpleNamespace(stage_id=99, stage_scene="res://x.tscn", hp=5,
                                         inventory={}, grammar_version="r2.1")
        train._record_found(mdp_stub, 0, [], {}, {"replay_deadline": 4500}, False, 1)
    finally:
        sr.record_clear = orig
    check("기록 실패가 회계에 적재", len(train._PERSIST_FAILURES) == 1)
    check("실패 시 rc=3(클리어 통과여도)", train._final_rc(True) == 3)
    check("스윕이 rc=3 거부(재시도)", not sweep_stages.run_ok(3, "=== 집계: 3/3 ..."))
    train._PERSIST_FAILURES.clear()


def p10_replay_failed_display() -> None:
    print("P10 현행-런타임 리플레이 실패 해 표시(R10-H1)")
    base = {"stage_id": 11, "stage": "res://scenes/stages/Stage11.tscn", "saved": 4,
            "frame": 1342, "hp": 4, "actions": [], "episodes": 10, "grammar": "r2.1",
            "seeds": [0], "_seeds": {0}, "_runs": 1, "ts": "2026-07-12T00:00:00Z"}
    ok = dict(base, _replay={"cleared": True, "saved": 4, "frame": 1342})
    bad = dict(base, _replay={"cleared": False, "saved": 1, "frame": 500})
    unv = dict(base)                            # _replay 부재 = 캐시 무효화 직후(R14-H1)
    card_ok = found_viewer._card(ok, cleared=True)
    card_bad = found_viewer._card(bad, cleared=True)
    card_unv = found_viewer._card(unv, cleared=True)
    check("리플레이 성공 해 = 클리어 배지·현행 집계 포함",
          'badge full' in card_ok and 'data-cleared="true"' in card_ok)
    check("리플레이 실패 해 = stale 배지·현행 집계 제외",
          'badge stale' in card_bad and 'data-cleared="false"' in card_bad)
    check("리플레이 실패 해 = 현행 실측값 표시(저장값 아님)",
          '>1</span>' in card_bad.split('class="score"')[1][:200])
    check("리플레이 부재 해 = 미검증 배지·현행 집계 제외(클리어 위장 금지)",
          'badge unverified' in card_unv and 'data-cleared="false"' in card_unv)
    # 4-상태 필터 모델(R15-M1): failed/unverified가 '미클리어(partial)'로 오분류 금지
    card_part = found_viewer._card(dict(base, best_reward=1.0), cleared=False)
    check("data-state 4-상태 정확 부여",
          'data-state="verified-clear"' in card_ok and 'data-state="failed"' in card_bad
          and 'data-state="unverified"' in card_unv and 'data-state="partial"' in card_part)
    html_out = found_viewer.render([ok, bad, unv], [])
    check("요약 집계 = 검증-클리어만 + 실패·미검증 명시 표기",
          "고유 해(검증) 1개" in html_out and "리플레이 실패 1개" in html_out
          and "미검증 1개" in html_out)
    check("필터 = data-state 정확 매칭 + 요주의 분리(불리언 필터 은퇴)",
          "s === f" in html_out and 'data-filter="attention"' in html_out
          and "dataset.cleared" not in html_out)


def p11_transient_replay_error() -> None:
    print("P11 일시 리플레이 오류 미캐시·재시도(R11)")
    import solve
    calls = {"n": 0}

    def fake_run_plan(*a, **k):
        calls["n"] += 1
        if calls["n"] == 1:
            return {"error": "no SOLVER_RESULT"}           # 1회차 = 인프라 오류(문자열)
        if calls["n"] == 2:
            return {"error": None, "cleared": True}        # 2회차 = null-값 error 키(R12)
        return {"cleared": True, "saved": 4, "frame": 1000}  # 3회차 = 정상 verdict

    orig_rp, orig_ld = solve.run_plan, sr.level_digest
    try:
        solve.run_plan = fake_run_plan
        sr.level_digest = lambda sid: "a" * 16             # noqa: E731 — 결속 검증 가능화
        rec = _rec(0)
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            def _no_cache() -> bool:
                c = d / "replay_cache"
                return not (c.exists() and list(c.glob("*.json")))

            r1 = dict(rec)
            found_viewer.attach_replays([r1], d, do_replay=True)
            check("오류 응답 = 부착 안 함", "_replay" not in r1)
            check("오류 응답 = 캐시 미저장", _no_cache())
            r2 = dict(rec)
            found_viewer.attach_replays([r2], d, do_replay=True)   # 2회차 = error:null(R12)
            check("null-값 error 키도 부착 안 함", calls["n"] == 2 and "_replay" not in r2)
            check("null-값 error 키도 캐시 미저장", _no_cache())
            r3 = dict(rec)
            found_viewer.attach_replays([r3], d, do_replay=True)
            check("다음 --replay가 재시도(재호출)", calls["n"] == 3)
            check("정상 verdict = 부착+캐시", (r3.get("_replay") or {}).get("cleared") is True
                  and len(list((d / "replay_cache").glob("*.json"))) == 1)
            # 오염된 캐시(error:null 잔존물) 방어: 읽기 가드가 키-존재로 거부 → 재시도
            cpath = next((d / "replay_cache").glob("*.json"))
            poisoned = {"error": None, "cleared": True,
                        "_cache": found_viewer._cache_binding(rec)}
            cpath.write_text(json.dumps(poisoned), encoding="utf-8")
            r4 = dict(rec)
            found_viewer.attach_replays([r4], d, do_replay=True)
            check("오염 캐시(error:null) 불인정 + 재시도", calls["n"] == 4
                  and (r4.get("_replay") or {}).get("cleared") is True)
    finally:
        solve.run_plan = orig_rp
        sr.level_digest = orig_ld


def p12_migration_poisoned_cache() -> None:
    print("P12 migrate 오염-캐시 거부(R13 공유 검증기)")
    orig = _patch_ld()
    try:
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            cache = d / "replay_cache"
            cache.mkdir(parents=True)
            rec = _rec(0)
            rec["ts"] = "2026-07-12T00:00:00Z"
            rec["deadline_frames"] = 6000
            (d / "stage99_seed0.found.json").write_text(json.dumps(rec), encoding="utf-8")
            binding = sr.cache_binding(99)
            good_trace = {"0": [[0, 0]]}
            poisoned = {"error": None, "cleared": True, "trace": good_trace,
                        "saved": 5, "frame": 1000, "_cache": binding}
            ck = sr.replay_cache_key(rec)
            cpath = cache / f"stage99_{ck}.json"
            cpath.write_text(json.dumps(poisoned), encoding="utf-8")
            sr.migrate(d, stage_max=99)         # error:null payload → 스킵돼야 함
            check("오염 payload(error:null) 승격 차단", not sr.registry_path(99, d).exists())
            binding_mismatch = {"cleared": True, "trace": good_trace, "saved": 5,
                                "frame": 1000, "_cache": dict(binding, runtime_digest="x" * 16)}
            cpath.write_text(json.dumps(binding_mismatch), encoding="utf-8")
            sr.migrate(d, stage_max=99)
            check("결속 불일치 payload 승격 차단", not sr.registry_path(99, d).exists())
            valid = {"cleared": True, "trace": good_trace, "saved": 5, "frame": 1000,
                     "_cache": binding}
            cpath.write_text(json.dumps(valid), encoding="utf-8")
            # 손상 log(비-UTF8) + **이중 기재**(같은 이벤트가 사이드카와 log 양쪽) 공존(R19·R20)
            (d / "log.jsonl").write_bytes(b"\xff\xfebroken-line\n"
                                          + json.dumps(rec).encode("utf-8") + b"\n")
            sr.migrate(d, stage_max=99)
            regp = sr.registry_path(99, d)
            check("유효 payload는 정상 이행(손상 log 공존에도)", regp.exists())
            reg1 = json.loads(regp.read_text(encoding="utf-8"))
            check("이중 기재(사이드카+log) = 1회 카운트",
                  len(reg1["solutions"]) == 1 and reg1["solutions"][0]["runs"] == 1)
            sr.migrate(d, stage_max=99)          # 재실행 멱등(R20-M2)
            reg2 = json.loads(regp.read_text(encoding="utf-8"))
            check("migrate 재실행 = runs 불변(멱등)",
                  reg2["solutions"][0]["runs"] == 1 and
                  reg2["solutions"][0]["seeds"] == reg1["solutions"][0]["seeds"])
            # R21-M2: 타입 손상 레코드(문자열 seed·bool stage_id·비-str ts)는 이행 전 거부
            bad_recs = [dict(rec, seed="0"), dict(rec, stage_id=True), dict(rec, ts=123)]
            (d / "log.jsonl").write_bytes(
                b"\n".join(json.dumps(r).encode("utf-8") for r in bad_recs) + b"\n")
            sr.migrate(d, stage_max=99)
            reg3 = json.loads(regp.read_text(encoding="utf-8"))
            check("타입 손상 레코드 이행 거부(runs·seeds 불변)",
                  reg3["solutions"][0]["runs"] == 1 and
                  reg3["solutions"][0]["seeds"] == reg1["solutions"][0]["seeds"])
            # R21-M3: 늦게 캐시-적격이 된 **이전** 실행-동치 이벤트(다른 plan_key, 같은 trace)가
            # ts 고수위에 유실되지 않고 원장으로 회수됨
            rec_old = dict(rec, ts="2026-07-11T00:00:00Z",
                           actions=[{"skill": "blocker", "target": {"select": "max_x"},
                                     "trigger": {"type": "ant_reaches_x", "cmp": "ge",
                                                 "x": 148}}])   # 다른 plan_key
            assert sr.plan_key(rec_old["actions"]) != sr.plan_key(rec["actions"])
            (d / "log.jsonl").write_bytes(json.dumps(rec_old).encode("utf-8") + b"\n")
            sr.migrate(d, stage_max=99)          # 캐시 없음 → 아직 스킵
            reg4 = json.loads(regp.read_text(encoding="utf-8"))
            check("캐시-부재 이전 이벤트는 아직 미이행", reg4["solutions"][0]["runs"] == 1)
            old_res = dict(valid)                # 같은 trace = 같은 exec_digest(실행-동치)
            (cache / f"stage99_{sr.replay_cache_key(rec_old)}.json").write_text(
                json.dumps(old_res), encoding="utf-8")
            sr.migrate(d, stage_max=99)          # 이제 적격 → 원장에 없으므로 카운트
            reg5 = json.loads(regp.read_text(encoding="utf-8"))
            check("늦은-캐시 이전 이벤트 회수(runs 1→2, 해는 1개 유지)",
                  len(reg5["solutions"]) == 1 and reg5["solutions"][0]["runs"] == 2
                  and len(reg5["solutions"][0].get("events") or []) == 2)
            sr.migrate(d, stage_max=99)          # 재실행 멱등 재확인
            reg6 = json.loads(regp.read_text(encoding="utf-8"))
            check("원장 멱등 유지(runs 불변)", reg6["solutions"][0]["runs"] == 2)
            # R22: 같은 초·같은 plan_key(양자화 동치)·다른 raw actions = 별개 이벤트로 이행
            twin_a = dict(rec, ts="2026-07-12T09:00:00Z",
                          actions=[{"skill": "blocker", "target": {"select": "max_x"},
                                    "trigger": {"type": "at_frame", "frame": 60}}])
            twin_b = dict(twin_a,
                          actions=[{"skill": "blocker", "target": {"select": "max_x"},
                                    "trigger": {"type": "at_frame", "frame": 119}}])
            assert sr.plan_key(twin_a["actions"]) == sr.plan_key(twin_b["actions"])
            check("무손실 event_id = 충돌 없음", sr.event_id(twin_a) != sr.event_id(twin_b))
            res_a = {"cleared": True, "saved": 5, "frame": 2000,
                     "trace": {"0": [[7, 0]]}, "_cache": binding}
            res_b = {"cleared": True, "saved": 5, "frame": 2100,
                     "trace": {"0": [[8, 0]]}, "_cache": binding}   # 다른 trace = 별개 해
            for tw, r in ((twin_a, res_a), (twin_b, res_b)):
                (cache / f"stage99_{sr.replay_cache_key(tw)}.json").write_text(
                    json.dumps(r), encoding="utf-8")
            (d / "log.jsonl").write_bytes(
                json.dumps(twin_a).encode("utf-8") + b"\n"
                + json.dumps(twin_b).encode("utf-8") + b"\n")
            sr.migrate(d, stage_max=99)
            reg7 = json.loads(regp.read_text(encoding="utf-8"))
            check("같은 초 쌍둥이 이벤트 모두 이행(해 1→3)", len(reg7["solutions"]) == 3)
            # v2 레코드: train.py 부여 고유 event가 그대로 원장 키(SoT)
            check("부여된 event ID 패스스루",
                  sr.event_id({"event": "ab12cd34ef56ab78"}) == "ab12cd34ef56ab78")
    finally:
        sr.level_digest = orig
        sr._RUNTIME_DIGEST_CACHE.clear()


def p13_sweep_state_durability() -> None:
    print("P13 스윕 state 내구성(R15-M2)")
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        state_p = d / "sweep_state.json"
        # ① 손상 state = quarantine 보존 + 빈 state 재시작(기동 좌초 금지)
        state_p.write_text('{"stage01": {"done"', encoding="utf-8")   # 중단된 쓰기 시뮬레이션
        st = sweep_stages._load_state(state_p)
        check("손상 state → 빈 state 재시작", st == {})
        check("손상본 quarantine 보존", len(list(d.glob("sweep_state.corrupt-*.json"))) == 1)
        # ② 원자적 저장(부분쓰기 tmp 잔존 없음) + 라운드트립
        sweep_stages._save_state(state_p, {"stage01": {"done": True}})
        check("원자 저장 라운드트립", sweep_stages._load_state(state_p) == {"stage01": {"done": True}})
        check("tmp 잔존 없음", not list(d.glob("*.tmp*")))
        # ①b 비-UTF8 손상(R16): read_text의 UnicodeDecodeError도 quarantine 경로
        state_p.unlink()
        state_p.write_bytes(b"\xff\xfe\x00invalid")
        st_b = sweep_stages._load_state(state_p)
        check("비-UTF8 state → 빈 state 재시작", st_b == {})
        check("비-UTF8 손상본도 quarantine", len(list(d.glob("sweep_state.corrupt-*.json"))) >= 2)
        # ①c parse-valid 구조 위반(R16): null 엔트리·비수치 attempts가 기동을 못 죽임
        fp = sweep_stages.campaign_fingerprint("0,1,2")
        check("null 엔트리 = 재시도(크래시 없음)",
              not sweep_stages.state_entry_ok(None, fp, "a" * 16))
        check("list 엔트리 = 재시도(크래시 없음)",
              not sweep_stages.state_entry_ok([1, 2], fp, "a" * 16))
        check("비수치 attempts 관용(0으로)",
              sweep_stages._prev_attempts({"attempts": "abc"}) == 0
              and sweep_stages._prev_attempts(None) == 0
              and sweep_stages._prev_attempts({"attempts": 3}) == 3)
        # ③ 단일-러너 락 프리미티브: 선점 핸들 보유 중 두 번째 시도는 거부
        lock_p = d / "sweep.lock"
        f1 = open(lock_p, "a+b")
        f2 = open(lock_p, "a+b")
        try:
            f1.seek(0)
            check("첫 러너 락 획득", sr._try_lock(f1))
            f2.seek(0)
            check("동시 러너 락 거부", not sr._try_lock(f2))
        finally:
            sr._unlock(f1)
            f1.close()
            f2.close()


def main() -> int:
    for fn in (p1_corrupt_quarantine, p1b_parse_valid_corruption, p2_concurrency,
               p3_cache_binding, p4_sweep_outcome, p4b_legacy_state,
               p5_partial_best, p5b_same_class_replay_divergence,
               p6_viewer_filename_binding, p7_unverifiable_fail_closed,
               p9_runtime_digest_binding, p10_replay_failed_display,
               p11_transient_replay_error, p12_migration_poisoned_cache,
               p13_sweep_state_durability, p8_persist_failure_escalation):
        fn()
    n_fail = len(FAILS)
    print(f"=== registry_guard_probe: {'PASS' if not n_fail else 'FAIL'} "
          f"(실패 {n_fail}건{': ' + ', '.join(FAILS) if FAILS else ''}) ===")
    return 1 if n_fail else 0


if __name__ == "__main__":
    sys.exit(main())
