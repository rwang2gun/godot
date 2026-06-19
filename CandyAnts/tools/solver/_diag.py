import os, sys
os.environ.setdefault("PYTHONIOENCODING","utf-8")
sys.path.insert(0, os.path.dirname(__file__))
import json
import model, solve
from pathlib import Path

ROOT = solve.ROOT
sid = int(sys.argv[1]) if len(sys.argv)>1 else 14
extra = json.loads(sys.argv[2]) if len(sys.argv)>2 else []
layout = model.parse_layout(ROOT/"data"/"stage_layouts"/f"stage{sid:02d}_layout.tres")
meta = solve.stage_meta(sid)
hp = int(meta["candy_hp"])
deadline = int(round(meta["time_limit_seconds"]*60))+1500
scene = f"res://scenes/stages/Stage{sid:02d}.tscn"
res = solve.run_plan(scene, extra, deadline, trace=True)
print("RESULT", solve._fmt(res, hp), "actions_fired=", res.get("actions_fired"))
tr = res.get("trace", {})
occ = layout["occupied"]; haz = layout["hazard"]
def land(col, row):
    # next solid below starting from row+1 in column col
    r = row+1
    while r < 40:
        if (col, r) in occ:
            return r-1  # body rests here
        if (col, r) in haz:
            return ("water", r)
        r += 1
    return ("void", r)
def tag(s):
    st = s[4] if len(s) > 4 else "?"
    return f"{s[1]},{s[2]}{'*' if s[3] else ''}[{st}]"
only = int(sys.argv[3]) if len(sys.argv) > 3 else None
for si in sorted(int(k) for k in tr.keys()):
    if only is not None and si != only:
        continue
    ss = tr[str(si)] if str(si) in tr else tr[si]
    last = ss[-1]
    print(f"ant{si}: end=({last[1]},{last[2]}) carry={last[3]} state={last[4] if len(last)>4 else '?'} nsamp={len(ss)}")
    print(f"   path: {'->'.join(tag(s) for s in ss)}")
