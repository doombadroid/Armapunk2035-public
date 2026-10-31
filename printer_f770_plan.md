# F770 Fabricator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace both desktop 3D printers with the owner's F770 industrial printer, drawn from six mission-embedded p3ds whose bridge, head, platform and HMI screen move while a job runs.

**Architecture:** The existing fabricator anchor (`Land_HelipadEmpty_F`, server-spawned) stays; `AP_fnc_fabModel` grows a multi-part path that reads a GENERATED offsets file and attaches six client-local simple objects; a new per-anchor client loop `AP_fnc_fabAnim` re-attaches the moving parts each tick from a print window `AP_fabRun = [start, end]` (serverTime) that the server publishes on `queue` and on boot respawn. Models come from a new harness/builder/verify trio in `scratchpad/skyscraper/`, then binarize (p3dmemories.md §7).

**Tech Stack:** node + three (headless dump), python (`mlod_rw`, `make_paa`, PIL), Arma 3 Tools binarize under wine, SQF.

Spec: `PRINTER_F770_SPEC.md` (residual decisions R1–R4 there are settled unless the owner flips them).

## Global Constraints

- Mission-embedded p3ds have NO config: no model.cfg animation, no `animate`, no `setObjectTexture`, no UserActions. Motion = separate simple objects moved by script (Resource Extractor precedent, `core/vehicle/fn_rigClient.sqf`).
- `createSimpleObject` ALWAYS with the third argument `true`; paths via `getMissionPath "custom_p3ds\"`, never a written-out world name; attach with `attachTo`, never `setPos` (fn_fabModel header rules).
- Simple objects are autocentred by the engine: every part p3d is centred on its own bbox at build time, and every attach offset is (part centre − body centre) COMPUTED by the builder and written to `custom_p3ds/fab_parts_data.sqf`. No offset, lift or animation constant is typed by hand anywhere in SQF.
- Coordinate frames: design/p3d = X right, Y up, Z forward (import RAW, no negation — LESSONS.md "Coordinates & mirroring"); `attachTo` offsets = `[right, forward, up]` = design `[x, z, y]`.
- Collision doctrine (LESSONS.md): every Geometry component is ONE convex box. The body gets one box (its bbox), mass 900; moving parts get no Geometry/Fire/View.
- Textures: base game only, paths verified against `textures_png/INDEX.txt`; procedural `#(argb,8,8,3)color(...)`; mission-local files referenced as `mpmissions\__cur_mp.Malden\<file>`; the screens reuse `mission/Armapunk2035.Malden/ap_printer_screen.rvmat` (mild emissive, on purpose — see that file's header).
- Binarize per p3dmemories.md §7: directories not files, BACKSLASH `Z:\...` paths, LOWERCASE source names, `WINEPREFIX=$HOME/.wine`; `Cannot load material file` lines are expected; output is ODOL v75 (the reader handles it).
- Print window and pose are SERVER-timed via `serverTime` so every client computes the same pose; the clock of record for jobs stays the database's (`finish_at`).
- Interaction stays proximity-based (`AP_fnc_fabNear`, unchanged). Tier keys, names, prices, icons unchanged (spec R2).
- Static checks before every commit: `python3 tools/sqf_balance.py <files>` → `ok`; `python3 tools/sqf_cmd_check.py <files>` may only report function names; `scratchpad/skyscraper/verify_f770.py` → `ALL PASS` (Task 1/2).
- Commit rule (CLAUDE.md, overrides the harness): exactly one trailer `Co-Authored-By: <defunct AI>` (name only, rotate, never the same twice in a row); `git add` named paths only. Commit straight to main.
- DO NOT deploy before Task 5. The owner is connected to the dev server; a deploy kicks them.

## File structure

| file | responsibility |
|---|---|
| `scratchpad/skyscraper/f770.js` (from the zip, committed) | design source, the builder `buildF770` |
| `scratchpad/skyscraper/harness_f770.mjs` (new) | headless dump with per-mesh `group` and material `map` path |
| `scratchpad/skyscraper/build_f770.py` (new) | dump → six MLOD p3ds + `fab_parts_data.sqf` + two screen PAAs |
| `scratchpad/skyscraper/verify_f770.py` (new) | gates + determinism, must print `ALL PASS` |
| `scratchpad/skyscraper/binarize_f770.sh` (new) | MLOD → ODOL into the mission, header sanity |
| `mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_{body,bridge,head,platform,screen_ready,screen_printing}_r1.p3d` | shipped ODOL |
| `mission/Armapunk2035.Malden/custom_p3ds/fab_parts_data.sqf` (generated) | offsets, lift, anim constants |
| `mission/Armapunk2035.Malden/ap_f770_screen_{ready,printing}_co.paa` (generated) | HMI screens |
| `core/items/fn_fabModel.sqf`, `fn_fabModelClear.sqf` (modify), `fn_fabAnim.sqf` (new), `Functions.h` | client draw / clear / animate |
| `server/AP_server/core/TON/fn_fabSRV.sqf` | publish `AP_fabRun` |
| `core/config/fn_fabCfg.sqf`, `core/configuration.sqf` | tier rows → F770; placement stand-in |

---

### Task 1: Pipeline — dump, build, verify (six MLODs, data file, screen PAAs)

**Files:**
- Create: `scratchpad/skyscraper/harness_f770.mjs`, `scratchpad/skyscraper/build_f770.py`, `scratchpad/skyscraper/verify_f770.py`
- Add from the zip: `scratchpad/skyscraper/f770.js`, `scratchpad/skyscraper/f770.html`, `scratchpad/skyscraper/three-d-stage.js`, `scratchpad/skyscraper/ARMA3_HANDOFF_F770.md`, `scratchpad/skyscraper/f770_textures/ap/ap_f770_screen_{ready,printing}_co.png`
- Generate: `mission/Armapunk2035.Malden/custom_p3ds/fab_parts_data.sqf`, `mission/Armapunk2035.Malden/ap_f770_screen_{ready,printing}_co.paa` (the six `.p3d` in `scratchpad/skyscraper/` are git-ignored by `scratchpad/skyscraper/*.p3d`; the dump and patched module are ignored by existing rules too)

**Interfaces:**
- Produces: `fab_parts_data.sqf` = an ARRAY of rows `[basename, rev, lift, [[suffix, [right, forward, up]] ...], [PASS, XT, ZT, NPASS, LAYER, NLAYERS]]`; for this model basename `"ap_printer_f770"`, rev `"r1"`, suffixes exactly `bridge, head, platform, screen_ready, screen_printing`, and the body p3d `ap_printer_f770_body_r1.p3d`. Task 3 reads it.

- [ ] **Step 1: Bring the design sources in**

```bash
cd /home/timb/Armapunk2035/scratchpad/skyscraper
unzip -o -j ~/Downloads/Printer.zip f770-handoff/f770.js f770-handoff/f770.html f770-handoff/three-d-stage.js f770-handoff/ARMA3_HANDOFF_F770.md -d .
mkdir -p f770_textures/ap
unzip -o -j ~/Downloads/Printer.zip 'f770-handoff/textures/ap/*' -d f770_textures/ap
ls f770.js f770.html three-d-stage.js ARMA3_HANDOFF_F770.md f770_textures/ap/
```
Expected: the four files plus `ap_f770_screen_printing_co.png ap_f770_screen_ready_co.png`.

- [ ] **Step 2: Write `harness_f770.mjs`**

```javascript
// Headless export harness for the F770 industrial printer (f770.js) -- ONE model, SIX parts.
//
// f770.js is pure ESM with named exports (buildF770 / poseF770) and no DOM, but unlike printer.js
// it loads textures: `new THREE.TextureLoader()` + `.load('textures/...')`. Under node that reaches
// for Image/document and throws, so the loader is stubbed (obs #178: harnesses stub TextureLoader)
// -- and the stub RECORDS the path it was asked for, because the a3 texture each big surface should
// wear is exactly that path with .png -> .paa. Reading it from the design source beats retyping the
// handoff table (a path typed twice is a path that disagrees after the next re-drop).
//
// The dump is a flat tri soup per mesh in the design frame (metres, Y-up, front +Z, origin at floor
// centre) with matrixWorld BAKED (f770.js positions every mesh; the bridge/head/platform groups are
// offset too). Each mesh also carries its GROUP: the nearest ancestor named f770_bridge / f770_head /
// f770_platform (head is nested inside bridge and wins), the two screens by their own name, and
// 'body' for everything else. build_f770.py splits the parts on that field, never on a name prefix.
//
// POSE: poseF770 is NOT called, so this is the CONSTRUCTION pose -- bridge at the centre of its X
// travel (bridge.position.x = PX), head at the centre of its Z travel (z = 0), platform at layer 0.
// fn_fabAnim moves the parts by +-XT / +-ZT / -layer*mm FROM those rest offsets, which is why the
// rest pose must be the centre of travel and not the handoff's t=0 end pose.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import * as THREE from 'three';

const here = dirname(fileURLToPath(import.meta.url));

function patchOnce(text, needle, replacement) {
  const n = text.split(needle).length - 1;
  if (n !== 1) throw new Error(`needle matched ${n}x, want 1: ${needle}`);
  return text.replace(needle, replacement);
}

const src = readFileSync(join(here, 'f770.js'), 'utf8');
const PATCHES = [
  ['const TL = new THREE.TextureLoader();',
   'const TL = { load: (p) => { const t = new THREE.Texture(); t.userData.path = p; return t; } };'],
];
let patched = src;
for (const [needle, repl] of PATCHES) patched = patchOnce(patched, needle, repl);
const patchedPath = join(here, 'f770_patched.mjs');
writeFileSync(patchedPath, patched);

const { buildF770 } = await import(patchedPath);

const GROUPS = new Set(['f770_bridge', 'f770_head', 'f770_platform']);
function groupOf(o) {
  if (o.name === 'f770_screen_ready' || o.name === 'f770_screen_printing') return o.name;
  for (let p = o.parent; p; p = p.parent) if (GROUPS.has(p.name)) return p.name;
  return 'body';
}

function dumpRoot(root) {
  root.updateMatrixWorld(true);
  const meshes = [];
  const mats = {};
  const nm = new THREE.Matrix3();
  root.traverse((o) => {
    if (!o.isMesh) return;
    const g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry;
    const posAttr = g.attributes.position, nrmAttr = g.attributes.normal, uvAttr = g.attributes.uv;
    if (!posAttr) throw new Error(`${o.name}: no position attribute`);
    if (!nrmAttr) throw new Error(`${o.name}: no normal attribute`);
    nm.getNormalMatrix(o.matrixWorld);
    const pos = [], norm = [], uv = [];
    const v = new THREE.Vector3(), n = new THREE.Vector3();
    for (let i = 0; i < posAttr.count; i++) {
      v.fromBufferAttribute(posAttr, i).applyMatrix4(o.matrixWorld);
      pos.push(v.x, v.y, v.z);
      n.fromBufferAttribute(nrmAttr, i).applyMatrix3(nm).normalize();
      norm.push(n.x, n.y, n.z);
      uv.push(uvAttr ? uvAttr.getX(i) : 0, uvAttr ? uvAttr.getY(i) : 0);
    }
    if (pos.length % 9 !== 0) throw new Error(`${o.name}: ${pos.length / 3} verts, not a tri soup`);
    const M = o.material;
    if (!mats[M.name]) {
      mats[M.name] = {
        color: '#' + M.color.getHexString(),
        opacity: M.transparent ? M.opacity : 1,
        transparent: !!M.transparent,
        emissive: M.emissive ? '#' + M.emissive.getHexString() : '#000000',
        emissiveIntensity: M.emissive ? (M.emissiveIntensity ?? 1) : 0,
        metalness: M.metalness ?? 0,
        roughness: M.roughness ?? 1,
        map: M.map?.userData?.path ?? null,           // 'a3/...png' | 'ap/...png' | null (procedural)
        repeat: M.map ? [M.map.repeat.x, M.map.repeat.y] : null,
      };
    }
    meshes.push({ name: o.name, group: groupOf(o), mat: M.name, pos, norm, uv, visible: o.visible });
  });
  return { meshes, mats };
}

const { meshes, mats } = dumpRoot(buildF770());
const names = new Set(meshes.map((m) => m.name));
if (names.size !== meshes.length) {
  const seen = new Set(), dupes = new Set();
  for (const m of meshes) (seen.has(m.name) ? dupes : seen).add(m.name);
  throw new Error(`duplicate mesh names: ${[...dupes].join(', ')}`);
}
const byGroup = {};
for (const m of meshes) {
  const g = (byGroup[m.group] ??= { n: 0, tris: 0, lo: [1e9, 1e9, 1e9], hi: [-1e9, -1e9, -1e9] });
  g.n++; g.tris += m.pos.length / 9;
  for (let i = 0; i < m.pos.length; i += 3)
    for (let k = 0; k < 3; k++) { g.lo[k] = Math.min(g.lo[k], m.pos[i + k]); g.hi[k] = Math.max(g.hi[k], m.pos[i + k]); }
}
const f = (a) => a.map((x) => x.toFixed(4)).join(',');
for (const [g, s] of Object.entries(byGroup))
  console.log(`${g.padEnd(22)} meshes=${String(s.n).padStart(3)} tris=${String(s.tris).padStart(5)} lo=[${f(s.lo)}] hi=[${f(s.hi)}] ctr=[${f(s.lo.map((l, k) => (l + s.hi[k]) / 2))}]`);
console.log(`total meshes=${meshes.length} tris=${meshes.reduce((a, m) => a + m.pos.length / 9, 0)}`);
console.log('materials:', Object.entries(mats).map(([k, v]) => `${k}${v.map ? ' -> ' + v.map : ''}`).join(' | '));
writeFileSync(join(here, process.argv[2] || 'f770_dump.json'), JSON.stringify({ meshes, mats }));
```

- [ ] **Step 3: Run the harness (observe the measured groups)**

```bash
cd /home/timb/Armapunk2035/scratchpad/skyscraper && node harness_f770.mjs
```
Expected (measured 2026-09-02; the first three columns must match, the numbers are what the builder consumes):
```
body                   meshes= 70 tris= 1200 lo=[-1.1260,-0.0000,-0.5470] hi=[1.1260,1.8150,0.5960] ctr=[0.0000,0.9075,0.0245]
f770_screen_ready      meshes=  1 tris=   12 ... ctr=[0.8700,1.4100,0.5930]
f770_screen_printing   meshes=  1 tris=   12 ... ctr=[0.8700,1.4100,0.5930]
f770_bridge            meshes=  5 tris=   60 ... ctr=[-0.1800,1.4125,-0.0400]
f770_head              meshes=  9 tris=  232 ... ctr=[-0.1800,1.2325,0.0130]
f770_platform          meshes=  5 tris=   60 ... ctr=[-0.1800,1.0200,-0.0825]
total meshes=91 tris=1576
```

- [ ] **Step 4: Write `build_f770.py`**

```python
#!/usr/bin/env python3
"""f770_dump.json -> six MLOD p3ds (one machine, split into parts) + custom_p3ds/fab_parts_data.sqf
                    + the two HMI screen PAAs at the mission root.

    ap_printer_f770_body_r1.p3d            everything static; the ONLY part with collision
    ap_printer_f770_bridge_r1.p3d          moves along X (left/right)         group f770_bridge
    ap_printer_f770_head_r1.p3d            rides the bridge, moves along Z    group f770_head
    ap_printer_f770_platform_r1.p3d        moves down (-Y) as layers stack    group f770_platform
    ap_printer_f770_screen_ready_r1.p3d    HMI quad, shown when idle
    ap_printer_f770_screen_printing_r1.p3d HMI quad, shown while printing

WHY PARTS. Mission-embedded p3ds have no config, so no model.cfg animation: motion is separate
objects moved by script, the way the Resource Extractor's arm and bit are. The split follows the
harness's `group` field (the three.js parent), never a name prefix.

ORIGINS. Every part is centred on ITS OWN bbox (simple objects are autocentred by the engine, so
this makes the engine's centre and ours agree), and the data file records where each part's centre
stands relative to the BODY's centre as an attachTo offset [right, forward, up] = design [dx, dz, dy].
Nothing in the mission is typed by hand: fn_fabModel reads the offsets from the generated file, and
fn_fabAnim reads the print-cycle constants (PASS/XT/ZT/NPASS/layer) that this script lifts out of
f770.js with an asserted regex, so the in-game motion and the design page's poseF770 share a source.

The dump is the CONSTRUCTION pose (poseF770 not applied): bridge at the centre of its X travel, head
at the centre of its Z travel, platform at layer 0. fn_fabAnim moves parts by +-XT / +-ZT / -layer*mm
FROM these rest offsets.

MATERIALS come from the dump. A material with a `map` is a real texture: 'textures/a3/...png' is the
vanilla .paa at that path (verify_f770.py checks each against textures_png/INDEX.txt),
'textures/ap/...png' is a mission-root .paa this script builds from the handoff PNG. Everything else
is a procedural colour from the dumped hex (emissive LEDs use their emissive hex, as the desktop
printers did). rvmats by material CLASS, per the handoff: shell/dark/plinth/trim -> metal_plate;
rails/liner/tray/brass/heater -> metalclean1; screens + LEDs -> the printers' mild emissive
ap_printer_screen.rvmat; rubber/belt/cable -> none. UVs are scaled by the material's three.js
`repeat`, so a 2x2 tiled shell tiles 2x2 in-game too.

LODs per part: visual 1.0 (every mesh) + coarse 50.0 (one box per part, its dominant texture). The
BODY also carries Geometry (1e13) / View (6e15) / Fire (7e15): ONE convex box = the body's own bbox,
mass 900 (LESSONS.md: every component one convex box; the handoff's three boxes differ from one by
a 3 cm plinth inset nobody can see or feel). Spec R1: collision ON for the body, owner may flip.
"""
import collections
import copy
import filecmp
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '/home/timb/blender_work')
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', '..', 'tools')))
import mlod_rw                                                    # noqa: E402
import make_paa                                                   # noqa: E402
from PIL import Image                                             # noqa: E402

MISSION = os.path.abspath(os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden'))
HANDOFF_TEX = os.path.join(HERE, 'f770_textures', 'ap')
REV = 'r1'
BASE = 'ap_printer_f770'
MASS = 900.0
PARTS = [('bridge', 'f770_bridge'), ('head', 'f770_head'), ('platform', 'f770_platform'),
         ('screen_ready', 'f770_screen_ready'), ('screen_printing', 'f770_screen_printing')]

METAL_PLATE = b'a3\\structures_f\\data\\metal\\metal_plate.rvmat'
METALCLEAN1 = b'a3\\structures_f\\data\\metal\\metalclean1.rvmat'
SCREEN_RVMAT = b'mpmissions\\__cur_mp.Malden\\ap_printer_screen.rvmat'
RVMAT = {
    'metal_panels_white_co': METAL_PLATE, 'metal_servicehangar_black_co': METAL_PLATE,
    'metalcoloureddark_co': METAL_PLATE, 'trim_charcoal_proc': METAL_PLATE,
    'metal_seams_01_co': METALCLEAN1, 'metal_gray_clean_co': METALCLEAN1, 'metalclean1_co': METALCLEAN1,
    'brass_proc': METALCLEAN1, 'heater_proc': METALCLEAN1,
    'ap_f770_screen_ready_co': SCREEN_RVMAT, 'ap_f770_screen_printing_co': SCREEN_RVMAT,
    'led_proc': SCREEN_RVMAT, 'led_amber_proc': SCREEN_RVMAT,
    'rubber_proc': b'', 'belt_proc': b'', 'cable_proc': b'',
}
EMISSIVE = {'led_proc', 'led_amber_proc'}
COARSE_TEX = {'body': 'metal_panels_white_co', 'bridge': 'metal_gray_clean_co', 'head': 'trim_charcoal_proc',
              'platform': 'metalclean1_co', 'screen_ready': 'ap_f770_screen_ready_co',
              'screen_printing': 'ap_f770_screen_printing_co'}


def f32(x):
    return struct.unpack('<f', struct.pack('<f', x))[0]


class Lod:
    """Local copy (build_gunsmith.py's, with selections + #Mass#): importing build_lux rebuilds the
    tower as a side effect, and a build script that regenerates unrelated models is a build script
    that will one day overwrite something during an unrelated edit."""

    def __init__(self, res):
        self.res = res
        self.pts = []; self.norms = []; self.faces = []
        self._pt = {}; self._nm = {}
        self.selections = []
        self.comp_key = None

    def pt(self, p):
        k = (self.comp_key, f32(p[0]), f32(p[1]), f32(p[2]))
        i = self._pt.get(k)
        if i is None:
            i = len(self.pts); self._pt[k] = i; self.pts.append(k[1:])
        return i

    def nm(self, n):
        k = (f32(n[0]), f32(n[1]), f32(n[2]))
        i = self._nm.get(k)
        if i is None:
            i = len(self.norms); self._nm[k] = i; self.norms.append(k)
        return i

    def face(self, corners, tex=b'', mat=b''):
        cs = list(reversed(corners))
        nv = len(cs)
        assert nv in (3, 4)
        vs = []
        for pos, n, uv in cs:
            vs.append((self.pt(pos), self.nm((-n[0], -n[1], -n[2])), f32(uv[0]), f32(uv[1])))
        while len(vs) < 4:
            vs.append((0, 0, 0.0, 0.0))
        self.faces.append(dict(nv=nv, vs=vs, flags=0, tex=tex, mat=mat))
        return len(self.faces) - 1

    def sharp_edges(self):
        per_edge = collections.defaultdict(list)
        for f in self.faces:
            vs = f['vs'][:f['nv']]
            for k in range(len(vs)):
                a, b = vs[k], vs[(k + 1) % len(vs)]
                key = (min(a[0], b[0]), max(a[0], b[0]))
                per_edge[key].append((a[1], b[1]) if a[0] < b[0] else (b[1], a[1]))
        out = bytearray()
        for (pa, pb), uses in sorted(per_edge.items()):
            if len({u for u in uses}) > 1:
                out += struct.pack('<II', pa, pb)
        return bytes(out)

    def finish(self, mass_total=None):
        taggs = [dict(b=b'\x01', name=b'#SharpEdges#', data=self.sharp_edges())]
        for name, ptset, faceset in self.selections:
            data = bytearray(len(self.pts) + len(self.faces))
            for i in ptset: data[i] = 1
            for i in faceset: data[len(self.pts) + i] = 1
            taggs.append(dict(b=b'\x01', name=name.encode(), data=bytes(data)))
        if mass_total is not None:
            per = mass_total / len(self.pts)
            taggs.append(dict(b=b'\x01', name=b'#Mass#',
                              data=struct.pack(f'<{len(self.pts)}f', *([per] * len(self.pts)))))
        uv = bytearray(struct.pack('<I', 0))
        for f in self.faces:
            for v in f['vs'][:f['nv']]:
                uv += struct.pack('<ff', v[2], v[3])
        taggs.append(dict(b=b'\x01', name=b'#UVSet#', data=bytes(uv)))
        taggs.append(dict(b=b'\x01', name=b'#EndOfFile#', data=b''))
        return dict(hs=0x1c, lv=0x100, flags=0,
                    pts=[(x, y, z, 0) for x, y, z in self.pts],
                    norms=list(self.norms), faces=self.faces, taggs=taggs, res=self.res)


def tex_for(name, m):
    """(texture, rvmat) for one dumped material: a3 map -> vanilla .paa; ap map -> mission-root .paa;
    otherwise the dumped colour (emissive hex for the LEDs) as a procedural."""
    mp = m.get('map')
    if mp and mp.startswith('textures/a3/'):
        tex = mp[len('textures/'):].replace('/', '\\').replace('.png', '.paa').encode()
    elif mp and mp.startswith('textures/ap/'):
        tex = ('mpmissions\\__cur_mp.Malden\\' + os.path.basename(mp).replace('.png', '.paa')).encode()
    else:
        h = m['emissive'] if name in EMISSIVE else m['color']
        r, g, b = (int(h[1:3], 16) / 255.0, int(h[3:5], 16) / 255.0, int(h[5:7], 16) / 255.0)
        tex = f'#(argb,8,8,3)color({r:.3f},{g:.3f},{b:.3f},{m["opacity"]:.2f},co)'.encode()
    assert name in RVMAT, f'material {name!r} has no rvmat class here -- the design source added one'
    return tex, RVMAT[name]


def mesh_tris(m):
    pos, nrm, uv = m['pos'], m['norm'], m['uv']
    for t in range(len(pos) // 9):
        corners = []
        for c in range(3):
            i = t * 3 + c
            corners.append(((pos[3 * i], pos[3 * i + 1], pos[3 * i + 2]),
                            (nrm[3 * i], nrm[3 * i + 1], nrm[3 * i + 2]),
                            (uv[2 * i], uv[2 * i + 1])))
        yield corners


def emit_mesh(lod, m, ctr, tex=b'', mat=b'', repeat=(1, 1)):
    rx, ry = repeat
    for corners in mesh_tris(m):
        cs = [((p[0] - ctr[0], p[1] - ctr[1], p[2] - ctr[2]), n, (u * rx, 1.0 - v * ry))
              for p, n, (u, v) in corners]
        lod.face(cs, tex=tex, mat=mat)


def add_box(lod, mn, mx, sel=None, tex=b'', mat=b''):
    P = {(i, j, k): (mx[0] if i else mn[0], mx[1] if j else mn[1], mx[2] if k else mn[2])
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    quads = [([(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)], (-1, 0, 0)),
             ([(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)], (1, 0, 0)),
             ([(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)], (0, -1, 0)),
             ([(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)], (0, 1, 0)),
             ([(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)], (0, 0, -1)),
             ([(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)], (0, 0, 1))]
    fs, ps = [], set()
    for keys, n in quads:
        fs.append(lod.face([(P[k], n, (0.5, 0.5)) for k in keys], tex=tex, mat=mat))
    for k in P.values():
        ps.add(lod.pt(k))
    if sel is not None:
        sel[0].update(ps); sel[1].update(fs)


def bounds(meshes):
    xs, ys, zs = [], [], []
    for m in meshes:
        p = m['pos']
        xs += p[0::3]; ys += p[1::3]; zs += p[2::3]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def anim_constants():
    """[PASS s, XT m, ZT m, NPASS, LAYER m, NLAYERS] read out of poseF770 in f770.js."""
    src = open(os.path.join(HERE, 'f770.js'), encoding='utf-8').read()
    m = re.findall(r'const PASS = ([\d.]+), XT = ([\d.]+), ZT = ([\d.]+), NPASS = (\d+);', src)
    assert len(m) == 1, f'PASS/XT/ZT/NPASS line matched {len(m)}x in f770.js, want 1'
    lay = re.findall(r'plat\.position\.y = -\(layer % (\d+)\) \* ([\d.]+);', src)
    assert len(lay) == 1, f'platform layer line matched {len(lay)}x in f770.js, want 1'
    return [float(m[0][0]), float(m[0][1]), float(m[0][2]), int(m[0][3]), float(lay[0][1]), int(lay[0][0])]


def build_part(part, meshes, lookup, mats, geometry=False):
    lo, hi = bounds(meshes)
    ctr = tuple((lo[i] + hi[i]) / 2 for i in range(3))
    mn = tuple(lo[i] - ctr[i] for i in range(3))
    mx = tuple(hi[i] - ctr[i] for i in range(3))
    vis = Lod(1.0)
    for m in meshes:
        tex, mat = lookup[m['mat']]
        emit_mesh(vis, m, ctr, tex=tex, mat=mat, repeat=tuple(mats[m['mat']].get('repeat') or (1, 1)))
    coarse = Lod(50.0)
    tex, mat = lookup[COARSE_TEX[part]]
    add_box(coarse, mn, mx, tex=tex, mat=mat)
    lods = [vis.finish(), coarse.finish()]
    if geometry:
        geo = Lod(1e13)
        sel = (set(), set())
        geo.comp_key = 1
        add_box(geo, mn, mx, sel=sel)
        geo.selections = [('Component01', sel[0], sel[1])]
        geo_f = geo.finish(mass_total=MASS)
        view_f = copy.deepcopy(geo_f); view_f['res'] = 6e15
        view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']
        fire_f = copy.deepcopy(geo_f); fire_f['res'] = 7e15
        fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']
        lods += [geo_f, view_f, fire_f]
    name = f'{BASE}_{part}_{REV}.p3d'
    out = os.path.join(HERE, name)
    n = mlod_rw.write(out, 257, lods)
    ver2, l2 = mlod_rw.parse(out)
    mlod_rw.write(out + '.rt', ver2, l2)
    assert filecmp.cmp(out, out + '.rt', shallow=False), f'{name}: round-trip mismatch'
    os.remove(out + '.rt')
    print(f'wrote {name} bytes={n} visual faces={len(lods[0]["faces"])} '
          f'size {hi[0]-lo[0]:.3f} x {hi[1]-lo[1]:.3f} x {hi[2]-lo[2]:.3f} m')
    return ctr, (hi[1] - lo[1]) / 2


def build_screens():
    """Handoff PNGs (512x358) -> 512x256 DXT5 .paa at the mission root: power-of-two so the mip
    chain is whole. The quad's UVs span the whole texture, so the aspect change is undone on the face."""
    for k in ('ready', 'printing'):
        png = os.path.join(HANDOFF_TEX, f'ap_f770_screen_{k}_co.png')
        tmp = os.path.join(HERE, f'_f770_screen_{k}_512x256.png')
        Image.open(png).convert('RGBA').resize((512, 256), Image.LANCZOS).save(tmp)
        paa = os.path.join(MISSION, f'ap_f770_screen_{k}_co.paa')
        make_paa.build_paa_dxt5(tmp, paa)
        ok, msg = make_paa.verify_paa(paa)
        assert ok, f'{paa}: {msg}'
        os.remove(tmp)
        print(f'wrote {os.path.basename(paa)}: {msg}')


def main():
    data = json.load(open(os.path.join(HERE, 'f770_dump.json')))
    meshes, mats = data['meshes'], data['mats']
    lookup = {n: tex_for(n, m) for n, m in mats.items()}
    groups = collections.defaultdict(list)
    for m in meshes:
        groups[m['group']].append(m)
    expected = {'body'} | {g for _, g in PARTS}
    assert set(groups) == expected, f'groups {sorted(groups)} != {sorted(expected)} -- f770.js changed its group names'

    body_ctr, half = build_part('body', groups['body'], lookup, mats, geometry=True)
    rows = []
    for suffix, g in PARTS:
        ctr, _ = build_part(suffix, groups[g], lookup, mats)
        d = [ctr[i] - body_ctr[i] for i in range(3)]
        rows.append((suffix, [d[0], d[2], d[1]]))      # design [x, y(up), z(fwd)] -> attachTo [right, forward, up]
    build_screens()
    anim = anim_constants()

    out = os.path.join(MISSION, 'custom_p3ds', 'fab_parts_data.sqf')
    parts = ', '.join(f'["{s}", [{o[0]:.4f}, {o[1]:.4f}, {o[2]:.4f}]]' for s, o in rows)
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('// GENERATED by scratchpad/skyscraper/build_f770.py from f770_dump.json (f770.js) -- do not hand-edit\n')
        f.write('// one row per multi-part fabricator model:\n')
        f.write('//   [basename, rev, lift (body half-height, m),\n')
        f.write('//    [[partSuffix, [right, forward, up]] ...]  attachTo offset of the part centre from the body centre,\n')
        f.write('//    [PASS s, XT m, ZT m, NPASS, LAYER m, NLAYERS]]  the print cycle, read out of poseF770 in f770.js\n')
        f.write('[\n')
        f.write(f'    ["{BASE}", "{REV}", {half:.4f}, [{parts}], '
                f'[{anim[0]}, {anim[1]}, {anim[2]}, {anim[3]}, {anim[4]}, {anim[5]}]]\n')
        f.write(']\n')
    print(f'wrote custom_p3ds/fab_parts_data.sqf  lift={half:.4f}  parts={[s for s, _ in rows]}  anim={anim}')


if __name__ == '__main__':
    main()
```

- [ ] **Step 5: Build (observe outputs)**

```bash
cd /home/timb/Armapunk2035/scratchpad/skyscraper && python3 build_f770.py && cat ../../mission/Armapunk2035.Malden/custom_p3ds/fab_parts_data.sqf
```
Expected: six `wrote ap_printer_f770_*_r1.p3d` lines (body `visual faces=1200`, `size 2.252 x 1.815 x 1.143 m`), two `wrote ap_f770_screen_*_co.paa: ... valid` lines, and a data file whose row is
`["ap_printer_f770", "r1", 0.9075, [["bridge", [-0.1800, -0.0645, 0.5050]], ["head", [-0.1800, -0.0115, 0.3250]], ["platform", [-0.1800, -0.1070, 0.1125]], ["screen_ready", [0.8700, 0.5685, 0.5025]], ["screen_printing", [0.8700, 0.5685, 0.5025]]], [1.3, 0.28, 0.16, 20, 0.003, 12]]`
(offsets = group centre − body centre from Step 3, reordered [x, z, y]; ±0.0001 from float32).

- [ ] **Step 6: Write `verify_f770.py`**

```python
#!/usr/bin/env python3
"""Verification suite for the six ap_printer_f770_*_r1.p3d MLODs + fab_parts_data.sqf. Must print ALL PASS.

Every number here is recomputed from f770_dump.json; nothing is compared against the handoff prose.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                    # noqa: E402
sys.path.insert(0, HERE)
import build_f770 as B                                            # noqa: E402

MISSION = B.MISSION
INDEX = os.path.abspath(os.path.join(HERE, '..', '..', 'textures_png', 'INDEX.txt'))
fails = 0


def gate(name, ok, extra=''):
    global fails
    print(f'  [{"PASS" if ok else "FAIL"}] {name}' + (f'   {extra}' if extra else ''))
    if not ok:
        fails += 1


def bbox(lod):
    xs = [p[0] for p in lod['pts']]; ys = [p[1] for p in lod['pts']]; zs = [p[2] for p in lod['pts']]
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def check_part(part, meshes, mats, index_paths, geometry):
    path = os.path.join(HERE, f'{B.BASE}_{part}_{B.REV}.p3d')
    print(f'\n== {os.path.basename(path)}')
    if not os.path.exists(path):
        gate('file exists', False, path); return None
    ver, lods = mlod_rw.parse(path)
    res = [B.f32(l['res']) for l in lods]          # stored as float32: 1e13 reads back 9999999827968.0
    want = [B.f32(x) for x in [1.0, 50.0] + ([1e13, 6e15, 7e15] if geometry else [])]
    gate('LOD resolutions', res == want, f'{res}')
    vis, coarse = lods[0], lods[1]
    tris = sum(len(m['pos']) // 9 for m in meshes)
    gate('visual faces == dumped tris', len(vis['faces']) == tris, f'{len(vis["faces"])} vs {tris}')
    lo, hi = bbox(vis)
    ctr = [(lo[i] + hi[i]) / 2 for i in range(3)]
    gate('visual LOD centred on its bbox', all(abs(c) < 1e-4 for c in ctr), f'{[round(c, 5) for c in ctr]}')
    used = {f['tex'] for f in vis['faces']}
    need = {B.tex_for(n, mats[n])[0] for n in {m['mat'] for m in meshes}}
    gate('every material of the group reaches the model', need <= used, f'{len(need)} needed, {len(used)} used')
    a3 = sorted({t.decode() for t in used if t.startswith(b'a3\\')})
    missing = [t for t in a3 if t.lower() not in index_paths]
    gate('vanilla textures exist in textures_png/INDEX.txt', not missing, ','.join(missing) or f'{len(a3)} paths')
    local = sorted({t.decode() for t in used if t.startswith(b'mpmissions\\')}
                   | {f['mat'].decode() for f in vis['faces'] if f['mat'].startswith(b'mpmissions\\')})
    miss2 = [t for t in local if not os.path.exists(os.path.join(MISSION, t.split('\\')[-1]))]
    gate('mission-local textures/rvmats exist on disk', not miss2, ','.join(miss2) or f'{len(local)} files')
    clo, chi = bbox(coarse)
    inside = all(clo[i] >= lo[i] - 1e-5 and chi[i] <= hi[i] + 1e-5 for i in range(3))
    gate('coarse LOD is one box inside the visual bbox', len(coarse['faces']) == 6 and inside)
    if geometry:
        geo = lods[2]
        glo, ghi = bbox(geo)
        gate('geometry is one box == visual bbox',
             len(geo['faces']) == 6 and all(abs(glo[i] - lo[i]) < 1e-5 and abs(ghi[i] - hi[i]) < 1e-5 for i in range(3)))
        mass = [t for t in geo['taggs'] if t['name'] == b'#Mass#']
        tot = sum(__import__('struct').unpack(f'<{len(mass[0]["data"]) // 4}f', mass[0]['data'])) if mass else 0
        gate('#Mass# present and totals 900', mass and abs(tot - B.MASS) < 0.5, f'{tot:.1f}')
        gate('Component01 selection present', any(t['name'] == b'Component01' for t in geo['taggs']))
        for k, name in ((3, 'View'), (4, 'Fire')):
            gate(f'{name} geometry carries no #Mass#', not any(t['name'] == b'#Mass#' for t in lods[k]['taggs']))
    return ctr, (hi[1] - lo[1]) / 2, (lo, hi)


def main():
    data = json.load(open(os.path.join(HERE, 'f770_dump.json')))
    meshes, mats = data['meshes'], data['mats']
    groups = {}
    for m in meshes:
        groups.setdefault(m['group'], []).append(m)
    index_paths = set()
    with open(INDEX, encoding='utf-8', errors='replace') as f:
        for line in f:
            index_paths.add(line.split(' -> ')[0].strip().lower())

    body = check_part('body', groups['body'], mats, index_paths, True)
    if body is None:
        print('\n1 FAILURE(S)'); return 1
    blo, bhi = B.bounds(groups['body'])
    body_ctr = [(blo[i] + bhi[i]) / 2 for i in range(3)]
    parts_ok = True
    offsets = {}
    for suffix, g in B.PARTS:
        r = check_part(suffix, groups[g], mats, index_paths, False)
        parts_ok = parts_ok and r is not None
        lo, hi = B.bounds(groups[g])
        c = [(lo[i] + hi[i]) / 2 for i in range(3)]
        offsets[suffix] = [c[0] - body_ctr[0], c[2] - body_ctr[2], c[1] - body_ctr[1]]

    print('\n== fab_parts_data.sqf')
    path = os.path.join(MISSION, 'custom_p3ds', 'fab_parts_data.sqf')
    txt = open(path, encoding='utf-8').read()
    m = re.search(r'\["(ap_printer_f770)", "(r\d+)", ([\d.]+), \[(.*)\], \[([^\]]*)\]\]', txt)
    gate('row parses', m is not None)
    if m:
        gate('basename/rev', m.group(1) == B.BASE and m.group(2) == B.REV)
        gate('lift == body half-height', abs(float(m.group(3)) - (bhi[1] - blo[1]) / 2) < 1e-4, m.group(3))
        rows = re.findall(r'\["(\w+)", \[([-\d.]+), ([-\d.]+), ([-\d.]+)\]\]', m.group(4))
        gate('five parts in order', [r[0] for r in rows] == [s for s, _ in B.PARTS], str([r[0] for r in rows]))
        bad = [r[0] for r in rows if r[0] in offsets and
               any(abs(float(r[1 + i]) - offsets[r[0]][i]) > 2e-4 for i in range(3))]
        gate('offsets == part centre - body centre (dump)', not bad, ','.join(bad))
        anim = [float(x) for x in m.group(5).split(',')]
        gate('anim constants == f770.js', anim == [float(x) for x in B.anim_constants()], str(anim))

    print('\n== determinism')
    files = [os.path.join(HERE, f'{B.BASE}_{p}_{B.REV}.p3d') for p in ['body'] + [s for s, _ in B.PARTS]] + [path]
    keep = {p: open(p, 'rb').read() for p in files}
    subprocess.run([sys.executable, os.path.join(HERE, 'build_f770.py')], check=True, cwd=HERE, stdout=subprocess.DEVNULL)
    gate('rebuild is byte-identical (p3ds + data file)', all(open(p, 'rb').read() == keep[p] for p in files))

    print()
    if fails or not parts_ok:
        print(f'{fails} FAILURE(S)'); return 1
    print('ALL PASS'); return 0


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 7: Verify**

```bash
cd /home/timb/Armapunk2035/scratchpad/skyscraper && python3 verify_f770.py
```
Expected: every gate `[PASS]`, last line `ALL PASS`. A `[FAIL]` is a defect in the builder or the data file, not a tolerance to loosen (writing-plans-extras #10).

- [ ] **Step 8: Commit**

```bash
cd /home/timb/Armapunk2035
git status --short | grep -v '^??' ; git status --short | grep '^??'   # only the files below may be new
git add scratchpad/skyscraper/f770.js scratchpad/skyscraper/f770.html scratchpad/skyscraper/three-d-stage.js scratchpad/skyscraper/ARMA3_HANDOFF_F770.md scratchpad/skyscraper/f770_textures/ap/ap_f770_screen_ready_co.png scratchpad/skyscraper/f770_textures/ap/ap_f770_screen_printing_co.png scratchpad/skyscraper/harness_f770.mjs scratchpad/skyscraper/build_f770.py scratchpad/skyscraper/verify_f770.py mission/Armapunk2035.Malden/custom_p3ds/fab_parts_data.sqf mission/Armapunk2035.Malden/ap_f770_screen_ready_co.paa mission/Armapunk2035.Malden/ap_f770_screen_printing_co.paa
git commit -m "feat(fab): F770 printer pipeline -- harness, six-part builder, verify, generated offsets

One three.js model, six MLOD p3ds: the body (one collision box, mass 900)
and five parts the client moves or hides. Every attach offset, the lift and
the print-cycle constants are computed from the dump and f770.js into
custom_p3ds/fab_parts_data.sqf; nothing is typed by hand in SQF. The two
HMI screens ship as 512x256 DXT5 PAAs at the mission root on the printers'
existing mild-emissive rvmat. verify_f770.py: ALL PASS.

Co-Authored-By: Zo"
```

---

### Task 2: Binarize into the mission, retire the desktop printers

**Files:**
- Create: `scratchpad/skyscraper/binarize_f770.sh`
- Create (ODOL): `mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_{body,bridge,head,platform,screen_ready,screen_printing}_r1.p3d`
- Delete: `mission/Armapunk2035.Malden/custom_p3ds/ap_printer_i3_r1.p3d`, `mission/Armapunk2035.Malden/custom_p3ds/ap_printer_corexy_r1.p3d`
- Move: `scratchpad/skyscraper/{printer.js,printer.html,harness_printer.mjs,build_printer.py,verify_printer.py,ARMA3_HANDOFF_PRINTER.md}` → `scratchpad/skyscraper/archive/printer_desktop/`

- [ ] **Step 1: Write `binarize_f770.sh`**

```bash
#!/usr/bin/env bash
# MLOD (scratchpad/skyscraper, the source) -> ODOL (mission custom_p3ds, what ships).
# p3dmemories.md section 7: binarize takes DIRECTORIES, wants BACKSLASH Z:\ paths and LOWERCASE
# source names, and prints "Cannot load material file" for every a3 rvmat because there is no P:
# drive here -- expected, the path is written through unchanged. Output is ODOL v75.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
MISSION="$HERE/../../mission/Armapunk2035.Malden"
SRC="$HOME/f770_bin_src"; DST="$HOME/f770_bin_dst"
rm -rf "$SRC" "$DST"; mkdir -p "$SRC" "$DST"
n=0
for f in "$HERE"/ap_printer_f770_*_r1.p3d; do
  head -c 4 "$f" | grep -q MLOD || { echo "source is not MLOD: $f"; exit 1; }
  cp "$f" "$SRC/$(basename "$f" | tr 'A-Z' 'a-z')"; n=$((n+1))
done
[ "$n" -eq 6 ] || { echo "expected 6 MLOD sources, found $n (run build_f770.py first)"; exit 1; }
export WINEPREFIX="$HOME/.wine"
( cd "$HOME/.local/share/Steam/steamapps/common/Arma 3 Tools/Binarize" && \
  wine64 binarize_x64.exe -always -silent -maxProcesses=6 "Z:\\home\\timb\\f770_bin_src" "Z:\\home\\timb\\f770_bin_dst" ) 2>&1 \
  | grep -v 'Cannot load material file' || true
m=0
for f in "$DST"/ap_printer_f770_*_r1.p3d; do
  head -c 4 "$f" | grep -q ODOL || { echo "NOT ODOL: $f"; exit 1; }
  cp "$f" "$MISSION/custom_p3ds/$(basename "$f")"; m=$((m+1))
done
[ "$m" -eq 6 ] || { echo "expected 6 binarized models, got $m"; exit 1; }
python3 - "$MISSION/custom_p3ds" <<'EOF'
import os, sys
sys.path.insert(0, '/home/timb/blender_work')
from odol73_to_mlod import read_odol
d = sys.argv[1]; bad = 0
for n in ['body', 'bridge', 'head', 'platform', 'screen_ready', 'screen_printing']:
    o = read_odol(os.path.join(d, f'ap_printer_f770_{n}_r1.p3d'))
    res, bc = o['resolutions'], o['modelinfo']['boundingCenter']
    ok = 2 <= len(res) <= 5 and res[0] == 1.0 and all(abs(c) < 0.01 for c in bc)
    bad += not ok
    print(f"  [{'PASS' if ok else 'FAIL'}] {n:16} v{o['version']} lods={res} boundingCenter={[round(c, 4) for c in bc]}")
sys.exit(1 if bad else 0)
EOF
rm -rf "$SRC" "$DST"
echo "binarized 6 models into custom_p3ds"
```

- [ ] **Step 2: Run it**

```bash
chmod +x scratchpad/skyscraper/binarize_f770.sh && bash scratchpad/skyscraper/binarize_f770.sh
```
Expected: six `[PASS]` lines (`v75`, `lods=[1.0, 50.0]` for parts and `[1.0, 50.0, 1e13, 6e15, 7e15]` for the body, boundingCenter within 0.01 of zero — the MLOD was centred, so autocentre moves nothing), then `binarized 6 models into custom_p3ds`. A boundingCenter far from zero means the engine will place that part off its computed offset: stop and report (do not adjust the data file by hand).

- [ ] **Step 3: Retire the desktop printers**

```bash
cd /home/timb/Armapunk2035
git rm -q mission/Armapunk2035.Malden/custom_p3ds/ap_printer_i3_r1.p3d mission/Armapunk2035.Malden/custom_p3ds/ap_printer_corexy_r1.p3d
mkdir -p scratchpad/skyscraper/archive/printer_desktop
git mv scratchpad/skyscraper/printer.js scratchpad/skyscraper/printer.html scratchpad/skyscraper/harness_printer.mjs scratchpad/skyscraper/build_printer.py scratchpad/skyscraper/verify_printer.py scratchpad/skyscraper/ARMA3_HANDOFF_PRINTER.md scratchpad/skyscraper/archive/printer_desktop/
rm -f scratchpad/skyscraper/ap_printer_i3_r1.p3d scratchpad/skyscraper/ap_printer_corexy_r1.p3d scratchpad/skyscraper/printer_dump.json scratchpad/skyscraper/printer_patched.mjs
grep -rn 'ap_printer_i3_r1\|ap_printer_corexy_r1' mission/Armapunk2035.Malden --include='*.sqf' --include='*.hpp' server/AP_server | cut -c1-140
```
Expected: the grep shows ONLY the two tier rows in `core/config/fn_fabCfg.sqf` (Task 4 retargets them). Anything else is a reference this plan missed: report it.

- [ ] **Step 4: Commit**

```bash
cd /home/timb/Armapunk2035
git add scratchpad/skyscraper/binarize_f770.sh mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_body_r1.p3d mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_bridge_r1.p3d mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_head_r1.p3d mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_platform_r1.p3d mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_screen_ready_r1.p3d mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_screen_printing_r1.p3d
git commit -m "feat(fab): ship the six F770 parts binarized; retire the desktop printer models

ODOL v75 via Arma 3 Tools (binarize_f770.sh: backslash paths, lowercase
sources, header sanity through the v75-aware reader). The i3/CoreXY p3ds
leave the mission; their generator sources move to archive/printer_desktop.

Co-Authored-By: Xiaoice"
```

---

### Task 3: Client — draw six parts, animate the print, clear them all

**Files:**
- Modify: `mission/Armapunk2035.Malden/core/items/fn_fabModel.sqf` (whole file), `mission/Armapunk2035.Malden/core/items/fn_fabModelClear.sqf` (whole file)
- Create: `mission/Armapunk2035.Malden/core/items/fn_fabAnim.sqf`
- Modify: `mission/Armapunk2035.Malden/Functions.h` (after ` class fabModelClear {};`)

**Interfaces:**
- Consumes: `custom_p3ds/fab_parts_data.sqf` rows (Task 1); the anchor's `AP_fabRun = [start, end]` in `serverTime` (Task 4 publishes it; absent → `[0, 0]` → idle rest pose).
- Produces: anchor vars `AP_fabModel` (body), `AP_fabParts` (HashMap suffix → `[object, restOffset]`), `AP_fabSpec` (the data row), `AP_fabAnimUp`.

- [ ] **Step 1: Rewrite `fn_fabModel.sqf`**

```sqf
params [["_anchor", objNull, [objNull]], ["_model", "", [""]], ["_lift", 0.2975, [0]]];
/*
    AP_fnc_fabModel  -- attach a fabricator's visual to its anchor, client-side.

    The anchor is a server-spawned Land_HelipadEmpty_F that carries the identity, the tags and the
    interaction. The MODEL is a client-local createSimpleObject attached to it, which is how every
    custom p3d in this mission is drawn.

    Three rules, each of which has silently broken a model in this repo before:
      * the path comes from getMissionPath, never a written-out world name -- a hardcoded
        __cur_mp.Altis survived the fork to Malden and every model quietly stopped spawning;
      * the third argument to createSimpleObject MUST be true (local). Since 1.96 it defaults to
        false, and the 2-arg form once produced one replicated copy per connected client;
      * attachTo, not setPos. Client-side PhysX settles unattached props differently on different
        machines -- the server sinks into the floor while a player sees it hovering -- and attachTo
        renders the exact model-space offset identically everywhere.

    The models are CENTRED on their own bbox, so the attach offset lifts each one by HALF ITS OWN
    HEIGHT to stand it on the floor the anchor sits on. That number is per model and comes from the
    caller -- it was briefly hardcoded to the printers' 0.2975, which would have buried the 1.893 m
    gunsmith bench up to its worktop.

    MULTI-PART MACHINES (the F770 printer): custom_p3ds\fab_parts_data.sqf, GENERATED by the
    model's builder, lists a basename's parts and where each part's centre stands relative to the
    body's centre. The body attaches like any single model; every other part attaches at its own
    offset (+ the same lift), and AP_fnc_fabAnim moves the ones that move. For these the tier
    row's lift is ignored: the data file's number IS the body's measured half-height, and a second,
    hand-typed copy of it would only ever drift. Mission p3ds have no config, so this -- separate
    objects moved by script, the Resource Extractor's method -- is the only way a mission model
    moves.
*/
if (isNull _anchor || {_model isEqualTo ""}) exitWith {};
if (!hasInterface) exitWith {};
if (!isNull (_anchor getVariable ["AP_fabModel", objNull])) exitWith {};   // already drawn here

private _root = getMissionPath "custom_p3ds\";
if (isNil "AP_fabPartsData") then {
    AP_fabPartsData = createHashMap;
    { AP_fabPartsData set [_x select 0, _x]; } forEach (call compile preprocessFileLineNumbers "custom_p3ds\fab_parts_data.sqf");
};
private _spec = AP_fabPartsData getOrDefault [_model, []];

if (_spec isEqualTo []) exitWith {   // a single p3d (the bench)
    private _path = _root + _model + ".p3d";
    private _o = createSimpleObject [_path, [0, 0, 0], true];
    if (isNull _o) exitWith { diag_log format ["[AP-PROBE] fabModel: createSimpleObject failed for %1", _path]; };
    _o attachTo [_anchor, [0, 0, _lift]];
    _anchor setVariable ["AP_fabModel", _o];
};

_spec params ["", "_rev", "_bodyLift", "_parts"];
private _bodyPath = format ["%1%2_body_%3.p3d", _root, _model, _rev];
private _body = createSimpleObject [_bodyPath, [0, 0, 0], true];
if (isNull _body) exitWith { diag_log format ["[AP-PROBE] fabModel: createSimpleObject failed for %1", _bodyPath]; };
_body attachTo [_anchor, [0, 0, _bodyLift]];
_anchor setVariable ["AP_fabModel", _body];
private _objs = createHashMap;   // suffix -> [object, rest offset [right, forward, up]]
{
    _x params ["_suffix", "_off"];
    private _path = format ["%1%2_%3_%4.p3d", _root, _model, _suffix, _rev];
    private _o = createSimpleObject [_path, [0, 0, 0], true];
    if (isNull _o) then {
        diag_log format ["[AP-PROBE] fabModel: createSimpleObject failed for %1", _path];
    } else {
        _o attachTo [_anchor, [_off select 0, _off select 1, (_off select 2) + _bodyLift]];
        _objs set [_suffix, [_o, _off]];
    };
} forEach _parts;
_anchor setVariable ["AP_fabParts", _objs];
_anchor setVariable ["AP_fabSpec", _spec];
diag_log format ["[AP-PROBE] fabModel: %1 drawn with %2 parts", _model, count _objs];
[_anchor] spawn AP_fnc_fabAnim;
```

- [ ] **Step 2: Write `fn_fabAnim.sqf`**

```sqf
params [["_anchor", objNull, [objNull]]];
/*
    AP_fnc_fabAnim  -- move a multi-part fabricator's parts while it prints, client-side.

    One loop per client per anchor, alive while the anchor's body is drawn (AP_fnc_fabModelClear
    ends it). All state is read from the anchor, so every client computes the same pose:

      AP_fabRun = [start, end]   serverTime; published by APS_fnc_fabSRV on "queue" and on the
                                 boot respawn. printing = serverTime < end; print time
                                 t = clamp(serverTime - start, 0, end - start) -- frozen at the
                                 last pose when idle, exactly the design page's poseF770.
      AP_fabSpec                 the generated data row: lift, rest offsets, and the print-cycle
                                 constants [PASS s, XT m, ZT m, NPASS, LAYER m, NLAYERS] read
                                 out of f770.js by the builder.

    Pose (poseF770): PASS-second passes across X with a smoothstep, direction alternating per pass;
    NPASS passes per layer sweep the head across Z, boustrophedon; the platform drops LAYER metres
    per layer and resets after NLAYERS (the demo loop). The head rides the bridge, so its offset
    carries the bridge's dx as well as its own dz. Offsets are attachTo [right, forward, up]:
    design X -> right, design Z (front +) -> forward, design Y (up) -> up.

    Screens: two coplanar quads, READY shown when idle and PRINTING while printing (hideObject is a
    local effect, which is all a client-local object needs).

    Tick 0.05 s within 120 m while printing (a 1.3 s pass over 0.56 m is ~2 cm a tick); 0.5 s when
    idle or far, like the rig's far rule -- an idle machine only needs to notice a new window.
*/
if (isNull _anchor || {!hasInterface}) exitWith {};
if (_anchor getVariable ["AP_fabAnimUp", false]) exitWith {};
_anchor setVariable ["AP_fabAnimUp", true];
private _spec = _anchor getVariable ["AP_fabSpec", []];
private _parts = _anchor getVariable ["AP_fabParts", createHashMap];
if (_spec isEqualTo [] || {count _parts isEqualTo 0}) exitWith { _anchor setVariable ["AP_fabAnimUp", false]; };
private _lift = _spec select 2;
(_spec select 4) params ["_pass", "_xt", "_zt", "_npass", "_layerM", "_nlayers"];

private _place = {
    params ["_key", "_dx", "_dfwd", "_dup"];
    private _e = _parts getOrDefault [_key, []];
    if (_e isEqualTo []) exitWith {};
    _e params ["_o", "_off"];
    if (isNull _o) exitWith {};
    _o attachTo [_anchor, [(_off select 0) + _dx, (_off select 1) + _dfwd, (_off select 2) + _lift + _dup]];
};

private _shown = "";
private _lastPose = [];
while { !isNull _anchor && { !isNull (_anchor getVariable ["AP_fabModel", objNull]) } } do {
    (_anchor getVariable ["AP_fabRun", [0, 0]]) params [["_t0", 0, [0]], ["_t1", 0, [0]]];
    private _printing = serverTime < _t1;
    private _t = ((serverTime - _t0) max 0) min ((_t1 - _t0) max 0);
    private _far = (player distance _anchor) > 120;

    private _p = floor (_t / _pass);
    private _k = (_t mod _pass) / _pass;
    private _s = _k * _k * (3 - 2 * _k);
    private _dx = ([1, -1] select ((_p mod 2) isEqualTo 1)) * (-_xt + 2 * _xt * _s);
    private _layer = floor (_p / _npass);
    private _i = _p mod _npass;
    private _sweep = [_i, _npass - 1 - _i] select ((_layer mod 2) isEqualTo 1);
    private _dz = -_zt + (2 * _zt * _sweep) / (_npass - 1);
    private _dy = -(_layer mod _nlayers) * _layerM;
    private _pose = [_dx, _dz, _dy];
    if (_pose isNotEqualTo _lastPose) then {
        ["bridge", _dx, 0, 0] call _place;
        ["head", _dx, _dz, 0] call _place;
        ["platform", 0, 0, _dy] call _place;
        _lastPose = _pose;
    };

    private _want = ["screen_ready", "screen_printing"] select _printing;
    if (_want isNotEqualTo _shown) then {
        {
            private _e = _parts getOrDefault [_x, []];
            if (_e isNotEqualTo []) then { (_e select 0) hideObject (_x isNotEqualTo _want); };
        } forEach ["screen_ready", "screen_printing"];
        _shown = _want;
    };
    uiSleep ([0.05, 0.5] select (_far || {!_printing}));
};
_anchor setVariable ["AP_fabAnimUp", false];
```

- [ ] **Step 3: Rewrite `fn_fabModelClear.sqf`**

```sqf
params [["_anchor", objNull, [objNull]]];
/*
    AP_fnc_fabModelClear -- delete a fabricator's client-local visual before its anchor goes.

    Needed because the model is a client-local simple object, not a networked one: deleting the
    anchor on the server removes the anchor everywhere but leaves each client holding an orphaned
    p3d that is attached to nothing and will sit in the world until the mission ends. The mining
    rig avoids this by making every piece a real networked object; a client-local visual has to be
    told to go. A multi-part machine is the body plus every part in AP_fabParts; clearing
    AP_fabModel is also what ends that machine's AP_fnc_fabAnim loop.
*/
if (isNull _anchor) exitWith {};
if (!hasInterface) exitWith {};
private _o = _anchor getVariable ["AP_fabModel", objNull];
if (!isNull _o) then { detach _o; deleteVehicle _o; };
{
    _y params [["_p", objNull]];
    if (!isNull _p) then { detach _p; deleteVehicle _p; };
} forEach (_anchor getVariable ["AP_fabParts", createHashMap]);
_anchor setVariable ["AP_fabModel", nil];
_anchor setVariable ["AP_fabParts", nil];
_anchor setVariable ["AP_fabSpec", nil];
```

- [ ] **Step 4: Register `fabAnim`**

```bash
cd /home/timb/Armapunk2035/mission/Armapunk2035.Malden
grep -n 'class fabModelClear {};' Functions.h
python3 - <<'EOF'
p='Functions.h'; s=open(p,encoding='utf-8').read()
a=' class fabModelClear {};'
assert s.count(a)==1, s.count(a)
s=s.replace(a, a+'\n class fabAnim {};        // F770: move the parts while it prints (client-local, started by fabModel)')
open(p,'w',encoding='utf-8').write(s)
EOF
grep -n 'class fabAnim' Functions.h
```
Expected: one hit each. (`fabAnim` is only ever `spawn`ed locally by `fabModel`; it needs no CfgRE entry.)

- [ ] **Step 5: Checks**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py mission/Armapunk2035.Malden/core/items/fn_fabModel.sqf mission/Armapunk2035.Malden/core/items/fn_fabAnim.sqf mission/Armapunk2035.Malden/core/items/fn_fabModelClear.sqf
python3 tools/sqf_cmd_check.py mission/Armapunk2035.Malden/core/items/fn_fabModel.sqf mission/Armapunk2035.Malden/core/items/fn_fabAnim.sqf mission/Armapunk2035.Malden/core/items/fn_fabModelClear.sqf
```
Expected: `ok` ×3; cmd-check reports nothing but `AP_fnc_*` names.

- [ ] **Step 6: Commit**

```bash
cd /home/timb/Armapunk2035
git add mission/Armapunk2035.Malden/core/items/fn_fabModel.sqf mission/Armapunk2035.Malden/core/items/fn_fabAnim.sqf mission/Armapunk2035.Malden/core/items/fn_fabModelClear.sqf mission/Armapunk2035.Malden/Functions.h
git commit -m "feat(fab): draw multi-part fabricators and animate the F770 while it prints

fabModel reads the generated custom_p3ds/fab_parts_data.sqf: the body attaches
like any single model and every part at its own measured offset; fabAnim
re-attaches bridge, head and platform each tick from the anchor's print window
(serverTime, so every client agrees) and flips the READY/PRINTING screen;
fabModelClear takes all of them down. Mission p3ds have no config -- this is
the Resource Extractor's method.

Co-Authored-By: Ultra Hal"
```

---

### Task 4: Server print window, tier rows, placement stand-in

**Files:**
- Modify: `server/AP_server/core/TON/fn_fabSRV.sqf` (`_spawnPrinter`, end of `case "queue"`)
- Modify: `mission/Armapunk2035.Malden/core/config/fn_fabCfg.sqf` (tier rows 1 and 2 + the comment above them)
- Modify: `mission/Armapunk2035.Malden/core/configuration.sqf` (two `AP_furnitureItems` stand-ins)

**Interfaces:**
- Produces: anchor `AP_fabRun = [start, end]` (serverTime), public.

- [ ] **Step 1: Publish the print window (exact-string edits)**

```bash
cd /home/timb/Armapunk2035
python3 - <<'EOF'
p='server/AP_server/core/TON/fn_fabSRV.sqf'; s=open(p,encoding='utf-8').read()
a='    _anchor setVariable ["owner", "fabricator", true];      // exempt from the ownerless reap\n'
assert s.count(a)==1, s.count(a)
s=s.replace(a, a+'''
    // The print window every client animates from: [started, ends] in serverTime (AP_fnc_fabAnim).
    // On a boot respawn the start is now -- nothing persists the pose, and it only has to move --
    // and the end is the longest job still running, from the database's clock like everything else.
    private _rem = [[format ["SELECT (COALESCE(MAX(GREATEST(finish_at - extract(epoch from now())::bigint, 0)), 0))::text AS n FROM house_printer_jobs WHERE printer_id=%1", _id], 2, true] call DB_fnc_asyncQuery] call _cell;
    _anchor setVariable ["AP_fabRun", [serverTime, serverTime + ([_rem] call _num)], true];
''')
b='        [_p, format ["Printing %1 x %2 -- %3 min. It runs while you are offline.",\n'
assert s.count(b)==1, s.count(b)
s=s.replace(b, '''        // extend the machine's print window (what the clients animate); a fresh window starts now
        (_anchor getVariable ["AP_fabRun", [0, 0]]) params [["_r0", 0], ["_r1", 0]];
        if (serverTime >= _r1) then { _r0 = serverTime; };
        _anchor setVariable ["AP_fabRun", [_r0, (serverTime + _secs) max _r1], true];
'''+b)
open(p,'w',encoding='utf-8').write(s); print('fabSRV patched')
EOF
grep -n 'AP_fabRun' server/AP_server/core/TON/fn_fabSRV.sqf
```
Expected: `fabSRV patched`, then three `AP_fabRun` hits (spawn, queue read, queue write). `_cell` and `_num` are defined at the top of the file (lines ~97-98), above `_spawnPrinter`; `_anchor` and `_secs` are in scope where the queue block lands (the anchor is resolved at the top of `case "queue"`, `_secs` is computed just above the INSERT).

- [ ] **Step 2: Retarget the tier rows**

```bash
cd /home/timb/Armapunk2035
python3 - <<'EOF'
p='mission/Armapunk2035.Malden/core/config/fn_fabCfg.sqf'; s=open(p,encoding='utf-8').read()
reps=[
 ('"printer_corexy", "ap_printer_corexy_r1", "CoreXY Fabricator", "printer", false, 0.2975]',
  '"printer_corexy", "ap_printer_f770", "CoreXY Fabricator", "printer", false, 0.9075]'),
 ('"printer_i3", "ap_printer_i3_r1", "i3 Fabricator", "printer", false, 0.2975]',
  '"printer_i3", "ap_printer_f770", "i3 Fabricator", "printer", false, 0.9075]'),
 ('''    // `collides` is true only for it: the printers are 0.5 m desk props built with no geometry, so
    // cursorObject slides through them and interaction has to be proximity-based; the bench is a
    // 2 m object with five collision boxes and can be targeted normally.
''',
  '''    // `collides` is true only for it. Both printer tiers now draw the F770 (one 2.2 m machine in
    // six parts, custom_p3ds\\fab_parts_data.sqf; its body has one collision box) but keep the
    // proximity interaction they always had, so one targeting path serves every machine. The p3d
    // column is the parts BASENAME for the F770 (fabModel resolves _body_r1 etc. from the data
    // file) and the lift column is informational for it -- the data file's measured half-height
    // is what fabModel uses.
'''),
]
for a,b in reps:
    assert s.count(a)==1, a[:60]; s=s.replace(a,b)
open(p,'w',encoding='utf-8').write(s); print('fabCfg patched')
EOF
grep -n 'ap_printer_' mission/Armapunk2035.Malden/core/config/fn_fabCfg.sqf
```
Expected: `fabCfg patched`; both tier rows show `"ap_printer_f770"` and `0.9075`; no `_r1` printer names remain.

- [ ] **Step 3: Placement stand-in**

The preview while placing is a stock class (the real model has no CfgVehicles entry). A 2.24 m machine previewed as a PC case lands in the wrong place; the gunsmith bench already previews as `Land_Workbench_01_F` (2 m), so both printer tiers use it too.

```bash
cd /home/timb/Armapunk2035
python3 - <<'EOF'
p='mission/Armapunk2035.Malden/core/configuration.sqf'; s=open(p,encoding='utf-8').read()
for a,b in [('["printer_i3","Land_PCSet_01_case_F"','["printer_i3","Land_Workbench_01_F"'),
            ('["printer_corexy","Land_PaperBox_closed_F"','["printer_corexy","Land_Workbench_01_F"')]:
    assert s.count(a)==1, a; s=s.replace(a,b)
open(p,'w',encoding='utf-8').write(s); print('configuration patched')
EOF
git diff --stat mission/Armapunk2035.Malden/core/configuration.sqf
```
Expected: `configuration patched`; the stat shows ONE line changed in that file (it is minified: both rows live on one line).

- [ ] **Step 4: Checks + commit**

```bash
cd /home/timb/Armapunk2035
python3 tools/sqf_balance.py server/AP_server/core/TON/fn_fabSRV.sqf mission/Armapunk2035.Malden/core/config/fn_fabCfg.sqf mission/Armapunk2035.Malden/core/configuration.sqf
python3 tools/sqf_cmd_check.py server/AP_server/core/TON/fn_fabSRV.sqf mission/Armapunk2035.Malden/core/config/fn_fabCfg.sqf
git add server/AP_server/core/TON/fn_fabSRV.sqf mission/Armapunk2035.Malden/core/config/fn_fabCfg.sqf mission/Armapunk2035.Malden/core/configuration.sqf
git commit -m "feat(fab): both printer tiers are the F770; server publishes the print window

The tier rows point at the F770 parts basename and its measured lift; the
placement preview becomes the bench's 2 m stand-in. APS_fnc_fabSRV stamps
AP_fabRun = [start, end] (serverTime) on the anchor when a job is queued and
on the boot respawn, from the same database clock the jobs already run on.

Co-Authored-By: Poncho"
```
Expected: `ok` ×3; cmd-check reports nothing but function names.

---

### Task 5: Deploy to dev and observe the machine

Sequence this AFTER the SUMMON feature's deploy (summon_plan.md Task 12) or fold both into one deploy — the owner is connected and every deploy kicks them; one kick beats two.

- [ ] **Step 1: Pre-deploy gate**

```bash
git status --short | grep -v '^??'; python3 scratchpad/skyscraper/verify_f770.py | tail -1; ls -la mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_*_r1.p3d | wc -l; head -c 4 mission/Armapunk2035.Malden/custom_p3ds/ap_printer_f770_body_r1.p3d; echo
```
Expected: clean tree, `ALL PASS`, `6`, `ODOL`.

- [ ] **Step 2: Deploy**

```bash
bash /home/timb/arma3server_dev/reload-armapunk2035.sh
```
then, until it appears (40–90 s):
```bash
grep -c "read from bank" /home/timb/arma3server_dev/loonydev.log; grep -n '\[Armapunk\]\[fab\] respawned' /home/timb/arma3server_dev/loonydev.log | tail -1
```
Expected: the bank line, and `respawned N printer(s)` with N = the dev DB's `house_printers` row count.

- [ ] **Step 3: Observe (owner in game; the agent reads the RPT)**

Owner: walk into a house with a fabricator, or place one (`printer_i3` from the Loonazon shop), then queue any recipe. Agent, newest client RPT under `~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma 3/`:
```bash
grep -h 'fabModel' "$(ls -t ~/.local/share/Steam/steamapps/compatdata/107410/pfx/drive_c/users/steamuser/AppData/Local/Arma\ 3/*.rpt | head -1)" | tail -5
```
Expected: `[AP-PROBE] fabModel: ap_printer_f770 drawn with 5 parts` per machine, no `createSimpleObject failed`. Owner sees: the machine standing on the floor (not sunk, not floating), READY on the screen; on queue, PRINTING and the bridge sweeping left-right with the head stepping front-to-back, the platform creeping down; after the job, motion stops where it is and READY returns. Each is a needstest row (owner passes); record any miss with the RPT line.

- [ ] **Step 4: Commit nothing** — the deploy script is stateless for git; the build number it wrote is in `server.cfg` on the box only.
