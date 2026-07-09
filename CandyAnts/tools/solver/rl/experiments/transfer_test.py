"""전이(transfer) 실험 — 사용자 성공기준 #2.

"이전 학습이 다음 도전의 시도 횟수(eps/batch)를 유의미하게 감소시키는가."

측정: 한 TARGET 스테이지를 두 조건에서 first-greedy-clear까지 걸린 batch/eps로 비교.
  - SCRATCH : 무작위 초기화 정책 → TARGET 학습.
  - TRANSFER: 무작위 정책 → SOURCE 학습(클리어) → 가중치 이월(transfer) → TARGET 학습.
전이 성립 = TRANSFER batches ≪ SCRATCH batches (같은 cap·shaping·cfg, seed만 짝지음).

설계 근거(스킬 어휘 공유 — 워크로그 함정 회피): 전이가 성립할 *진짜 기회*는 공유 스킬이
TARGET의 **주 동작(병목) 스킬**일 때뿐이다. 1~10 커리큘럼 내 공유 스킬(climber 1·6, floater
2·5)은 모두 TARGET의 병목이 아니라(6=digger 고유, 5=sand_mound 고유) 전이가 원천적으로 제한적.
반면 blocker 계열(11=×1, 12=×3, 17=×4)은 공유 스킬이 곧 주 스킬 → 전이가 병목을 직접 건드린다.

train.py 무수정 재사용: train_seed가 이미 (result{episodes,batches,cleared}, state) 반환 +
ckpt_mode="transfer"(cross-stage 가중치 이월, 스테이지-파생 상태 리셋)를 네이티브 지원.
transfer compat 계약: SOURCE ckpt는 (a) cleared_seg, (b) TARGET과 다른 stage_id 여야 함 — 둘 다 충족.

사용법:
    # 캘리브레이션 — 각 스테이지 scratch batches-to-clear 실측(source/target 선정용)
    python tools/solver/rl/experiments/transfer_test.py --calibrate 11 12 17 --seeds 1 --cap 120
    # 본 측정 — SOURCE→TARGET 전이
    python tools/solver/rl/experiments/transfer_test.py --source 11 --target 12 --seeds 3 --cap 150
"""
import argparse
import statistics
import sys
import time

sys.path.insert(0, "tools/solver/rl")
sys.path.insert(0, "tools/solver")
sys.path.insert(0, "scripts")
import train as T          # noqa: E402
from mdp import StageMDP   # noqa: E402


def mk_cfg(args, cap: int) -> dict:
    # 기본 = 문서화된 S12 solving 레시피(R2_PIN): trace shaping + train_deadline 4500 + SIL.
    # 양 조건(scratch/transfer)에 **동일 레시피** 적용 — 유일한 차이는 source 사전학습 유무.
    cfg = dict(T.DEFAULTS)
    cfg["shaping"] = args.shaping
    cfg["train_deadline"] = args.train_deadline
    cfg["sil"] = args.sil
    cfg["sil_buffer"] = args.sil_buffer
    cfg["sil_coef"] = args.sil_coef
    cfg["blocker_coef"] = args.blocker_coef   # §11 S12 돌파 레시피(0=기존 동작 불변)
    cfg["knowledge_coef"] = args.knowledge_coef   # §14.3 지식-축적 보상(0=기존 동작 불변)
    cfg["max_batches"] = cap          # 결정론적 종료 — batch 수만 (wall/eps 무관)
    cfg["max_episodes"] = 10 ** 9
    cfg["max_wall"] = 10 ** 12
    return cfg


def run_stage(mdp, pool, seed, cfg, ckpt=None, mode=None):
    res, state = T.train_seed(mdp, pool, seed, cfg, ckpt_in=ckpt, ckpt_mode=mode)
    return res, state


def save_tagged_ckpt(state, stage_id: int, seed: int, tag: str):
    # SOP §12.1(항상 저장) — 본 ckpt(stageNN_seedS.r2.pt)와 경로 분리로 미덮어쓰기.
    p = T.ckpt_path(stage_id, seed)
    p = p.parent / f"{p.stem}.{tag}.pt"
    sha = T.save_ckpt(p, state)
    print(f"     | ckpt 저장({tag}): {p} sha256={sha[:16]}…")


def _fmt(res) -> str:
    if res["cleared"]:
        return f"CLEAR @ batch {res['batches']} ({res['episodes']} eps, {res['wall_s']}s)"
    return f"DNF (cap {res['batches']} batch, {res['episodes']} eps, bestR {res['best_reward']:.3f})"


def main() -> int:
    ap = argparse.ArgumentParser(description="전이 측정(성공기준 #2)")
    ap.add_argument("--source", type=int, help="사전학습 스테이지(전이 조건, 매 seed 새로 학습)")
    ap.add_argument("--source-ckpt", help="기존 해결 ckpt 재사용(source 학습 생략). {seed} 치환. "
                                          "예: data/solutions/rl_ckpt/stage11_seed{seed}.r2.pt")
    ap.add_argument("--target", type=int, help="측정 대상 스테이지")
    ap.add_argument("--calibrate", type=int, nargs="+", help="scratch batches-to-clear 실측할 스테이지들")
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--seed-list", type=str, default=None,
                    help="명시 seed 목록(콤마, 예: 0,2) — range(--seeds) 대체. 소스 ckpt 없는 seed 스킵용")
    ap.add_argument("--cap", type=int, default=150, help="TARGET first-clear 탐색 batch 상한(=DNF 컷)")
    ap.add_argument("--src-cap", type=int, default=120, help="SOURCE 클리어 학습 batch 상한")
    ap.add_argument("--envs", type=int, default=4)
    ap.add_argument("--shaping", default="trace", choices=["none", "trace"])
    ap.add_argument("--train-deadline", type=int, default=4500, help="S12 recipe material knob(R2_PIN)")
    ap.add_argument("--sil", action="store_true", default=True, help="self-imitation(S12 fallback 2)")
    ap.add_argument("--no-sil", dest="sil", action="store_false")
    ap.add_argument("--sil-buffer", type=int, default=8)
    ap.add_argument("--sil-coef", type=float, default=0.1)
    ap.add_argument("--blocker-coef", type=float, default=0.0,
                    help="§11 S12 돌파 레시피 계수(양 조건 동일 적용; 0=기존 동작 불변)")
    ap.add_argument("--knowledge-coef", type=float, default=0.0,
                    help="§14.3 지식-축적 보상 계수(양 조건 동일 적용; 0=기존 동작 불변)")
    ap.add_argument("--no-save-ckpt", dest="save_ckpt", action="store_false", default=True,
                    help="SOP §12.1 기본=항상 저장(태그 분리 경로). 끌 때만 지정")
    args = ap.parse_args()
    seed_iter = ([int(x) for x in args.seed_list.split(",")] if args.seed_list
                 else list(range(args.seeds)))

    stages = set(args.calibrate or [])
    if args.source:
        stages.add(args.source)
    if args.target:
        stages.add(args.target)
    if not stages:
        ap.error("--calibrate 또는 --source/--target 필요")

    mdps = {s: StageMDP(s, grammar=T.GRAMMAR_R2) for s in stages}
    preflight_scene = mdps[args.target or sorted(stages)[0]].stage_scene
    pool, n_eff, _ = T.build_pool(args.envs, preflight_scene,
                                  with_trace=(args.shaping == "trace" or args.blocker_coef > 0
                                              or args.knowledge_coef > 0))
    print(f"[transfer] envs_effective={n_eff} shaping={args.shaping} sil={args.sil} "
          f"train_deadline={args.train_deadline} cap={args.cap} src_cap={args.src_cap} seeds={args.seeds}")
    t0 = time.monotonic()

    if args.calibrate:
        print(f"\n=== CALIBRATE (scratch batches-to-clear) ===")
        cfg = mk_cfg(args, args.cap)
        for s in args.calibrate:
            for seed in seed_iter:
                res, st = run_stage(mdps[s], pool, seed, cfg)
                print(f"  stage {s:>2} seed {seed}: {_fmt(res)}")
                if args.save_ckpt:
                    save_tagged_ckpt(st, s, seed, "calib")
        pool.close()
        print(f"[transfer] calibrate 완료 ({time.monotonic() - t0:.0f}s)")
        return 0

    if not args.target or not (args.source or args.source_ckpt):
        ap.error("본 측정엔 --target + (--source 또는 --source-ckpt) 필요")

    cfg_t = mk_cfg(args, args.cap)
    cfg_s = mk_cfg(args, args.src_cap)
    tgt_mdp = mdps[args.target]
    src_mdp = mdps.get(args.source) if args.source else None
    scratch_b, xfer_b = [], []
    src_label = f"stage{args.source}" if args.source else f"ckpt({args.source_ckpt})"
    print(f"\n=== TRANSFER  source={src_label} → target=stage{args.target} ===")
    print("seed | SCRATCH(target 직접) | TRANSFER(source→이월→target)")
    for seed in seed_iter:
        rs, st_s = run_stage(tgt_mdp, pool, seed, cfg_t)                    # scratch
        if args.source_ckpt:                                               # 기존 해결 ckpt 재사용(source 학습 생략)
            import torch as _t
            path = args.source_ckpt.format(seed=seed)
            try:
                src_state = _t.load(path, weights_only=False)
                src_state.setdefault("_file_path", path)
                src_note = f"loaded {path} (stage{src_state.get('stage_id')}, cleared={src_state.get('cleared_seg')})"
                src_ok = bool(src_state.get("cleared_seg"))
            except FileNotFoundError:
                src_note = f"ckpt 없음: {path}"
                src_ok = False
        else:
            rsrc, src_state = run_stage(src_mdp, pool, seed, cfg_s)         # source 사전학습
            src_note = f"src {src_label}: {_fmt(rsrc)}"
            src_ok = rsrc["cleared"]
        if not src_ok:
            xfer_txt = f"SOURCE-DNF/미클리어 → 전이 불가"
            rx, st_x = None, None
        else:
            rx, st_x = run_stage(tgt_mdp, pool, seed, cfg_t, ckpt=src_state, mode="transfer")
            xfer_txt = _fmt(rx)
        print(f"  {seed}  | {_fmt(rs)}")
        print(f"     |   {src_note}")
        print(f"     | {xfer_txt}")
        if args.save_ckpt:
            save_tagged_ckpt(st_s, args.target, seed, "scratch")
            if st_x is not None:
                save_tagged_ckpt(st_x, args.target, seed, "xfer")
        if rs["cleared"]:
            scratch_b.append(rs["batches"])
        if rx and rx["cleared"]:
            xfer_b.append(rx["batches"])

    print(f"\n=== 요약 (source=stage{args.source} → target=stage{args.target}) ===")
    n = len(seed_iter)
    print(f"  SCRATCH  클리어 {len(scratch_b)}/{n} seed"
          + (f", batches {sorted(scratch_b)} median={statistics.median(scratch_b):.0f}" if scratch_b else ""))
    print(f"  TRANSFER 클리어 {len(xfer_b)}/{n} seed"
          + (f", batches {sorted(xfer_b)} median={statistics.median(xfer_b):.0f}" if xfer_b else ""))
    ns, nx = len(scratch_b), len(xfer_b)
    if scratch_b and xfer_b:
        sm, xm = statistics.median(scratch_b), statistics.median(xfer_b)
        verdict = ("전이 성립(유의미 감소)" if xm <= 0.6 * sm
                   else "미미/무전이" if xm >= 0.9 * sm else "부분 전이")
        print(f"  판정: median batch SCRATCH {sm:.0f} → TRANSFER {xm:.0f} "
              f"({100 * (1 - xm / sm):+.0f}%) + 클리어율 {ns}/{n}→{nx}/{n} → {verdict}")
    elif nx > ns:
        print(f"  판정: SCRATCH {ns}/{n} → TRANSFER {nx}/{n} 클리어 — 전이가 클리어율 향상(강한 긍정). "
              f"TRANSFER batches {sorted(xfer_b)}")
    elif ns > nx:
        print(f"  판정: SCRATCH {ns}/{n} > TRANSFER {nx}/{n} — 전이가 오히려 해로움(음성/간섭).")
    else:
        print(f"  판정: 양 조건 {ns}/{n} 클리어 — 클리어율 동률. cap 상향 또는 seed 증대로 batch 분포 비교 필요.")
    pool.close()
    print(f"[transfer] 완료 ({time.monotonic() - t0:.0f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
