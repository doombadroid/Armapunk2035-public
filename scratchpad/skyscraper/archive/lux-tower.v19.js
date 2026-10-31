import * as THREE from 'three';
import { buildKitchen } from './kitchen.js';
import { buildShower } from './shower.js';
import { buildToilet } from './toilet.js';
import { AC_UNIT } from './ac-unit-data.js';
const DOORS = (await (await fetch('./lux-doors-manifest.json')).json()).doors;

// ---- 30-story luxury tower, 2077 massing ----
// Rounded-square plan: NW/SW/SE corners = R9 glass arcs; NE corner = flat square monolith
// (window slits + blade fin above roof) reserved as the holographic-ad canvas.
const EPS = .005, SLAB = .28, OUT = 18, IN = 17.55;
const L = [.3]; for (let i = 1; i <= 30; i++) L.push(L[i - 1] + (i === 1 ? 6.0 : 3.6));
const ROOF = L[30]; // 110.7
const CORNERS = [[-9, 9, -Math.PI / 2], [-9, -9, Math.PI], [9, -9, Math.PI / 2]]; // cx, cz, thetaStart (quarter arcs)

const mats = {};
const TL = new THREE.TextureLoader();
function tex(p) { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; }
function M(name, opts) { const m = new THREE.MeshStandardMaterial(opts); m.name = name; mats[name] = m; return m; }
M('concrete_panels_co',              { map: tex('a3/structures_f_enoch/data/concrete/concrete_panels_co.png'), roughness: .85 });
M('gallery_wall_plaster_a_co',       { map: tex('a3/structures_f_aow/civilian/gallery_01/data/gallery_wall_plaster_a_co.png'), roughness: .62, metalness: .04 });
M('glass_blackout_proc',            { color: 0x05070a, roughness: .02, metalness: .45, transparent: true, opacity: .94, side: THREE.DoubleSide });
M('glass_interior_proc',            { color: 0xcfe2ea, roughness: .05, metalness: .1, transparent: true, opacity: .16, side: THREE.DoubleSide, depthWrite: false });
M('concrete_floor_02_co',           { map: tex('a3/structures_f_enoch/data/floor/concrete/concrete_floor_02_co.png'), roughness: .95 });
M('gallery_floor_parquet_b_co',      { map: tex('a3/structures_f_aow/civilian/gallery_01/data/gallery_floor_parquet_b_co.png'), roughness: .34, metalness: .06 });
M('tile_04a_co',                    { map: tex('a3/structures_f/data/tile/tile_04a_co.png'), roughness: .55 });
M('marble_tiles_01_co',                     { map: tex('a3/structures_f_exp/data/tiles/marble_tiles_01_co.png'), roughness: .5 });
M('marble_tiles_02_co',    { map: tex('a3/structures_f_exp/data/tiles/marble_tiles_02_co.png'), roughness: .6 });
M('rollup_combo_co',                { map: tex('a3/structures_f/data/metal/rollup_combo_co.png'), roughness: .5,  metalness: .3 });
M('house_big02_multi2',             { map: tex('a3/structures_f_enoch/data/wood/woodfine_01_co.png'), color: 0xa08a6a, roughness: .3, metalness: .06 });
M('door_brass_proc',                { color: 0xc0a058, roughness: .28, metalness: .85 });
M('office_addons_co',               { map: tex('a3/structures_f/civ/offices/data/office_addons_co.png'), roughness: .55, metalness: .2 });
M('metal_grey_proc',                { color: 0x8d9296, roughness: .45, metalness: .35 });
M('metal_elevator_proc',            { color: 0xc9cdd2, roughness: .15, metalness: .85 });
M('metal_dark_proc',                { color: 0x23272d, roughness: .45, metalness: .4 });
M('white_marking_proc',             { color: 0xe8e6df, roughness: .8, side: THREE.DoubleSide });
M('neon_cyan_proc',                 { color: 0x0db8ff, emissive: 0x0db8ff, emissiveIntensity: 1.8, roughness: .3 });
M('neon_magenta_proc',              { color: 0xff0f8c, emissive: 0xff0f8c, emissiveIntensity: 1.8, roughness: .3 });
M('neon_violet_proc',               { color: 0x9e40ff, emissive: 0x9e40ff, emissiveIntensity: 1.8, roughness: .3 });
M('dancefloor_proc',                { color: 0x241a3e, emissive: 0x3d2a72, emissiveIntensity: .7, roughness: .35 });

// ---- helpers ----
const _m = new THREE.Matrix4(), _e = new THREE.Euler(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(1, 1, 1), _p = new THREE.Vector3();
function boxGeo(w, h, d, s = 2) {
  const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let v = 0; v < 4; v++) { const i = f * 4 + v; uv.setXY(i, uv.getX(i) * dims[f][0] / s, uv.getY(i) * dims[f][1] / s); }
  return g;
}
function place(g, x, y, z, rx = 0, ry = 0, rz = 0) { _q.setFromEuler(_e.set(rx, ry, rz)); g.applyMatrix4(_m.compose(_p.set(x, y, z), _q, _s)); return g; }
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
function BB(x0, x1, y0, y1, z0, z1) { return alignUV(place(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)); }
function chordBoxes(cx, cz, r, th, y0, y1, t0, n = 8) { // faceted quarter-arc band from convex boxes
  const geos = [], step = Math.PI / 2 / n, rc = r * Math.cos(step / 2) - th / 2, len = 2 * r * Math.sin(step / 2) + .01;
  for (let k = 0; k < n; k++) {
    const a = t0 + (k + .5) * step;
    geos.push(place(boxGeo(len, y1 - y0, th), cx + rc * Math.sin(a), (y0 + y1) / 2, cz + rc * Math.cos(a), 0, a, 0));
  }
  return geos;
}
function arcShell(cx, cz, r, y0, y1, t0) { // smooth quarter glass shell
  const g = new THREE.CylinderGeometry(r, r, y1 - y0, 8, 1, true, t0, Math.PI / 2);
  return place(g, cx, (y0 + y1) / 2, cz);
}
function pie(cx, cz, r, y0, y1, t0) { // solid convex quarter-cylinder wedge
  const g = new THREE.CylinderGeometry(r, r, y1 - y0, 8, 1, false, t0, Math.PI / 2);
  return place(g, cx, (y0 + y1) / 2, cz);
}
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
  if (split) {
    geos.forEach((g, i) => { const m = new THREE.Mesh(g.index ? g.toNonIndexed() : g, mat); m.name = `${name}_c${String(i).padStart(2, '0')}`; m.castShadow = m.receiveShadow = true; parent.add(m); });
    return;
  }
  const m = new THREE.Mesh(merge(geos), mat);
  m.name = name; m.castShadow = m.receiveShadow = true; parent.add(m);
  return m;
}
function wallX(x0, x1, zc, t, y0, y1, doors = []) {
  const g = []; let c = x0;
  for (const d of [...doors].sort((a, b) => a.c - b.c)) {
    const a = d.c - d.w / 2, b = d.c + d.w / 2;
    if (a > c) g.push(BB(c, a, y0, y1, zc - t / 2, zc + t / 2));
    if (y0 + d.h < y1 - .002) g.push(BB(a, b, y0 + d.h, y1, zc - t / 2, zc + t / 2));
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
    if (y0 + d.h < y1 - .002) g.push(BB(xc - t / 2, xc + t / 2, y0 + d.h, y1, a, b));
    c = b;
  }
  if (c < z1) g.push(BB(xc - t / 2, xc + t / 2, y0, y1, c, z1));
  return g;
}
function frameX(cx, zc, w, h, y0) {
  const j = .09, d = .32, v = .02;
  return [BB(cx - w / 2 - j, cx - w / 2 + v, y0, y0 + h + j, zc - d / 2, zc + d / 2),
          BB(cx + w / 2 - v, cx + w / 2 + j, y0, y0 + h + j, zc - d / 2, zc + d / 2),
          BB(cx - w / 2, cx + w / 2, y0 + h - v, y0 + h + j, zc - d / 2, zc + d / 2)];
}
function frameZ(cz, xc, w, h, y0) {
  const j = .09, d = .32, v = .02;
  return [BB(xc - d / 2, xc + d / 2, y0, y0 + h + j, cz - w / 2 - j, cz - w / 2 + v),
          BB(xc - d / 2, xc + d / 2, y0, y0 + h + j, cz + w / 2 - v, cz + w / 2 + j),
          BB(xc - d / 2, xc + d / 2, y0 + h - v, y0 + h + j, cz - w / 2, cz + w / 2)];
}
function pinRectUV(g, U0, V0, U1, V1) { // pin every quad of a box to an atlas rect
  const uv = g.attributes.uv;
  for (let f = 0; f + 3 < uv.count; f += 4) {
    let mu = 1e9, Mu = -1e9, mv = 1e9, Mv = -1e9;
    for (let i = f; i < f + 4; i++) { mu = Math.min(mu, uv.getX(i)); Mu = Math.max(Mu, uv.getX(i)); mv = Math.min(mv, uv.getY(i)); Mv = Math.max(Mv, uv.getY(i)); }
    for (let i = f; i < f + 4; i++) {
      const nu = (uv.getX(i) - mu) / (Mu - mu || 1), nv = (uv.getY(i) - mv) / (Mv - mv || 1);
      uv.setXY(i, U0 + nu * (U1 - U0), V0 + nv * (V1 - V0));
    }
  }
  return g;
}
function pinGlassUV(g) {
  const uv = g.attributes.uv;
  for (let f = 0; f + 3 < uv.count; f += 4) {
    let mu = 1e9, Mu = -1e9, mv = 1e9, Mv = -1e9;
    for (let i = f; i < f + 4; i++) { mu = Math.min(mu, uv.getX(i)); Mu = Math.max(Mu, uv.getX(i)); mv = Math.min(mv, uv.getY(i)); Mv = Math.max(Mv, uv.getY(i)); }
    for (let i = f; i < f + 4; i++) {
      const nu = (uv.getX(i) - mu) / (Mu - mu || 1), nv = (uv.getY(i) - mv) / (Mv - mv || 1);
      uv.setXY(i, .46 + nu * .16, .443 + nv * .325);
    }
  }
  return g;
}
function pinGlassUVAll(g) { // whole-geometry pin (cylinder shells etc — no quad stride)
  const uv = g.attributes.uv;
  let mu = 1e9, Mu = -1e9, mv = 1e9, Mv = -1e9;
  for (let i = 0; i < uv.count; i++) { mu = Math.min(mu, uv.getX(i)); Mu = Math.max(Mu, uv.getX(i)); mv = Math.min(mv, uv.getY(i)); Mv = Math.max(Mv, uv.getY(i)); }
  for (let i = 0; i < uv.count; i++) {
    const nu = (uv.getX(i) - mu) / (Mu - mu || 1), nv = (uv.getY(i) - mv) / (Mv - mv || 1);
    uv.setXY(i, .46 + nu * .16, .443 + nv * .325);
  }
  return g;
}
const SEGMAP = { '0': 'abcdef', '1': 'bc', '2': 'abgde', '3': 'abgcd', '4': 'fgbc', '5': 'afgcd', '6': 'afgedc', '7': 'abc', '8': 'abcdefg', '9': 'abfgcd' };
function segDigits(str, cx, cy, z0, z1, h, flip = false) {
  const geos = [], w = h * .52, t = h * .13, gap = h * .18, full = str.length * w + (str.length - 1) * gap;
  let x0 = cx - full / 2;
  const X = (a, b) => flip ? [2 * cx - b, 2 * cx - a] : [a, b];
  for (const ch of str) {
    const Lx = x0, R = x0 + w, T = cy + h / 2, B = cy - h / 2, Mid = cy;
    const S = { a: [Lx, R, T - t, T], d: [Lx, R, B, B + t], g: [Lx, R, Mid - t / 2, Mid + t / 2],
                f: [Lx, Lx + t, Mid, T], b: [R - t, R, Mid, T], e: [Lx, Lx + t, B, Mid], c: [R - t, R, B, Mid] };
    for (const s of SEGMAP[ch]) { const [xa, xb] = X(S[s][0], S[s][1]); geos.push(BB(xa, xb, S[s][2], S[s][3], z0, z1)); }
    x0 += w + gap;
  }
  return geos;
}
function buildStairs(y0, rise) {
  const half = rise / 2, n = Math.max(10, Math.ceil(half / .18)), r = half / n;
  const run = 3.2, tread = run / (n - 1), A = [], B_ = [], land = [], rails = [];
  for (let k = 0; k < n - 1; k++) { const z1 = 1.6 - k * tread, top = y0 + (k + 1) * r; A.push(BB(-5.9, -4.6, top - r - .16, top, z1 - tread, z1)); }
  land.push(BB(-5.9, -1.8, y0 + half - .22, y0 + half, -2.9, -1.6));
  for (let k = 0; k < n - 1; k++) { const z0 = -1.6 + k * tread, top = y0 + half + (k + 1) * r; B_.push(BB(-3.1, -1.8, top - r - .16, top, z0, z0 + tread)); }
  const th = Math.atan2(half, run), len = Math.hypot(run, half);
  for (const [lx, rot, yc] of [[-4.63, th, y0 + half / 2], [-3.07, -th, y0 + rise * .75]])
    for (const ry of [.55, .95]) rails.push(place(boxGeo(.06, .09, len), lx, yc + ry, 0, rot, 0, 0));
  rails.push(BB(-4.66, -3.04, y0 + half + .05, y0 + half + .95, -1.66, -1.60));
  rails.push(BB(-4.66, -3.04, y0 + .05, y0 + .95, 1.60, 1.66));
  return { A, B: B_, land, rails };
}
// NE chamfer: flat 45° billboard wall cutting the corner from (9,18) to (18,9) — the hologram canvas
const SQ2 = Math.SQRT1_2, CC = 13.5, ROTC = Math.PI / 4;
function chamferBox(len, y0, y1, th, off = 0, tMid = 0) {
  return place(boxGeo(len, y1 - y0, th), CC + tMid * SQ2 + off * SQ2, (y0 + y1) / 2, CC - tMid * SQ2 + off * SQ2, 0, ROTC, 0);
}
function chamferWall(y0, y1, dark, glass) {
  const segs = [[-6.3, -3.41], [-2.96, -.24], [.24, 2.96], [3.41, 6.3]];
  for (const [a, b] of segs) dark.push(chamferBox(b - a, y0, y1, .45, -.225, (a + b) / 2));
  for (const s of [-3.185, 0, 3.185]) glass.push(chamferBox(.42, y0 + EPS, y1 - EPS, .06, -.19, s));
}
function chamferFill(y0, y1) { // solid floor fill behind the chamfer (steps overlap the rotated band; all convex)
  return [BB(9, 16, y0, y1, 9, 11), BB(9, 14, y0, y1, 11, 13), BB(9, 12, y0, y1, 13, 15),
          chamferBox(13, y0, y1, 2.2, -1.34, 0)];
}

function planPiece(edge, r, y0, y1, holes = []) {
  const sh = new THREE.Shape(), C = 26.67, k = C - edge;
  sh.moveTo(-edge, -9); sh.lineTo(-edge, 9);
  sh.absarc(-9, 9, r, Math.PI, Math.PI / 2, true);
  sh.lineTo(k, edge); sh.lineTo(edge, k); sh.lineTo(edge, -9);
  sh.absarc(9, -9, r, 0, -Math.PI / 2, true);
  sh.lineTo(-9, -edge);
  sh.absarc(-9, -9, r, -Math.PI / 2, -Math.PI, true);
  sh.closePath();
  for (const [x0, x1, z0, z1] of holes) {
    const h = new THREE.Path();
    h.moveTo(x0, z0); h.lineTo(x0, z1); h.lineTo(x1, z1); h.lineTo(x1, z0); h.closePath();
    sh.holes.push(h);
  }
  const g = new THREE.ExtrudeGeometry(sh, { depth: y1 - y0, bevelEnabled: false, curveSegments: 12 });
  g.rotateX(Math.PI / 2); g.translate(0, y1, 0);
  return alignUV(g.toNonIndexed());
}
const GBB = (x0, x1, y0, y1, z0, z1) => BB(x0 + .02, x1 - .02, y0 + .002, y1 - .002, z0 + .02, z1 - .02);

export function buildTower() {
  // fixture prototypes — built once, cloned per floor (clones share geometry + materials)
  const PROTO = { kitchen: buildKitchen(), shower: buildShower(), toilet: buildToilet() };
  function fixture(kind, name, parent, x, y, z, ry = 0) {
    const g = PROTO[kind].clone(true);
    g.name = name; g.position.set(x, y, z); g.rotation.y = ry;
    g.traverse(o => { if (o.isMesh) o.name = name + '_' + o.name; });
    parent.add(g);
  }
  const root = new THREE.Group();
  root.name = 'arma3_lux_tower_30f';
  const GX = 17.82, GX2 = 17.88;
  const MULS = [-5.9, -2.95, 0, 2.95, 5.9];   // straight-run mullions, all four faces

  for (let i = 0; i < 30; i++) {
    const p = String(i + 1).padStart(2, '0');
    const fl = new THREE.Group(); fl.name = 'floor_' + p; root.add(fl);
    const y = L[i], yTop = L[i + 1] - SLAB, rise = L[i + 1] - L[i];
    const w0 = y + .01, w1 = yTop;

    // -- slab (plan-shaped: rect strips clipped at rounded corners + convex pie wedges) --
    if (i === 0) {
      mesh(`F${p}_slab`, [planPiece(OUT, 9, 0, .3)], mats.concrete_floor_02_co, fl);
      mesh(`GEO_F${p}_slab`, [
        GBB(-OUT, OUT, 0, .3, -9, 9), GBB(-9, 9, 0, .3, 9, OUT), GBB(-9, 9, 0, .3, -OUT, -9),
        ...chamferFill(.002, .298),
        ...CORNERS.map(([cx, cz, t0]) => pie(cx, cz, 8.98, .002, .298, t0))], mats.concrete_floor_02_co, fl, true);
    } else {
      mesh(`F${p}_slab`, [planPiece(IN - .02, 8.53, y - SLAB, y,
        [[-5.9, -1.8, -2.9, 1.6], [-1.5, 2.0, -2.9, 2.9], [2.3, 5.9, -2.9, 2.9]])], mats.concrete_floor_02_co, fl);
      mesh(`GEO_F${p}_slab`, [
        GBB(-IN + .02, 9, y - SLAB, y, 2.9, 9), GBB(-9, 9, y - SLAB, y, 9, IN - .02),
        GBB(9, IN - .02, y - SLAB, y, -9, 9),
        ...chamferFill(y - SLAB + .002, y - .002),
        GBB(-IN + .02, IN - .02, y - SLAB, y, -9, -2.9), GBB(-9, 9, y - SLAB, y, -IN + .02, -9),
        GBB(-IN + .02, -5.9, y - SLAB, y, -2.9, 2.9),
        GBB(-5.9, -1.8, y - SLAB, y, 1.6, 2.9),
        GBB(-1.8, -1.5, y - SLAB, y, -2.9, 2.9),
        GBB(2.0, 2.3, y - SLAB, y, -2.9, 2.9),
        GBB(5.9, IN - .02, y - SLAB, y, -2.9, 2.9),
        ...CORNERS.map(([cx, cz, t0]) => pie(cx, cz, 8.51, y - SLAB + .002, y - .002, t0))],
        mats.concrete_floor_02_co, fl, true);
    }

    // -- core + suite walls (unchanged program) --
    const walls = [];
    walls.push(...wallX(-6.1, 6.1, 3, .2, w0, w1, [{ c: -3.8, w: 1.0, h: 2.2 }, { c: .25, w: 1.6, h: 2.3 }, { c: 4.1, w: 1.6, h: 2.3 }]));
    walls.push(...wallX(-6.1, 6.1, -3, .2, w0, w1));
    walls.push(...wallZ(-2.95, 2.95, -6, .2, w0, w1));
    walls.push(...wallZ(-2.95, 2.95, 6, .2, w0, w1));
    walls.push(...wallZ(-2.95, 2.95, -1.7, .2, w0, w1));
    walls.push(...wallZ(-2.95, 2.95, 2.15, .2, w0, w1));
    if (i > 0) {
      walls.push(...wallZ(7, IN + .05, 7, .2, w0, w1));
      walls.push(...wallX(3.45, IN + .05, 7, .2, w0, w1, [{ c: 5.2, w: 1.0, h: 2.2 }, { c: 10, w: 1.1, h: 2.2 }]));
      walls.push(...wallZ(7, 12.05, 3.5, .2, w0, w1));
      walls.push(...wallX(3.45, 7.05, 12, .2, w0, w1));
    }
    mesh(`F${p}_walls_interior`, walls, mats.gallery_wall_plaster_a_co, fl, true);

    // -- floor coverings (clipped to plan + pie fills) --
    const c0 = y + .005, c1 = y + .025;
    if (i === 0) {
      mesh(`F${p}_floor_stone`, [planPiece(17.5, 8.5, c0, c1, [[-6.1, 6.1, -3.1, 3.1]])], mats.marble_tiles_02_co, fl);
    } else {
      mesh(`F${p}_floor_wood`, [planPiece(17.5, 8.5, c0, c1,
        [[-6.1, 6.1, -3.1, 3.1], [3.43, 7.07, 7.02, 12.07]])], mats.gallery_floor_parquet_b_co, fl);
      mesh(`F${p}_floor_bath`, [BB(3.55, 6.95, c0, c1, 7.05, 11.95)], mats.marble_tiles_01_co, fl);
      // -- fixtures: kitchen run on the W wall; shower + toilet on the bath's far wall (z=11.9),
      //    facing the doorway at x 5.2 in the z=7 wall --
      fixture('kitchen', `F${p}_KITCHEN`, fl, -17.25, c1, 0, Math.PI / 2);
      fixture('shower', `F${p}_SHOWER`, fl, 5.99, c1, 11.19, Math.PI);
      fixture('toilet', `F${p}_TOILET`, fl, 4.2, c1, 11.56, Math.PI);
    }

    // -- premium ceiling: white panel plates floated 4 mm under the slab above (visual only) --
    const e0 = yTop - .016, e1 = yTop - .004;
    mesh(`F${p}_ceiling`, [planPiece(17.5, 8.5, e0, e1, [[-6.1, 6.1, -3.1, 3.1]])], mats.gallery_wall_plaster_a_co, fl);

    // -- stairs, elevator panels, signage (unchanged) --
    const st = buildStairs(y, rise);
    mesh(`F${p}_stairA`, st.A, mats.concrete_floor_02_co, fl, true);
    mesh(`F${p}_stairB`, st.B, mats.concrete_floor_02_co, fl, true);
    mesh(`F${p}_stairLand`, st.land, mats.concrete_floor_02_co, fl, true);
    mesh(`F${p}_stair_rails`, st.rails, mats.metal_grey_proc, fl, true);
    mesh(`F${p}_elevator_doors`, [
      BB(-.55, 1.05, w0, w0 + 2.3, 2.92, 2.98),
      BB(3.3, 4.9, w0, w0 + 2.3, 2.92, 2.98)], mats.metal_elevator_proc, fl);
    const plates = [], digits = [], fno = String(i + 1).padStart(2, '0');
    plates.push(BB(-2.5, -1.3, w0 + 1.3, w0 + 2.0, 3.095, 3.12));
    digits.push(...segDigits(fno, -1.9, w0 + 1.65, 3.12, 3.137, .5));
    plates.push(BB(-3.1, -2.0, w0 + 1.35, w0 + 1.95, 2.88, 2.905));
    digits.push(...segDigits(fno, -2.55, w0 + 1.65, 2.865, 2.882, .42, true));
    mesh(`F${p}_sign_plates`, plates, mats.metal_dark_proc, fl);
    mesh(`F${p}_sign_digits`, digits, mats.white_marking_proc, fl);

    // -- facade: straight runs + glass arcs + NE monolith --
    const dark = [], glass = [], glassArc = [], mull = [], neon = [], frames = [];
    const b0 = i === 0 ? .295 : y + .15, b1 = yTop + EPS;
    // straight glass runs (N/E stop at monolith edge x/z=9)
    if (i === 0) {
      glass.push(...wallX(-8.9, 8.9, 17.85, .06, b0, b1, [{ c: 0, w: 4.2, h: 3.2 }]));       // N + entrance
      glass.push(...wallX(-8.9, 8.9, -17.85, .06, b0, b1, [{ c: 0, w: 1.4, h: 2.4 }]));       // S + exit
      glass.push(BB(GX, GX2, b0, b1, -8.9, 8.9));                                             // E
      glass.push(BB(-GX2, -GX, b0, b1, -8.9, 8.9));                                           // W
      frames.push(...frameX(0, -17.85, 1.4, 2.4, .3));
      // violet portal + canopy + apron + fixed-open panes
      neon.push(BB(-2.3, -2.14, .3, 3.75, 17.92, 18.0), BB(2.14, 2.3, .3, 3.75, 17.92, 18.0), BB(-2.3, 2.3, 3.6, 3.76, 17.92, 18.0));
      dark.push(BB(-3.6, 3.6, 4.1, 4.34, 18.02, 21.2));
      neon.push(BB(-3.55, 3.55, 4.12, 4.2, 21.15, 21.26));
      dark.push(BB(-4.5, 4.5, 0, .3, OUT, 21), BB(-4.5, 4.5, 0, .15, 21, 21.7));
      const leafL = boxGeo(2.06, 3.16, .05); leafL.translate(1.03, 0, 0);
      const leafR = boxGeo(2.06, 3.16, .05); leafR.translate(-1.03, 0, 0);
      place(leafL, -2.1, .3 + 1.58, 17.85, 0, THREE.MathUtils.degToRad(100), 0);
      place(leafR, 2.1, .3 + 1.58, 17.85, 0, THREE.MathUtils.degToRad(-100), 0);
      mesh(`F${p}_entrance_leaves`, [pinGlassUV(leafL), pinGlassUV(leafR)], mats.glass_blackout_proc, fl);
      mesh(`F${p}_reception`, [BB(-2.6, 2.6, .31, 1.35, 10, 11.1)], mats.metal_dark_proc, fl, true);
      mesh(`F${p}_reception_top`, [BB(-2.66, 2.66, 1.35, 1.4, 9.94, 11.16)], mats.white_marking_proc, fl);
      mesh(`F${p}_reception_neon`, [BB(-2.6, 2.6, .45, .53, 9.95, 10.01)], mats.neon_cyan_proc, fl);
      mesh(`F${p}_columns`, [
        BB(-10.3, -9.7, .31, yTop, -10.3, -9.7), BB(9.7, 10.3, .31, yTop, -10.3, -9.7),
        BB(-10.3, -9.7, .31, yTop, 9.7, 10.3), BB(9.7, 10.3, .31, yTop, 9.7, 10.3)], mats.concrete_panels_co, fl, true);
    } else {
      glass.push(BB(-8.9, 8.9, b0 - EPS, b1, GX, GX2));    // N
      glass.push(BB(GX, GX2, b0 - EPS, b1, -8.9, 8.9));    // E
      glass.push(BB(-GX2, -GX, b0 - EPS, b1, -8.9, 8.9));   // W
      glass.push(BB(-8.9, 8.9, b0 - EPS, b1, -GX2, -GX));   // S
      // spandrels: lower/upper bands with a recessed neon groove between (nothing coplanar, corners on plan circle)
      const nA = y - .16, nB = y - .04, n0 = y - .155, n1 = y - .045;
      dark.push(BB(-9, 8.92, y - SLAB, nA, 17.55, OUT), BB(-9, 8.92, nB, b0, 17.55, OUT));
      dark.push(BB(17.55, OUT, y - SLAB, nA, -9, 8.92), BB(17.55, OUT, nB, b0, -9, 8.92));
      dark.push(chamferBox(12.6, y - SLAB, nA, .45, -.235), chamferBox(12.6, nB, b0, .45, -.235));
      dark.push(BB(-OUT, -17.55, y - SLAB, nA, -9, 9), BB(-OUT, -17.55, nB, b0, -9, 9));
      dark.push(BB(-9, 9, y - SLAB, nA, -OUT, -17.55), BB(-9, 9, nB, b0, -OUT, -17.55));
      for (const [cx, cz, t0] of CORNERS) {
        dark.push(...chordBoxes(cx, cz, 9.0, .45, y - SLAB, nA, t0));
        dark.push(...chordBoxes(cx, cz, 9.0, .45, nB, b0, t0));
      }
      // cyan neon ring recessed .04 into the groove
      neon.push(BB(-9, 8.9, n0, n1, 17.6, 17.96));
      neon.push(BB(17.6, 17.96, n0, n1, -9, 8.9));
      neon.push(chamferBox(12.6, n0, n1, .3, -.19));
      neon.push(BB(-17.96, -17.6, n0, n1, -9, 9));
      neon.push(BB(-9, 9, n0, n1, -17.96, -17.6));
      for (const [cx, cz, t0] of CORNERS) neon.push(...chordBoxes(cx, cz, 8.96, .3, n0, n1, t0));
    }
    // rounded glass corners (smooth shells) + arc mullion posts + tangent posts
    for (const [cx, cz, t0] of CORNERS) {
      glassArc.push(arcShell(cx, cz, 8.85, b0 - (i ? EPS : 0), b1, t0));
      for (let k = 1; k <= 3; k++) {
        const a = t0 + k * Math.PI / 8;
        mull.push(place(boxGeo(.12, b1 - b0, .12), cx + 8.85 * Math.sin(a), (b0 + b1) / 2, cz + 8.85 * Math.cos(a), 0, a, 0));
      }
    }
    for (const [px, pz] of [[-8.95, 17.8], [-17.8, 8.95], [-17.8, -8.95], [-8.95, -17.8], [8.95, -17.8], [17.8, -8.95], [8.95, 17.8], [17.8, 8.95]])
      mull.push(BB(px - .14, px + .14, b0 - EPS, b1, pz - .14, pz + .14));
    // straight-run mullions
    for (const q of (i === 0 ? [-6, -3, 3, 6] : MULS)) {
      mull.push(BB(q - .05, q + .05, b0 - EPS, b1, 17.79, 17.91));
      mull.push(BB(17.79, 17.91, b0 - EPS, b1, q - .05, q + .05));
    }
    for (const q of (i === 0 ? [-6, -3, 3, 6] : MULS)) {
      mull.push(BB(-17.91, -17.79, b0 - EPS, b1, q - .05, q + .05));
      mull.push(BB(q - .05, q + .05, b0 - EPS, b1, -17.91, -17.79));
    }
    // NE chamfer billboard wall (the future hologram canvas)
    chamferWall(b0, b1, dark, glass);
    frames.push(...frameX(-3.8, 3, 1.0, 2.2, w0));
    if (i > 0) { frames.push(...frameX(5.2, 7, 1.0, 2.2, w0)); frames.push(...frameX(10, 7, 1.1, 2.2, w0)); }
    mesh(`F${p}_facade_dark`, dark, mats.metal_dark_proc, fl, true);
    const paneGeos = [...glass.map(pinGlassUV), ...glassArc.map(pinGlassUVAll)];
    mesh(`F${p}_glass`, paneGeos, mats.glass_blackout_proc, fl);
    // inner lining: the same panes shrunk about the tower axis so they sit 8 cm inboard —
    // blackout reads from outside, this light uniform tint is what you see from inside
    const LS = 1 - .08 / 17.88;
    mesh(`F${p}_glass_inner`, paneGeos.map(g => g.clone().scale(LS, 1, LS)), mats.glass_interior_proc, fl);
    mesh(`F${p}_window_frames`, mull, mats.metal_dark_proc, fl);
    mesh(`F${p}_neon_ring`, neon, i === 0 ? mats.neon_violet_proc : mats.neon_cyan_proc, fl);
    mesh(`F${p}_door_frames`, frames, mats.metal_grey_proc, fl);
  }

  // magenta strips framing the billboard chamfer ends, ground to blade top
  mesh('NEON_corners', [
    BB(9.0, 9.12, .35, ROOF + 9.1, 18.0, 18.12),
    BB(18.0, 18.12, .35, ROOF + 9.1, 9.0, 9.12)], mats.neon_magenta_proc, root);

  // ---- roof ----
  const rf = new THREE.Group(); rf.name = 'roof'; root.add(rf);
  mesh('ROOF_slab', [planPiece(IN - .02, 8.53, ROOF - SLAB, ROOF,
    [[-5.9, -1.8, -2.9, 1.6]])], mats.concrete_floor_02_co, rf);
  mesh('GEO_ROOF_slab', [
    GBB(-IN + .02, 9, ROOF - SLAB, ROOF, 2.9, 9), GBB(-9, 9, ROOF - SLAB, ROOF, 9, IN - .02),
    GBB(9, IN - .02, ROOF - SLAB, ROOF, -9, 9), ...chamferFill(ROOF - SLAB + .002, ROOF - .002),
    GBB(-IN + .02, IN - .02, ROOF - SLAB, ROOF, -9, -2.9), GBB(-9, 9, ROOF - SLAB, ROOF, -IN + .02, -9),
    GBB(-IN + .02, -5.9, ROOF - SLAB, ROOF, -2.9, 2.9),
    GBB(-5.9, -1.8, ROOF - SLAB, ROOF, 1.6, 2.9),
    GBB(-1.8, IN - .02, ROOF - SLAB, ROOF, -2.9, 2.9),
    ...CORNERS.map(([cx, cz, t0]) => pie(cx, cz, 8.51, ROOF - SLAB + .002, ROOF - .002, t0))], mats.concrete_floor_02_co, rf, true);
  mesh('ROOF_edge_band', [
    BB(-9, 8.92, ROOF - SLAB, ROOF, 17.55, OUT), BB(17.55, OUT, ROOF - SLAB, ROOF, -9, 8.92),
    chamferBox(12.6, ROOF - SLAB, ROOF, .45, -.235),
    BB(-OUT, -17.55, ROOF - SLAB, ROOF, -9, 9), BB(-9, 9, ROOF - SLAB, ROOF, -OUT, -17.55),
    ...CORNERS.flatMap(([cx, cz, t0]) => chordBoxes(cx, cz, 9.0, .45, ROOF - SLAB, ROOF, t0))], mats.metal_dark_proc, rf, true);
  const d0 = ROOF + .001, d1 = ROOF + .021;
  mesh('ROOF_deck_tile', [planPiece(17.7, 8.7, d0, d1, [[-6.2, -1.4, -3.1, 3.1]])], mats.marble_tiles_01_co, rf);
  const pA = ROOF + 1.12, pB = ROOF + 1.24, pT = ROOF + 1.36;
  mesh('ROOF_parapet', [
    BB(-9, 8.92, ROOF, pA, 17.75, OUT), BB(-9, 8.92, pB, pT, 17.75, OUT),
    BB(17.75, OUT, ROOF, pA, -9, 8.92), BB(17.75, OUT, pB, pT, -9, 8.92),
    BB(-OUT, -17.75, ROOF, pA, -9, 9), BB(-OUT, -17.75, pB, pT, -9, 9),
    BB(-9, 9, ROOF, pA, -OUT, -17.75), BB(-9, 9, pB, pT, -OUT, -17.75),
    ...CORNERS.flatMap(([cx, cz, t0]) => [...chordBoxes(cx, cz, 9.0, .25, ROOF, pA, t0), ...chordBoxes(cx, cz, 9.0, .25, pB, pT, t0)])], mats.metal_dark_proc, rf, true);
  mesh('ROOF_parapet_neon', [
    BB(-9, 8.9, pA + .005, pB - .005, 17.7, 17.96), BB(17.7, 17.96, pA + .005, pB - .005, -9, 8.9),
    BB(-17.96, -17.7, pA + .005, pB - .005, -9, 9), BB(-9, 9, pA + .005, pB - .005, -17.96, -17.7),
    ...CORNERS.flatMap(([cx, cz, t0]) => chordBoxes(cx, cz, 8.96, .15, pA + .005, pB - .005, t0))], mats.neon_cyan_proc, rf);
  // blade fin IS the parapet along the chamfer (proud of the wall plane, no coplanar faces)
  mesh('ROOF_blade', [
    chamferBox(12.6, ROOF, ROOF + 9.16, .3, -.11)], mats.metal_dark_proc, rf, true);
  mesh('ROOF_blade_neon', [
    chamferBox(12.4, ROOF + 9.16, ROOF + 9.22, .1, -.11)], mats.neon_magenta_proc, rf);
  // stair hut
  const hutW = [];
  hutW.push(...wallX(-6.3, -1.3, 3.1, .2, ROOF, ROOF + 2.7));
  hutW.push(...wallX(-6.3, -1.3, -3.1, .2, ROOF, ROOF + 2.7));
  hutW.push(...wallZ(-3.15, 3.15, -6.2, .2, ROOF, ROOF + 2.7));
  hutW.push(...wallZ(-3.15, 3.15, -1.4, .2, ROOF, ROOF + 2.7, [{ c: 2.25, w: 1.0, h: 2.2 }]));
  hutW.push(BB(-6.4, -1.2, ROOF + 2.7, ROOF + 2.86, -3.25, 3.25));
  mesh('ROOF_hut', hutW, mats.metal_dark_proc, rf, true);
  mesh('ROOF_hut_doorframe', frameZ(2.25, -1.4, 1.0, 2.2, ROOF + .01), mats.metal_grey_proc, rf);
  mesh('ROOF_stair_guard', [BB(-5.9, -3.04, ROOF + .05, ROOF + .95, 1.60, 1.66)], mats.metal_grey_proc, rf);
  // helipad NE (square-corner quadrant)
  const ring = new THREE.RingGeometry(5.4, 5.9, 56);
  ring.rotateX(-Math.PI / 2); ring.translate(10, ROOF + .035, 7.5);
  mesh('ROOF_helipad_neon', [ring], mats.neon_cyan_proc, rf);
  mesh('ROOF_helipad_markings', [
    BB(9.0, 9.6, ROOF + .025, ROOF + .05, 6.0, 9.0),
    BB(10.4, 11.0, ROOF + .025, ROOF + .05, 6.0, 9.0),
    BB(9.6, 10.4, ROOF + .025, ROOF + .05, 7.2, 7.8)], mats.white_marking_proc, rf);
  // rooftop bar + lounge (SE quadrant, replaces the pool — no vanilla above-sea water)
  mesh('ROOF_bar', [
    BB(6.3, 7.2, ROOF + .02, ROOF + 1.1, -13.6, -10.2),
    BB(7.2, 10.2, ROOF + .02, ROOF + 1.1, -11.1, -10.2),
    BB(5.7, 6.0, ROOF + .02, ROOF + 1.5, -13.6, -10.2)], mats.metal_dark_proc, rf, true);
  mesh('ROOF_bar_top', [
    BB(6.26, 7.3, ROOF + 1.1, ROOF + 1.15, -13.66, -10.14),
    BB(7.2, 10.26, ROOF + 1.1, ROOF + 1.15, -11.16, -10.14),
    BB(5.66, 6.04, ROOF + 1.5, ROOF + 1.55, -13.66, -10.14)], mats.white_marking_proc, rf);
  mesh('ROOF_bar_neon', [
    BB(7.19, 7.27, ROOF + .3, ROOF + .38, -13.55, -10.27),
    BB(7.27, 10.14, ROOF + .3, ROOF + .38, -10.27, -10.19)], mats.neon_cyan_proc, rf);
  const stools = [];
  for (const sz of [-13.3, -12.4, -11.5]) stools.push(place(new THREE.CylinderGeometry(.22, .18, .75, 10), 7.9, ROOF + .395, sz));
  for (const sx of [8.2, 9.2]) stools.push(place(new THREE.CylinderGeometry(.22, .18, .75, 10), sx, ROOF + .395, -9.6));
  mesh('ROOF_bar_stools', stools, mats.rollup_combo_co, rf, true);
  mesh('ROOF_lounge', [
    BB(10.6, 13.6, ROOF + .02, ROOF + .45, -14.05, -13.3),
    BB(10.6, 13.6, ROOF + .45, ROOF + .95, -14.2, -14.05),
    BB(12.9, 13.7, ROOF + .02, ROOF + .45, -13.3, -11.2),
    BB(13.7, 13.85, ROOF + .45, ROOF + .95, -13.3, -11.2),
    BB(9.2, 9.9, ROOF + .02, ROOF + .42, -12.5, -11.8),
    BB(9.2, 9.9, ROOF + .02, ROOF + .42, -11.4, -10.7)], mats.metal_dark_proc, rf, true);
  mesh('ROOF_lounge_table', [BB(11.0, 12.2, ROOF + .02, ROOF + .4, -12.7, -11.9)], mats.metal_dark_proc, rf, true);
  mesh('ROOF_lounge_table_top', [BB(10.96, 12.24, ROOF + .4, ROOF + .44, -12.74, -11.86)], mats.white_marking_proc, rf);
  mesh('ROOF_lounge_neon', [BB(10.96, 12.24, ROOF + .33, ROOF + .4, -11.92, -11.86)], mats.neon_violet_proc, rf);
  // dance floor SW — top face keeps a clean 0..1 UV map for the scripted animated PAA (disco pattern)
  const dfG = new THREE.BoxGeometry(6, .1, 6);
  place(dfG, -11, ROOF + .07, -10.5);
  const dfM = new THREE.Mesh(dfG, mats.dancefloor_proc);
  dfM.name = 'ROOF_dancefloor'; dfM.castShadow = dfM.receiveShadow = true; rf.add(dfM);
  const dfLines = [];
  for (let k = 1; k < 8; k++) {
    dfLines.push(BB(-14 + k * .75 - .015, -14 + k * .75 + .015, ROOF + .12, ROOF + .125, -13.5, -7.5));
    dfLines.push(BB(-14, -8, ROOF + .12, ROOF + .125, -13.5 + k * .75 - .015, -13.5 + k * .75 + .015));
  }
  mesh('ROOF_dancefloor_grid', dfLines, mats.metal_dark_proc, rf);
  mesh('ROOF_dancefloor_frame', [
    BB(-14.25, -7.75, ROOF + .02, ROOF + .12, -13.75, -13.5), BB(-14.25, -7.75, ROOF + .02, ROOF + .12, -7.5, -7.25),
    BB(-14.25, -14, ROOF + .02, ROOF + .12, -13.5, -7.5), BB(-8, -7.75, ROOF + .02, ROOF + .12, -13.5, -7.5)], mats.metal_dark_proc, rf, true);
  mesh('ROOF_dancefloor_neon', [
    BB(-14.28, -7.72, ROOF + .09, ROOF + .15, -13.78, -13.72), BB(-14.28, -7.72, ROOF + .09, ROOF + .15, -7.28, -7.22),
    BB(-14.28, -14.22, ROOF + .09, ROOF + .15, -13.75, -7.25), BB(-7.78, -7.72, ROOF + .09, ROOF + .15, -13.75, -7.25)], mats.neon_cyan_proc, rf);
  // party speakers (script say3D at speaker_N_pos memory points — see handoff)
  for (const [n, sx, sz, dir] of [[1, -14.9, -7.0, 1], [2, -7.1, -14.0, -1]]) {
    mesh('ROOF_speaker_' + n, [
      BB(sx - .4, sx + .4, ROOF + .02, ROOF + 1.3, sz - .35, sz + .35),
      BB(sx - .3, sx + .3, ROOF + 1.3, ROOF + 1.75, sz - .28, sz + .28)], mats.metal_dark_proc, rf, true);
    mesh('ROOF_speaker_' + n + '_cones', [
      place(new THREE.CylinderGeometry(.22, .22, .06, 12), sx + dir * .43, ROOF + .45, sz, 0, 0, Math.PI / 2),
      place(new THREE.CylinderGeometry(.15, .15, .06, 12), sx + dir * .43, ROOF + 1.0, sz, 0, 0, Math.PI / 2),
      place(new THREE.CylinderGeometry(.12, .12, .06, 12), sx + dir * .33, ROOF + 1.5, sz, 0, 0, Math.PI / 2)], mats.metal_grey_proc, rf);
  }
  // AC (ripped), vents, mast — repositioned inside the rounded plan
  const eq = [];
  for (const [vx, vz] of [[-15.5, 7.5], [-13, 10.5], [15.2, 2.2], [15.6, -4.5]]) {
    eq.push(place(new THREE.CylinderGeometry(.18, .18, .9, 16), vx, ROOF + .47, vz));
    eq.push(place(new THREE.CylinderGeometry(.3, .3, .07, 16), vx, ROOF + .95, vz));
  }
  eq.push(place(new THREE.CylinderGeometry(.06, .1, 6, 16), -5.6, ROOF + 2.86 + 3, -2.4));
  eq.push(place(new THREE.SphereGeometry(.14, 16, 12), -5.6, ROOF + 2.86 + 6, -2.4));
  mesh('ROOF_equipment', eq, mats.rollup_combo_co, rf, true);
  [[-14.9, 11.9, Math.PI / 2], [-11.4, 14.9, 0], [-8.0, 15.9, 0], [15.9, -5.5, 0]].forEach(([ax, az, ry], k) => {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(AC_UNIT.positions.slice(), 3));
    g.setAttribute('uv', new THREE.BufferAttribute(AC_UNIT.uvs.slice(), 2));
    g.computeVertexNormals();
    place(g, ax, ROOF + .02, az, 0, ry, 0);
    const m = new THREE.Mesh(g, mats.office_addons_co);
    m.name = 'ROOF_ac_0' + (k + 1); m.castShadow = m.receiveShadow = true; rf.add(m);
  });
  mesh('ROOF_mast_neon', [BB(-5.72, -5.48, ROOF + 2.86 + 4.4, ROOF + 2.86 + 4.9, -2.52, -2.28)], mats.neon_magenta_proc, rf);

  // ---- foundation: 3 m deep plinth under the whole footprint, inset 0.06 (for slope placement) ----
  const fd = new THREE.Group(); fd.name = 'foundation'; root.add(fd);
  mesh('FOUNDATION', [
    BB(-17.94, 17.94, -3, .1, -8.94, 8.94),
    BB(-8.94, 8.94, -3, .1, 8.94, 17.94), BB(-8.94, 8.94, -3, .1, -17.94, -8.94),
    ...CORNERS.map(([cx, cz, t0]) => pie(cx, cz, 8.94, -3, .1, t0)),
    // stepped fill under the NE chamfer (kept inside x+z ≤ 26.9)
    BB(9, 16.9, -3, .1, 9, 10), BB(9, 15.9, -3, .1, 10, 11), BB(9, 14.9, -3, .1, 11, 12),
    BB(9, 13.9, -3, .1, 12, 13), BB(9, 12.9, -3, .1, 13, 14), BB(9, 11.9, -3, .1, 14, 15),
    BB(9, 10.9, -3, .1, 15, 16), BB(9, 9.9, -3, .1, 16, 17)],
    mats.concrete_panels_co, fd, true);

  // ---- door leaves (unchanged; names = selections) ----
  const dg = new THREE.Group(); dg.name = 'doors'; root.add(dg);
  for (const d of DOORS) {
    const [x0, x1, y0b, y1b, z0, z1] = d.box;
    const alongX = (x1 - x0) > (z1 - z0);
    // Local frame: u = across the opening, v = height, w = thickness. Panelled veneer leaf with a
    // proud moulding frame on BOTH faces + brass hardware (lever set, kick plates, latch edge).
    const U0 = alongX ? x0 : z0, U1 = alongX ? x1 : z1;
    const W0 = alongX ? z0 : x0, W1 = alongX ? z1 : x1;
    const axisU = alongX ? d.axis.x : d.axis.z;
    const B = (u0, u1, v0, v1, w0, w1) => alongX ? BB(u0, u1, v0, v1, w0, w1) : BB(w0, w1, v0, v1, u0, u1);
    const leaf = [], hw = [];
    const P = .024, IN = .055, ST = .07;                     // moulding proud, edge inset, stile width
    leaf.push(B(U0, U1, y0b, y1b, W0, W1));                  // slab
    const RB = y0b + .10, RM0 = y0b + .95, RM1 = y0b + 1.01, RT = y1b - .10;
    for (const [f0, f1] of [[W1, W1 + P], [W0 - P, W0]]) {   // moulding frame, both faces
      leaf.push(B(U0 + IN, U0 + IN + ST, RB, RT, f0, f1), B(U1 - IN - ST, U1 - IN, RB, RT, f0, f1));
      leaf.push(B(U0 + IN, U1 - IN, RB, RB + ST, f0, f1), B(U0 + IN, U1 - IN, RT - ST, RT, f0, f1));
      leaf.push(B(U0 + IN, U1 - IN, RM0, RM1, f0, f1));
    }
    // brass: kick plates, latch edge, lever sets
    const latch = Math.abs(U0 - axisU) < Math.abs(U1 - axisU) ? U1 : U0;
    const sgn = latch > axisU ? -1 : 1;                       // into the leaf from the latch edge
    for (const [f0, f1] of [[W1 + P, W1 + P + .004], [W0 - P - .004, W0 - P]]) {
      hw.push(B(U0 + IN + ST, U1 - IN - ST, y0b + .12, y0b + .28, f0, f1));   // kick plate
    }
    // brass latch edge, proud of the moulding so it actually reads
    hw.push(B(Math.min(latch, latch + sgn * .022), Math.max(latch, latch + sgn * .022), y0b, y1b, W0 - P - .002, W1 + P + .002));
    const hu = latch + sgn * .085, hy = y0b + 1.06;
    for (const [r0, r1, l0, l1] of [[W1, W1 + .022, W1 + .022, W1 + .07], [W0 - .022, W0, W0 - .07, W0 - .022]]) {
      hw.push(B(hu - .04, hu + .04, hy - .04, hy + .04, r0, r1));             // rose plate
      hw.push(B(Math.min(hu, hu + sgn * .13), Math.max(hu, hu + sgn * .13), hy - .014, hy + .014, l0, l1)); // lever, toward the hinge
    }
    mesh(d.id, leaf, mats.house_big02_multi2, dg);
    mesh(d.id + '_hw', hw, mats.door_brass_proc, dg);
  }
  return root;
}
