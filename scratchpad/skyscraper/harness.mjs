// Headless export harness: owns tower.js's runtime (no browser, no stage).
// Load-time string patch records a per-primitive registry inside mesh();
// each needle must match EXACTLY once or we fail loudly.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, 'tower.js'), 'utf8');

function patchOnce(text, needle, replacement) {
  const n = text.split(needle).length - 1;
  if (n !== 1) throw new Error(`needle matched ${n}x, want 1: ${needle}`);
  return text.replace(needle, replacement);
}

let patched = src;
// v13: texture-preview TextureLoader touches the DOM (document.createElementNS)
// — stubbed to a bare Texture; the converter only consumes material NAMES.
patched = patchOnce(patched, 'new THREE.TextureLoader()',
  '{ load: () => new THREE.Texture() }');
// r6: tower.js loads the door manifest via browser fetch(); node has no base URL
// for relative fetch — swap in a filesystem read (same JSON, same shape).
patched = patchOnce(
  patched,
  `const DOORS = (await (await fetch('./doors-manifest.json')).json()).doors;`,
  `const DOORS = JSON.parse((await import('node:fs')).readFileSync(new URL('./doors-manifest.json', import.meta.url), 'utf8')).doors;`
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
  `function mesh(name, geos, mat, parent, split = false) {
  if (!geos.length) return;`,
  `function mesh(name, geos, mat, parent, split = false) {
  if (!geos.length) return;
  globalThis.__REG.push({ name, mat: mat.name, prims: geos.map(__aabb) });`
);

// Signage chirality normalization (drop 8). MEASURED, not assumed: the r10
// in-game plates render mirrored ("201" reads "10S") while the browser viewer
// shows them correct — the source authors digit flips for the three.js CAMERA,
// which views the declared arma axes (X east, Y up, Z north) mirror-imaged.
// The handoff's own coordinate-convention section defines the acceptance test
// ("plate 201 must read normally" in-engine); inverting segDigits' mirror
// branch satisfies it for every sign. Geometry/doors/manifest stay RAW as the
// section demands — text chirality is the only viewer-space content.
patched = patchOnce(
  patched,
  `  const X = (a, b) => flip ? [2 * cx - b, 2 * cx - a] : [a, b];`,
  `  const X = (a, b) => flip ? [a, b] : [2 * cx - b, 2 * cx - a];`
);

const patchedPath = join(here, 'tower_patched.mjs');
writeFileSync(patchedPath, patched);

const { buildTower } = await import(patchedPath);
const root = buildTower();

// Dump every mesh's final tri-soup (merge() output is non-indexed) + registry.
const meshes = [];
root.traverse((o) => {
  if (!o.isMesh) return;
  if (o.geometry.index) throw new Error(`indexed geometry on ${o.name}`);
  const g = o.geometry;
  meshes.push({
    name: o.name,
    parent: o.parent.name,
    mat: o.material.name,
    pos: Array.from(g.attributes.position.array),
    norm: Array.from(g.attributes.normal.array),
    uv: Array.from(g.attributes.uv.array),
  });
});

// world transforms are all identity (groups at origin) — assert that.
root.updateMatrixWorld(true);
root.traverse((o) => {
  if (!o.isMesh) return;
  const e = o.matrixWorld.elements;
  const I = [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1];
  for (let i = 0; i < 16; i++)
    if (Math.abs(e[i] - I[i]) > 1e-9) throw new Error(`non-identity world matrix on ${o.name}`);
});

const out = { meshes, registry: globalThis.__REG };
writeFileSync(join(here, process.argv[2] || 'tower_dump.json'), JSON.stringify(out));
console.log(`meshes=${meshes.length} registryMeshes=${out.registry.length} ` +
  `prims=${out.registry.reduce((a, r) => a + r.prims.length, 0)} ` +
  `tris=${meshes.reduce((a, m) => a + m.pos.length / 9, 0)}`);
