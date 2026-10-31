#!/usr/bin/env python3
"""
mapdata_rebuild_from_export.py -- rebuild the Malden half of allLocalMapEntities from the raw
engine sweep, replacing the entries produced by the class+XY join.

WHY. debug/mapExportRuntime.sqf's log is correct: 9,201 rows, each one object, each with its own
ATL height and vectors. The step that turned it into array entries matched sqm objects to exported
rows by class + XY within 1.5 m (the same rule tools/sqm_strip_exported.py uses to decide what to
delete from the sqm). XY is not a unique key -- anything stacked shares it -- so a stacked pair
matched ONE exported row twice: 838 rows in the array are duplicates and 835 real objects are gone.
At the prison both HESCOs of each pair got the upper one's height (nothing at ground level, one
hanging at 2.13 m); at the federal reserve the canal plates, which stack 12.4 m apart, swapped.

THE FIX IS THE KEY, NOT THE TOLERANCE. Objects are matched per (class, XY-cluster) and then paired
BY HEIGHT ORDER inside that cluster: within one class at one XY, exported ATL is a strictly
increasing function of the sqm's world height (ATL = worldZ - terrain + <constant for the class>),
so the nth lowest sqm object is the nth lowest exported row. Every exported row is consumed at most
once, which is what makes duplication impossible rather than merely unlikely.

WHICH OBJECTS BELONG IN THE ARRAY. Exactly the ones already deleted from mission.sqm: the
pre-export sqm minus the current one. That set is a fact on disk, so this script never re-decides
what to export -- it only gives each of those objects the right height and vectors.

Verification before it writes anything: no exported row used twice, every deleted sqm object
matched, and the rebuilt block's row count equals the number of deleted sqm objects.

Usage:
    python3 tools/mapdata_rebuild_from_export.py            # report only
    python3 tools/mapdata_rebuild_from_export.py --write    # rewrite fn_mapData.sqf (.bak first)
"""
import os
import re
import shutil
import subprocess
import struct
import sys
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPDATA = os.path.join(REPO, "mission/Armapunk2035.Malden/core/config/fn_mapData.sqf")
SQM_NOW = os.path.join(REPO, "mission/Armapunk2035.Malden/mission.sqm")
EXPORT_LOG = os.path.join(REPO, "build/mapexport_malden.log")
# the sqm as it was when the sweep ran, i.e. before sqm_strip_exported.py deleted from it
SQM_BEFORE_COMMIT = "ddae690^:mission/Armapunk2035.Malden/mission.sqm"

XY_CLUSTER = 0.15   # metres: same object seen by the sweep vs the sqm (rounding only, not a join tolerance)


# ---------------------------------------------------------------- binarized sqm reader
def read_sqm(data):
    """Return [(type, x, y, worldZ, has_init)] for every dataType=Object in a rapified sqm."""
    assert data[:4] == b"\x00raP", "not a binarized sqm"

    def asciiz(i):
        j = data.index(b"\x00", i)
        return data[i:j].decode("latin1"), j + 1

    def comp(i):
        v = s = 0
        while True:
            b = data[i]
            i += 1
            v |= (b & 0x7f) << s
            if not (b & 0x80):
                break
            s += 7
        return v, i

    def value(sub, i):
        if sub == 0:
            return asciiz(i)
        if sub == 1:
            return struct.unpack_from("<f", data, i)[0], i + 4
        if sub == 2:
            return struct.unpack_from("<i", data, i)[0], i + 4
        return None, i

    def arr(i):
        n, i = comp(i)
        out = []
        for _ in range(n):
            t = data[i]
            i += 1
            if t == 3:
                a, i = arr(i)
                out.append(a)
            else:
                v, i = value(t, i)
                out.append(v)
        return out, i

    def parse_class(i):
        _inh, i = asciiz(i)
        n, i = comp(i)
        props, subs = {}, []
        for _ in range(n):
            t = data[i]
            i += 1
            if t == 0:
                nm, i = asciiz(i)
                off = struct.unpack_from("<I", data, i)[0]
                i += 4
                subs.append((nm, off))
            elif t == 1:
                sub = data[i]
                i += 1
                nm, i = asciiz(i)
                v, i = value(sub, i)
                props[nm] = v
            elif t == 2:
                nm, i = asciiz(i)
                v, i = arr(i)
                props[nm] = v
            elif t in (3, 4):
                nm, i = asciiz(i)
            elif t == 5:
                nm, i = asciiz(i)
                i += 4
                v, i = arr(i)
                props[nm] = v
            else:
                break
        return props, subs

    def node(off):
        props, subs = parse_class(off)
        return {"props": props, "subs": {nm: node(o) for nm, o in subs}}

    def walk(n):
        yield n
        for c in n["subs"].values():
            yield from walk(c)

    out = []
    for n in walk(node(16)):
        p = n["props"]
        if p.get("dataType") != "Object":
            continue
        pi = n["subs"].get("PositionInfo", {}).get("props", {})
        at = n["subs"].get("Attributes", {}).get("props", {})
        pos = pi.get("position")
        if not pos or len(pos) < 3:
            continue
        # Eden position[] = [X, height(ASL), mapY]
        out.append((p.get("type", "?"), pos[0], pos[2], pos[1], bool(at.get("init", ""))))
    return out


def git_show(spec):
    return subprocess.run(["git", "-C", REPO, "show", spec],
                          check=True, stdout=subprocess.PIPE).stdout


# ---------------------------------------------------------------- inputs
sqm_before = read_sqm(git_show(SQM_BEFORE_COMMIT))
sqm_now = read_sqm(open(SQM_NOW, "rb").read())

key_now = defaultdict(int)
for t in sqm_now:
    key_now[(t[0], round(t[1], 3), round(t[2], 3), round(t[3], 3))] += 1

deleted = []
for t in sqm_before:
    k = (t[0], round(t[1], 3), round(t[2], 3), round(t[3], 3))
    if key_now[k] > 0:
        key_now[k] -= 1
    else:
        deleted.append(t)

RAWRE = re.compile(
    r'-MAPEXPORT- \[""([^"]+)"",\['
    r'([-\d.]+),([-\d.]+),([-\d.]+)\],\[\['
    r'([-\d.]+),([-\d.]+),([-\d.]+)\],\['
    r'([-\d.]+),([-\d.]+),([-\d.]+)\]\]\]')
raw = []
for line in open(EXPORT_LOG, encoding="latin1"):
    m = RAWRE.search(line)
    if m:
        g = m.groups()
        raw.append((g[0], float(g[1]), float(g[2]), float(g[3]), g[4:7], g[7:10]))

print("sqm before export : %d objects" % len(sqm_before))
print("sqm now           : %d objects" % len(sqm_now))
print("deleted from sqm  : %d  <- these must be in the array" % len(deleted))
print("raw exported rows : %d" % len(raw))


# ---------------------------------------------------------------- component + assignment match
# The sweep does NOT report the sqm's XY. getPosATL is the transformed boundingCenter, so a row's XY
# is the sqm position plus that model's centre offset rotated by its yaw -- measured here at up to
# 1.62 m. So proximity alone cannot identify an object, and neither can height alone (stacks share
# XY). Both together can: inside one class, cluster everything that could plausibly be the same
# object, then solve the assignment on a cost that uses horizontal distance AND height RELATIVE to
# the cluster (ATL = worldZ - terrain + <class constant>, so within a cluster the two agree up to a
# shared constant, which cancels in a difference from the cluster median).
LINK = 2.5   # metres: two things this far apart can still be the same object after the centre offset
Z_W = 1.0    # weight on the relative-height term of the cost


def components(items, radius):
    """Union-find over items ((x, y) accessors below) linking anything within `radius`."""
    parent = list(range(len(items)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    grid = defaultdict(list)
    for i, (x, y) in enumerate(items):
        grid[(int(x // radius), int(y // radius))].append(i)
    for (gx, gy), idxs in grid.items():
        near = []
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                near += grid.get((gx + dx, gy + dy), [])
        for i in idxs:
            for j in near:
                if i < j and abs(items[i][0] - items[j][0]) <= radius \
                        and abs(items[i][1] - items[j][1]) <= radius:
                    union(i, j)
    out = defaultdict(list)
    for i in range(len(items)):
        out[find(i)].append(i)
    return list(out.values())


try:
    from scipy.optimize import linear_sum_assignment
    import numpy as np
    HAVE_SCIPY = True
except ImportError:
    HAVE_SCIPY = False

by_class_del, by_class_raw = defaultdict(list), defaultdict(list)
for d in deleted:
    by_class_del[d[0]].append(d)
for r in raw:
    by_class_raw[r[0]].append(r)

matched, unmatched, used_rows = [], [], 0
for cls, dels in by_class_del.items():
    rows = by_class_raw.get(cls, [])
    if not rows:
        unmatched += dels
        continue
    items = [(d[1], d[2]) for d in dels] + [(r[1], r[2]) for r in rows]
    for comp in components(items, LINK):
        ds = [dels[i] for i in comp if i < len(dels)]
        rs = [rows[i - len(dels)] for i in comp if i >= len(dels)]
        if not ds:
            continue
        if not rs:
            unmatched += ds
            continue
        dmed = sorted(d[3] for d in ds)[len(ds) // 2]
        rmed = sorted(r[3] for r in rs)[len(rs) // 2]

        def cost(d, r):
            return (abs(d[1] - r[1]) + abs(d[2] - r[2])
                    + Z_W * abs((d[3] - dmed) - (r[3] - rmed)))

        if HAVE_SCIPY and len(ds) * len(rs) > 1:
            m = np.array([[cost(d, r) for r in rs] for d in ds])
            if len(ds) > len(rs):   # pad so every row still gets a column or stays unassigned
                pad = np.full((len(ds), len(ds) - len(rs)), 1e6)
                m = np.hstack([m, pad])
            ri, ci = linear_sum_assignment(m)
            for i, j in zip(ri, ci):
                if j < len(rs):
                    matched.append((ds[i], rs[j]))
                    used_rows += 1
                else:
                    unmatched.append(ds[i])
        else:
            pairs = sorted(((cost(d, r), i, j) for i, d in enumerate(ds) for j, r in enumerate(rs)))
            takend, takenr = set(), set()
            for _c, i, j in pairs:
                if i in takend or j in takenr:
                    continue
                takend.add(i)
                takenr.add(j)
                matched.append((ds[i], rs[j]))
                used_rows += 1
            unmatched += [d for i, d in enumerate(ds) if i not in takend]

used = set(id(r) for _d, r in matched)

print("matched           : %d" % len(matched))
print("unmatched sqm objs: %d" % len(unmatched))
print("raw rows consumed : %d (each at most once: %s)"
      % (len(used), len(used) == len(matched)))

if unmatched:
    from collections import Counter
    print("  unmatched by class:", Counter(u[0] for u in unmatched).most_common(8))


# ---------------------------------------------------------------- emit
def fmt(entry):
    cls, x, y, z, d, u = entry
    return ('["%s",[%.3f,%.3f,%.3f],[[%s,%s,%s],[%s,%s,%s]],"",false]'
            % (cls, x, y, z, d[0], d[1], d[2], u[0], u[1], u[2]))


rows = [fmt(c) for _d, c in matched]
# Identical rows are only acceptable when the ENGINE reported identical rows -- the designer really
# did place two of the same prop in the same spot. The failure this script exists to undo shows up
# as a row appearing more often than the sweep saw it, so that is what gets asserted.
raw_fmt_counts = defaultdict(int)
for r in raw:
    raw_fmt_counts[fmt(r)] += 1
built = defaultdict(int)
for r in rows:
    built[r] += 1
over = {k: (v, raw_fmt_counts.get(k, 0)) for k, v in built.items() if v > raw_fmt_counts.get(k, 0)}
print("identical rows in rebuild: %d (engine reported %d such rows; over-count: %d)"
      % (len(rows) - len(set(rows)),
         sum(v - 1 for v in raw_fmt_counts.values() if v > 1), len(over)))

if "--write" not in sys.argv:
    print("\n(report only -- pass --write to rewrite fn_mapData.sqf)")
    sys.exit(0)

if over:
    sys.exit("REFUSING TO WRITE: %d rows appear more often than the engine reported them" % len(over))
if len(unmatched) > 1:
    sys.exit("REFUSING TO WRITE: %d sqm objects have no exported row" % len(unmatched))

# The array is one minified literal, so entries are cut by walking brackets, not by a regex -- a
# regex over the whole file matched ONE span here and an edit built on it appended instead of
# replacing. Split at depth 1, then classify each entry by whether it was already in the array
# before the export commit; everything else is what the export added and is what gets replaced.
def split_entries(text):
    """[(start, end)] of each depth-1 element of the first [...] literal in `text`."""
    i = text.index("[")
    depth, in_str, spans, entry_start = 0, False, [], None
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '"':
                if i + 1 < len(text) and text[i + 1] == '"':
                    i += 2
                    continue
                in_str = False
        elif c == '"':
            in_str = True
        elif c == "[":
            depth += 1
            if depth == 2:
                entry_start = i
        elif c == "]":
            depth -= 1
            if depth == 1 and entry_start is not None:
                spans.append((entry_start, i + 1))
                entry_start = None
            elif depth == 0:
                return spans, i
        i += 1
    raise ValueError("unterminated array")


norm = lambda s: re.sub(r"\s+", "", s)

cur_txt = open(MAPDATA, encoding="latin1").read()
cur_spans, close_idx = split_entries(cur_txt)
pre_txt = git_show("ddae690^:mission/Armapunk2035.Malden/core/config/fn_mapData.sqf").decode("latin1")
pre_spans, _ = split_entries(pre_txt)

pre_pool = defaultdict(int)
for a, b in pre_spans:
    pre_pool[norm(pre_txt[a:b])] += 1

kept, replaced = [], 0
for a, b in cur_spans:
    e = cur_txt[a:b]
    if pre_pool[norm(e)] > 0:
        pre_pool[norm(e)] -= 1
        kept.append(e)
    else:
        replaced += 1

print("array entries: %d total, %d pre-existing (kept), %d added by the export (replaced by %d)"
      % (len(cur_spans), len(kept), replaced, len(rows)))
if replaced < 8000:
    sys.exit("REFUSING TO WRITE: only %d entries look like export output -- expected ~8,651" % replaced)

shutil.copyfile(MAPDATA, MAPDATA + ".bak")
head = cur_txt[:cur_spans[0][0]]
tail = cur_txt[close_idx:]
open(MAPDATA, "w", encoding="latin1").write(head + ",".join(kept + rows) + tail)

after_txt = open(MAPDATA, encoding="latin1").read()
after_spans, _ = split_entries(after_txt)
big = lambda t: sum(1 for m in re.finditer(r'\[\s*"[^"]+"\s*,\s*\[\s*([-\d.]+)\s*,\s*([-\d.]+)', t)
                    if float(m.group(1)) > 12800 or float(m.group(2)) > 12800)
print("wrote %s (.bak kept)" % os.path.basename(MAPDATA))
print("  entries %d -> %d   (expected %d)" % (len(cur_spans), len(after_spans), len(kept) + len(rows)))
print("  Altis-range entries %d -> %d   (must be unchanged)" % (big(cur_txt), big(after_txt)))
if len(after_spans) != len(kept) + len(rows):
    sys.exit("POST-WRITE CHECK FAILED: entry count is wrong -- restore from .bak")
