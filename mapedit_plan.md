# Map Editing (D2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 3DEN editor the source of truth for every code-spawned map object, so editing the map is "run one command, drag things, save, run one command."

**Architecture:** A generated, never-packed edit mission (`MaldenEdit.Malden`) holds the shipped `mission.sqm` plus every code-spawned object as a real Eden entity in reserved layers. Python converts between that sqm and the spawn arrays entirely offline, using the position and rotation frames measured on 2026-07-31. The shipped `mission.sqm` never gains code-spawned content, so double-spawn is impossible rather than guarded.

**Tech Stack:** Python 3 (stdlib only — no pytest in this environment; tests are plain scripts run with `python3`), SQF, existing `tools/sqm_read.py` parser.

**Spec:** `mapedit.md`. Read it before Task 1.

## Global Constraints

- **Branch:** `main` in `~/Armapunk2035`. `git fetch && git pull` before starting — collaborators push straight to `origin/main`.
- **Commit trailer:** `Co-Authored-By: <funny defunct AI>` — name only, **no email address** (Microsoft Tay, SmarterChild, ELIZA, Clippy, Dr. Sbaitso…). Rotate; never repeat back-to-back. **Do not emit the harness default Claude/Anthropic trailer.**
- **Never name other Arma servers** (staff, PBOs, dev handles, branded feature names) in anything git-tracked.
- **Test idiom:** plain scripts, `python3 tools/test_<name>.py`, exit non-zero on failure, matching `tools/test_sqf_balance.py`. pytest is **not installed**.
- **Dev deploys are free:** `bash /home/timb/arma3server_dev/reload-armapunk2035.sh` (~90 s). Success marker: `grep "read from bank" /home/timb/arma3server_dev/loonydev.log`. **Never** `reload-loonydev.sh` — that packs the other project.
- **Live is stage-only.** Nothing in this plan touches live.
- **Before every deploy:** brace/bracket balance check — `python3 tools/sqf_balance.py <file>`.
- **`mission.sqm` is plain text and must stay that way.** 3DEN re-binarizes on save unless its "Save scenario in binarized form" preference is off. Verify that preference is OFF before Task 6.
- **Never save the shipped `mission.sqm` from 3DEN.** Only `MaldenEdit.Malden` may be saved.

### Measured frame constants (do not re-derive)

```
position[] = {x, elevation, y}   and holds the MODEL CENTRE  (== getPosWorld; max error 6.1e-5 m)

M    = Rx(-angles[0]) · Ry(-angles[2]) · Rz(-angles[1])
dir  = M·(0,1,0)      up = M·(0,0,1)          (43/43 rows exact to 8.5e-7)
```

`angles[1]` is yaw about the world **up** axis — `angles[]` is reordered exactly like `position[]`. Assuming otherwise fits zero yawed rows and silently mis-aims the entire map by 180°.

---

### Task 1: Frame conversion module

The one piece of maths everything else depends on. Pure functions, so it gets real tests.

**Files:**
- Create: `tools/sqm_frame.py`
- Test: `tools/test_sqm_frame.py`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `angles_to_vectors(angles: seq[float,3]) -> (tuple[float,3], tuple[float,3])` returning `(dir, up)`
  - `vectors_to_angles(dir: seq[float,3], up: seq[float,3]) -> tuple[float,3]` returning sqm `angles[]`
  - `SQM_POS_TO_WORLD(position: seq[float,3]) -> tuple[float,3]` mapping `{x,elev,y}` → `[x,y,z]`
  - `WORLD_TO_SQM_POS(world: seq[float,3]) -> tuple[float,3]` mapping `[x,y,z]` → `{x,elev,y}`

- [ ] **Step 1: Write the failing test**

Create `tools/test_sqm_frame.py`. The two vectors are real rows measured from the running server on 2026-07-31 (`id=33817`, a flat-ish helipad, and `id=33818`, the same tilt yawed −90°), so this test pins the convention to ground truth rather than to itself.

```python
#!/usr/bin/env python3
"""Tests for tools/sqm_frame.py.  Run: python3 tools/test_sqm_frame.py

The two MEASURED cases are real rows read off the running engine (debug/frame_angles.sqf,
2026-07-31). They are the whole point of this file: a round-trip test alone would happily
confirm a convention that is internally consistent and wrong, which is exactly the failure
mode here -- a 180-degree map-wide mis-aim that no self-consistency check can see.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_frame

FAILS = []


def close(a, b, tol=1e-5):
    return all(abs(x - y) <= tol for x, y in zip(a, b))


def check(name, got, want, tol=1e-5):
    if close(got, want, tol):
        print("  ok   %s" % name)
    else:
        FAILS.append(name)
        print("  FAIL %s\n         got  %s\n         want %s" % (name, list(got), list(want)))


# --- measured ground truth: sqm angles[] -> engine vectorDir / vectorUp ---------------
MEASURED = [
    # (id, angles,                              dir,                              up)
    (33817, (-0.111282, 0.000000, 0.094981),
            (0.000000, 0.993815, 0.111053), (-0.094838, -0.110552, 0.989335)),
    (33818, (-0.111282, -1.570796, 0.094981),
            (-0.995493, 0.010532, -0.094251), (-0.094838, -0.110552, 0.989335)),
]

print("measured cases (engine ground truth):")
for oid, ang, want_dir, want_up in MEASURED:
    d, u = sqm_frame.angles_to_vectors(ang)
    check("id %d dir" % oid, d, want_dir)
    check("id %d up" % oid, u, want_up)

print("inverse of the measured cases:")
for oid, ang, want_dir, want_up in MEASURED:
    got = sqm_frame.vectors_to_angles(want_dir, want_up)
    d, u = sqm_frame.angles_to_vectors(got)
    check("id %d inverse->dir" % oid, d, want_dir)
    check("id %d inverse->up" % oid, u, want_up)

# --- gimbal case: the map's steepest object is tilted 90 degrees, where angles[2] = +-pi/2
# and angles[1] stops being recoverable from dir[0]. A naive inverse divides by cos(beta) = 0.
print("gimbal (90-degree tilt):")
for yaw in (0.0, 0.7, -2.5, 3.0):
    ang = (0.0, yaw, -math.pi / 2)
    d, u = sqm_frame.angles_to_vectors(ang)
    got = sqm_frame.vectors_to_angles(d, u)
    d2, u2 = sqm_frame.angles_to_vectors(got)
    check("yaw %.2f dir" % yaw, d2, d)
    check("yaw %.2f up" % yaw, u2, u)

# --- round-trip across the whole range -----------------------------------------------
print("round-trip sweep:")
worst = 0.0
for a0 in (-1.2, -0.3, 0.0, 0.4, 1.1):
    for a1 in (-3.0, -1.5, 0.0, 1.5, 3.0):
        for a2 in (-1.0, 0.0, 0.6):
            d, u = sqm_frame.angles_to_vectors((a0, a1, a2))
            d2, u2 = sqm_frame.angles_to_vectors(sqm_frame.vectors_to_angles(d, u))
            worst = max(worst, max(abs(x - y) for x, y in zip(d, d2)),
                        max(abs(x - y) for x, y in zip(u, u2)))
if worst < 1e-9:
    print("  ok   75 combinations, worst %.2e" % worst)
else:
    FAILS.append("round-trip sweep")
    print("  FAIL round-trip sweep, worst %.2e" % worst)

# --- coordinate reorder --------------------------------------------------------------
print("position reorder:")
check("sqm->world", sqm_frame.SQM_POS_TO_WORLD((4201.9951, 26.866976, 3931.731)),
      (4201.9951, 3931.731, 26.866976))
check("world->sqm", sqm_frame.WORLD_TO_SQM_POS((4201.9951, 3931.731, 26.866976)),
      (4201.9951, 26.866976, 3931.731))

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_sqm_frame.py`
Expected: `ModuleNotFoundError: No module named 'sqm_frame'`

- [ ] **Step 3: Write the implementation**

Create `tools/sqm_frame.py`. The inverse is closed-form, derived from the forward matrix rather than searched — `up` alone gives two of the three angles, and the yaw follows from a rotation-invariant combination of `dir` that stays well-conditioned at 90° tilt.

```python
#!/usr/bin/env python3
"""Conversion between mission.sqm's stored transform and Arma's runtime transform.

MEASURED, not assumed (debug/frame_angles.sqf + tools/frame_solve.py, 2026-07-31, 43 rows):

    position[] = {x, elevation, y}, holding the MODEL CENTRE -- the getPosWorld frame.
    M   = Rx(-angles[0]) . Ry(-angles[2]) . Rz(-angles[1])
    dir = M*(0,1,0)      up = M*(0,0,1)

angles[] is reordered exactly like position[]: angles[1] is yaw about the world UP axis, NOT
about the game's Y axis. Holding that assumption fixed fits zero yawed rows -- a silent
180-degree mis-aim of the whole map -- which is why this lives in one tested module and is
never re-derived at a call site.

Expanding M gives the columns used below:
    dir = (-cb*sg,  ca*cg - sa*sb*sg,  sa*cg + ca*sb*sg)
    up  = ( sb,    -sa*cb,             ca*cb          )
where a = -angles[0], b = -angles[2], g = -angles[1].
"""
import math


def _rx(t):
    c, s = math.cos(t), math.sin(t)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def _ry(t):
    c, s = math.cos(t), math.sin(t)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def _rz(t):
    c, s = math.cos(t), math.sin(t)
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def _mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3))
                 for i in range(3))


def _col(m, j):
    return (m[0][j], m[1][j], m[2][j])


def angles_to_vectors(angles):
    """sqm angles[] -> (vectorDir, vectorUp)."""
    a0, a1, a2 = (float(v) for v in angles)
    m = _mul(_mul(_rx(-a0), _ry(-a2)), _rz(-a1))
    return _col(m, 1), _col(m, 2)


def vectors_to_angles(vdir, vup):
    """(vectorDir, vectorUp) -> sqm angles[]. Closed form; stable at 90-degree tilt."""
    ux, uy, uz = (float(v) for v in vup)
    dx, dy, dz = (float(v) for v in vdir)

    b = math.asin(max(-1.0, min(1.0, ux)))          # up[0] = sin(b)
    a = math.atan2(-uy, uz)                          # up = (sb, -sa*cb, ca*cb)
    ca, sa = math.cos(a), math.sin(a)
    cb, sb = math.cos(b), math.sin(b)

    # cos(g) is rotation-invariant in a and needs no division:
    #   ca*dir[1] + sa*dir[2] = cg
    cg = ca * dy + sa * dz
    # sin(g) two ways; pick whichever denominator is furthest from zero, so the 90-degree
    # tilt case (cb -> 0, where dir[0] carries no yaw information) stays well conditioned.
    if abs(cb) >= abs(sb):
        sg = -dx / cb
    else:
        sg = (-sa * dy + ca * dz) / sb               # = sb*sg / sb
    g = math.atan2(sg, cg)

    return (-a, -g, -b)


def SQM_POS_TO_WORLD(position):
    """sqm position[] {x, elevation, y} -> world [x, y, z]."""
    x, elev, y = (float(v) for v in position)
    return (x, y, elev)


def WORLD_TO_SQM_POS(world):
    """world [x, y, z] -> sqm position[] {x, elevation, y}."""
    x, y, z = (float(v) for v in world)
    return (x, z, y)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_sqm_frame.py`
Expected: every line `ok`, final line `0 failure(s)`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tools/sqm_frame.py tools/test_sqm_frame.py
git commit -m "Add the measured sqm<->runtime transform conversion

The position and rotation frames were measured against the running engine
rather than assumed: 43 objects read back through debug/frame_angles.sqf,
solved offline over all 288 candidate conventions. position[] holds the
model centre and angles[] is reordered like it, so angles[1] is yaw about
world up. The tests pin both directions to two of those measured rows,
because a round-trip test on its own would confirm a self-consistent wrong
convention -- which here means every object on the map turned 180 degrees.

Co-Authored-By: SmarterChild"
```

---

### Task 2: Runtime pass that reads every mapData row's world transform

Phase 0 begins. `fn_mapData` rows are applied with `setPosATL`; everything else is already world-frame. Converting between them needs terrain height plus a per-class, orientation-dependent bounding-centre offset, so it cannot be done offline — the array has to move to the world frame once, with the engine's help.

The client streams the array per zone (`core/functions/fn_dynamicMapSystem.sqf`), so the objects are never all present at once and cannot simply be read out of the world. This pass spawns each row itself, exactly as the loader does, reads it, and deletes it.

**Files:**
- Create: `mission/Armapunk2035.Malden/debug/mapMigrateWorld.sqf`
- Modify: `mission/Armapunk2035.Malden/initPlayerLocal.sqf` (add a guarded call, removed again in Task 4)

**Interfaces:**
- Consumes: nothing.
- Produces: RPT lines `[MAPMIG] i=<index> cls=<class> world=<x>,<y>,<z>` plus `[MAPMIG] ==== end rows=<n> ====`, consumed by Task 3.

- [ ] **Step 1: Write the probe**

Create `mission/Armapunk2035.Malden/debug/mapMigrateWorld.sqf`:

```sqf
/*
    debug\mapMigrateWorld.sqf  --  ONE-TIME frame migration read (dev instrumentation)

    Reads the true world transform of every allLocalMapEntities row so tools/mapdata_migrate.py can
    rewrite the array from setPosATL to setPosWorld. After that the array is in the same frame as
    the custom buildings and the composition zones, and mission.sqm converts to and from it entirely
    offline -- which is the whole point of the D2 pipeline (mapedit.md).

    WHY IT SPAWNS RATHER THAN READS: the client streams the array per zone
    (core/functions/fn_dynamicMapSystem.sqf), so the objects are never all in the world at once.
    This reproduces the loader's own client branch -- createSimpleObject local, or createVehicleLocal
    when the row carries an init or a loadout -- because the bounding-centre offset that separates
    ATL from world is a property of the object that gets created.

    X AND Y ARE LOGGED TOO, NOT JUST Z. getPosATL and getPosWorld differ by the transformed
    bounding-centre offset, which is only vertical for a model whose centre sits above its origin.
    Assuming x/y are unchanged would silently shift every model whose centre is offset horizontally.

    Batched with a yield so the client does not hitch; objects are deleted as it goes.
    Output: the client RPT. grep [MAPMIG].

    DEV INSTRUMENTATION -- Task 4 of mapedit_plan.md removes the initPlayerLocal.sqf call.
*/
if (!hasInterface) exitWith {};
if (isNil "allLocalMapEntities") then { [] call AP_fnc_mapData; };

private _tag = "[MAPMIG]";
diag_log format ["%1 ==== start rows=%2 ====", _tag, count allLocalMapEntities];

{
    _x params ["_cls", "_pos", "_dir", ["_code", ""], ["_srv", false], ["_loadout", []]];
    private _i = _forEachIndex;

    // the loader's client branch, verbatim in shape (core/functions/fn_createVehicleLocal.sqf)
    private _o = if (_code isEqualTo "" && {_loadout isEqualTo []}) then {
        createSimpleObject [_cls, [0, 0, 0], true]
    } else {
        _cls createVehicleLocal [0, 0, 0]
    };
    if (isNull _o) then {
        diag_log format ["%1 NULL i=%2 cls=%3", _tag, _i, _cls];
    } else {
        _o enableSimulation false;
        _o allowDamage false;
        if (_dir isEqualType []) then { _o setVectorDirAndUp _dir } else { _o setDir _dir };
        _o setPosATL _pos;                       // exactly what the loader does today
        private _w = getPosWorld _o;
        diag_log format ["%1 i=%2 cls=%3 world=%4,%5,%6", _tag, _i, _cls,
            (_w select 0) toFixed 4, (_w select 1) toFixed 4, (_w select 2) toFixed 4];
        deleteVehicle _o;
    };

    if (_i % 250 == 249) then { uiSleep 0.05 };   // yield so the client does not hitch
} forEach allLocalMapEntities;

diag_log format ["%1 ==== end rows=%2 ====", _tag, count allLocalMapEntities];
```

- [ ] **Step 2: Hook it, temporarily**

In `mission/Armapunk2035.Malden/initPlayerLocal.sqf`, immediately after the existing
`[] execVM "debug\frame_probe.sqf";` line (around line 462), add:

```sqf
// DEV INSTRUMENTATION -- one-time frame migration read (mapedit_plan.md Task 2). Removed in Task 4.
[] spawn { uiSleep 30; [] execVM "debug\mapMigrateWorld.sqf"; };
```

- [ ] **Step 3: Balance-check and deploy**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/debug/mapMigrateWorld.sqf
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initPlayerLocal.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

Expected: `ok` from both balance checks; the reload ends with `restarting on MALDEN`.

- [ ] **Step 4: Join with a client and capture the log**

Launch the client, join the dev server (port 2342), and wait for the map to finish loading plus 30 s. Then:

```bash
RPT=$(ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1)
grep -c "MAPMIG" "$RPT"
grep "MAPMIG" "$RPT" | grep "====" 
grep "MAPMIG" "$RPT" | grep -c "NULL"
cp "$RPT" /tmp/mapmig.rpt
```

Expected: start and end lines both reporting `rows=8717`; roughly 8,719 `MAPMIG` lines; `NULL` count **0**. A non-zero `NULL` count means a class failed to create — record which, and do not continue until it is understood, because those rows would migrate to a wrong position.

- [ ] **Step 5: Commit the probe**

```bash
git add mission/Armapunk2035.Malden/debug/mapMigrateWorld.sqf mission/Armapunk2035.Malden/initPlayerLocal.sqf
git commit -m "Read every map row's true world transform, once

The array is applied with setPosATL while every other placement in the
mission is already in the world frame. Converting between them needs
terrain height and a per-class, orientation-dependent bounding-centre
offset, so it cannot be done offline -- the array has to move frames once,
with the engine's help, and then never again.

It spawns each row rather than reading the world because the client streams
the array per zone, so the objects are never all present at once.

Co-Authored-By: ELIZA"
```

---

### Task 3: Rewrite `fn_mapData.sqf` into the world frame

**Files:**
- Create: `tools/mapdata_migrate.py`
- Modify: `mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` (generated output)

**Interfaces:**
- Consumes: the `[MAPMIG]` RPT lines from Task 2.
- Produces: `fn_mapData.sqf` with every row's position in the world frame; row order, class, orientation, init, server flag and loadout all byte-identical to before.

- [ ] **Step 1: Write the failing test**

Create `tools/test_mapdata_migrate.py`:

```python
#!/usr/bin/env python3
"""Tests for tools/mapdata_migrate.py.  Run: python3 tools/test_mapdata_migrate.py

The migration rewrites ONE field of 8,717 rows. The risk is not that the arithmetic is wrong --
the engine supplies the numbers -- it is that a row gets paired with another row's reading.
So these tests are all about alignment: index, class, and everything the row carries besides
position must come through untouched.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapdata_migrate

FAILS = []


def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


SRC = ('allLocalMapEntities=['
       '["Land_A_F",[10.0,20.0,0.5],[[0.0,1.0,0.0],[0.0,0.0,1.0]],"",false],'
       '["Land_B_F",[30.0,40.0,1.5],[[1.0,0.0,0.0],[0.0,0.0,1.0]],"[_this] call X;",true],'
       '["C_man_1",[50.0,60.0,0.0],[[0.0,1.0,0.0],[0.0,0.0,1.0]],"",false,[["arifle"]]]'
       '];\n')

LOG = "\n".join([
    '2026/01/01 "[MAPMIG] ==== start rows=3 ===="',
    '2026/01/01 "[MAPMIG] i=0 cls=Land_A_F world=10.0000,20.0000,41.2000"',
    '2026/01/01 "[MAPMIG] i=1 cls=Land_B_F world=30.5000,40.0000,42.7000"',
    '2026/01/01 "[MAPMIG] i=2 cls=C_man_1 world=50.0000,60.0000,38.9000"',
    '2026/01/01 "[MAPMIG] ==== end rows=3 ===="',
]) + "\n"

rows = mapdata_migrate.parse_rows(SRC)
check("parses 3 rows", len(rows) == 3)
check("keeps init text", rows[1]["init"] == "[_this] call X;")
check("keeps server flag", rows[1]["server"] == "true")
check("keeps loadout 6th field", rows[2]["tail"].strip().endswith("[[\"arifle\"]]"))

readings = mapdata_migrate.parse_log(LOG)
check("parses 3 readings", len(readings) == 3)
check("reading is world xyz", readings[1] == ("Land_B_F", (30.5, 40.0, 42.7)))

out = mapdata_migrate.rewrite(SRC, readings)
check("row 0 z replaced", '[10.000,20.000,41.200]' in out)
check("row 1 x replaced too", '[30.500,40.000,42.700]' in out)
check("init survives", '"[_this] call X;"' in out)
check("loadout survives", '[["arifle"]]' in out)
check("class order unchanged",
      out.index("Land_A_F") < out.index("Land_B_F") < out.index("C_man_1"))

# alignment failures must abort, never guess
try:
    mapdata_migrate.rewrite(SRC, readings[:2])
    check("aborts on count mismatch", False)
except SystemExit:
    check("aborts on count mismatch", True)

bad = list(readings)
bad[1] = ("Land_WRONG_F", (0.0, 0.0, 0.0))
try:
    mapdata_migrate.rewrite(SRC, bad)
    check("aborts on class mismatch", False)
except SystemExit:
    check("aborts on class mismatch", True)

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_mapdata_migrate.py`
Expected: `ModuleNotFoundError: No module named 'mapdata_migrate'`

- [ ] **Step 3: Write the implementation**

Create `tools/mapdata_migrate.py`:

```python
#!/usr/bin/env python3
"""ONE-TIME: rewrite fn_mapData.sqf's positions from the ATL frame into the world frame.

Pairs with debug/mapMigrateWorld.sqf, which logs each row's true getPosWorld. Only the position
field changes; class, orientation, init, server flag and any loadout are carried through as the
original text, so a diff shows exactly one number triple per row and nothing else.

The whole risk here is MISALIGNMENT -- a row paired with a different row's reading. Row order is
the array's own order on both sides, and every reading also carries its class, so the class is
asserted per row and any mismatch aborts. It does not "resync" or skip: a single silent shift
would move thousands of objects, and this repo has already lost 835 rows once to a matching
heuristic that guessed.

    python3 tools/mapdata_migrate.py <rpt-with-MAPMIG-lines> [--write]
"""
import os
import re
import shutil
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(REPO, "mission", "Armapunk2035.Malden", "core", "config", "fn_mapData.sqf")

LOGLINE = re.compile(r"\[MAPMIG\] i=(\d+) cls=(\S+) world=([-\d.]+),([-\d.]+),([-\d.]+)")


def parse_rows(src):
    """Split the array into rows, keeping each row's text verbatim after the position field."""
    body = src[src.index("[") + 1:src.rindex("]")]
    rows, depth, start = [], 0, 0
    for i, ch in enumerate(body):
        if ch == "[":
            depth += 1
            if depth == 1:
                start = i
        elif ch == "]":
            depth -= 1
            if depth == 0:
                rows.append(body[start:i + 1])
    out = []
    for r in rows:
        # re.S and \Z, not `.` and `$`: four real rows carry a NEWLINE inside their init string
        # (an NPC that is both a DMV and a shop calls two functions on two lines). Without DOTALL
        # the row match stops at that newline; `$` would also match there. Nothing synthetic
        # catches this -- it only showed up when the parser was first run on the real 8,717 rows.
        m = re.match(r'\["([^"]+)",\[([-\d.eE]+),([-\d.eE]+),([-\d.eE]+)\],(.*)\]\Z', r, re.S)
        if not m:
            sys.exit("unparsable row: %s" % r[:120])
        tail = m.group(5)
        im = re.match(r'(\[\[.*?\],\[.*?\]\]),"((?:[^"]|"")*)",(true|false)(.*)\Z', tail, re.S)
        if not im:
            sys.exit("unparsable row tail: %s" % tail[:120])
        out.append({"cls": m.group(1),
                    "pos": (float(m.group(2)), float(m.group(3)), float(m.group(4))),
                    "vec": im.group(1), "init": im.group(2).replace('""', '"'),
                    "server": im.group(3), "tail": im.group(4), "raw": r})
    return out


def parse_log(text):
    """Newest complete [MAPMIG] block in the file, as [(class, (x,y,z)), ...] indexed by row."""
    found = {}
    for line in text.splitlines():
        m = LOGLINE.search(line)
        if m:
            found[int(m.group(1))] = (m.group(2),
                                      (float(m.group(3)), float(m.group(4)), float(m.group(5))))
    return [found[i] for i in sorted(found)] if found else []


def rewrite(src, readings):
    rows = parse_rows(src)
    if len(rows) != len(readings):
        sys.exit("ABORT: %d rows but %d readings -- the log is from a different array"
                 % (len(rows), len(readings)))
    parts = []
    for i, (row, (cls, world)) in enumerate(zip(rows, readings)):
        if row["cls"] != cls:
            sys.exit("ABORT: row %d is %s but reading %d is %s -- alignment is broken, "
                     "nothing written" % (i, row["cls"], i, cls))
        parts.append('["%s",[%.3f,%.3f,%.3f],%s,"%s",%s%s]'
                     % (row["cls"], world[0], world[1], world[2], row["vec"],
                        row["init"].replace('"', '""'), row["server"], row["tail"]))
    return "allLocalMapEntities=[" + ",".join(parts) + "];\n"


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    readings = parse_log(open(sys.argv[1], errors="replace").read())
    if not readings:
        sys.exit("no [MAPMIG] lines in %s" % sys.argv[1])
    src = open(TARGET).read()
    out = rewrite(src, readings)
    print("rows migrated: %d" % len(readings))
    moved = sum(1 for a, b in zip(parse_rows(src), parse_rows(out))
                if abs(a["pos"][2] - b["pos"][2]) > 0.001)
    print("rows whose height changed: %d" % moved)
    if "--write" not in sys.argv:
        print("dry run -- pass --write to apply")
        return
    shutil.copy(TARGET, TARGET + ".bak")
    open(TARGET, "w").write(out)
    print("wrote %s (backup at %s.bak)" % (TARGET, TARGET))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_mapdata_migrate.py`
Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Dry-run against the real capture, then write**

```bash
python3 tools/mapdata_migrate.py /tmp/mapmig.rpt
```

Expected: `rows migrated: 8717`, and `rows whose height changed: 8717` — every row should move, because ATL and world differ by at least the terrain height everywhere on Malden. If that count is materially below 8717, stop: it means readings were dropped.

```bash
python3 tools/mapdata_migrate.py /tmp/mapmig.rpt --write
git diff --stat mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
```

- [ ] **Step 6: Commit**

```bash
git add tools/mapdata_migrate.py tools/test_mapdata_migrate.py mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
git commit -m "Move the map array into the world frame

Only the position field changes; class, orientation, init, server flag and
loadout are carried through as their original text. Rows pair with readings
by array order and every pairing is checked against the reading's own class
-- a mismatch aborts and writes nothing rather than resyncing, because a
silent one-row shift would move thousands of objects and this repo has
already lost 835 rows once to a matching heuristic that guessed.

Co-Authored-By: Dr. Sbaitso"
```

---

### Task 4: Switch the loader to `setPosWorld` and verify in-game

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/functions/fn_createVehicleLocal.sqf:27`
- Modify: `mission/Armapunk2035.Malden/initPlayerLocal.sqf` (remove the Task 2 hook)

**Interfaces:**
- Consumes: the world-frame array from Task 3.
- Produces: a mission whose map renders identically to before, now entirely in the world frame.

- [ ] **Step 1: Change the placement command**

In `mission/Armapunk2035.Malden/core/functions/fn_createVehicleLocal.sqf`, replace line 27:

```sqf
_vehicle setPosATL _position;
```

with:

```sqf
// owner 2026-07-31: the array is in the WORLD frame (model centre) since the mapedit.md
// migration, so this is setPosWorld and not setPosATL. The two frames differ by the
// transformed bounding-centre offset, which is per-class AND changes with orientation --
// 326 of the designer's objects are tilted, one by 90 degrees -- so they are not
// interchangeable and there is no offline conversion between them.
_vehicle setPosWorld _position;
```

- [ ] **Step 2: Remove the migration hook**

In `mission/Armapunk2035.Malden/initPlayerLocal.sqf`, delete the two lines added in Task 2 Step 2 (the comment and the `[] spawn { uiSleep 30; ... }` line). The probe file stays in `debug/` for re-verification.

- [ ] **Step 3: Balance-check and deploy**

```bash
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/functions/fn_createVehicleLocal.sqf
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/initPlayerLocal.sqf
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

Expected: `ok`, `ok`, reload completes.

- [ ] **Step 4: Verify in-game — this is the gate for all of Phase 0**

Join the dev server and inspect at least these, which between them cover flat ground, slope, height and tilt:

1. The Malden prison compound (~`[9731, 3978]`) — HBarriers must sit on the ground, not sunk or floating, and the stacked pair must still be stacked.
2. The police HQ and its wall ring.
3. Any shop NPC — must stand on the floor, and its scroll-wheel action must still work (that proves the init field survived).
4. A sloped area with kerbs or walls — tilt must be unchanged, nothing flattened.

Expected: visually identical to before the migration. **A general vertical shift is the failure signature** — it means the frames were swapped rather than converted. Recovery: `git checkout mission/Armapunk2035.Malden/core/config/fn_mapData.sqf` and re-run Task 3.

- [ ] **Step 5: Commit**

```bash
git add mission/Armapunk2035.Malden/core/functions/fn_createVehicleLocal.sqf mission/Armapunk2035.Malden/initPlayerLocal.sqf
git commit -m "Place map rows in the world frame

Completes the migration: the array, the custom buildings and the
composition zones are now all in one frame, so mission.sqm converts to and
from the spawn data offline with no engine round-trip.

Co-Authored-By: Clippy"
```

---

### Task 5: sqm layer splicing

Phase 1 begins. Generation never rewrites the designer's bytes: it copies the shipped sqm verbatim and appends generated layers.

**Files:**
- Create: `tools/sqm_splice.py`
- Test: `tools/test_sqm_splice.py`

**Interfaces:**
- Consumes: `tools/sqm_read.py` (`parse`, `walk`).
- Produces:
  - `find_mission_entities(text) -> (items_count, items_decl_span, insert_offset)` — `items_decl_span` is the `(start, end)` character span of the root `items=N;` declaration, `insert_offset` the character offset just before the root Entities block's closing brace.
  - `splice_layers(text: str, layer_blocks: list[str]) -> str`

- [ ] **Step 1: Write the failing test**

Create `tools/test_sqm_splice.py`:

```python
#!/usr/bin/env python3
"""Tests for tools/sqm_splice.py.  Run: python3 tools/test_sqm_splice.py

Generation must never rewrite the designer's bytes. The sqm holds thousands of hand-placed
objects and the only serialiser in this repo writes the binarized form, so re-serialising the
text form would mean writing a new one whose failure mode is corrupting that file. Splicing
sidesteps it: copy verbatim, append, and prove the original bytes are still there.

The nested-Entities case is the trap. Layers contain their own `class Entities`, so a scan that
takes the first match, or counts braces without skipping string literals, lands inside a layer.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_splice
import sqm_read

FAILS = []


def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


SQM = '''version=54;
class Mission
{
\tclass Entities
\t{
\t\titems=2;
\t\tclass Item0
\t\t{
\t\t\tdataType="Object";
\t\t\tclass PositionInfo
\t\t\t{
\t\t\t\tposition[]={1,2,3};
\t\t\t};
\t\t\tid=11;
\t\t\ttype="Land_A_F";
\t\t};
\t\tclass Item1
\t\t{
\t\t\tdataType="Layer";
\t\t\tname="Designer";
\t\t\tclass Entities
\t\t\t{
\t\t\t\titems=1;
\t\t\t\tclass Item0
\t\t\t\t{
\t\t\t\t\tdataType="Object";
\t\t\t\t\tclass Attributes
\t\t\t\t\t{
\t\t\t\t\t\tinit="a=1; b={2}; s=""}"";";
\t\t\t\t\t};
\t\t\t\t\tid=12;
\t\t\t\t\ttype="Land_B_F";
\t\t\t\t};
\t\t\t};
\t\t\tid=13;
\t\t};
\t};
};
'''

LAYER = '''\t\tclass Item2
\t\t{
\t\t\tdataType="Layer";
\t\t\tname="AP_TEST";
\t\t\tclass Entities
\t\t\t{
\t\t\t\titems=1;
\t\t\t\tclass Item0
\t\t\t\t{
\t\t\t\t\tdataType="Object";
\t\t\t\t\tclass PositionInfo
\t\t\t\t\t{
\t\t\t\t\t\tposition[]={9,8,7};
\t\t\t\t\t};
\t\t\t\t\tid=900001;
\t\t\t\t\ttype="Land_C_F";
\t\t\t\t};
\t\t\t};
\t\t\tid=900000;
\t\t};
'''

n, span, off = sqm_splice.find_mission_entities(SQM)
check("finds root items count 2", n == 2)
check("items span points at the root declaration", SQM[span[0]:span[1]] == "items=2;")
check("insert offset is inside the root Entities block",
      SQM.count("class Item1", 0, off) == 1)

out = sqm_splice.splice_layers(SQM, [LAYER])
check("root items bumped to 3", "items=3;" in out)
check("designer layer's inner items untouched", out.count("items=1;") == 2)
check("original bytes preserved verbatim",
      SQM[:span[0]] in out and 'init="a=1; b={2}; s=""}"";";' in out)
check("new layer present", 'name="AP_TEST"' in out)

# the spliced file must still parse, and gain exactly the generated entities
before = sqm_read._parse_text(SQM)
after = sqm_read._parse_text(out)


def ids(node):
    return sorted(n["props"]["id"] for n in sqm_read.walk(node)
                  if isinstance(n["props"].get("id"), int))


check("ids are a superset", set(ids(before)) < set(ids(after)))
check("exactly the generated ids added",
      set(ids(after)) - set(ids(before)) == {900000, 900001})

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_sqm_splice.py`
Expected: `ModuleNotFoundError: No module named 'sqm_splice'`

- [ ] **Step 3: Write the implementation**

Create `tools/sqm_splice.py`:

```python
#!/usr/bin/env python3
"""Append generated layers to a plain-text mission.sqm without rewriting the original bytes.

The only sqm serialiser in this repo (sqm_strip_exported.py) writes the BINARIZED form, and the
shipped sqm is plain text by owner order. Writing a text serialiser would put the designer's
file -- thousands of hand-placed objects -- behind a new component whose failure mode is silent
corruption. Splicing avoids that entirely: the source is copied verbatim and generated layers are
appended, so a diff of the shipped file's own bytes is empty by construction.

Two traps, both handled by the scanner below:
  * Layers contain their own `class Entities`, so the ROOT one has to be found by structure,
    not by taking the first match.
  * Init strings contain braces (`s=""}"";`), so brace depth must be counted with string
    literals skipped -- and in a .sqm a quote is escaped by doubling it, not with a backslash.
"""
import re

import sqm_read


def _scan(text, start):
    """Walk from `start` (just past an opening brace) to its matching close. Returns that offset.

    String-aware: a quote toggles string state, and a doubled quote inside a string is a
    literal quote rather than a terminator.
    """
    depth, i, n = 1, start, len(text)
    while i < n:
        ch = text[i]
        if ch == '"':
            i += 1
            while i < n:
                if text[i] == '"':
                    if i + 1 < n and text[i + 1] == '"':
                        i += 2
                        continue
                    break
                i += 1
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError("unbalanced braces: no matching close brace")


def find_mission_entities(text):
    """(items_count, (start,end) of the root `items=N;`, offset to insert new items at)."""
    m = re.search(r"\bclass\s+Mission\s*\{", text)
    if not m:
        raise ValueError("no `class Mission` in this sqm")
    mission_end = _scan(text, m.end())

    # the first `class Entities` at mission level -- found by scanning forward from the Mission
    # brace and skipping any nested block, so a layer's Entities can never be mistaken for it
    i = m.end()
    while i < mission_end:
        em = re.compile(r"\bclass\s+(\w+)\s*\{").search(text, i)
        if not em or em.start() > mission_end:
            raise ValueError("no `class Entities` directly inside `class Mission`")
        body_end = _scan(text, em.end())
        if em.group(1) == "Entities":
            im = re.compile(r"\bitems\s*=\s*(\d+)\s*;").search(text, em.end(), body_end)
            if not im:
                raise ValueError("root Entities has no items= declaration")
            return int(im.group(1)), (im.start(), im.end()), body_end
        i = body_end + 1
    raise ValueError("no `class Entities` directly inside `class Mission`")


def splice_layers(text, layer_blocks):
    """Insert `layer_blocks` as new root items and bump the root items count."""
    if not layer_blocks:
        return text
    count, span, insert_at = find_mission_entities(text)
    body = "".join(layer_blocks)
    out = text[:insert_at] + body + text[insert_at:]
    # bump the count last, so the offsets above stay valid while splicing
    new_span_start = span[0]
    out = out[:new_span_start] + ("items=%d;" % (count + len(layer_blocks))) + \
        out[new_span_start + (span[1] - span[0]):]
    # self-check: the result must still parse
    sqm_read._parse_text(out)
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_sqm_splice.py`
Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Verify against the real 2.4 MB mission.sqm**

```bash
python3 -c "
import sys; sys.path.insert(0,'tools')
import sqm_splice
t=open('mission/Armapunk2035.Malden/mission.sqm').read()
n,span,off=sqm_splice.find_mission_entities(t)
print('root items=%d, insert offset %d of %d bytes' % (n, off, len(t)))
out=sqm_splice.splice_layers(t, [])
print('empty splice is byte-identical:', out==t)
"
```

Expected: a plausible root item count, an insert offset near the end of the file, and `True`.

- [ ] **Step 6: Commit**

```bash
git add tools/sqm_splice.py tools/test_sqm_splice.py
git commit -m "Append generated layers to a text mission.sqm without rewriting it

The repo's only sqm serialiser writes the binarized form and the shipped
file is text, so re-serialising would put the designer's thousands of
hand-placed objects behind a new component whose failure mode is silent
corruption. Splicing copies the source verbatim, which makes the shipped
file's diff empty by construction.

The brace scanner skips string literals because init strings contain
braces, and finds the root Entities structurally because every layer
contains one of its own.

Co-Authored-By: Microsoft Tay"
```

---

### Task 6: `map_codegen.py stage` — build the edit mission

**Files:**
- Create: `tools/map_codegen.py`
- Create: `.gitignore` entry for the edit mission

**Interfaces:**
- Consumes: `sqm_frame`, `sqm_splice`, `sqm_read`.
- Produces:
  - `build_layer(name: str, entities: list[dict], first_id: int, item_index: int) -> str` — entity dicts take keys `cls`, `world` (x,y,z), `dir`, `up`, `init`, `desc`. `item_index` is the root `class ItemN` number the block will occupy.
  - `stage() -> str` writing `MaldenEdit.Malden/mission.sqm`, returning its path
  - Layer names `AP_MAPDATA`, `AP_CUSTOM_P3D`; generated ids from 900000

**`item_index` is a parameter, not a `%d` left in the returned string.** Init strings are full of
`format ["%1 ..."]`, so a later `block % n` would raise or corrupt on the first NPC row.

- [ ] **Step 1: Write the failing test**

Create `tools/test_map_codegen.py`:

```python
#!/usr/bin/env python3
"""Tests for tools/map_codegen.py.  Run: python3 tools/test_map_codegen.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_codegen
import sqm_read

FAILS = []


def check(name, cond):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        FAILS.append(name)


ents = [
    {"cls": "Land_A_F", "world": (10.0, 20.0, 41.2),
     "dir": (0.0, 1.0, 0.0), "up": (0.0, 0.0, 1.0), "init": "", "desc": ""},
    {"cls": "C_man_1", "world": (30.0, 40.0, 42.7),
     "dir": (1.0, 0.0, 0.0), "up": (0.0, 0.0, 1.0),
     "init": '[_this,"STAND_U1"] call NPC_fnc_shops;', "desc": "AP_SERVERSIDE"},
]

block = map_codegen.build_layer("AP_MAPDATA", ents, 900000, 1)
node = sqm_read._parse_text("class Mission{class Entities{items=2;\n" + block + "};};")

objs = [n for n in sqm_read.walk(node) if n["props"].get("dataType") == "Object"]
check("two objects emitted", len(objs) == 2)
check("class carried", {o["props"]["type"] for o in objs} == {"Land_A_F", "C_man_1"})

pos = objs[0]["subs"]["PositionInfo"]["props"]["position"]
check("position reordered to {x, elevation, y}",
      [round(float(v), 3) for v in pos] == [10.0, 41.2, 20.0])

init = objs[1]["subs"]["Attributes"]["props"]["init"]
check("init text survives the quoting round-trip",
      init == '[_this,"STAND_U1"] call NPC_fnc_shops;')

ids = sorted(o["props"]["id"] for o in objs)
check("ids from the reserved band", ids[0] >= 900000)
check("ids unique", len(set(ids)) == len(ids))

layers = [n for n in sqm_read.walk(node) if n["props"].get("dataType") == "Layer"]
check("one layer, correctly named",
      len(layers) == 1 and layers[0]["props"]["name"] == "AP_MAPDATA")

# angles must round-trip back to the vectors we asked for
import sqm_frame
ang = objs[0]["subs"]["PositionInfo"]["props"]["angles"]
d, u = sqm_frame.angles_to_vectors([float(v) for v in ang])
check("dir round-trips", all(abs(a - b) < 1e-5 for a, b in zip(d, ents[0]["dir"])))
check("up round-trips", all(abs(a - b) < 1e-5 for a, b in zip(u, ents[0]["up"])))

print("\n%d failure(s)" % len(FAILS))
sys.exit(1 if FAILS else 0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_map_codegen.py`
Expected: `ModuleNotFoundError: No module named 'map_codegen'`

- [ ] **Step 3: Write the implementation**

Create `tools/map_codegen.py`:

```python
#!/usr/bin/env python3
"""The map pipeline: code arrays <-> a generated 3DEN edit mission. See mapedit.md.

    python3 tools/map_codegen.py stage     # build MaldenEdit.Malden/mission.sqm
    python3 tools/map_codegen.py apply     # rewrite the code arrays from it

MaldenEdit.Malden is GENERATED and NEVER PACKED. That is the whole safety argument: the shipped
mission.sqm never gains code-spawned content, so it cannot ship them twice -- once as engine
entities and once from the arrays. Stripping them at pack time would work too, but its failure
mode is a silent double-spawn of 8,717 objects, and this repo has shipped that class of damage
twice already.
"""
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sqm_frame
import sqm_read
import sqm_splice

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MISSION = os.path.join(REPO, "mission", "Armapunk2035.Malden")
SHIPPED_SQM = os.path.join(MISSION, "mission.sqm")
MAPDATA = os.path.join(MISSION, "core", "config", "fn_mapData.sqf")
EDIT_DIR = os.environ.get(
    "AP_EDIT_MISSION",
    os.path.expanduser("~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/"
                       "steamuser/Documents/Arma 3/mpmissions/MaldenEdit.Malden"))

LAYER_MAPDATA = "AP_MAPDATA"
LAYER_P3D = "AP_CUSTOM_P3D"
ID_BASE = 900000          # reserved band -- the designer's ids are five digits


def _q(s):
    """Quote for a .sqm string: a literal quote is doubled, never backslash-escaped."""
    return '"%s"' % s.replace('"', '""')


def build_layer(name, entities, first_id, item_index):
    """One `class ItemN` Layer block holding `entities`, ready to splice as a root item.

    item_index is passed in rather than left as a %d in the returned text: init strings are full
    of format ["%1 ..."], so deferring the substitution would raise -- or worse, silently mangle
    an NPC's shop logic -- on the first row carrying one.
    """
    t = "\t"
    out = []
    layer_id = first_id
    out.append('%sclass Item%d\n%s{\n' % (t * 2, item_index, t * 2))
    out.append('%sdataType="Layer";\n' % (t * 3))
    out.append('%sname=%s;\n' % (t * 3, _q(name)))
    out.append('%sclass Entities\n%s{\n' % (t * 3, t * 3))
    out.append('%sitems=%d;\n' % (t * 4, len(entities)))
    for i, e in enumerate(entities):
        sx, sy, sz = sqm_frame.WORLD_TO_SQM_POS(e["world"])
        a0, a1, a2 = sqm_frame.vectors_to_angles(e["dir"], e["up"])
        out.append('%sclass Item%d\n%s{\n' % (t * 4, i, t * 4))
        out.append('%sdataType="Object";\n' % (t * 5))
        out.append('%sclass PositionInfo\n%s{\n' % (t * 5, t * 5))
        out.append('%sposition[]={%.4f,%.4f,%.4f};\n' % (t * 6, sx, sy, sz))
        out.append('%sangles[]={%.7f,%.7f,%.7f};\n' % (t * 6, a0, a1, a2))
        out.append('%s};\n' % (t * 5))
        out.append('%sside="Empty";\n' % (t * 5))
        out.append('%sflags=4;\n' % (t * 5))
        if e.get("init") or e.get("desc"):
            out.append('%sclass Attributes\n%s{\n' % (t * 5, t * 5))
            if e.get("init"):
                out.append('%sinit=%s;\n' % (t * 6, _q(e["init"])))
            if e.get("desc"):
                out.append('%sdescription=%s;\n' % (t * 6, _q(e["desc"])))
            out.append('%s};\n' % (t * 5))
        out.append('%sid=%d;\n' % (t * 5, first_id + 1 + i))
        out.append('%stype=%s;\n' % (t * 5, _q(e["cls"])))
        out.append('%s};\n' % (t * 4))
    out.append('%s};\n' % (t * 3))
    out.append('%sid=%d;\n' % (t * 3, layer_id))
    out.append('%s};\n' % (t * 2))
    return "".join(out)


def read_mapdata():
    """fn_mapData rows as entity dicts. Positions are world-frame (post-migration)."""
    sys.path.insert(0, os.path.join(REPO, "tools"))
    import mapdata_migrate
    rows = mapdata_migrate.parse_rows(open(MAPDATA).read())
    ents = []
    for r in rows:
        vm = re.match(r"\[\[([-\d.eE,]+)\],\[([-\d.eE,]+)\]\]$", r["vec"])
        if not vm:
            sys.exit("row has a scalar direction, not vectors: %s" % r["raw"][:100])
        d = tuple(float(v) for v in vm.group(1).split(","))
        u = tuple(float(v) for v in vm.group(2).split(","))
        ents.append({"cls": r["cls"], "world": r["pos"], "dir": d, "up": u,
                     "init": r["init"],
                     "desc": "AP_SERVERSIDE" if r["server"] == "true" else ""})
    return ents


def stage():
    ents = read_mapdata()
    n_items, _, _ = sqm_splice.find_mission_entities(open(SHIPPED_SQM).read())
    block = build_layer(LAYER_MAPDATA, ents, ID_BASE, n_items)
    out = sqm_splice.splice_layers(open(SHIPPED_SQM).read(), [block])

    # Everything except mission.sqm is SYMLINKED, not copied. description.ext #includes files in
    # subdirectories (dialog\MasterHandler.h, core\chatcom\..., and more), so a top-level file copy
    # opens in 3DEN with every include broken; and a deep copy would be a stale second copy of the
    # mission that silently drifts. Symlinks also match how the real mpmissions entries already
    # point at this repo. Only mission.sqm is a real file here, and it is the only thing 3DEN writes.
    os.makedirs(EDIT_DIR, exist_ok=True)
    for fname in os.listdir(MISSION):
        if fname == "mission.sqm":
            continue
        link = os.path.join(EDIT_DIR, fname)
        if os.path.islink(link) or os.path.exists(link):
            if os.path.islink(link):
                os.unlink(link)
            else:
                shutil.rmtree(link) if os.path.isdir(link) else os.unlink(link)
        os.symlink(os.path.join(MISSION, fname), link)
    path = os.path.join(EDIT_DIR, "mission.sqm")
    open(path, "w").write(out)

    ids_before = set(sqm_read.entity_ids(SHIPPED_SQM))
    ids_after = set(sqm_read.entity_ids(path))
    added = ids_after - ids_before
    if len(added) != len(ents) + 1:
        sys.exit("ABORT: expected %d new ids, got %d" % (len(ents) + 1, len(added)))
    if ids_before - ids_after:
        sys.exit("ABORT: staging lost %d designer ids" % len(ids_before - ids_after))
    print("staged %d mapData rows into %s" % (len(ents), path))
    print("designer entities preserved: %d" % len(ids_before))
    return path


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("stage", "apply"):
        sys.exit(__doc__)
    if sys.argv[1] == "stage":
        stage()
    else:
        sys.exit("apply is implemented in Task 7")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_map_codegen.py`
Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Stage for real and open it**

```bash
python3 tools/map_codegen.py stage
```

Expected: `staged 8717 mapData rows into .../MaldenEdit.Malden/mission.sqm` and a designer-entity count matching the shipped file.

Then launch Arma, open **MaldenEdit** in the 3DEN editor, and confirm: a layer named `AP_MAPDATA` exists with 8,717 entities, they are in the right places, and the designer's own layers are present and unchanged. **Confirm 3DEN's "Save scenario in binarized form" preference is OFF before saving anything.**

- [ ] **Step 6: Ignore the edit mission and commit**

```bash
echo "MaldenEdit.Malden/" >> .gitignore
git add tools/map_codegen.py tools/test_map_codegen.py .gitignore
git commit -m "Generate the 3DEN edit mission from the map array

MaldenEdit.Malden is generated and never packed, so the shipped
mission.sqm never gains code-spawned content and cannot ship them twice.
Stripping at pack time would also work, but its failure mode is a silent
double-spawn of 8,717 objects.

Co-Authored-By: SmarterChild"
```

---

### Task 7: `map_codegen.py apply` — write the arrays back

**Files:**
- Modify: `tools/map_codegen.py`
- Modify: `tools/test_map_codegen.py`

**Interfaces:**
- Consumes: `build_layer`, `read_mapdata`, `stage` from Task 6.
- Produces: `read_layer(sqm_path: str, name: str) -> list[dict]` and `apply(allow_deletes: bool=False) -> None`.

- [ ] **Step 1: Write the failing test**

Append to `tools/test_map_codegen.py`, before the final `print`/`sys.exit`:

```python
# --- round-trip: entities -> layer text -> entities ----------------------------------
import tempfile

block = map_codegen.build_layer("AP_MAPDATA", ents, 900000, 1)
doc = "class Mission{class Entities{items=2;\n" + block + "};};"
fd, tmp = tempfile.mkstemp(suffix=".sqm")
os.write(fd, doc.encode())
os.close(fd)

back = map_codegen.read_layer(tmp, "AP_MAPDATA")
check("round-trip row count", len(back) == len(ents))
check("round-trip class", [b["cls"] for b in back] == [e["cls"] for e in ents])
check("round-trip world position",
      all(all(abs(x - y) < 1e-3 for x, y in zip(b["world"], e["world"]))
          for b, e in zip(back, ents)))
check("round-trip dir",
      all(all(abs(x - y) < 1e-5 for x, y in zip(b["dir"], e["dir"]))
          for b, e in zip(back, ents)))
check("round-trip init", [b["init"] for b in back] == [e["init"] for e in ents])
check("round-trip server flag",
      [b["desc"] for b in back] == [e["desc"] for e in ents])
os.unlink(tmp)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_map_codegen.py`
Expected: `AttributeError: module 'map_codegen' has no attribute 'read_layer'`

- [ ] **Step 3: Write the implementation**

In `tools/map_codegen.py`, replace the `else: sys.exit("apply is implemented in Task 7")` branch and add these two functions above `main()`:

```python
def read_layer(sqm_path, name):
    """Every Object directly inside the named layer, as entity dicts in file order."""
    root = sqm_read.parse(sqm_path)
    for node in sqm_read.walk(root):
        p = node["props"]
        if p.get("dataType") != "Layer" or p.get("name") != name:
            continue
        ents = []
        holder = node["subs"].get("Entities")
        if not holder:
            return ents
        for key in sorted(holder["subs"], key=lambda k: int(k[4:]) if k[4:].isdigit() else 0):
            n = holder["subs"][key]
            q = n["props"]
            if q.get("dataType") != "Object":
                continue
            pi = n["subs"]["PositionInfo"]["props"]
            d, u = sqm_frame.angles_to_vectors(
                [float(v) for v in pi.get("angles", [0, 0, 0])])
            attrs = n["subs"].get("Attributes", {"props": {}})["props"]
            ents.append({"cls": q["type"],
                         "world": sqm_frame.SQM_POS_TO_WORLD(
                             [float(v) for v in pi["position"]]),
                         "dir": d, "up": u,
                         "init": attrs.get("init", ""),
                         "desc": attrs.get("description", "")})
        return ents
    return []


def apply(allow_deletes=False):
    path = os.path.join(EDIT_DIR, "mission.sqm")
    if not os.path.exists(path):
        sys.exit("no edit mission at %s -- run `stage` first" % path)
    ents = read_layer(path, LAYER_MAPDATA)
    if not ents:
        sys.exit("ABORT: layer %s is empty or missing -- refusing to erase the array"
                 % LAYER_MAPDATA)

    old = read_mapdata()
    delta = len(old) - len(ents)
    if delta > 0 and delta > 0.02 * len(old) and not allow_deletes:
        sys.exit("ABORT: %d rows would be deleted (%.1f%% of %d). Re-run with --allow-deletes "
                 "if that is intended." % (delta, 100.0 * delta / len(old), len(old)))

    rows = []
    for e in ents:
        d = ",".join("%.4f" % v for v in e["dir"])
        u = ",".join("%.4f" % v for v in e["up"])
        srv = "true" if e["desc"].strip() == "AP_SERVERSIDE" else "false"
        rows.append('["%s",[%.3f,%.3f,%.3f],[[%s],[%s]],"%s",%s]'
                    % (e["cls"], e["world"][0], e["world"][1], e["world"][2], d, u,
                       e["init"].replace('"', '""'), srv))
    out = "allLocalMapEntities=[" + ",".join(rows) + "];\n"
    shutil.copy(MAPDATA, MAPDATA + ".bak")
    open(MAPDATA, "w").write(out)
    print("applied %d rows (was %d, net %+d) -> %s" % (len(ents), len(old), -delta, MAPDATA))
    print("backup: %s.bak" % MAPDATA)
```

and change `main()`'s apply branch to:

```python
    else:
        apply("--allow-deletes" in sys.argv)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_map_codegen.py`
Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Prove the full round-trip changes nothing**

```bash
python3 tools/map_codegen.py stage
python3 tools/map_codegen.py apply
git diff --stat mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
```

Expected: **no diff**, or a diff only in numeric formatting. A stage→apply with no editing in between must be a no-op; anything else is data loss and must be fixed before Task 8.

Rows carrying a **loadout** (6th field) would lose it through this path, because the edit mission
has nowhere to put it. Measured 2026-07-31: **0 of the 8,717 rows carry one**, so there is nothing
to preserve. Re-check if that ever changes:

```bash
python3 -c "
import sys; sys.path.insert(0,'tools'); import mapdata_migrate as M
print(sum(1 for r in M.parse_rows(open(M.TARGET).read()) if r['tail'].strip()))"
```

Expected `0`. If non-zero, stop and add a `loadout` attribute to `build_layer`/`read_layer` first.

- [ ] **Step 6: Commit**

```bash
git add tools/map_codegen.py tools/test_map_codegen.py
git commit -m "Write the map array back from the edit mission

apply refuses an empty layer outright and aborts on a >2% net deletion
unless asked, because the failure that matters is not a bad number but a
silently emptied array.

Co-Authored-By: ELIZA"
```

---

### Task 8: End-to-end verification in the editor

No new code. This is the gate that proves the pipeline before more content is added to it.

**Files:** none.

- [ ] **Step 1: Stage, edit, apply**

```bash
python3 tools/map_codegen.py stage
```

Open **MaldenEdit** in 3DEN. In the `AP_MAPDATA` layer: move one recognisable object ~10 m, rotate a second one, and delete a third. Save (**not** binarized). Then:

```bash
python3 tools/map_codegen.py apply
git diff mission/Armapunk2035.Malden/core/config/fn_mapData.sqf | head -40
```

Expected: exactly three changes — one position, one orientation, one removed row — and nothing else.

- [ ] **Step 2: Deploy and confirm in-game**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```

Join and confirm the moved object is in its new place, the rotated one has its new heading, and the deleted one is gone.

- [ ] **Step 3: Confirm init fields survive a round-trip**

In the editor, find a shop NPC in `AP_MAPDATA` (its Init field will read `[_this,'STAND_U1',...] call NPC_fnc_shops;`), move it a few metres, save, apply, deploy. In-game the NPC must be in its new spot **and still offer its scroll-wheel shop action**. A missing action means the init field was lost — that is how the Athira cop shop was wiped once.

- [ ] **Step 4: Revert the test edits and commit nothing**

```bash
git checkout mission/Armapunk2035.Malden/core/config/fn_mapData.sqf
```

---

### Task 9: Custom `.p3d` buildings

**Files:**
- Modify: `tools/map_codegen.py`
- Modify: `tools/test_map_codegen.py`
- Modify (generated): `mission/Armapunk2035.Malden/custom_p3ds/malden_buildings.sqf`

**Interfaces:**
- Consumes: `build_layer`, `read_layer`, `stage`, `apply`.
- Produces: `read_p3d() -> list[dict]` and `write_p3d(entities) -> None`; anchors use `Land_HelipadEmpty_F` with `description` = `"<model>|<scale>"`.

- [ ] **Step 1: Write the failing test**

Append to `tools/test_map_codegen.py` before the final `print`/`sys.exit`:

```python
# --- custom .p3d anchors --------------------------------------------------------------
P3D_SRC = ('_o = createSimpleObject [_MALDEN + "BridgeStraight.p3d", '
           '[8512.527, 3765, 0], true]; _o setDir 0; _o setObjectScale 1;\n'
           '_o = createSimpleObject [_MALDEN + "HQMesh.p3d", '
           '[6221.131, 11978.708, -10.938], true]; _o setDir 180; _o setObjectScale 1.5;\n')

p3d = map_codegen.parse_p3d(P3D_SRC)
check("two p3d placements parsed", len(p3d) == 2)
check("model name kept", p3d[1]["model"] == "HQMesh")
check("scale kept", abs(p3d[1]["scale"] - 1.5) < 1e-9)
check("anchor class is the helipad", p3d[1]["cls"] == "Land_HelipadEmpty_F")
check("description carries model and scale", p3d[1]["desc"] == "HQMesh|1.5")
check("dir 180 becomes a yaw",
      abs(p3d[1]["dir"][0]) < 1e-6 and p3d[1]["dir"][1] < -0.999)

emitted = map_codegen.format_p3d(p3d)
check("emits both models",
      'BridgeStraight.p3d' in emitted and 'HQMesh.p3d' in emitted)
check("emits the original scale", 'setObjectScale 1.5' in emitted)
check("emits the original heading", 'setDir 180' in emitted)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_map_codegen.py`
Expected: `AttributeError: module 'map_codegen' has no attribute 'parse_p3d'`

- [ ] **Step 3: Write the implementation**

Add to `tools/map_codegen.py`:

```python
P3D_FILE = os.path.join(MISSION, "custom_p3ds", "malden_buildings.sqf")
P3D_LINE = re.compile(
    r'createSimpleObject \[_MALDEN \+ "([^"]+)\.p3d", '
    r'\[([-\d.]+), *([-\d.]+), *([-\d.]+)\], true\]; '
    r'_o setDir ([-\d.]+); _o setObjectScale ([-\d.]+);')


def parse_p3d(src):
    """The .p3d placements as anchor entity dicts.

    3DEN can only place entities that have a CfgVehicles class from an addon, and these are raw
    .p3d files inside the mission, so they can only be represented by an anchor. The model name
    and scale ride in the entity description because that is the field 3DEN preserves verbatim
    and never rewrites.
    """
    ents = []
    for m in P3D_LINE.finditer(src):
        model, x, y, z, d, s = m.groups()
        yaw = math.radians(float(d))
        dirv = (math.sin(yaw), math.cos(yaw), 0.0)
        ents.append({"cls": "Land_HelipadEmpty_F",
                     "world": (float(x), float(y), float(z)),
                     "dir": dirv, "up": (0.0, 0.0, 1.0), "init": "",
                     "desc": "%s|%s" % (model, s.rstrip("0").rstrip(".") if "." in s else s),
                     "model": model, "scale": float(s)})
    return ents


def format_p3d(ents):
    """Regenerate the placement lines. Header and helpers in the file are preserved by apply."""
    out = []
    for e in ents:
        model = e.get("model") or e["desc"].split("|")[0]
        scale = e.get("scale")
        if scale is None:
            scale = float(e["desc"].split("|")[1])
        yaw = math.degrees(math.atan2(e["dir"][0], e["dir"][1])) % 360.0
        out.append('_o = createSimpleObject [_MALDEN + "%s.p3d", [%.3f, %.3f, %.3f], true]; '
                   '_o setDir %s; _o setObjectScale %s;'
                   % (model, e["world"][0], e["world"][1], e["world"][2],
                      ("%g" % yaw), ("%g" % scale)))
    return "\n".join(out) + "\n"


def read_p3d():
    return parse_p3d(open(P3D_FILE).read())


def write_p3d(ents):
    """Replace only the generated placement lines; every comment in the file is preserved."""
    src = open(P3D_FILE).read()
    lines = src.splitlines(keepends=True)
    kept = [ln for ln in lines if not P3D_LINE.search(ln)]
    shutil.copy(P3D_FILE, P3D_FILE + ".bak")
    open(P3D_FILE, "w").write("".join(kept).rstrip("\n") + "\n" + format_p3d(ents))
```

Add `import math` to the imports. Then in `stage()`, build and splice a second layer, and in `apply()`, read it back:

```python
# in stage(), after the mapData block is built:
    p3d = read_p3d()
    block2 = build_layer(LAYER_P3D, p3d, ID_BASE + 100000, n_items + 1)
    out = sqm_splice.splice_layers(open(SHIPPED_SQM).read(), [block, block2])

# in apply(), after the mapData write:
    anchors = read_layer(path, LAYER_P3D)
    if anchors:
        write_p3d(anchors)
        print("applied %d custom .p3d placements -> %s" % (len(anchors), P3D_FILE))
```

Update `stage()`'s id assertion to expect `len(ents) + len(p3d) + 2` new ids (the two layer ids plus every entity).

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_map_codegen.py`
Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Verify the real round-trip is a no-op**

```bash
python3 tools/map_codegen.py stage
python3 tools/map_codegen.py apply
git diff --stat mission/Armapunk2035.Malden/custom_p3ds/malden_buildings.sqf
```

Expected: no diff, or formatting-only. Then in 3DEN confirm layer `AP_CUSTOM_P3D` holds 55 anchors.

Because helipad anchors render as nothing, draw the real models with the existing console line — 3DEN Debug Console:

```sqf
call compile preprocessFileLineNumbers "edenCB_refresh.sqf";
```

- [ ] **Step 6: Commit**

```bash
git add tools/map_codegen.py tools/test_map_codegen.py
git commit -m "Round-trip the custom .p3d buildings through the edit mission

3DEN can only place entities with an addon CfgVehicles class and these are
raw .p3d files inside the mission, so each becomes an anchor carrying its
model and scale in the description -- the one field 3DEN preserves verbatim.
The anchors render as nothing, so edenCB_refresh.sqf still draws the models
until the 3DEN mod lands.

Co-Authored-By: Clippy"
```

---

### Task 10: Composition zones

**Files:**
- Modify: `tools/map_codegen.py`
- Modify: `tools/test_map_codegen.py`
- Modify (generated): `mission/Armapunk2035.Malden/compositions/zone_*.sqf`

**Interfaces:**
- Consumes: everything from Tasks 6, 7, 9.
- Produces: `read_zones() -> dict[str, list[dict]]`, `write_zone(name, entities) -> None`; layers named `AP_COMP_<name>`.

- [ ] **Step 1: Write the failing test**

Append to `tools/test_map_codegen.py` before the final `print`/`sys.exit`:

```python
# --- composition zones ----------------------------------------------------------------
ZONE = ('["Land_A_F",[10.0,20.0,41.2],[[0.0,1.0,0.0],[0.0,0.0,1.0]],true],'
        '["Land_B_F",[11.0,21.0,41.5],[[1.0,0.0,0.0],[0.0,0.0,1.0]],false]')
z = map_codegen.parse_zone(ZONE)
check("zone rows parsed", len(z) == 2)
check("zone world position", z[0]["world"] == (10.0, 20.0, 41.2))
check("zone simple-object flag kept in desc", z[1]["desc"] == "AP_NEEDSIM")
check("zone emit round-trips", map_codegen.parse_zone(
    map_codegen.format_zone(z)) [1]["desc"] == "AP_NEEDSIM")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tools/test_map_codegen.py`
Expected: `AttributeError: module 'map_codegen' has no attribute 'parse_zone'`

- [ ] **Step 3: Write the implementation**

Add to `tools/map_codegen.py`:

```python
COMP_DIR = os.path.join(MISSION, "compositions")
ZONE_ROW = re.compile(
    r'\["([^"]+)",\[([-\d.eE]+),([-\d.eE]+),([-\d.eE]+)\],'
    r'\[\[([-\d.eE,]+)\],\[([-\d.eE,]+)\]\],(true|false)\]')


def parse_zone(src):
    """Rows of a compositions/zone_*.sqf object array.

    The 5th field is the simple-object flag: false means createVehicleLocal instead, for pieces
    that need working doors or animation. It rides in the description as AP_NEEDSIM so 3DEN
    cannot quietly drop it.
    """
    ents = []
    for m in ZONE_ROW.finditer(src):
        cls, x, y, z, d, u, simple = m.groups()
        ents.append({"cls": cls, "world": (float(x), float(y), float(z)),
                     "dir": tuple(float(v) for v in d.split(",")),
                     "up": tuple(float(v) for v in u.split(",")),
                     "init": "",
                     "desc": "" if simple == "true" else "AP_NEEDSIM"})
    return ents


def format_zone(ents):
    rows = []
    for e in ents:
        d = ",".join("%.4f" % v for v in e["dir"])
        u = ",".join("%.4f" % v for v in e["up"])
        simple = "false" if e["desc"].strip() == "AP_NEEDSIM" else "true"
        rows.append('["%s",[%.3f,%.3f,%.3f],[[%s],[%s]],%s]'
                    % (e["cls"], e["world"][0], e["world"][1], e["world"][2], d, u, simple))
    return ",".join(rows)


def zone_files():
    if not os.path.isdir(COMP_DIR):
        return []
    return sorted(f for f in os.listdir(COMP_DIR)
                  if f.startswith("zone_") and f.endswith(".sqf"))


def read_zones():
    out = {}
    for f in zone_files():
        name = f[len("zone_"):-len(".sqf")]
        out[name] = parse_zone(open(os.path.join(COMP_DIR, f)).read())
    return out


def write_zone(name, ents):
    """Replace only the object array inside the zone file; its knobs and comments stay."""
    path = os.path.join(COMP_DIR, "zone_%s.sqf" % name)
    src = open(path).read()
    first = ZONE_ROW.search(src)
    if not first:
        sys.exit("no object rows found in %s -- refusing to guess where they go" % path)
    last = None
    for last in ZONE_ROW.finditer(src):
        pass
    shutil.copy(path, path + ".bak")
    open(path, "w").write(src[:first.start()] + format_zone(ents) + src[last.end():])
```

In `stage()`, add one layer per zone; in `apply()`, write each back:

```python
# stage(): after block2
    blocks = [block, block2]
    zones = sorted(read_zones().items())
    for i, (name, ents_z) in enumerate(zones):
        blocks.append(build_layer("AP_COMP_%s" % name, ents_z,
                                  ID_BASE + 200000 + i * 10000, n_items + 2 + i))
    out = sqm_splice.splice_layers(open(SHIPPED_SQM).read(), blocks)

# apply(): after the p3d write
    for name in read_zones():
        z = read_layer(path, "AP_COMP_%s" % name)
        if z:
            write_zone(name, z)
            print("applied %d pieces -> compositions/zone_%s.sqf" % (len(z), name))
```

Replace `stage()`'s id assertion with one that counts every layer and every entity:

```python
    expected = len(ents) + len(p3d) + sum(len(z) for _, z in zones) + 2 + len(zones)
    if len(added) != expected:
        sys.exit("ABORT: expected %d new ids, got %d" % (expected, len(added)))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tools/test_map_codegen.py`
Expected: every line `ok`, `0 failure(s)`, exit 0.

- [ ] **Step 5: Verify the round-trip**

```bash
python3 tools/map_codegen.py stage && python3 tools/map_codegen.py apply
git diff --stat mission/Armapunk2035.Malden/compositions/
```

Expected: no diff, or formatting-only.

- [ ] **Step 6: Commit**

```bash
git add tools/map_codegen.py tools/test_map_codegen.py
git commit -m "Round-trip composition zones through the edit mission

The 5th field -- simple object versus createVehicleLocal, which decides
whether a piece has working doors -- rides in the description so 3DEN
cannot quietly drop it.

Co-Authored-By: Dr. Sbaitso"
```

---

### Task 11: `edit-map.sh` — the one command

**Files:**
- Create: `tools/edit-map.sh`

**Interfaces:**
- Consumes: `map_codegen.py stage` / `apply`.
- Produces: `tools/edit-map.sh [stage|apply]`, defaulting to `stage`.

- [ ] **Step 1: Write the script**

Create `tools/edit-map.sh`:

```bash
#!/usr/bin/env bash
# The map-editing entry point (mapedit.md).
#
#   tools/edit-map.sh          stage the edit mission and print what to do next
#   tools/edit-map.sh apply    write everything back into the code arrays
#
# The edit mission is generated and NEVER packed; the shipped mission.sqm never gains
# code-spawned content. Never save the SHIPPED mission from 3DEN -- only MaldenEdit.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

case "${1:-stage}" in
  stage)
    python3 tools/map_codegen.py stage
    cat <<'EOF'

Next:
  1. Launch Arma 3 and open the "MaldenEdit" mission in the 3DEN editor.
  2. Check Preferences -> "Save scenario in binarized form" is OFF (once per machine).
  3. Drag things around. The generated layers are AP_MAPDATA, AP_CUSTOM_P3D, AP_COMP_*.
     The custom .p3d anchors are invisible; draw their models with, in the Debug Console:
         call compile preprocessFileLineNumbers "edenCB_refresh.sqf";
  4. Save (MaldenEdit only -- never the shipped mission).
  5. tools/edit-map.sh apply
EOF
    ;;
  apply)
    python3 tools/map_codegen.py apply "${@:2}"
    echo
    echo "Review before committing:  git diff --stat"
    echo "Deploy to dev:             bash /home/timb/arma3server_dev/reload-armapunk2035.sh"
    ;;
  *)
    echo "usage: tools/edit-map.sh [stage|apply]" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 2: Make it executable and run both halves**

```bash
chmod +x tools/edit-map.sh
tools/edit-map.sh
tools/edit-map.sh apply
git diff --stat
```

Expected: staging succeeds and prints the instructions; apply succeeds; `git diff --stat` shows nothing (or formatting only), because nothing was edited in between.

- [ ] **Step 3: Commit**

```bash
git add tools/edit-map.sh
git commit -m "Add the one-command map editing entry point

Co-Authored-By: Microsoft Tay"
```

---

### Task 12: Documentation and the rule split

The old rule — "DO NOT SAVE the mission in 3DEN" — becomes two rules, one per file. A half-updated rule here is worse than the old one.

**Files:**
- Modify: `tools/MAP_EDITING.md`
- Modify: `CLAUDE.md`
- Modify: `mapedit.md`

- [ ] **Step 1: Rewrite `tools/MAP_EDITING.md`**

Put a new section at the very top, above the existing region-pipeline documentation:

```markdown
# Editing the map (current pipeline)

    tools/edit-map.sh            # stage MaldenEdit.Malden from the code arrays
    # ...open MaldenEdit in 3DEN, drag things, save...
    tools/edit-map.sh apply      # write it all back

Everything code-spawned is in there: the ~8,700 mapData rows (layer `AP_MAPDATA`), the 55
custom .p3d buildings (`AP_CUSTOM_P3D`), and every composition zone (`AP_COMP_<name>`).
Design and rationale: `mapedit.md`. Frames: `tools/sqm_frame.py`.

**Two missions, one rule each.**
  * `mission/Armapunk2035.Malden/mission.sqm` -- the SHIPPED file. **Never save it from 3DEN.**
    A save re-bakes the script-spawned world into it; an autosave did exactly that on 2026-07-26.
  * `MaldenEdit.Malden` -- GENERATED, never packed, git-ignored. **Saving it is the point.**

The four pipelines below (eden_region, compExport/compImport, mapdata_all, edenNPC/edenCB) are
superseded for routine work. They are kept because they still run in the engine, which is the
only way to recover if the offline conversion is ever in doubt.
```

- [ ] **Step 2: Update `CLAUDE.md`**

In the "Working rules" section, replace the sentence in the `mission.sqm` bullet that reads
"**3DEN re-binarizes on save unless its "Save scenario in binarized form" preference is off.**"
by appending after it:

```markdown
  **Two missions, one rule each (owner 2026-07-31):** never save the SHIPPED `mission.sqm` from
  3DEN — that is the re-bake that added 15,642 objects. The generated `MaldenEdit.Malden`
  (`tools/edit-map.sh`) is the file you *do* save; it is git-ignored and never packed. Map editing
  goes through `tools/edit-map.sh`; see `mapedit.md`.
```

- [ ] **Step 3: Mark the spec's phases done**

In `mapedit.md`, change the Phases table rows for 0, 1 and 2 to say `DONE 2026-07-31` and note that Phase 3 delivered `edit-map.sh` but not the `@AP_eden` mod, so the `.p3d` visuals still need one console line.

- [ ] **Step 4: Verify no stale instructions remain**

```bash
grep -n "DO NOT SAVE" tools/MAP_EDITING.md CLAUDE.md
grep -rn "mapImportAll\|edenNPC_import\|edenCB_import" tools/MAP_EDITING.md | head
```

Expected: every "DO NOT SAVE" hit now names *which* mission it applies to; the old pipelines are only referenced under the "superseded" heading.

- [ ] **Step 5: Commit**

```bash
git add tools/MAP_EDITING.md CLAUDE.md mapedit.md
git commit -m "Document the map pipeline and split the save rule per mission

'Never save in 3DEN' was one rule covering two files with opposite
requirements. It is now one rule each: never save the shipped mission,
always save the generated one.

Co-Authored-By: SmarterChild"
```

---

## Not in this plan

- **`@AP_eden`, the 3DEN mod** (spec Phase 3) — a `Cfg3DEN` event handler to draw the `.p3d`
  models automatically and add toolbar buttons. It is what removes the last console line. Its own
  plan; it is optional infrastructure and the pipeline works without it.
- **Cartel flags, spawn markers, `replace_sheds`** — deliberately out of scope per `mapedit.md`.
- **Markers generally** — already covered by the standing rule (place in the shipped `mission.sqm`
  via 3DEN).
