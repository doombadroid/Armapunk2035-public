#!/usr/bin/env python3
"""
roadgraph_build.py -- build the routing graph from a LoonyDev road dump.

Input: an RPT/loonydev.log containing -ROADDUMP-/-NAMEDUMP- lines emitted by
mission debug/roadDump.sqf. Each road line is a JSON array:

  ["key","type",width,isPed,isBridge,[begX,begY],[endX,endY],["connKey",...]]

Model: a POINT graph. Nodes are segment endpoints clustered within CLUSTER
metres (junction pieces overlap, so several segments share each corner);
every road segment becomes one edge between its two endpoint nodes. This is
the standard road-network shape -- degree at a point IS the junction arity.
(v1 used segment-as-node + endpoint snapping; junction endpoint clusters
turned into cliques and the collapse emitted 400k bogus edges. Points, not
segments.)

Pipeline:
  1. parse segments + POI names
  2. cluster endpoints (union-find, spatial hash) -> point nodes
  3. edges = segments between nodes (self-loops from clustering dropped)
  4. seam-stitch: components other than the main one get joined to the
     nearest main-component node within STITCH metres (bridge seams etc.)
  5. collapse degree-2 chains -> junction graph with polyline edges for A*
  6. emit build/roadgraph.json, build/roadgraph_preview.svg, stats to stdout

Usage: tools/roadgraph_build.py <logfile> [--out build/]
"""
import json
import math
import re
import sys
from collections import defaultdict
from pathlib import Path

CLUSTER = 2.5   # metres: endpoints closer than this are the same junction point
STITCH = 12.0   # metres: max gap the cross-component seam-stitch will bridge

# Bridges the map DESIGNER placed as mission .p3d objects (malden_buildings.sqf) are not engine road
# pieces, so roadDump cannot see them: the banks they join come out as separate components and no
# vehicle can route between them. STITCH only spans 12m; these gaps are hundreds of metres by design,
# so they have to be declared. Each entry is (pointA, pointB, why) in world coords -- the nearest
# graph node to each point is joined by one edge.
# "via" carries the REAL deck centreline. A straight node-to-node link is not enough: the nearest
# graph nodes sit on the approach roads, 24-30m to the side of the deck, so a car steering at the
# line drove off the bridge. "step" densifies the polyline into intermediate nodes -- the GPS HUD
# measures off-route distance to the nearest route VERTEX (fn_gpsHud "_bd > 60"), so a single 923m
# hop left the driver ~460m from either end mid-span and the route recalculated every 2.5s forever.
MANUAL_LINKS = {
    # The designer's crossing is a DUAL CARRIAGEWAY: two separate one-way decks ~25.6m apart,
    # eastbound at y~3752.4 and westbound at y~3778.0, measured in game by the owner. The 16
    # BridgeStraight pieces are placed at y=3765.0, but that is the object ORIGIN -- the midline
    # BETWEEN the two decks, i.e. the gap. Routing down y=3765 (551dbfc) therefore drove the car
    # along the median rather than on either carriageway.
    #
    # Both decks are added, because the road graph is UNDIRECTED and has no one-way concept: a
    # single link would mean half of all crossings are plotted down a deck the driver cannot
    # legitimately use. With both present, whichever the router picks is at least a real surface.
    # The two mainland ramps meet different road endpoints (EB 8426.9,3759.5 / WB 8426.5,3777.8),
    # so entry side usually selects the natural carriageway; the island ramps share one endpoint.
    "Malden": [
        dict(a=[8426.9, 3759.5], b=[9348.5, 3745.2],
             via=[[8444.16, 3752.61],   # ramp start, mainland
                  [8488.12, 3752.23],   # deck start   (z 14.21)
                  [9285.90, 3752.10],   # deck end     (z 25.19)
                  [9332.16, 3753.04]],  # ramp bottom, island
             step=25,
             oneway=True,
             offset_left=1.5,
             why="designer's custom bridge, EASTBOUND carriageway (mainland -> island)"),
        # NOTE the ordering: a -> via -> b IS the direction of travel. Westbound runs island to
        # mainland, so it must be declared island-first. Written mainland-first (copying the
        # eastbound entry) it built a second mainland->island deck and left island->mainland with
        # no legal route at all.
        dict(a=[9348.5, 3745.2], b=[8426.5, 3777.8],
             via=[[9334.85, 3779.20],   # ramp start, island
                  [9286.75, 3777.82],   # deck start   (z 25.75)
                  [8489.11, 3777.97],   # deck end     (z 14.38)
                  [8454.07, 3777.11]],  # ramp end, mainland
             step=25,
             oneway=True,
             offset_left=1.5,
             why="designer's custom bridge, WESTBOUND carriageway (island -> mainland)"),
    ],
}

START_RE = re.compile(r'-ROADDUMP- START world=(\S+) size=(\d+)')


def parse_world(logpath):
    """World name + size from the dump header, so the emitted graph is not mislabelled."""
    with open(logpath, errors="replace") as f:
        for line in f:
            m = START_RE.search(line)
            if m:
                return m.group(1), int(m.group(2))
    return "Unknown", 0


def manual_links(world, node_pos, adj, edge_info, forced):
    """Join banks connected only by a mission-placed bridge, FOLLOWING the deck.

    Inserts intermediate nodes along a->via...->b every `step` metres and chains them, rather than
    adding one long edge. Two reasons this matters, both observed in game on Malden:
      * steering: the autopilot pursues the route line, so a straight node-to-node link 24-30m off
        the real deck drove the car off the bridge.
      * routing: the GPS HUD measures off-route distance to the nearest route VERTEX, so one 923m
        hop reads as ~460m off-route mid-span and re-plots every 2.5s.
    Returns [(dist, nodes_added, why), ...]; fills `forced` with nodes that must stay junctions."""
    added = []
    for spec in MANUAL_LINKS.get(world, []):
        a, b = spec["a"], spec["b"]
        na = min(range(len(node_pos)), key=lambda i: math.dist(node_pos[i], a))
        nb = min(range(len(node_pos)), key=lambda i: math.dist(node_pos[i], b))
        if na == nb:
            continue
        step = spec.get("step", 40)
        line = [node_pos[na]] + [list(p) for p in spec.get("via", [])] + [node_pos[nb]]

        # offset_left: shift the declared centreline perpendicular to the direction of travel,
        # positive = to the driver's LEFT. Arma is x=east / y=north, so for a heading (dx,dy) the
        # left normal is (-dy,dx). Applied only to the via points -- the endpoints are existing road
        # nodes and must stay where the road actually is. Each point uses the local heading through
        # it (previous -> next) so the offset follows curves instead of shearing them.
        # The autopilot ALSO applies its own lane offset (laneOff ~2.2m) on top of whatever line it
        # is given, so this is a correction to the deck centreline, not a lane choice.
        off = float(spec.get("offset_left", 0.0))
        if off and len(line) > 2:
            shifted = [line[0]]
            for k in range(1, len(line) - 1):
                pp, pc, pn = line[k - 1], line[k], line[k + 1]
                dx, dy = pn[0] - pp[0], pn[1] - pp[1]
                m = math.hypot(dx, dy) or 1.0
                shifted.append([pc[0] - dy / m * off, pc[1] + dx / m * off])
            shifted.append(line[-1])
            line = shifted
        # densify
        dense = [line[0]]
        for k in range(len(line) - 1):
            p, q = line[k], line[k + 1]
            seg = math.dist(p, q)
            n = max(1, int(seg // step))
            for s in range(1, n):
                f = s / n
                dense.append([p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f])
            dense.append(q)
        # chain: na -> new nodes -> nb
        chain, total = [na], 0.0
        for pt in dense[1:-1]:
            nid = len(node_pos)
            node_pos.append(pt)
            chain.append(nid)
        chain.append(nb)
        ow = spec.get("oneway", False)
        for u, v in zip(chain, chain[1:]):
            d = math.dist(node_pos[u], node_pos[v])
            total += d
            # oneway_from stores the node traffic flows FROM, so the direction survives the
            # (min,max) key ordering and any later chain reversal in collapse().
            edge_info.setdefault((min(u, v), max(u, v)),
                                 dict(len=d, width=8, cls=1, bridge=True, ped=False,
                                      oneway_from=(u if ow else None)))
            adj[u].add(v)
            adj[v].add(u)
        if ow:
            # Pin both ends as junctions. Without this a degree-2 ramp foot lets collapse() merge the
            # one-way chain into the adjoining two-way road, and the merged edge would have mixed
            # direction -- which can only be emitted as bidirectional, silently losing the restriction.
            forced.update({chain[0], chain[-1]})
        added.append((total, len(chain) - 2, spec["why"]))
    return added

# RPT wraps the logged string in quotes and doubles internal ones: "-ROADDUMP- [""k"",...]"
ROAD_RE = re.compile(r'-ROADDUMP- (\[.*\])"?\s*$')
NAME_RE = re.compile(r'-NAMEDUMP- (\[.*\])"?\s*$')


def unrpt(s):
    return s.replace('""', '"')


def parse(logpath):
    segs, names = {}, []
    with open(logpath, errors="replace") as f:
        for line in f:
            m = ROAD_RE.search(line)
            if m:
                try:
                    k, rtype, width, isped, isbridge, beg, end, conn = json.loads(unrpt(m.group(1)))
                except (ValueError, TypeError):
                    continue
                segs[k] = dict(type=rtype, width=width, ped=bool(isped),
                               bridge=bool(isbridge), beg=beg, end=end,
                               conn=[c for c in conn if c])
                continue
            m = NAME_RE.search(line)
            if m:
                try:
                    cls, name, ntype, x, y, rad = json.loads(unrpt(m.group(1)))
                except (ValueError, TypeError):
                    continue
                names.append(dict(cls=cls, name=name, type=ntype, pos=[x, y], radius=rad))
    return segs, names


class DSU:
    def __init__(self, n):
        self.p = list(range(n))

    def find(self, a):
        while self.p[a] != a:
            self.p[a] = self.p[self.p[a]]
            a = self.p[a]
        return a

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.p[rb] = ra



def build(segs):
    """Nodes = clustered segment endpoints ('ports'). Arma road pieces OVERLAP --
    adjacent pieces' endpoints rarely coincide -- so geometric clustering alone
    fragments the net. roadsConnectedTo is the authoritative connectivity: for
    each reported pair, union the two nearest ports across the pair. Geometric
    clustering stays as extra glue for junction overlap."""
    keys = list(segs)
    idx = {k: i for i, k in enumerate(keys)}
    pts = []
    for k in keys:
        pts.append(segs[k]["beg"])
        pts.append(segs[k]["end"])

    dsu = DSU(len(pts))
    # authoritative: reported connections -> union nearest port pair
    for i, k in enumerate(keys):
        for c in segs[k]["conn"]:
            j = idx.get(c)
            if j is None or j <= i:
                continue
            best = min(((2 * i + a, 2 * j + b) for a in (0, 1) for b in (0, 1)),
                       key=lambda ab: math.dist(pts[ab[0]], pts[ab[1]]))
            dsu.union(*best)
    # glue: coincident ports (junction piece overlap)
    cell = defaultdict(list)
    for i, p in enumerate(pts):
        cell[(int(p[0] // CLUSTER), int(p[1] // CLUSTER))].append(i)
    for i, p in enumerate(pts):
        cx, cy = int(p[0] // CLUSTER), int(p[1] // CLUSTER)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for j in cell.get((cx + dx, cy + dy), ()):
                    if j > i and math.dist(p, pts[j]) <= CLUSTER:
                        dsu.union(i, j)
    groups = defaultdict(list)
    for i in range(len(pts)):
        groups[dsu.find(i)].append(i)
    node_pos, node_of = [], {}
    for members in groups.values():
        nid = len(node_pos)
        node_pos.append([sum(pts[i][0] for i in members) / len(members),
                         sum(pts[i][1] for i in members) / len(members)])
        for i in members:
            node_of[i] = nid

    adj = defaultdict(set)
    edge_info = {}  # (a,b) a<b -> dict
    for i, k in enumerate(keys):
        a, b = node_of[2 * i], node_of[2 * i + 1]
        if a == b:
            continue  # sub-cluster stub piece
        key = (min(a, b), max(a, b))
        length = math.dist(node_pos[a], node_pos[b])
        prev = edge_info.get(key)
        if prev is None or length < prev["len"]:  # dedupe parallel duplicates, keep shortest
            # cls: 0 MAIN ROAD, 1 ROAD, 2 TRACK, 3 HIDE/other. Width is USELESS for class --
            # the engine reports TRACK width as 10, same as highways (the Telos ridge-trail bug).
            cls = {"MAIN ROAD": 0, "ROAD": 1, "TRACK": 2}.get(segs[k]["type"], 3)
            edge_info[key] = dict(len=length, width=segs[k]["width"], cls=cls,
                                  bridge=segs[k]["bridge"], ped=segs[k]["ped"])
        adj[a].add(b)
        adj[b].add(a)
    return node_pos, adj, edge_info


def components(adj, n_nodes):
    seen, comps = set(), []
    for start in range(n_nodes):
        if start in seen or start not in adj:
            continue
        stack, comp = [start], []
        seen.add(start)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for nb in adj[cur]:
                if nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    return comps


def stitch(node_pos, adj, edge_info, comps):
    """Join every minor component to the nearest main-component node within STITCH m."""
    if len(comps) <= 1:
        return 0
    main = set(comps[0])
    cell = defaultdict(list)
    for i in main:
        p = node_pos[i]
        cell[(int(p[0] // STITCH), int(p[1] // STITCH))].append(i)
    joined = 0
    for comp in comps[1:]:
        best = None
        for i in comp:
            p = node_pos[i]
            cx, cy = int(p[0] // STITCH), int(p[1] // STITCH)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for j in cell.get((cx + dx, cy + dy), ()):
                        d = math.dist(p, node_pos[j])
                        if d <= STITCH and (best is None or d < best[0]):
                            best = (d, i, j)
        if best:
            _, i, j = best
            key = (min(i, j), max(i, j))
            edge_info.setdefault(key, dict(len=best[0], width=6, cls=2, bridge=False, ped=False))
            adj[i].add(j)
            adj[j].add(i)
            joined += 1
    return joined


def collapse(node_pos, adj, edge_info, forced=()):
    """Degree-2 chain collapse -> junction graph with polyline edges."""
    junctions = {n for n in adj if len(adj[n]) != 2} | set(forced)
    # pure loops (roundabout islands) need an anchor
    seen = set(junctions)
    for n in adj:
        if n in seen:
            continue
        cur, chain = n, [n]
        seen.add(n)
        while True:
            nxt = next((x for x in adj[cur] if x not in seen), None)
            if nxt is None:
                break
            seen.add(nxt)
            chain.append(nxt)
            cur = nxt
        if not any(c in junctions for c in chain):
            junctions.add(chain[0])

    def einfo(a, b):
        return edge_info.get((min(a, b), max(a, b)), dict(len=math.dist(node_pos[a], node_pos[b]),
                                                          width=6, cls=2, bridge=False, ped=False,
                                                          oneway_from=None))

    edges, done = [], set()
    for n in junctions:
        for nb in adj[n]:
            if (n, nb) in done:
                continue
            chain, prev, cur = [n], n, nb
            while cur not in junctions:
                chain.append(cur)
                nxt = next((x for x in adj[cur] if x != prev), None)
                if nxt is None:
                    break
                prev, cur = cur, nxt
            chain.append(cur)
            done.add((n, nb))
            done.add((chain[-1], chain[-2]))
            infos = [einfo(chain[i], chain[i + 1]) for i in range(len(chain) - 1)]
            # direction relative to the emitted a->b (= chain order): 1 forward, -1 reverse, 0 both.
            dirs = []
            for i, inf in enumerate(infos):
                src = inf.get("oneway_from")
                dirs.append(0 if src is None else (1 if src == chain[i] else -1))
            if dirs and all(d == 1 for d in dirs):
                oneway = 1
            elif dirs and all(d == -1 for d in dirs):
                oneway = -1
            else:
                if any(d != 0 for d in dirs):
                    print("  WARNING: mixed-direction chain %s..%s emitted as two-way" % (n, chain[-1]))
                oneway = 0
            edges.append(dict(
                oneway=oneway,
                a=n, b=chain[-1],
                len=round(sum(i["len"] for i in infos), 1),
                width=max(i["width"] for i in infos),
                cls=max(i["cls"] for i in infos),
                bridge=any(i["bridge"] for i in infos),
                ped=all(i["ped"] for i in infos),
                poly=[[round(node_pos[c][0], 1), round(node_pos[c][1], 1)] for c in chain]))
    return junctions, edges


def svg_preview(edges, names, out, world=30720):
    S = 1600 / world

    def pt(p):
        return f"{p[0] * S:.1f},{(world - p[1]) * S:.1f}"

    w = ['<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1600" '
         'style="background:#0d0f14">']
    for e in sorted(edges, key=lambda e: e["width"]):
        if e["ped"]:
            color, sw = "#3a4150", 0.6
        elif e["width"] >= 12:
            color, sw = "#c7a24e", 1.8   # highways
        elif e["width"] >= 8:
            color, sw = "#8a939f", 1.1   # main roads
        else:
            color, sw = "#525b68", 0.7   # tracks
        if e["bridge"]:
            color = "#4ea3c7"
        pts = " ".join(pt(p) for p in e["poly"])
        w.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="{sw}"/>')
    for n in names:
        if n["type"] in ("NameCityCapital", "NameCity", "NameVillage"):
            big = n["type"] != "NameVillage"
            x, y = n["pos"][0] * S, (world - n["pos"][1]) * S
            w.append(f'<text x="{x:.0f}" y="{y:.0f}" fill="{"#e8e2d0" if big else "#9aa3ae"}" '
                     f'font-size="{14 if big else 9}" font-family="monospace" '
                     f'text-anchor="middle">{n["name"]}</text>')
    w.append("</svg>")
    Path(out).write_text("\n".join(w))


def emit_sqf(junctions, jpos, edges, out):
    """SQF literal for the in-game GPS: [nodes, edges] with node ids remapped
    to contiguous 0..N-1 (array indexing beats HashMaps in SQF hot loops).
    Loaded by AP_fnc_gpsInit via compile preprocessFileLineNumbers."""
    order = sorted(junctions)
    remap = {n: i for i, n in enumerate(order)}

    def num(v):
        s = f"{v:.1f}"
        return s[:-2] if s.endswith(".0") else s

    nodes_sqf = ",".join(f"[{num(jpos[n][0])},{num(jpos[n][1])}]" for n in order)
    parts = []
    for e in edges:
        if e["a"] not in remap or e["b"] not in remap:
            continue  # degenerate chain that never reached a junction
        poly = ",".join(f"[{num(x)},{num(y)}]" for x, y in e["poly"])
        parts.append(f"[{remap[e['a']]},{remap[e['b']]},{num(e['len'])},{e['cls']},"
                     f"{1 if e['ped'] else 0},[{poly}],{e.get('oneway', 0)}]")
    edges_sqf = ",".join(parts)
    Path(out).write_text(
        "// GENERATED by tools/roadgraph_build.py -- DO NOT EDIT (re-run the road dump pipeline)\n"
        "// [nodes (idx -> [x,y]), edges ([nodeA, nodeB, length_m, cls(0 main/1 road/2 track/3 hidden), isPed, polyline, oneway])]\n"
        "// oneway: 0 = two-way, 1 = nodeA->nodeB only, -1 = nodeB->nodeA only\n"
        f"[[{nodes_sqf}],\n[{edges_sqf}]]\n")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    logpath = sys.argv[1]
    outdir = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else Path("build")
    outdir.mkdir(parents=True, exist_ok=True)

    world, wsize = parse_world(logpath)
    print(f"world           : {world} ({wsize}m)")
    segs, names = parse(logpath)
    print(f"segments parsed : {len(segs)}")
    print(f"named places    : {len(names)}")

    node_pos, adj, edge_info = build(segs)
    print(f"point nodes     : {len(node_pos)} ({len(edge_info)} raw edges)")

    comps = components(adj, len(node_pos))
    print(f"components      : {len(comps)} (largest {len(comps[0])} nodes = "
          f"{len(comps[0]) / max(sum(len(c) for c in comps), 1) * 100:.1f}%)")
    joined = stitch(node_pos, adj, edge_info, comps)
    comps2 = components(adj, len(node_pos))
    print(f"seam-stitch     : +{joined} joins (<= {STITCH}m) -> {len(comps2)} components "
          f"(largest {len(comps2[0]) / max(sum(len(c) for c in comps2), 1) * 100:.1f}%)")

    forced = set()
    for d, nadded, why in manual_links(world, node_pos, adj, edge_info, forced):
        print(f"manual link     : {d:.0f}m via {nadded} inserted nodes -- {why}")
    comps3 = components(adj, len(node_pos))
    print(f"after manual    : {len(comps3)} components "
          f"(largest {len(comps3[0]) / max(sum(len(c) for c in comps3), 1) * 100:.1f}%)")

    junctions, edges = collapse(node_pos, adj, edge_info, forced)
    total_km = sum(e["len"] for e in edges) / 1000
    print(f"junction graph  : {len(junctions)} nodes, {len(edges)} edges, {total_km:.1f} km of road")

    graph = dict(
        world=world, worldSize=wsize, cluster=CLUSTER,
        nodes={str(n): [round(node_pos[n][0], 1), round(node_pos[n][1], 1)] for n in junctions},
        edges=edges,
        names=names,
    )
    gpath = outdir / "roadgraph.json"
    gpath.write_text(json.dumps(graph))
    print(f"wrote           : {gpath} ({gpath.stat().st_size // 1024} KB)")

    spath = outdir / "roadgraph_preview.svg"
    svg_preview(edges, names, spath)
    print(f"wrote           : {spath}")

    qpath = outdir / "roadgraph_data.sqf"
    emit_sqf(junctions, {n: node_pos[n] for n in junctions}, edges, qpath)
    print(f"wrote           : {qpath} ({qpath.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
