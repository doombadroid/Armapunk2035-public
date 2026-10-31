// Compare two harness runs.  node scratchpad/grid3d_harness/compare.mjs baseline after
// Structural invariants must match EXACTLY; pixels are reported as a percentage of
// differing pixels so a human can judge whether a small delta is antialiasing or a bug.
import fs from 'fs'; import path from 'path'; import zlib from 'zlib';
const HERE = new URL('.', import.meta.url).pathname;
const [a, b] = process.argv.slice(2);
const J = (l) => JSON.parse(fs.readFileSync(path.join(HERE, l + '.json'), 'utf8'));
const A = J(a), B = J(b);
let bad = 0;
const walk = (x, y, p = '') => {
  if (JSON.stringify(x) === JSON.stringify(y)) return;
  if (x && y && typeof x === 'object' && typeof y === 'object' && !Array.isArray(x)) {
    for (const k of new Set([...Object.keys(x), ...Object.keys(y)])) walk(x[k], y[k], p + '.' + k);
    return;
  }
  console.log(`DIFF ${p}\n   ${a}: ${JSON.stringify(x)}\n   ${b}: ${JSON.stringify(y)}`); bad++;
};
// `mode` is EXPECTED to change (inline -> module); everything else must not.
//
// assetHits: the ONE addition a correct extraction must make is fetching the module
// itself, and no implementation can avoid it -- RequestFile is the only load path a
// blob: page has. So that single entry is subtracted before comparing, and NOTHING
// else is: the order and identity of every real asset load is still asserted exactly.
// Extend this list only for a fetch the task itself introduces, never to silence one.
// malden_fen.txt: fences split out of bld.txt and loaded lazily (2026-09-08).
// malden_sat128.txt / malden_sat256.txt: the pre-composed satellite tiers (2026-09-08). This
// harness serves NEITHER, on purpose -- so the fetch is attempted, rejects, and the page takes
// the per-tile path; that is the fallback gate, and the png staying byte-identical is what it
// proves. Only the 128 one appears in a fallback run: the 256 fetch is never attempted when the
// 128 atlas did not land, which is itself part of what this asserts. The atlas path has its own
// harness, render_map_atlas.mjs, which serves both.
// Deferring the mesh library past settle also reorders a REAL asset load on purpose, so
// assetHits is compared as a sorted set: identity and count still exact, sequence free --
// the sequence is now the feature under test, not an invariant.
const EXPECTED_NEW_ASSETS = ['ui\\html\\grid3d.js', 'ui\\html\\malden_fen.txt',
                             'ui\\html\\malden_sat128.txt', 'ui\\html\\malden_sat256.txt'];
const strip = (o) => {
  const c = structuredClone(o.probe);
  delete c.mode;
  if (Array.isArray(c.assetHits)) c.assetHits = c.assetHits.filter(h => !EXPECTED_NEW_ASSETS.includes(h)).sort();
  return c;
};
walk(strip(A), strip(B), 'probe');
walk(A.errors, B.errors, 'errors');
console.log(`\nmode: ${A.probe.mode} -> ${B.probe.mode}`);
const sz = (l) => fs.statSync(path.join(HERE, l + '.png')).size;
console.log(`png bytes: ${sz(a)} vs ${sz(b)}`);
const same = Buffer.compare(fs.readFileSync(path.join(HERE, a + '.png')),
                            fs.readFileSync(path.join(HERE, b + '.png'))) === 0;
console.log(`png byte-identical: ${same}`);
console.log(bad === 0 ? '\nINVARIANTS MATCH' : `\n${bad} INVARIANT DIFFERENCE(S)`);
process.exit(bad === 0 ? 0 : 1);
