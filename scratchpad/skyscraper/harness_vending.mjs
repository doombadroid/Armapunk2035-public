// Headless export harness for the vending machine (vending.js).
//
// Same shape as harness_gunsmith.mjs: pure ESM, one named export (buildVending), no fetch, no DOM
// of its own. ONE load-time patch, the same one every viewer-facing source in this pipeline needs.
//
// WORLD MATRICES ARE IDENTITY HERE, and that is a property of the source, not an assumption.
// vending.js's add() calls geo.rotateX/Y/Z and geo.translate BEFORE constructing the Mesh, so every
// transform is already baked into the vertex data and each Mesh sits at the origin unrotated. The
// bake below is therefore a no-op — kept anyway, because it costs nothing and a re-drop that starts
// positioning Meshes instead of geometry would otherwise collapse the machine into a pile at the
// origin with no error. (harness_gunsmith.mjs bakes for real; harness_garage.mjs asserts identity
// and would REJECT this source. Baking is the option that is correct either way.)
//
// The dump is a flat tri soup per mesh in the design's own frame: meters, Y-up, front = +Z, origin
// at floor centre. build_vending.py re-centres on the bbox.
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

const src = readFileSync(join(here, 'vending.js'), 'utf8');
// The viewer previews real a3 textures through a TextureLoader, which touches the DOM
// (document.createElementNS) and dies headless. Stubbed to a bare Texture -- the converter consumes
// material NAMES and maps them to .paa paths itself, so the pixels were never wanted here.
const PATCHES = [['new THREE.TextureLoader()', '{ load: () => new THREE.Texture() }']];
let patched = src;
for (const [needle, repl] of PATCHES) patched = patchOnce(patched, needle, repl);
const patchedPath = join(here, 'vending_patched.mjs');
writeFileSync(patchedPath, patched);

const { buildVending } = await import(patchedPath);

function dumpRoot(root) {
  root.updateMatrixWorld(true);
  const meshes = [];
  const mats = {};
  const nm = new THREE.Matrix3();
  root.traverse((o) => {
    if (!o.isMesh) return;
    const g = o.geometry.index ? o.geometry.toNonIndexed() : o.geometry;
    const posAttr = g.attributes.position;
    const nrmAttr = g.attributes.normal;
    const uvAttr = g.attributes.uv;
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
      };
    }
    meshes.push({ name: o.name, mat: M.name, pos, norm, uv });
  });
  return { meshes, mats };
}

const { meshes, mats } = dumpRoot(buildVending());

// The LOD ladder and the per-shop logo retexture both select meshes BY NAME, so a duplicate name
// would silently take whichever the builder hit last. vending.js's own counter suffix makes every
// name unique; this asserts that rather than trusting it.
const names = new Set(meshes.map((m) => m.name));
if (names.size !== meshes.length) {
  const seen = new Set(), dupes = new Set();
  for (const m of meshes) (seen.has(m.name) ? dupes : seen).add(m.name);
  throw new Error(`duplicate mesh names: ${[...dupes].join(', ')}`);
}

// THE THREE LOGO SLOTS ARE THE WHOLE POINT OF THIS PROP (see ARMA3_HANDOFF_VENDING.md). Each must
// exist exactly once and own a material nothing else uses -- that is what lets one .p3d per shop
// swap three texture paths and nothing more. A re-drop that renames a slot, or maps a second mesh
// onto a LOGO material, breaks the retexture silently: the machine still builds, just with a shop
// sign on the wrong face or a cabinet panel painted with the logo.
for (const slot of ['LOGO_front', 'LOGO_side_L', 'LOGO_side_R']) {
  const hits = meshes.filter((m) => m.name.startsWith(slot + '_'));
  if (hits.length !== 1) throw new Error(`${slot}: ${hits.length} meshes, want exactly 1`);
  const mat = hits[0].mat;
  const sharers = meshes.filter((m) => m.mat === mat).map((m) => m.name);
  if (sharers.length !== 1) throw new Error(`${slot}: material ${mat} also on ${sharers.join(', ')}`);
}

const tris = meshes.reduce((a, m) => a + m.pos.length / 9, 0);
const xs = [], ys = [], zs = [];
for (const m of meshes)
  for (let i = 0; i < m.pos.length; i += 3) { xs.push(m.pos[i]); ys.push(m.pos[i + 1]); zs.push(m.pos[i + 2]); }
const bb = (a) => `[${Math.min(...a).toFixed(3)},${Math.max(...a).toFixed(3)}]`;
console.log(`vending: meshes=${meshes.length} tris=${tris} bbox x${bb(xs)} y${bb(ys)} z${bb(zs)}`);
console.log(`size: ${(Math.max(...xs) - Math.min(...xs)).toFixed(3)} w x ${(Math.max(...ys) - Math.min(...ys)).toFixed(3)} h x ${(Math.max(...zs) - Math.min(...zs)).toFixed(3)} d`);

writeFileSync(join(here, process.argv[2] || 'vending_dump.json'), JSON.stringify({ vending: { meshes, mats } }));
