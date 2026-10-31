// Offline render harness for MALDEN GRID (ui/html/map.html) and, after Task 3,
// for anything else that loads ui/html/grid3d.js.
//
//   node scratchpad/grid3d_harness/render_map.mjs <label>
//
// Writes <label>.png and <label>.json beside this file. The JSON is the part that
// matters: structural invariants read out of the page's own globals after boot.
// Compare two labels with compare.mjs.
//
// WHY THIS EXISTS: Task 3 lifts ~900 lines of renderer out of map.html into a
// shared module. The acceptance criterion is "the map is unchanged", and the only
// honest way to assert that without a game client is to render the page before and
// after from identical inputs and diff both the numbers and the pixels.
//
// A3API is overridden BEFORE the page's own script runs, so the page's built-in
// standalone stub (synthetic 2-model mesh lib, procedural tiles, mock heightfield)
// never installs and we exercise the REAL baked assets instead.
//
// Determinism: Math.random is seeded, the demo bus's moving payloads are ignored
// (we push our own fixed one), and the camera is pinned before the screenshot.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE    = new URL('.', import.meta.url).pathname;
const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const HTML    = path.join(MISSION, 'ui/html');
const label   = process.argv[2] || 'run';

const assets = {
  'ui\\html\\malden_hf.txt':  fs.readFileSync(path.join(HTML, 'malden_hf.txt'),  'utf8'),
  'ui\\html\\malden_bld.txt': fs.readFileSync(path.join(HTML, 'malden_bld.txt'), 'utf8'),
  'ui\\html\\malden_msh.txt': fs.readFileSync(path.join(HTML, 'malden_msh.txt'), 'utf8'),
  // fences split out of bld (map cold-open work, 2026-09-08); loaded lazily by the page
  'ui\\html\\malden_fen.txt': fs.readFileSync(path.join(HTML, 'malden_fen.txt'), 'utf8'),
};
// grid3d.js only exists after Task 3; ship it when present so the same harness
// serves both sides of the refactor.
const gridPath = path.join(HTML, 'grid3d.js');
if (fs.existsSync(gridPath)) assets['ui\\html\\grid3d.js'] = fs.readFileSync(gridPath, 'utf8');
// The page self-boots the bridge; without it the first load logs a bridge failure
// and the page waits for an SQF injection that never comes.
assets['webui\\ui\\webui.js'] = fs.readFileSync(path.join(MISSION, 'webui/ui/webui.js'), 'utf8');

const browser = await puppeteer.launch({
  headless: 'new',
  args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox',
         '--disable-lcd-text', '--force-device-scale-factor=1'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1280, height: 720, deviceScaleFactor: 1 });

const errors = [];
page.on('pageerror', e => errors.push('pageerror: ' + e.message));
page.on('console',  m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });

await page.evaluateOnNewDocument((assets) => {
  // seeded PRNG -- the page's own code and any stub delay must not vary per run
  let s = 1234567;
  Math.random = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };

  window.__assetHits = [];
  window.A3API = {
    RequestFile: (p) => {
      window.__assetHits.push(p);
      return Object.prototype.hasOwnProperty.call(assets, p)
        ? Promise.resolve(assets[p])
        : Promise.reject(new Error('no such file: ' + p));
    },
    // webui.js refuses to boot without these and reports the page as unwhitelisted.
    // Answering them keeps the harness's boot path identical to the game's.
    // The real bridge answers every "log" call (webui/functions/fn_init.sqf:65
    // returns {ok:true}); a stub that swallowed them let each one time out as
    // "SQF timeout: log", which was a harness deficiency masquerading as a page
    // property. Answer them the way SQF does: WEBUI._resolve(id, true, base64 json).
    SendAlert:   (msg) => {
      (window.__alerts = window.__alerts || []).push(msg);
      try {
        const m = JSON.parse(msg);
        if (Array.isArray(m) && m[0] === 'CALL' && m[2] === 'log' && window.WEBUI && window.WEBUI._resolve) {
          const b64 = btoa(unescape(encodeURIComponent(JSON.stringify({ ok: true, msg: '' }))));
          setTimeout(() => window.WEBUI._resolve(m[1], true, b64), 0);
        }
      } catch (e) {}
    },
    SendConfirm: ()    => Promise.resolve(false),
    // Deterministic tile: flat colour keyed off the tile's own grid coords, so
    // the imagery is stable run to run but still distinguishable tile to tile.
    RequestTexture: (p, sz) => new Promise((res) => {
      const m = /s_(\d+)_(\d+)/.exec(p);
      const c = m ? +m[1] : 0, r = m ? +m[2] : 0;
      const cv = document.createElement('canvas'); cv.width = cv.height = sz;
      const g = cv.getContext('2d');
      g.fillStyle = `rgb(${30 + (c * 7) % 60},${40 + (r * 11) % 60},${35 + ((c + r) * 5) % 50})`;
      g.fillRect(0, 0, sz, sz);
      g.strokeStyle = 'rgba(245,166,35,.15)'; g.strokeRect(0.5, 0.5, sz - 1, sz - 1);
      res(cv.toDataURL());
    }),
  };
}, assets);

await page.goto('file://' + path.join(HTML, 'map.html'), { waitUntil: 'load' });
// Boot is a promise chain over three RequestFile calls plus tile pumping.
await new Promise(r => setTimeout(r, 9000));

const probe = await page.evaluate(() => {
  const g = (n) => { try { return eval(n); } catch (e) { return undefined; } };
  const RR   = g('R');                                  // post-Task-3 instance, if any
  // NOTE: this local must NOT be called R.  `const R = g('R')` self-shadows --
  // eval('R') runs while the const is still in its temporal dead zone, throws,
  // and every R fallback below silently reads undefined.
  const hf   = g('HF')      ?? (RR && RR.hf);
  const mesh = g('MESHLIB') ?? (RR && RR.meshes);
  const cnt  = (o) => (o == null ? null : (Array.isArray(o) ? o.length : Object.keys(o).length));
  const secStat = (name) => { const a = g(name) ?? (RR && RR[name]);
    if (!a) return null;
    return { buckets: a.length,
             drawn: a.filter(x => x && x.nt).length,
             tris: a.reduce((n, x) => n + ((x && x.nt) || 0), 0),
             verts: a.reduce((n, x) => n + ((x && x.nv) || 0), 0) }; };
  return {
    mode: RR ? 'module' : 'inline',
    hf: hf ? { n: hf.n, cell: hf.cell, extent: hf.extent,
               samples: hf.data ? hf.data.length : null,
               // a cheap content fingerprint: sum + a few fixed taps
               sum: hf.data ? Array.prototype.reduce.call(hf.data, (a, b) => a + b, 0).toFixed(1) : null,
               taps: hf.data ? [0, 12345, 33333, 39999].map(i => hf.data[i]) : null } : null,
    meshModels: cnt(mesh),
    SEC: g('SEC') ?? (RR && RR.SEC) ?? null,
    bldCount: g('bldCount') ?? (RR && RR.bldCount) ?? null,
    sectors:  secStat('sectors'),
    sectorsM: secStat('sectorsM'),
    sectorsF: secStat('sectorsF'),
    canvas: (() => { const c = document.getElementById('gl');
      return c ? { w: c.width, h: c.height } : null; })(),
    loadingText: (document.getElementById('loading') || {}).textContent ?? null,
    assetHits: window.__assetHits,
  };
});

// Pin the camera so the screenshot is a fixed view of a fixed world.
await page.evaluate(() => {
  if (typeof cam !== 'undefined') {
    cam.x = 7130; cam.y = 7909; cam.dist = 1800; cam.yaw = 0.6; cam.pitch = 0.9;
    if (typeof camClamp === 'function') camClamp();
  }
  if (typeof env !== 'undefined') { env.hour = 12; env.overcast = 0; }
  if (typeof dirty === 'function') dirty();
});
await new Promise(r => setTimeout(r, 2500));

await page.screenshot({ path: path.join(HERE, label + '.png') });
fs.writeFileSync(path.join(HERE, label + '.json'),
                 JSON.stringify({ label, errors, probe }, null, 2));
console.log(JSON.stringify({ label, errors, probe }, null, 2));
await browser.close();
