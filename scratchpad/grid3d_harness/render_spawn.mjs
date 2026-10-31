// Offline render harness for the 3D spawn screen (ui/html/spawn.html).
//
//   node scratchpad/grid3d_harness/render_spawn.mjs <label>
//
// Writes <label>.png and <label>.json beside this file, the same contract
// render_map.mjs uses, so compare.mjs works across both.
//
// WHY: the page cannot be reviewed in game -- Esc closes the dialog, so the
// console is unreachable, and a spawn screen is not something to debug on a live
// login. This renders it from the REAL baked assets (A3API is installed before
// the page's own script runs, so the page's standalone stub never takes over),
// pushes a FIXED spawn payload through the real webui bridge, and reads the
// page's own state back out.
//
// What the JSON asserts, and why each one is a bug that actually happens:
//   rows/cur/usable   the payload reached the list and a USABLE row was selected
//                     (a list that opens on a locked row is the first-usable
//                     findIndex failing)
//   lockedRendered    a locked row KEPT ITS PLACE -- the whole behaviour change
//   deployDisabled    the button refuses a locked selection
//   camNear           the camera FLEW to the selected point instead of sitting on
//                     the island centre; a spawn screen that never leaves the
//                     overview is the failure this page exists to avoid
//   hf/sectors        grid3d.js booted and the island is really there
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE    = new URL('.', import.meta.url).pathname;
const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const HTML    = path.join(MISSION, 'ui/html');
const label   = process.argv[2] || 'spawn';

const assets = {
  'ui\\html\\malden_hf.txt':  fs.readFileSync(path.join(HTML, 'malden_hf.txt'),  'utf8'),
  'ui\\html\\malden_bld.txt': fs.readFileSync(path.join(HTML, 'malden_bld.txt'), 'utf8'),
  'ui\\html\\malden_msh.txt': fs.readFileSync(path.join(HTML, 'malden_msh.txt'), 'utf8'),
  'ui\\html\\malden_fen.txt': fs.readFileSync(path.join(HTML, 'malden_fen.txt'), 'utf8'),
  'ui\\html\\grid3d.js':      fs.readFileSync(path.join(HTML, 'grid3d.js'),      'utf8'),
  'webui\\ui\\webui.js':      fs.readFileSync(path.join(MISSION, 'webui/ui/webui.js'), 'utf8'),
};
// The pre-composed satellite tiers. Shipped so the harness exercises the ATLAS
// path the game takes, not the per-tile fallback -- the two have different gates
// (satWait / allow256) and only one of them is what a player sees.
for (const res of [128, 256]) {
  const f = path.join(HTML, `malden_sat${res}.txt`);
  if (fs.existsSync(f)) assets[`ui\\html\\malden_sat${res}.txt`] = fs.readFileSync(f, 'utf8');
}

// The payload under test. Deliberately mixed: two usable towns, a house with no
// player count (-1, the native list's own rule for phouse_ rows), a CONTESTED
// gang building and an UNRESOLVED row at [0,0] -- the three states the screen has
// to render differently from each other.
// SPAWN_SIDE=cop / SPAWN_REDEPLOY=1 exercise the duty palette (.tal) and the
// REDEPLOY wording without a second harness.
const SIDE = process.env.SPAWN_SIDE || 'civ';
const REDEPLOY = process.env.SPAWN_REDEPLOY === '1';
const PAYLOAD = {
  side: SIDE, redeploy: REDEPLOY, respawned: false,
  rows: [
    { id: 0, label: 'La Trinite',      kind: 'city', x: 6180, y: 8420, near: 7,  reason: '' },
    { id: 1, label: 'Larche',          kind: 'city', x: 4260, y: 5980, near: 2,  reason: '' },
    { id: 2, label: 'The Shed',        kind: 'home', x: 5320, y: 7210, near: -1, reason: '' },
    { id: 3, label: 'Gang Building',   kind: 'gang', x: 8320, y: 7740, near: 4,  reason: 'CONTESTED -- ACTIVE WAR ZONE' },
    { id: 4, label: 'Governor Office', kind: 'duty', x: 0,    y: 0,    near: -1, reason: 'POSITION UNRESOLVED' },
  ],
};

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
  let s = 1234567;
  Math.random = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  window.__assetHits = [];
  window.__calls = [];
  window.A3API = {
    RequestFile: (p) => {
      window.__assetHits.push(p);
      return Object.prototype.hasOwnProperty.call(assets, p)
        ? Promise.resolve(assets[p])
        : Promise.reject(new Error('no such file: ' + p));
    },
    // Answer every CALL the way SQF does, or the page's awaits time out and the
    // timeout reads as a page bug. render_map.mjs's header records that trap.
    SendAlert: (msg) => {
      (window.__alerts = window.__alerts || []).push(msg);
      try {
        const m = JSON.parse(msg);
        if (Array.isArray(m) && m[0] === 'CALL') {
          window.__calls.push({ verb: m[2], args: m[3] });
          let reply = { ok: true, msg: '' };
          if (m[2] === 'spawnDeploy') reply = { ok: true, msg: 'WAKING AT HARNESS' };
          const b64 = btoa(unescape(encodeURIComponent(JSON.stringify(reply))));
          setTimeout(() => window.WEBUI && window.WEBUI._resolve(m[1], true, b64), 0);
        }
      } catch (e) {}
    },
    SendConfirm: () => Promise.resolve(false),
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

await page.goto('file://' + path.join(HTML, 'spawn.html'), { waitUntil: 'load' });
await new Promise(r => setTimeout(r, 7000));

// The push, through the REAL bridge: _emit is exactly what SQF's ExecJS calls.
await page.evaluate((payload) => {
  const b64 = btoa(unescape(encodeURIComponent(JSON.stringify(payload))));
  window.WEBUI._emit('spawn', b64);
}, PAYLOAD);
await new Promise(r => setTimeout(r, 3000));   // let the fly-to animation land

const probe = await page.evaluate(() => {
  const g = (n) => { try { return eval(n); } catch (e) { return undefined; } };
  const RR = g('R');
  const hf = RR && RR.hf;
  const C  = g('cam');
  const rws = g('rows') || [];
  const cr = g('cur');
  const sel = rws[cr];
  const listRows = Array.from(document.querySelectorAll('#list .srow')).map(r => ({
    label: r.querySelector('b').textContent,
    sub:   r.querySelector('.nm span').textContent,
    chip:  r.querySelector('.chip').textContent,
    lock:  r.classList.contains('lock'),
    sel:   r.hasAttribute('aria-current'),
  }));
  const btn = document.getElementById('deploy');
  return {
    hf: hf ? { n: hf.n, cell: hf.cell, samples: hf.data ? hf.data.length : null } : null,
    sectors:  (RR && RR.sectors)  ? RR.sectors.filter(x => x && x.nt).length  : null,
    sectorsM: (RR && RR.sectorsM) ? RR.sectorsM.filter(x => x && x.nt).length : null,
    sectorsF: (RR && RR.sectorsF) ? RR.sectorsF.filter(x => x && x.nt).length : null,
    meshModels: (RR && RR.meshes) ? Object.keys(RR.meshes).length : null,
    bldCount: (RR && RR.bldCount) != null ? RR.bldCount : null,
    rows: rws.length,
    cur: cr,
    curLabel: sel ? sel.label : null,
    usableSelected: !!(sel && !sel.reason),
    lockedRendered: listRows.filter(r => r.lock).map(r => r.label),
    lockedReasons:  listRows.filter(r => r.lock).map(r => r.sub),
    listRows,
    avail: (document.getElementById('avail') || {}).textContent,
    hcount: (document.getElementById('hcount') || {}).textContent,
    hgrid: (document.getElementById('hgrid') || {}).textContent,
    deployText: btn ? btn.querySelector('.t').textContent : null,
    deployDisabled: btn ? btn.disabled : null,
    overlayOff: (document.getElementById('connect') || {}).classList
                  ? document.getElementById('connect').classList.contains('off') : null,
    loadingHidden: (document.getElementById('loading') || {}).style
                  ? document.getElementById('loading').style.display === 'none' : null,
    appname: (document.getElementById('appname') || {}).textContent,
    tal: document.body.classList.contains('tal'),
    accent: getComputedStyle(document.body).getPropertyValue('--acc').trim(),
    zread: (document.getElementById('zread') || {}).textContent,
    /* PINS ARE PIXELS, asserted as pixels. R.project returns an ARRAY, and the
       first version of this page read .x/.y off it -- canvas drew every pin at
       NaN and swallowed it, so a map with no pins on it looked perfect in the
       screenshot and reported no error anywhere. Counting non-transparent pixels
       on the overlay is the assertion that catches that class. */
    pinPixels: (() => {
      const c = document.getElementById('ov');
      if (!c || !c.width) return null;
      const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      let n = 0;
      for (let i = 3; i < d.length; i += 4) if (d[i] > 8) n++;
      return n;
    })(),
    // Did the camera actually fly? Distance from the selected point, in metres.
    cam: C ? { tx: Math.round(C.tx), ty: Math.round(C.ty), dist: Math.round(C.dist),
               tiltDeg: Math.round(C.tilt * 180 / Math.PI) } : null,
    camNear: (C && sel) ? Math.round(Math.hypot(C.tx - sel.x, C.ty - sel.y)) : null,
    bootErr: window.__apBootErr || null,
    calls: window.__calls,
    assetHits: window.__assetHits,
  };
});

// Second act: select the LOCKED row and confirm the button refuses it, then the
// usable one again and confirm a deploy round-trips. Two clicks, one page.
const lockProbe = await page.evaluate(() => {
  const rws = (typeof rows !== 'undefined') ? rows : [];
  const li = rws.findIndex(p => !!p.reason);
  const btn = document.getElementById('deploy');
  document.querySelectorAll('#list .srow')[li].click();
  return { lockedIdx: li, lockedLabel: rws[li] && rws[li].label,
           deployText: btn.querySelector('.t').textContent, deployDisabled: btn.disabled };
});
// The fly-to is a 420 ms animation. Reading the camera in the same evaluate as
// the click measures where it STARTED, which is not the thing under test.
await new Promise(r => setTimeout(r, 1200));
lockProbe.camFlewToLocked = await page.evaluate(() => {
  const p = rows[rows.findIndex(r => !!r.reason)];
  return Math.round(Math.hypot(cam.tx - p.x, cam.ty - p.y));
});

const deployProbe = await page.evaluate(async () => {
  const rws = (typeof rows !== 'undefined') ? rows : [];
  const ui = rws.findIndex(p => !p.reason);
  document.querySelectorAll('#list .srow')[ui].click();
  document.getElementById('deploy').click();
  await new Promise(r => setTimeout(r, 600));
  const btn = document.getElementById('deploy');
  return { usableIdx: ui, deployText: btn.querySelector('.t').textContent,
           fill: btn.querySelector('.fill').style.width,
           msg: document.getElementById('msg').textContent,
           calls: window.__calls.map(c => c.verb + ':' + JSON.stringify(c.args)) };
});

await page.screenshot({ path: path.join(HERE, label + '.png') });
const out = { label, errors, probe, lockProbe, deployProbe };
fs.writeFileSync(path.join(HERE, label + '.json'), JSON.stringify(out, null, 2));
console.log(JSON.stringify(out, null, 2));
await browser.close();
