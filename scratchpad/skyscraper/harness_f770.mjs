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
