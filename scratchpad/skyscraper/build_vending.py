#!/usr/bin/env python3
"""vending_dump.json -> mission/.../custom_p3ds/ap_vend_<slug>_r1.p3d  (twelve of them)

The vending machine from vending.js via harness_vending.mjs, per ARMA3_HANDOFF_VENDING.md.

TWELVE FILES FROM ONE GEOMETRY, WHICH IS THE POINT OF THE PROP. The handoff's design is three
logo faces, each owning a material nothing else uses, so a shop variant is the same 956 triangles
with three texture paths swapped: "Duplicate the .p3d with different logo paths per brand." The
harness ASSERTS that one-mesh-one-material property (see its LOGO slot check) so a re-drop that
breaks it fails there rather than shipping twelve machines with the sign on the wrong face.

THE SHELL IS NOT metal_panels_white_co, AND THAT IS A DELIBERATE DEPARTURE FROM THE HANDOFF.
The design says "near-black gloss shell (metal_panels_white_co tinted dark)". That works in the
three.js viewer, where material.color multiplies the map. Arma does not tint: it paints the .paa
as authored, so pointing the shell at a WHITE panel texture would ship a white vending machine
against a design that is explicitly near-black. Same trap the gunsmith bench hit (build_gunsmith.py
r2, "the handoff's metal sheets are what the viewer TINTS by material colour"), same fix: the dark
parts go to metal_plate_04_co, which is dark and un-rusted at source. The design's intent -- near
black -- is preserved; only the route to it changes.

LODs, from the handoff's ladder, scaled to what the source actually contains. The document says
"~90 meshes / ~3.5k tris"; the shipped vending.js builds 58 meshes / 956 tris (the harness prints
both). The ladder's SHAPE is followed exactly -- LOD2 drops buttons, hinges and vents; LOD3 keeps
body plus front panel -- and the resulting counts land under the document's targets rather than on
them, because there was less geometry to start with.

    1.0    everything                                        956 tris
    2.0    no selection buttons/labels, hinges, vents, feet, small mech detail
    3.0    cabinet body, top cap, base, curved front panel, side logos
    1e13   Geometry: ONE box 0.81 x 1.83 x 0.84, mass 320    6e15 View    7e15 Fire

GEOMETRY IS THE HANDOFF'S BOX, NOT THE VISIBLE BOUNDS, and it is smaller than the model on
purpose. The visible mesh spans 0.824 x 1.830 x 0.902 -- the top cap's 6 mm lip, the curved
panel's 56 mm bulge and the door hinges all sit proud of the cabinet. Collision may be smaller
than the model and must never be larger, so the authored 0.81 x 1.83 x 0.84 is used verbatim: it
means the sign panel and the pickup flap cannot snag a player walking past, which is test-checklist
item 4 in the handoff.

ORIGIN: centred on its own bbox, like every simple object in this pipeline -- the engine
autocentres them and discards the authored origin, so centring makes the engine's centre and ours
agree and a plain setPosASL + halfHeight lands it exactly.
"""
import copy
import filecmp
import json
import os
import re
import struct
import sys

sys.path.insert(0, '/home/timb/blender_work')
import mlod_rw                                                     # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_gunsmith import Lod, add_box, emit                      # noqa: E402  reuse the writer

REV = 'r4'   # r4 (owner 2026-09-06): FLAT front panel re-drop (vendingflat.zip) so the served HTML sign sits flush. r3: mirror + black shell
# MLOD sources stay HERE, beside every other model in this pipeline. binarize_mlods.sh is what puts
# the ODOL into mission/custom_p3ds -- shipping the MLOD directly would work but loads slower and
# breaks the convention every other custom model in the mission follows.
OUT_DIR = HERE

A3 = b'a3\\'
MISSION = b'mpmissions\\__cur_mp.Malden\\'
CLEAN_RV = A3 + b'structures_f\\data\\metal\\metalclean1.rvmat'
SIGN_RV = MISSION + b'ap_vendsign.rvmat'

# The twelve shops, in the order the handoff's table lists them. The slug is the single key that
# ties the sign art, the .paa, the .p3d and the wiring table together.
SHOPS = ['synthmeat', 'cyberthreads', 'lopoint', 'carshop', 'airshop', 'gearshop',
         'illeagle', 'illeaglevehicles', 'pharma', 'reallyilleagle',
         'reallyilleagleweapons', 'kabuki']

# usemtl -> (texture, rvmat), for everything that is NOT a logo slot. The three LOGO_* materials
# are filled in per shop by tex_for() below.
TEX = {
    # "near-black gloss shell" / "black top cap". r2 mapped these to A3's metal_plate_04 / metal_seams
    # sheets, which read as grey concrete slabs in the plaza light (owner, first look: "should be black
    # all around and not whatever the image is"). r3: the same near-black the logo faces use.
    'metal_panels_white_co': (b'#(argb,8,8,3)color(0.05,0.06,0.08,1.0,co)', CLEAN_RV),
    'metal_seams_01_co':     (b'#(argb,8,8,3)color(0.05,0.06,0.08,1.0,co)', CLEAN_RV),
    # the small mech surfaces keep the design's own procedural colours, read out of the dump rather
    # than typed here -- see build_tex() -- because vending.js already states them.
}
PROC = {
    'vend_plate_proc':  CLEAN_RV,
    'vend_dark_proc':   CLEAN_RV,
    'vend_button_proc': CLEAN_RV,
    'vend_label_proc':  b'',          # lit label strip: flat, no spec ladder
    'vend_steel_proc':  CLEAN_RV,
    'vend_slot_proc':   CLEAN_RV,
    'vend_card_proc':   b'',
    'vend_flap_proc':   CLEAN_RV,
    'vend_vent_proc':   CLEAN_RV,
}
LOGO_MATS = {'LOGO_front_ca': 'front', 'LOGO_side_l_ca': 'side', 'LOGO_side_r_ca': 'side'}

# LOD 2.0: these go. The handoff's list -- "drop buttons/hinges/vents" -- plus the feet and the
# millimetre-scale coin mech parts, which are the same class of detail at the same size.
LOD2_DROP = re.compile(r'^(sel_btn_|sel_lbl_|hinge_|vent_|foot_|lock_|coin_slot_|coin_return_|'
                       r'bill_slit_|price_win_|flap_push_|door_seam_)')

# LOD 3.0: only these survive -- "body + front panel", read as the cabinet silhouette plus the sign
# faces, because a machine with no signs at distance is an anonymous black box.
LOD3_KEEP = re.compile(r'^(body_|top_cap_|base_|LOGO_front_|LOGO_side_L_|LOGO_side_R_|col_face_)')

# Geometry: the handoff's single authored box, (sizeX, sizeY, sizeZ) about the cabinet centre.
GEO_BOX = (0.81, 1.83, 0.84)
MASS = 320.0


def build_tex(mats, slug):
    """usemtl -> (texture, rvmat) for one shop. Procedural colours come from the DUMP, never typed."""
    out = {}
    for name, m in mats.items():
        if name in LOGO_MATS:
            # r2: the cabinet's own logo faces are plain near-black. The sign art lives on a vanilla
            # UserTexture quad hung 1-2 cm proud of each face by NPC_fnc_vendShop -- a REAL object,
            # which is what a Syntax-1 simple object cannot be: texturable, and able to carry
            # addAction (BIKI createSimpleObject: "cannot be textured", "addAction does not work").
            # One p3d for twelve shops follows from that; the per-shop MLODs are gone.
            out[name] = (b'#(argb,8,8,3)color(0.05,0.06,0.08,1.0,co)', CLEAN_RV)
        elif name in TEX:
            out[name] = TEX[name]
        elif name in PROC:
            r, g, b = (int(m['color'][i:i + 2], 16) / 255.0 for i in (1, 3, 5))
            out[name] = (b'#(argb,8,8,3)color(%.2f,%.2f,%.2f,1.0,co)' % (r, g, b), PROC[name])
        else:
            raise AssertionError(f'material with no mapping: {name}')
    return out


def mirror_x(meshes):
    """three.js is RIGHT-handed (X right, Y up, Z toward the viewer); an Arma p3d is LEFT-handed (X right,
    Y up, Z forward, away from the viewer). Copying the coordinates across keeps the front at +Z but a
    player facing the machine sees the design's +X on their LEFT -- the whole cabinet is a mirror
    image (owner, first look in-game: "they're inverted": the coin/button column on the wrong side).
    Negate X and reverse every triangle's winding so the faces still point out. The gunsmith / F770 /
    tower builders share the writer and carry the same mirror; this fixes the cabinet only."""
    for m in meshes:
        pos, nrm, uv = m['pos'], m['norm'], m['uv']
        for i in range(0, len(pos), 3): pos[i] = -pos[i]; nrm[i] = -nrm[i]
        P, N, U = [], [], []
        for t in range(len(pos) // 9):
            for c in (0, 2, 1):
                i = t * 3 + c
                P += pos[3 * i:3 * i + 3]; N += nrm[3 * i:3 * i + 3]; U += uv[2 * i:2 * i + 2]
        m['pos'], m['norm'], m['uv'] = P, N, U


def main():
    data = json.load(open(f'{HERE}/vending_dump.json'))['vending']
    meshes, mats = data['meshes'], data['mats']
    mirror_x(meshes)

    xs, ys, zs = [], [], []
    for m in meshes:
        p = m['pos']; xs += p[0::3]; ys += p[1::3]; zs += p[2::3]
    lo = (min(xs), min(ys), min(zs)); hi = (max(xs), max(ys), max(zs))
    ctr = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)

    # Every LOGO slot must be reachable by the LOD3 keep-list, or a distant machine loses its sign.
    for slot in ('LOGO_front', 'LOGO_side_L', 'LOGO_side_R'):
        hit = [m for m in meshes if m['name'].startswith(slot + '_')]
        assert len(hit) == 1, f'{slot}: {len(hit)} meshes'
        assert LOD3_KEEP.match(hit[0]['name']), f'{slot} is not in the LOD3 keep list'

    # The geometry box is authored about the CABINET centre (x 0, z 0 in the design frame), which
    # is not the visible-mesh centre -- the curved panel pushes the bbox forward. Centre the box on
    # the cabinet and then express it relative to the model origin we just chose.
    gmn = [-GEO_BOX[0] / 2 - ctr[0], 0.0 - ctr[1], -GEO_BOX[2] / 2 - ctr[2]]
    gmx = [GEO_BOX[0] / 2 - ctr[0], GEO_BOX[1] - ctr[1], GEO_BOX[2] / 2 - ctr[2]]
    for i in range(3):
        assert gmn[i] >= lo[i] - ctr[i] - 1e-6 and gmx[i] <= hi[i] - ctr[i] + 1e-6, \
            f'geometry box axis {i} is LARGER than the visible model; collision must never be'

    os.makedirs(OUT_DIR, exist_ok=True)

    # ---- sign slots, MEASURED from the logo meshes and emitted as SQF -- never hand-copied.
    # SQF model space is [x right, y FORWARD, z UP]; the p3d/design frame is X right, Y up,
    # Z forward, so p3d (x, y, z) -> SQF [x, z, y], all relative to the centred origin.
    # Front: the curved panel's PEAK z (its bulge), so the quad clears the arc; sides: the flat
    # quads' own plane. Each slot = [centre, outward normal, size [w, h]] and the quad is pushed
    # STANDOFF metres along the normal by the spawner.
    def slot(prefix, axis, sign):
        m = next(m for m in meshes if m['name'].startswith(prefix + '_'))
        P = m['pos']; X, Y, Z = P[0::3], P[1::3], P[2::3]
        cx, cy = (min(X) + max(X)) / 2, (min(Y) + max(Y)) / 2
        cz = (min(Z) + max(Z)) / 2
        if axis == 'z':
            cz = max(Z) if sign > 0 else min(Z)
        else:
            cx = max(X) if sign > 0 else min(X)
        size = [max(X) - min(X), max(Y) - min(Y)] if axis == 'z' else [max(Z) - min(Z), max(Y) - min(Y)]
        n = [0, sign, 0] if axis == 'z' else [sign, 0, 0]
        return [round(cx - ctr[0], 4), round(cz - ctr[2], 4), round(cy - ctr[1], 4)], n, [round(v, 3) for v in size]
    # after mirror_x the design's LEFT logo face sits at +x and its RIGHT at -x; the outward normal
    # follows the face, the design's name stays on the slot
    slots = [('front', slot('LOGO_front', 'z', +1)), ('side_l', slot('LOGO_side_L', 'x', +1)),
             ('side_r', slot('LOGO_side_R', 'x', -1))]
    inc = os.path.abspath(os.path.join(HERE, '..', '..', 'mission', 'Armapunk2035.Malden', 'npcs', 'vend_signs.inc.sqf'))
    with open(inc, 'w') as f:
        f.write('// GENERATED by scratchpad/skyscraper/build_vending.py from vending_dump.json -- do not hand-edit.\n')
        f.write('// Sign slots on ap_vend_cabinet_%s.p3d, SQF model space [x right, y forward, z up] from the\n' % REV)
        f.write('// centred origin: [face, centre, outward normal, [width, height] m]. Consumed by fn_vendShop.sqf.\n')
        f.write('AP_vendSignSlots = [\n')
        for i, (face, (c, n, sz)) in enumerate(slots):
            f.write('    ["%s", %s, %s, %s]%s\n' % (face, c, n, sz, ',' if i < len(slots) - 1 else ''))
        f.write('];\n')
    print('wrote', os.path.relpath(inc), slots)

    written = []
    for slug in ['cabinet']:
        tex = build_tex(mats, slug)
        vis, l2, l3 = Lod(1.0), Lod(2.0), Lod(3.0)
        for m in meshes:
            t, r = tex[m['mat']]
            emit(vis, m, ctr, tex=t, mat=r)
            if not LOD2_DROP.match(m['name']):
                emit(l2, m, ctr, tex=t, mat=r)
            if LOD3_KEEP.match(m['name']):
                emit(l3, m, ctr, tex=t, mat=r)

        geo = Lod(1e13)
        sel = (set(), set())
        geo.comp_key = 1
        add_box(geo, tuple(gmn), tuple(gmx), sel=sel)
        geo.selections = [('Component01', sel[0], sel[1])]
        geo_f = geo.finish(mass_total=MASS)
        view_f = copy.deepcopy(geo_f); view_f['res'] = 6e15
        view_f['taggs'] = [t for t in view_f['taggs'] if t['name'] != b'#Mass#']
        fire_f = copy.deepcopy(geo_f); fire_f['res'] = 7e15
        fire_f['taggs'] = [t for t in fire_f['taggs'] if t['name'] != b'#Mass#']

        out = os.path.join(OUT_DIR, f'ap_vend_{slug}_{REV}.p3d')
        lods = [vis.finish(), l2.finish(), l3.finish(), geo_f, view_f, fire_f]
        n = mlod_rw.write(out, 257, lods)
        ver2, back = mlod_rw.parse(out)
        mlod_rw.write(out + '.rt', ver2, back)
        assert filecmp.cmp(out, out + '.rt', shallow=False), f'{slug}: round-trip mismatch'
        os.remove(out + '.rt')
        written.append((slug, n, len(lods[0]['faces']), len(lods[1]['faces']), len(lods[2]['faces'])))

    for slug, n, f1, f2, f3 in written:
        print(f'  ap_vend_{slug}_{REV}.p3d  {n:7d} B   LOD 1.0={f1}  2.0={f2}  3.0={f3}')
    print(f'{len(written)} machines, {sum(w[1] for w in written)} bytes '
          f'({sum(w[1] for w in written) / 1e6:.2f} MB)')
    print(f'  visible {hi[0]-lo[0]:.3f} x {hi[1]-lo[1]:.3f} x {hi[2]-lo[2]:.3f} m   '
          f'halfHeight={(hi[1]-lo[1])/2:.4f}')
    print(f'  geometry {GEO_BOX[0]} x {GEO_BOX[1]} x {GEO_BOX[2]} m  mass={MASS}')


if __name__ == '__main__':
    main()
