// Headless export harness for the two desktop 3D printers (gunsmith.js).
//
// gunsmith.js is the cleanest design source this pipeline has taken: pure ESM, named exports
// (buildPrinterI3 / buildPrinterCoreXY), no fetch, no DOM, no TextureLoader. So there are ZERO
// load-time patches here -- patchOnce is kept and unused on purpose, because "no patches needed"
// is a fact worth being able to see at a glance on the next re-drop, and the helper must already
// be here (asserting needle count == 1) the moment one is.
//
// UNLIKE harness_garage.mjs, world matrices are NOT identity: gunsmith.js positions and rotates
// nearly every mesh (B()/C()/T() take x,y,z and optional rx/ry/rz). So this harness BAKES
// matrixWorld into the positions and the inverse-transpose into the normals. Asserting identity
// here, as the garage harness does, would reject the source outright; silently ignoring the
// transforms would collapse the whole printer into one pile at the origin.
//
// The dump is a flat tri soup per mesh, in the design's own frame: meters, Y-up, front = +Z,
// origin at floor centre. build_printer.py re-centres on the bbox.
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

const src = readFileSync(join(here, 'gunsmith.js'), 'utf8');
// ONE patch: the viewer previews real a3 textures through a TextureLoader, which touches the DOM
// (document.createElementNS) and dies headless. Stubbed to a bare Texture -- the converter consumes
// material NAMES and maps them to .paa paths itself, so the pixels were never wanted here. Same
// patch the garage harness carries, and the reason patchOnce exists at all.
const PATCHES = [['new THREE.TextureLoader()', '{ load: () => new THREE.Texture() }']];
let patched = src;
for (const [needle, repl] of PATCHES) patched = patchOnce(patched, needle, repl);
const patchedPath = join(here, 'gunsmith_patched.mjs');
writeFileSync(patchedPath, patched);

const { buildGunsmith } = await import(patchedPath);

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
      // ExtrudeGeometry/TubeGeometry carry UVs; a primitive without them still needs the slot
      // filled or the tri-soup walker in the builder reads undefined and writes NaN.
      uv.push(uvAttr ? uvAttr.getX(i) : 0, uvAttr ? uvAttr.getY(i) : 0);
    }
    if (pos.length % 9 !== 0) throw new Error(`${o.name}: ${pos.length / 3} verts, not a tri soup`);

    // Dump the material's own numbers so the builder never hand-copies a hex out of the design
    // source. Same rule as measuring layout rects in-page rather than transcribing them: a colour
    // typed twice is a colour that will disagree with the prototype on the next re-drop, silently.
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

// The LOD ladder selects meshes BY NAME (GS_spring_*, GS_rd_*, ...), so a duplicate name would
// silently take whichever the builder hit last out of the wrong LOD.
const out = {};
for (const [key, build] of [['gunsmith', buildGunsmith]]) {
  const { meshes, mats } = dumpRoot(build());
  const names = new Set(meshes.map((m) => m.name));
  if (names.size !== meshes.length) {
    const seen = new Set(), dupes = new Set();
    for (const m of meshes) (seen.has(m.name) ? dupes : seen).add(m.name);
    throw new Error(`${key}: duplicate mesh names: ${[...dupes].join(', ')}`);
  }
  out[key] = { meshes, mats };
  const tris = meshes.reduce((a, m) => a + m.pos.length / 9, 0);
  const xs = [], ys = [], zs = [];
  for (const m of meshes)
    for (let i = 0; i < m.pos.length; i += 3) { xs.push(m.pos[i]); ys.push(m.pos[i + 1]); zs.push(m.pos[i + 2]); }
  const bb = (a) => `[${Math.min(...a).toFixed(3)},${Math.max(...a).toFixed(3)}]`;
  console.log(`${key}: meshes=${meshes.length} tris=${tris} bbox x${bb(xs)} y${bb(ys)} z${bb(zs)}`);
}

writeFileSync(join(here, process.argv[2] || 'gunsmith_dump.json'), JSON.stringify(out));
