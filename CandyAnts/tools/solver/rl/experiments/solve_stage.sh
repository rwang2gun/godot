#!/usr/bin/env bash
# 단일 스테이지 집중 공략 — 단독 r2.1, 3 seed 병렬(각 single-seed 프로세스), 30분 wall.
# 사용법: bash solve_stage.sh <stage>
set -u
STAGE="$1"
cd /d/claude/godot/CandyAnts
export PYTHONUTF8=1
SP="C:/Users/code1412/AppData/Local/Temp/claude/D--claude-godot-CandyAnts/2ed49998-0b02-46e4-ae30-cf568ee5cb17/scratchpad"
SUM="$SP/solve_s${STAGE}_summary.txt"
: > "$SUM"
for seed in 0 1 2; do
  (
    log="$SP/solve_s${STAGE}_seed${seed}.log"
    t0=$SECONDS
    python tools/solver/rl/train.py --grammar r2.1 --stage "$STAGE" --seeds "$seed" --envs 3 \
      --max-episodes 20000 --max-wall 1800 --shaping trace --train-deadline 4500 --sil --save-ckpt \
      > "$log" 2>&1
    dt=$((SECONDS - t0))
    if grep -q "GREEDY CLEAR" "$log"; then
      line=$(grep "GREEDY CLEAR" "$log" | head -1 | sed 's/^ *//')
      echo "seed $seed: SOLVED (${dt}s) — $line" >> "$SUM"
    else
      last=$(grep -i "batch\|Error\|Exception" "$log" | tail -1 | sed 's/^ *//' | cut -c1-100)
      echo "seed $seed: unsolved (${dt}s) — $last" >> "$SUM"
    fi
  ) &
done
wait
echo "=== stage $STAGE DONE ===" >> "$SUM"
