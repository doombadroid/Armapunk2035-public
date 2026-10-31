// Headless export harness: owns tower.js's runtime (no browser, no stage).
// Load-time string patch records a per-primitive registry inside mesh();
// each needle must match EXACTLY once or we fail loudly.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import * as THREE from 'three';
// v13/v18: the viewer previews real textures, and TextureLoader touches the DOM
// (document.createElementNS) which node has not got. v13 stubbed the ONE call in
// lux-tower.js with a needle; v18 added kitchen/shower/toilet modules that each
// construct their own loader, and the needle silently missed them. Patch the
// CLASS instead: every importer, present and future, gets the stub. The converter
// only ever consumes material NAMES, so a bare Texture is enough.
THREE.TextureLoader.prototype.load = function () { return new THREE.Texture(); };

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, 'lux-tower.js'), 'utf8');

function patchOnce(text, needle, replacement) {
  const n = text.split(needle).length - 1;
  if (n !== 1) throw new Error(`needle matched ${n}x, want 1: ${needle}`);
  return text.replace(needle, replacement);
}

let patched = src;
// r5: floor-sign digit chirality — same authoring convention as the 20F tower
// (drop 8): the source mirrors digit strokes for the three.js CAMERA, which
// views the declared arma axes mirror-imaged. In-game (b0335, player-verified
// at F01/F29): every floor sign reads mirrored ("01" -> "10", "29" -> "65").
// Same fix as harness.mjs: invert segDigits' mirror branch — both sign sets
// per floor share it (flip=false north set, flip=true south set), so one
// inversion corrects both facings. Geometry/doors/holo stay RAW.
patched = patchOnce(
  patched,
  `  const X = (a, b) => flip ? [2 * cx - b, 2 * cx - a] : [a, b];`,
  `  const X = (a, b) => flip ? [a, b] : [2 * cx - b, 2 * cx - a];`
);
// r6: tower.js loads the door manifest via browser fetch(); node has no base URL
// for relative fetch — swap in a filesystem read (same JSON, same shape).
patched = patchOnce(
  patched,
  `const DOORS = (await (await fetch('./lux-doors-manifest.json')).json()).doors;`,
  `const DOORS = JSON.parse((await import('node:fs')).readFileSync(new URL('./lux-doors-manifest.json', import.meta.url), 'utf8')).doors;`
);
patched = patchOnce(
  patched,
  `import * as THREE from 'three';`,
  `import * as THREE from 'three';
globalThis.__REG = [];
function __aabb(g) {
  const a = g.attributes.position.array;
  const mn = [1e9, 1e9, 1e9], mx = [-1e9, -1e9, -1e9];
  for (let i = 0; i < a.length; i += 3)
    for (let k = 0; k < 3; k++) {
      if (a[i + k] < mn[k]) mn[k] = a[i + k];
      if (a[i + k] > mx[k]) mx[k] = a[i + k];
    }
  let aab = true;
  const nv = a.length / 3;
  outer: for (let i = 0; i < a.length; i += 3)
    for (let k = 0; k < 3; k++) {
      const v = a[i + k];
      if (Math.abs(v - mn[k]) > 1e-5 && Math.abs(v - mx[k]) > 1e-5) { aab = false; break outer; }
    }
  return { min: mn, max: mx, nv, aab };
}`
);
// tower.js bug normalization: BB() is called with swapped bounds wherever a
// mirrored coordinate (e.g. `11.7 * s`, s = -1) supplies the "min" — a
// negative-size BoxGeometry has mirrored winding AND normals, so the whole
// south/west facade is backface-culled (invisible) in the original viewer.
// The design intent (solid symmetric boxes) is unambiguous; normalize bounds.
// r5 rewrote BB (inline BoxGeometry + alignUV) but kept the swapped-bounds bug:
// mirrored facade calls still pass negative sizes. Same normalization, new needle.
patched = patchOnce(
  patched,
  `function BB(x0, x1, y0, y1, z0, z1) { return alignUV(place(new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)); }`,
  `function BB(x0, x1, y0, y1, z0, z1) { return alignUV(place(new THREE.BoxGeometry(Math.abs(x1 - x0), Math.abs(y1 - y0), Math.abs(z1 - z0)), (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)); }`
);
// r3: mesh() grew a split flag (one scene object per convex box, name_cNN).
// Registry records at ENTRY, pre-split, keyed by the BASE name — so the
// collision synthesis keys (F07_slab, ROOF_hut, ...) are stable across revs
// regardless of how the viewer chops the scene graph.
patched = patchOnce(
  patched,
  // v20 renamed mesh()'s 5th parameter split -> geo and gave it a third state
  // ('only' = collision geometry with no visible mesh). The INJECTION is unchanged:
  // still recorded at ENTRY, before any split, keyed by the base name, so the
  // collision-synthesis keys stay stable across revs. Only the needle moved.
  `function mesh(name, geos, mat, parent, geo = false) {
  if (!geos.length) return;`,
  `function mesh(name, geos, mat, parent, geo = false) {
  if (!geos.length) return;
  globalThis.__REG.push({ name, mat: mat.name, prims: geos.map(__aabb) });`
);

const patchedPath = join(here, 'lux_tower_patched.mjs');
writeFileSync(patchedPath, patched);

const { buildTower } = await import(patchedPath);
const root = buildTower();

// Dump every mesh's final tri-soup in WORLD space.
//
// v18 instances the kitchen/shower/toilet fixtures: they are cloned from a
// prototype and placed per floor with real rotations and translations, so the
// old "assert every world matrix is identity" check (valid while everything was
// baked at the origin) now fails legitimately. Bake the transform in instead —
// the converter consumes world-space tri soup either way, and asserting the old
// invariant would just refuse the new model.
root.updateMatrixWorld(true);
const meshes = [];
const _nm = new THREE.Matrix3();
root.traverse((o) => {
  if (!o.isMesh) return;
  const g = (o.geometry.index ? o.geometry.toNonIndexed() : o.geometry).clone();
  g.applyMatrix4(o.matrixWorld);                 // positions
  _nm.getNormalMatrix(o.matrixWorld);
  const n = g.attributes.normal;
  if (n) {
    const v = new THREE.Vector3();
    for (let i = 0; i < n.count; i++) {
      v.fromBufferAttribute(n, i).applyMatrix3(_nm).normalize();
      n.setXYZ(i, v.x, v.y, v.z);
    }
  }
  meshes.push({
    name: o.name,
    parent: o.parent ? o.parent.name : '',
    mat: o.material.name,
    pos: Array.from(g.attributes.position.array),
    norm: Array.from(g.attributes.normal.array),
    uv: Array.from(g.attributes.uv.array),
  });
});

const out = { meshes, registry: globalThis.__REG };
writeFileSync(join(here, process.argv[2] || 'tower_dump.json'), JSON.stringify(out));
console.log(`meshes=${meshes.length} registryMeshes=${out.registry.length} ` +
  `prims=${out.registry.reduce((a, r) => a + r.prims.length, 0)} ` +
  `tris=${meshes.reduce((a, m) => a + m.pos.length / 9, 0)}`);
