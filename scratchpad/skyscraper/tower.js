import * as THREE from 'three';
import { AC_UNIT } from './ac-unit-data.js';
import { DOOR_LEAF } from './door-leaf-data.js';
const DOORS = (await (await fetch('./doors-manifest.json')).json()).doors;

// ---- constants (meters, y-up, origin at plan center, base at y=0) ----
const EPS = .005;
const SLAB = .28;               // slab thickness
const L = [.3];                 // floor levels: L[0] lobby floor .. L[20] roof
for (let i = 1; i <= 20; i++) L.push(L[i - 1] + (i === 1 ? 5.0 : 3.4));
const ROOF = L[20];             // 69.9

// ---- materials, named after Arma 3 base-game textures (see ARMA3_HANDOFF.md) ----
const mats = {};
const TL = new THREE.TextureLoader();
function tex(p) { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; }
function M(name, opts) { const m = new THREE.MeshStandardMaterial(opts); m.name = name; mats[name] = m; return m; }
M('concrete_panels_co',              { map: tex('a3/structures_f_enoch/data/concrete/concrete_panels_co.png'), roughness: .85 });
M('plaster03_4x4_office_co',         { map: tex('a3/structures_f/data/plaster/plaster03_4x4_office_co.png'), roughness: .92 });
M('window_set_dark_2_ca',           { map: tex('a3/structures_f_exp/data/glass/window_set_dark_2_ca.png'), roughness: .1, metalness: .25, transparent: true, opacity: .8 });
M('concrete_floor_02_co',           { map: tex('a3/structures_f_enoch/data/floor/concrete/concrete_floor_02_co.png'), roughness: .95 });
M('hotel_02_floor_co',              { map: tex('a3/structures_f_exp/data/wood/hotel_02_floor_co.png'), roughness: .7 });
M('tile_04a_co',                    { map: tex('a3/structures_f/data/tile/tile_04a_co.png'), roughness: .55 });
M('asphalt_roof_a_co', { map: tex('a3/structures_f_enoch/data/roof/asphalt_roof_a_co.png'), roughness: 1 });
M('wooden_bridge_co',               { map: tex('a3/structures_f_exp/data/wood/wooden_bridge_co.png'), roughness: .75 });
M('rollup_combo_co',                { map: tex('a3/structures_f/data/metal/rollup_combo_co.png'), roughness: .5,  metalness: .3 });
M('office_addons_co',               { map: tex('a3/structures_f/civ/offices/data/office_addons_co.png'), roughness: .55, metalness: .2 });
M('house_big02_multi2',             { map: tex('a3/structures_f_argo/civilian/house_big02/data/i_house_big_02_b_pink_mlod_co.png'), roughness: .6 });
M('metal_grey_proc',                { color: 0x8d9296, roughness: .45, metalness: .35 });
M('metal_dark_proc',                { color: 0x33383e, roughness: .5,  metalness: .3 });
M('white_marking_proc',             { color: 0xe8e6df, roughness: .8, side: THREE.DoubleSide });

// ---- geometry helpers ----
const _m = new THREE.Matrix4(), _e = new THREE.Euler(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(1, 1, 1), _p = new THREE.Vector3();
function boxGeo(w, h, d, s = 2) { // box with world-scaled UVs (1 tile per s meters)
  const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) {
    const i = f * 4 + v;
    uv.setXY(i, uv.getX(i) * dims[f][0] / s, uv.getY(i) * dims[f][1] / s);
  }
  return g;
}
function place(g, x, y, z, rx = 0, ry = 0, rz = 0) {
  _q.setFromEuler(_e.set(rx, ry, rz));
  g.applyMatrix4(_m.compose(_p.set(x, y, z), _q, _s));
  return g;
}
// world-ALIGNED UVs (1 tile per s meters, continuous across adjacent boxes — keeps texture bands aligned)
function alignUV(g, s = 2) {
  const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
  for (let i = 0; i < uv.count; i++) {
    const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
    let u, v;
    if (ax >= ay && ax >= az) { u = p.getZ(i); v = p.getY(i); }
    else if (ay >= ax && ay >= az) { u = p.getX(i); v = p.getZ(i); }
    else { u = p.getX(i); v = p.getY(i); }
    uv.setXY(i, u / s, v / s);
  }
  return g;
}
function B(w, h, d, x, y, z) { return place(boxGeo(w, h, d), x, y, z); }
function BB(x0, x1, y0, y1, z0, z1) { return alignUV(place(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)); }
function merge(geos) {
  const list = geos.map(g => g.index ? g.toNonIndexed() : g);
  const n = list.reduce((a, g) => a + g.attributes.position.count, 0);
  const out = new THREE.BufferGeometry();
  for (const name of ['position', 'normal', 'uv']) {
    const it = list[0].attributes[name].itemSize, arr = new Float32Array(n * it); let o = 0;
    for (const g of list) { arr.set(g.attributes[name].array, o); o += g.attributes[name].array.length; }
    out.setAttribute(name, new THREE.BufferAttribute(arr, it));
  }
  return out;
}
function mesh(name, geos, mat, parent, split = false) {
  if (!geos.length) return;
  if (split) { // one object per convex box (collision-safe for P3D Geometry LOD)
    geos.forEach((g, i) => {
      const m = new THREE.Mesh(g.index ? g.toNonIndexed() : g, mat);
      m.name = `${name}_c${String(i).padStart(2, '0')}`; m.castShadow = m.receiveShadow = true;
      parent.add(m);
    });
    return;
  }
  const m = new THREE.Mesh(merge(geos), mat);
  m.name = name; m.castShadow = m.receiveShadow = true;
  parent.add(m);
  return m;
}
// wall runs with door openings (t = thickness); doors: {c: center, w, h}
function wallX(x0, x1, zc, t, y0, y1, doors = []) {
  const g = []; let c = x0;
  for (const d of [...doors].sort((a, b) => a.c - b.c)) {
    const a = d.c - d.w / 2, b = d.c + d.w / 2;
    if (a > c) g.push(BB(c, a, y0, y1, zc - t / 2, zc + t / 2));
    g.push(BB(a, b, y0 + d.h, y1, zc - t / 2, zc + t / 2));
    c = b;
  }
  if (c < x1) g.push(BB(c, x1, y0, y1, zc - t / 2, zc + t / 2));
  return g;
}
function wallZ(z0, z1, xc, t, y0, y1, doors = []) {
  const g = []; let c = z0;
  for (const d of [...doors].sort((a, b) => a.c - b.c)) {
    const a = d.c - d.w / 2, b = d.c + d.w / 2;
    if (a > c) g.push(BB(xc - t / 2, xc + t / 2, y0, y1, c, a));
    g.push(BB(xc - t / 2, xc + t / 2, y0 + d.h, y1, a, b));
    c = b;
  }
  if (c < z1) g.push(BB(xc - t / 2, xc + t / 2, y0, y1, c, z1));
  return g;
}
function frameX(cx, zc, w, h, y0) { // door frame, opening along x (v = overlap into wall edges, kills z-fighting)
  const j = .09, d = .32, v = .02;
  return [
    BB(cx - w / 2 - j, cx - w / 2 + v, y0, y0 + h + j, zc - d / 2, zc + d / 2),
    BB(cx + w / 2 - v, cx + w / 2 + j, y0, y0 + h + j, zc - d / 2, zc + d / 2),
    BB(cx - w / 2, cx + w / 2, y0 + h - v, y0 + h + j, zc - d / 2, zc + d / 2)];
}
function frameZ(cz, xc, w, h, y0) {
  const j = .09, d = .32, v = .02;
  return [
    BB(xc - d / 2, xc + d / 2, y0, y0 + h + j, cz - w / 2 - j, cz - w / 2 + v),
    BB(xc - d / 2, xc + d / 2, y0, y0 + h + j, cz + w / 2 - v, cz + w / 2 + j),
    BB(xc - d / 2, xc + d / 2, y0 + h - v, y0 + h + j, cz - w / 2, cz + w / 2)];
}

// switchback stair: lane A x[-4.4,-3.1] rises floor->mid landing (south),
// lane B x[-1.4,-0.1] rises mid landing->next floor (arrives at north landing slab strip)
function buildStairs(y0, rise) {
  const half = rise / 2, n = Math.max(10, Math.ceil(half / .18)), r = half / n;
  const run = 2.6, tread = run / (n - 1), A = [], B_ = [], land = [], rails = [];
  for (let k = 0; k < n - 1; k++) { const z1 = 1.3 - k * tread, top = y0 + (k + 1) * r; A.push(BB(-4.4, -3.1, top - r - .16, top, z1 - tread, z1)); }
  land.push(BB(-4.4, -.1, y0 + half - .22, y0 + half, -2.5, -1.3)); // mid landing
  for (let k = 0; k < n - 1; k++) { const z0 = -1.3 + k * tread, top = y0 + half + (k + 1) * r; B_.push(BB(-1.4, -.1, top - r - .16, top, z0, z0 + tread)); }
  const th = Math.atan2(half, run), len = Math.hypot(run, half);
  for (const [lx, rot, yc] of [[-3.13, th, y0 + half / 2], [-1.37, -th, y0 + rise * .75]])
    for (const ry of [.55, .95]) rails.push(place(boxGeo(.06, .09, len), lx, yc + ry, 0, rot, 0, 0));
  rails.push(BB(-3.16, -1.34, y0 + half + .05, y0 + half + .95, -1.36, -1.30)); // mid-landing well guard
  rails.push(BB(-3.16, -1.34, y0 + .05, y0 + .95, 1.30, 1.36));                 // floor-level well guard
  return { A, B: B_, land, rails };
}

// map each box face's UVs into the clean pane region of window_set_dark_2_ca
// (measured from the jewelry model's storefront: u .35-.63, v .23-.56 arma / v flipped for OBJ)
function pinGlassUV(g) {
  const uv = g.attributes.uv;
  for (let f = 0; f < uv.count; f += 4) {
    let mu = 1e9, Mu = -1e9, mv = 1e9, Mv = -1e9;
    for (let i = f; i < f + 4; i++) { mu = Math.min(mu, uv.getX(i)); Mu = Math.max(Mu, uv.getX(i)); mv = Math.min(mv, uv.getY(i)); Mv = Math.max(Mv, uv.getY(i)); }
    for (let i = f; i < f + 4; i++) {
      const nu = (uv.getX(i) - mu) / (Mu - mu || 1), nv = (uv.getY(i) - mv) / (Mv - mv || 1);
      uv.setXY(i, .46 + nu * .16, .443 + nv * .325);
    }
  }
  return g;
}

// 7-segment digits as boxes (base-game-legal: procedural color materials), on an x/y plane
const SEGMAP = { '0': 'abcdef', '1': 'bc', '2': 'abgde', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd', '6': 'afgedc', '7': 'abc', '8': 'abcdefg', '9': 'abfgcd' };
function segDigits(str, cx, cy, z0, z1, h, flip = false) {
  const geos = [], w = h * .52, t = h * .13, gap = h * .18, full = str.length * w + (str.length - 1) * gap;
  let x0 = cx - full / 2;
  const X = (a, b) => flip ? [2 * cx - b, 2 * cx - a] : [a, b];
  for (const ch of str) {
    const L = x0, R = x0 + w, T = cy + h / 2, B = cy - h / 2, M = cy;
    const S = { a: [L, R, T - t, T], d: [L, R, B, B + t], g: [L, R, M - t / 2, M + t / 2],
                f: [L, L + t, M, T], b: [R - t, R, M, T], e: [L, L + t, B, M], c: [R - t, R, B, M] };
    for (const s of SEGMAP[ch]) { const [xa, xb] = X(S[s][0], S[s][1]); geos.push(BB(xa, xb, S[s][2], S[s][3], z0, z1)); }
    x0 += w + gap;
  }
  return geos;
}

export function buildTower() {
  const root = new THREE.Group();
  root.name = 'arma3_skyscraper_20f';

  const MUL = [-8.4, -5.6, -2.8, 0, 2.8, 5.6, 8.4]; // facade mullion grid

  for (let i = 0; i < 20; i++) {
    const p = String(i + 1).padStart(2, '0');
    const fl = new THREE.Group(); fl.name = 'floor_' + p; root.add(fl);
    const y = L[i], yTop = L[i + 1] - SLAB, rise = L[i + 1] - L[i];
    const w0 = y + .01, w1 = yTop; // interior wall extent

    // -- slab under this floor (top face = floor level) --
    if (i === 0) {
      mesh(`F${p}_slab`, [BB(-12, 12, 0, .3, -12, 12)], mats.concrete_floor_02_co, fl, true);
    } else {
      mesh(`F${p}_slab`, [
        BB(-11.69, 11.69, y - SLAB, y, 2.5, 11.69),
        BB(-11.69, 11.69, y - SLAB, y, -11.69, -2.5),
        BB(-11.69, -4.4, y - SLAB, y, -2.5, 2.5),
        BB(4.4, 11.69, y - SLAB, y, -2.5, 2.5),
        BB(-4.4, -.1, y - SLAB, y, 1.3, 2.5),   // stair north landing
        BB(-.1, .1, y - SLAB, y, -2.5, 2.5)],   // under core divider
        mats.concrete_floor_02_co, fl, true);
    }

    // -- interior walls (plaster) --
    const walls = [];
    // core: stair (west half) + elevator shaft (east half)
    walls.push(...wallX(-4.6, 4.6, 2.6, .2, w0, w1, [{ c: -2.2, w: 1.0, h: 2.2 }, { c: 2.2, w: 1.4, h: 2.2 }]));
    walls.push(...wallX(-4.6, 4.6, -2.6, .2, w0, w1));
    walls.push(...wallZ(-2.55, 2.55, -4.5, .2, w0, w1));
    walls.push(...wallZ(-2.55, 2.55, 4.5, .2, w0, w1));
    walls.push(...wallZ(-2.55, 2.55, 0, .2, w0, w1)); // stair/shaft divider
    if (i > 0) {
      // ring corridor walls, one door per quadrant room
      walls.push(...wallX(-6.8, 6.8, 4.7, .2, w0, w1, [{ c: -3.3, w: 1.1, h: 2.2 }, { c: 3.3, w: 1.1, h: 2.2 }]));
      walls.push(...wallX(-6.8, 6.8, -4.7, .2, w0, w1, [{ c: -3.3, w: 1.1, h: 2.2 }, { c: 3.3, w: 1.1, h: 2.2 }]));
      walls.push(...wallZ(-4.75, 4.75, -6.7, .2, w0, w1));
      walls.push(...wallZ(-4.75, 4.75, 6.7, .2, w0, w1));
      // cross partitions between the 4 L-shaped rooms
      walls.push(...wallZ(4.75, 11.75, 0, .2, w0, w1));
      walls.push(...wallZ(-11.75, -4.75, 0, .2, w0, w1));
      walls.push(...wallX(6.75, 11.75, 0, .2, w0, w1));
      walls.push(...wallX(-11.75, -6.75, 0, .2, w0, w1));
    }
    mesh(`F${p}_walls_interior`, walls, mats.plaster03_4x4_office_co, fl, true);

    // -- floor coverings --
    const c0 = y + .005, c1 = y + .025;
    if (i === 0) {
      mesh(`F${p}_floor_tile`, [
        BB(-11.68, 11.68, c0, c1, 2.7, 11.68),
        BB(-11.68, 11.68, c0, c1, -11.68, -2.7),
        BB(-11.68, -4.6, c0, c1, -2.7, 2.7),
        BB(4.6, 11.68, c0, c1, -2.7, 2.7)], mats.tile_04a_co, fl);
    } else {
      mesh(`F${p}_floor_wood`, [
        BB(-11.68, -.1, c0, c1, 4.8, 11.68), BB(-11.68, -6.8, c0, c1, .1, 4.8),      // NW
        BB(.1, 11.68, c0, c1, 4.8, 11.68), BB(6.8, 11.68, c0, c1, .1, 4.8),          // NE
        BB(-11.68, -.1, c0, c1, -11.68, -4.8), BB(-11.68, -6.8, c0, c1, -4.8, -.1),  // SW
        BB(.1, 11.68, c0, c1, -11.68, -4.8), BB(6.8, 11.68, c0, c1, -4.8, -.1)],     // SE
        mats.hotel_02_floor_co, fl);
      mesh(`F${p}_floor_corridor`, [
        BB(-6.6, 6.6, c0, c1, 2.7, 4.6), BB(-6.6, 6.6, c0, c1, -4.6, -2.7),
        BB(-6.6, -4.6, c0, c1, -2.7, 2.7), BB(4.6, 6.6, c0, c1, -2.7, 2.7)],
        mats.concrete_floor_02_co, fl);
    }

    // -- stairs (one mesh per flight: a per-flight convex hull is a walkable wedge, never an overhang) --
    const st = buildStairs(y, rise);
    mesh(`F${p}_stairA`, st.A, mats.concrete_floor_02_co, fl, true);
    mesh(`F${p}_stairB`, st.B, mats.concrete_floor_02_co, fl, true);
    mesh(`F${p}_stairLand`, st.land, mats.concrete_floor_02_co, fl, true);
    mesh(`F${p}_stair_rails`, st.rails, mats.metal_grey_proc, fl, true);
    // fake elevator door sealing the shaft opening (replace with scripted elevator later)
    mesh(`F${p}_elevator_door`, [BB(1.5, 2.9, w0, w0 + 2.2, 2.58, 2.64)], mats.rollup_combo_co, fl);
    // signage: floor number in corridor (core N wall) + stairwell landing, room number beside each door
    const plates = [], digits = [], fno = String(i + 1);
    plates.push(BB(-.45, .45, w0 + 1.25, w0 + 1.95, 2.695, 2.72));
    digits.push(...segDigits(fno, 0, w0 + 1.6, 2.72, 2.737, .5));
    plates.push(BB(-1.35, -.45, w0 + 1.3, w0 + 1.9, 2.48, 2.505));
    digits.push(...segDigits(fno, -.9, w0 + 1.6, 2.465, 2.482, .42, true));
    if (i > 0) {
      for (const [cx, zc, rn] of [[-3.3, 4.7, '1'], [3.3, 4.7, '2'], [3.3, -4.7, '3'], [-3.3, -4.7, '4']]) {
        const s = (i + 1) + '0' + rn;
        if (zc > 0) { plates.push(BB(cx + .67, cx + 1.03, w0 + 1.42, w0 + 1.62, 4.585, 4.61)); digits.push(...segDigits(s, cx + .85, w0 + 1.52, 4.571, 4.586, .12, true)); }
        else { plates.push(BB(cx + .67, cx + 1.03, w0 + 1.42, w0 + 1.62, -4.61, -4.585)); digits.push(...segDigits(s, cx + .85, w0 + 1.52, -4.586, -4.571, .12)); }
      }
    }
    mesh(`F${p}_sign_plates`, plates, mats.metal_dark_proc, fl);
    mesh(`F${p}_sign_digits`, digits, mats.white_marking_proc, fl);

    // -- facade --
    const conc = [], glass = [], mull = [], frames = [];
    if (i === 0) {
      // lobby: storefront glazing, piers, entrance
      const g0 = .295, g1 = 4.3 + EPS;
      glass.push(...wallX(-11.3, 11.3, 11.85, .06, g0, g1, [{ c: 0, w: 3.6, h: 2.9 - g0 + .3 }]));  // N entrance
      glass.push(...wallX(-11.3, 11.3, -11.85, .06, g0, g1, [{ c: 0, w: 1.2, h: 2.2 }]));           // S exit
      glass.push(BB(11.82, 11.88, g0, g1, -11.3, 11.3));
      glass.push(BB(-11.88, -11.82, g0, g1, -11.3, 11.3));
      for (const s of [1, -1]) {
        conc.push(BB(11.2 * s, 12 * s, g0, g1, 11.2, 12), BB(11.2 * s, 12 * s, g0, g1, -12, -11.2)); // corner piers
        conc.push(BB(-12, 12, 4.3, yTop, 11.7 * s, 12 * s));                                          // header N/S
        conc.push(BB(11.7 * s, 12 * s, 4.3, yTop, -11.8, 11.8));                                      // header E/W
        for (const q of [5.6, -5.6]) {
          conc.push(BB(q - .25, q + .25, g0, g1, 11.68 * s, 12.02 * s)); // mid piers N/S
          conc.push(BB(11.68 * s, 12.02 * s, g0, g1, q - .25, q + .25)); // mid piers E/W
        }
        for (const q of [2.8, -2.8, 8.4, -8.4]) {
          mull.push(BB(q - .05, q + .05, g0, g1, 11.79 * s, 11.91 * s));
          mull.push(BB(11.79 * s, 11.91 * s, g0, g1, q - .05, q + .05));
        }
        conc.push(BB(8 * s - .275, 8 * s + .275, .31, yTop, 7.725, 8.275));   // interior columns
        conc.push(BB(8 * s - .275, 8 * s + .275, .31, yTop, -8.275, -7.725));
      }
      conc.push(BB(-3.4, 3.4, 3.5, 3.74, 12.02, 14.6));  // canopy
      conc.push(BB(-4, 4, 0, .3, 12, 14.2));             // entry apron
      conc.push(BB(-4, 4, 0, .15, 14.2, 14.8));          // step
      frames.push(...frameX(0, 11.85, 3.6, 2.9, .3));
      frames.push(...frameX(0, -11.85, 1.2, 2.2, .3));
      // decorative always-open entrance panes (no function): hinged open ~100° into the lobby
      const leafL = boxGeo(1.76, 2.86, .05); leafL.translate(.88, 0, 0);
      const leafR = boxGeo(1.76, 2.86, .05); leafR.translate(-.88, 0, 0);
      place(leafL, -1.78, 1.74, 11.85, 0, THREE.MathUtils.degToRad(100), 0);
      place(leafR, 1.78, 1.74, 11.85, 0, THREE.MathUtils.degToRad(-100), 0);
      mesh(`F${p}_entrance_leaves`, [pinGlassUV(leafL), pinGlassUV(leafR)], mats.window_set_dark_2_ca, fl);
      // parked elevator cab
      mesh(`F${p}_elevator_cab`, [
        BB(.9, 3.5, .31, .41, -.3, 2.5), BB(.9, 3.5, 2.63, 2.71, -.3, 2.5),
        BB(.9, .98, .41, 2.63, -.3, 2.5), BB(3.42, 3.5, .41, 2.63, -.3, 2.5),
        BB(.98, 3.42, .41, 2.63, -.3, -.22)], mats.metal_grey_proc, fl);
    } else {
      const b0 = y + .9, b1 = y + 2.4; // window band
      for (const s of [1, -1]) {
        conc.push(BB(-12, 12, y - SLAB, b0, 11.7 * s, 12 * s));       // spandrel N/S
        conc.push(BB(11.7 * s, 12 * s, y - SLAB, b0, -11.8, 11.8));   // spandrel E/W
        conc.push(BB(-12, 12, b1, yTop, 11.7 * s, 12 * s));           // header N/S
        conc.push(BB(11.7 * s, 12 * s, b1, yTop, -11.8, 11.8));       // header E/W
        for (const t of [1, -1]) conc.push(BB(11.2 * s, 12 * s, b0 - EPS, b1 + EPS, 11.2 * t, 12 * t)); // corner columns
        glass.push(BB(-11.3, 11.3, b0 - EPS, b1 + EPS, 11.82 * s, 11.88 * s));
        glass.push(BB(11.82 * s, 11.88 * s, b0 - EPS, b1 + EPS, -11.3, 11.3));
        for (const q of MUL) {
          mull.push(BB(q - .06, q + .06, b0 - EPS, b1 + EPS, 11.79 * s, 11.91 * s));
          mull.push(BB(11.79 * s, 11.91 * s, b0 - EPS, b1 + EPS, q - .06, q + .06));
        }
        mull.push(BB(-11.25, 11.25, b0 - .04, b0 + .04, 11.78 * s, 11.92 * s)); // sill rail
        mull.push(BB(-11.25, 11.25, b1 - .04, b1 + .04, 11.78 * s, 11.92 * s)); // head rail
        mull.push(BB(11.78 * s, 11.92 * s, b0 - .04, b0 + .04, -11.25, 11.25));
        mull.push(BB(11.78 * s, 11.92 * s, b1 - .04, b1 + .04, -11.25, 11.25));
      }
      for (const [cx, cz] of [[-3.3, 4.7], [3.3, 4.7], [-3.3, -4.7], [3.3, -4.7]])
        frames.push(...frameX(cx, cz, 1.1, 2.2, w0));
    }
    frames.push(...frameX(-2.2, 2.6, 1.0, 2.2, w0)); // stair door
    frames.push(...frameX(2.2, 2.6, 1.4, 2.2, w0));  // elevator door
    mesh(`F${p}_facade_concrete`, conc, mats.concrete_panels_co, fl, true);
    mesh(`F${p}_glass`, glass.map(pinGlassUV), mats.window_set_dark_2_ca, fl);
    mesh(`F${p}_window_frames`, mull, mats.metal_dark_proc, fl);
    mesh(`F${p}_door_frames`, frames, mats.wooden_bridge_co, fl);
  }

  // ---- roof ----
  const rf = new THREE.Group(); rf.name = 'roof'; root.add(rf);
  mesh('ROOF_slab', [
    BB(-11.69, 11.69, ROOF - SLAB, ROOF, 2.5, 11.69),
    BB(-11.69, 11.69, ROOF - SLAB, ROOF, -11.69, -2.5),
    BB(-11.69, -4.4, ROOF - SLAB, ROOF, -2.5, 2.5),
    BB(.1, 11.69, ROOF - SLAB, ROOF, -2.5, 2.5),      // shaft capped at roof
    BB(-4.4, -.1, ROOF - SLAB, ROOF, 1.3, 2.5),
    BB(-.1, .1, ROOF - SLAB, ROOF, -2.5, 2.5)], mats.concrete_floor_02_co, rf, true);
  const d0 = ROOF + .001, d1 = ROOF + .021;
  mesh('ROOF_deck_bitumen', [
    BB(-11.75, 11.75, d0, d1, 3.0, 11.75),
    BB(-11.75, 11.75, d0, d1, -11.75, -3.0),
    BB(-11.75, -4.8, d0, d1, -3.0, 3.0),
    BB(.4, 11.75, d0, d1, -3.0, 3.0)], mats.asphalt_roof_a_co, rf);
  mesh('ROOF_parapet', [
    BB(-12, 12, ROOF, ROOF + 1.2, 11.75, 12), BB(-12, 12, ROOF, ROOF + 1.2, -12, -11.75),
    BB(11.75, 12, ROOF, ROOF + 1.2, -11.8, 11.8), BB(-12, -11.75, ROOF, ROOF + 1.2, -11.8, 11.8),
    BB(-12.03, 12.03, ROOF + 1.2, ROOF + 1.26, 11.72, 12.03), BB(-12.03, 12.03, ROOF + 1.2, ROOF + 1.26, -12.03, -11.72),
    BB(11.72, 12.03, ROOF + 1.2, ROOF + 1.26, -11.9, 11.9), BB(-12.03, -11.72, ROOF + 1.2, ROOF + 1.26, -11.9, 11.9)],
    mats.concrete_panels_co, rf, true);
  // stair access hut
  const hutW = [];
  hutW.push(...wallX(-4.9, .5, 3.0, .2, ROOF, ROOF + 2.6));
  hutW.push(...wallX(-4.9, .5, -3.0, .2, ROOF, ROOF + 2.6));
  hutW.push(...wallZ(-3.05, 3.05, -4.8, .2, ROOF, ROOF + 2.6));
  hutW.push(...wallZ(-3.05, 3.05, .4, .2, ROOF, ROOF + 2.6, [{ c: 1.9, w: 1.0, h: 2.2 }]));
  hutW.push(BB(-5.0, .6, ROOF + 2.6, ROOF + 2.76, -3.2, 3.2)); // cap
  mesh('ROOF_hut', hutW, mats.concrete_panels_co, rf, true);
  mesh('ROOF_hut_doorframe', frameZ(1.9, .4, 1.0, 2.2, ROOF + .01), mats.wooden_bridge_co, rf);
  mesh('ROOF_stair_guard', [BB(-4.4, -1.34, ROOF + .05, ROOF + .95, 1.30, 1.36)], mats.metal_grey_proc, rf);
  // helipad markings
  const ring = new THREE.RingGeometry(4.3, 4.8, 48);
  ring.rotateX(-Math.PI / 2); ring.translate(6.5, ROOF + .035, 0);
  mesh('ROOF_helipad_markings', [ring,
    BB(5.7, 6.2, ROOF + .025, ROOF + .05, -1.3, 1.3),
    BB(6.8, 7.3, ROOF + .025, ROOF + .05, -1.3, 1.3),
    BB(6.2, 6.8, ROOF + .025, ROOF + .05, -.25, .25)], mats.white_marking_proc, rf);
  // AC units, vents, mast
  const eq = [];
  for (const [vx, vz] of [[-8.5, 2.4], [-6.9, 4.6], [8.2, -8.3], [5.1, -9.1]]) {
    eq.push(place(new THREE.CylinderGeometry(.18, .18, .9, 16), vx, ROOF + .47, vz));
    eq.push(place(new THREE.CylinderGeometry(.3, .3, .07, 16), vx, ROOF + .95, vz));
  }
  eq.push(place(new THREE.CylinderGeometry(.05, .08, 4.4, 16), -4.2, ROOF + 2.76 + 2.2, -2.3));
  eq.push(place(new THREE.SphereGeometry(.13, 16, 12), -4.2, ROOF + 2.76 + 4.4, -2.3));
  mesh('ROOF_equipment', eq, mats.rollup_combo_co, rf, true);

  // ---- foundation: 3 m deep plinth, inset 0.06 (slope placement) — Geometry/Fire only, never Roadway ----
  const fd = new THREE.Group(); fd.name = 'foundation'; root.add(fd);
  mesh('FOUNDATION', [BB(-11.94, 11.94, -3, .1, -11.94, 11.94)], mats.concrete_panels_co, fd, true);

  // ---- swinging door leaves (closed; names = Arma selections, see doors-manifest.json / model.cfg) ----
  // wood doors use the green House_Big02 leaf ripped verbatim (multimaterial rvmat, authentic UVs)
  const dg = new THREE.Group(); dg.name = 'doors'; root.add(dg);
  for (const d of DOORS) {
    if (d.kind === 'wood') {
      const src = DOOR_LEAF.groups.multi2;
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(src.positions), 3));
      g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(src.uvs), 2));
      g.computeVertexNormals();
      g.translate(.52, -.261, -4.755); // hinge edge -> origin, bottom -> y0, plane center -> z0
      const [x0, x1, y0b, , z0, z1] = d.box;
      const alongX = (x1 - x0) > (z1 - z0);
      // scale leaf width to overlap the frame's inner faces by ~15mm (kills the visible gap)
      const span = (alongX ? Math.max(Math.abs(x1 - d.axis.x), Math.abs(x0 - d.axis.x))
                           : Math.max(Math.abs(z1 - d.axis.z), Math.abs(z0 - d.axis.z))) + .025;
      g.scale(span / 1.02, 1, 1);
      let rot, hx, hz;
      if (alongX) { hx = d.axis.x; hz = (z0 + z1) / 2; rot = (Math.abs(x0 - d.axis.x) < Math.abs(x1 - d.axis.x)) ? 0 : Math.PI; }
      else { hx = (x0 + x1) / 2; hz = d.axis.z; rot = (Math.abs(z1 - d.axis.z) < Math.abs(z0 - d.axis.z)) ? Math.PI / 2 : -Math.PI / 2; }
      place(g, hx, y0b, hz, 0, rot, 0);
      const m = new THREE.Mesh(g, mats.house_big02_multi2);
      m.name = d.id; m.castShadow = m.receiveShadow = true; dg.add(m);
    } else {
      const g = BB(...d.box);
      pinGlassUV(g);
      mesh(d.id, [g], mats.window_set_dark_2_ca, dg);
    }
  }
  // AC units lifted verbatim from JewelryBuildingModel.p3d (authentic office_addons atlas UVs)
  [[-8.6, -7.6, 0], [-8.6, -4.2, 0], [-8.6, -.8, 0]].forEach(([ax, az, ry], i) => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(AC_UNIT.positions.slice(), 3));
    g.setAttribute('uv', new THREE.BufferAttribute(AC_UNIT.uvs.slice(), 2));
    g.computeVertexNormals();
    place(g, ax, ROOF + .02, az, 0, ry, 0);
    const m = new THREE.Mesh(g, mats.office_addons_co);
    m.name = 'ROOF_ac_0' + (i + 1); m.castShadow = m.receiveShadow = true;
    rf.add(m);
  });

  return root;
}
