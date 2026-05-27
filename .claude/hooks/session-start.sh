#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# This repo holds a Godot 4.6 project (CandyAnts/). Tests are launched via
#   python scripts/run_test.py <scene>
# which expects either GODOT_BIN to point at a Godot binary or `godot` to be
# on PATH. The remote image ships Godot 4.6 stable at /usr/local/bin/godot,
# so we just need to:
#   1. Expose GODOT_BIN to the session.
#   2. Run a one-shot project import so class_name registrations resolve
#      before any headless test runs (CandyAnts/CLAUDE.md L40).
set -euo pipefail

# Only run in Claude Code remote (cloud) environments — local devs already
# have their own Godot setup.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

log() { echo "[session-start] $*"; }

GODOT_BIN="${GODOT_BIN:-/usr/local/bin/godot}"
if [ ! -x "$GODOT_BIN" ]; then
  GODOT_BIN="$(command -v godot || true)"
fi
if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
  log "ERROR: no godot binary found (looked at /usr/local/bin/godot and PATH)"
  exit 1
fi
log "using $($GODOT_BIN --version 2>/dev/null || echo godot) at $GODOT_BIN"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GODOT_BIN=\"$GODOT_BIN\"" >> "$CLAUDE_ENV_FILE"
fi

# One-shot import for the CandyAnts project. Incremental on re-runs, so this
# stays cheap after the first session.
CANDYANTS_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/CandyAnts"
if [ -f "$CANDYANTS_DIR/project.godot" ]; then
  log "importing CandyAnts project"
  if ! "$GODOT_BIN" --headless --path "$CANDYANTS_DIR" --import >/tmp/candyants-import.log 2>&1; then
    log "WARNING: project import returned non-zero; see /tmp/candyants-import.log"
    tail -20 /tmp/candyants-import.log || true
  fi
else
  log "skipping import (no CandyAnts/project.godot)"
fi

log "done"
