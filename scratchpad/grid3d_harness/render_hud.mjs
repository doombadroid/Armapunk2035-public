// Offline harness for the STATUS HUD's 3D minimap (ui/html/hud.html).
//
//   node scratchpad/grid3d_harness/render_hud.mjs <label>
//
// Writes <label>.png (the whole overlay), <label>-panel.png (just the minimap,
// so a human can look at it), <label>-fallback.png and <label>.json, and prints
// a PASS/FAIL line per assertion. Exits non-zero if any assertion fails.
//
// WHY THIS IS NOT render_map.mjs. That harness proves a refactor changed
// NOTHING, by diffing pixels before and after. This panel is changing on
// purpose, so there is no "before" to diff against and a pixel comparison would
// be meaningless. It asserts ABSOLUTES instead -- and the one that earns its
// keep is #3:
//
//   1. the page boots clean: no page errors, no console errors, and it does not
//      fetch the mesh library (boxes only is a budget decision, not an accident);
//   2. the renderer came up and really DREW: terrain buffers built, buildings
//      drawn rather than merely parsed, and a framebuffer with an image in it --
//      and the DOM blips over it agree with the camera: a mark lands where the
//      renderer projects it (2f), a mark the panel still shows is NOT dragged
//      out to the rim (2g), and one that is genuinely off it still is (2h);
//   3. IDLE IS STILL. rAF is instrumented; the count must CLIMB while pushes
//      land and must then STOP climbing once they stop. Both halves matter --
//      "it stopped" proves nothing if rAF was never running. This is the whole
//      reason the frame budget exists: an always-on webview that never stops
//      drawing is invisible to a screenshot and costs the player frames for the
//      entire session;
//   4. the 2D tile panel still renders when the 3D path is off. "Off" today
//      means the module could not be loaded (Task 5 adds the preference); the
//      page must fall back rather than show a black square;
//   5. a webglcontextrestored arriving while a boot is still in flight does not
//      start a second one. This layer never closes, so a doubled boot is a
//      permanently orphaned atlas set and terrain VBO per event, not a blip.
//
// Same puppeteer path, same SwiftShader flags, same seeded Math.random and the
// same real-asset A3API override as render_map.mjs, deliberately -- two
// harnesses disagreeing about the environment is a bug factory.
//
// ON THE RETRY. Headless SwiftShader on this box loses the WebGL context at
// boot every so often, nondeterministically, on map.html as readily as on
// hud.html and with no page-side cause -- it was measured at ~1 run in 8 while
// diagnosing this. A lost context is an ENVIRONMENT result, not a page result,
// and letting it fail the run would train everyone to ignore the harness. So a
// run whose context died is retried, and the attempt count is printed: if the
// page ever really cannot hold a context this reports "3/3 attempts lost it"
// rather than quietly going green. The page itself now degrades to the 2D panel
// on a loss, which is the behaviour assertion 4 covers from the other side.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE    = new URL('.', import.meta.url).pathname;
const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const HTML    = path.join(MISSION, 'ui/html');
const label   = process.argv[2] || 'hud';

const rd = (p) => fs.readFileSync(path.join(HTML, p), 'utf8');
const FULL_ASSETS = {
  'ui\\html\\malden_hf.txt':  rd('malden_hf.txt'),
  'ui\\html\\malden_bld.txt': rd('malden_bld.txt'),
  // malden_msh.txt is DELIBERATELY ABSENT. The minimap must not ask for it --
  // real building silhouettes are the expensive path and this panel draws boxes.
  // If the page ever fetches it the stub rejects and assertion 1 goes red.
  'ui\\html\\grid3d.js':      rd('grid3d.js'),
  'webui\\ui\\webui.js':      fs.readFileSync(path.join(MISSION, 'webui/ui/webui.js'), 'utf8'),
};

// The tiles descriptor fn_hudWebPush actually sends for Malden (AP_hudWebTileDef).
const TILES = {
  base: 'a3\\map_malden\\data\\layers\\s_', ext: '_lco.paa', grid: 13,
  flipRow: true, pad: 3, ov: 16 / 512, res: 256, hf: 'ui\\html\\malden_hf.txt',
  tileMeters: 12800 / 13, worldSize: 12800,
};
const START = [7130, 7909];        // the same corner of the island render_map.mjs frames
const HDG = 34;                    // the heading the payload pushes, in degrees
// A point `m` metres straight ahead of the player. Compass bearings run
// clockwise from north and north is +y, so forward is (sin, cos) -- the same
// convention hud.html's own m3ChaseVP uses.
const ahead = (m) => [START[0] + Math.sin(HDG * Math.PI / 180) * m,
                      START[1] + Math.cos(HDG * Math.PI / 180) * m];
const AHEAD_ON  = ahead(350);      // clearly still on the panel (see 2g)
const OFF_PANEL = [START[0] + 1500, START[1]];   // 1.5 km east: nowhere near it
const HUD_PAYLOAD = {
  hp: 91, h2o: 72, food: 64, wanted: 0, paused: false, regen: false,
  map: {
    dir: HDG, pos: START.slice(), zoom: 500, tiles: TILES,
    marks: [
      { x: START[0] + 120, y: START[1] + 80,  kind: 'med' },
      { x: START[0] - 90,  y: START[1] + 140, kind: 'shop' },
      { x: START[0] + 200, y: START[1] - 60,  kind: 'gas' },
      { x: START[0] - 30,  y: START[1] - 80,  kind: 'veh', dir: 205 },
      /* THE RIM PAIR (assertions 2g / 2h). Index 4 is 350 m straight ahead --
         the chase camera still draws ground to roughly 600 m ahead at zoom 500,
         so this one is plainly ON the panel and must be placed where it
         projects, undimmed. Index 5 is 1.5 km away and cannot be on the panel
         at any heading, so it must be clamped to the 5.9rem rim and dimmed.
         Index 4 carries a name so the LABEL (.mml) shares the check -- icon and
         label read the same clip flag and must agree about it. */
      { x: AHEAD_ON[0],  y: AHEAD_ON[1],  kind: 'gas',  name: 'FAR350' },
      { x: OFF_PANEL[0], y: OFF_PANEL[1], kind: 'shop', name: 'OFF1500' },
    ],
  },
};

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

/* `reentryProbe` arms RUN 3's one-shot: the moment the page asks for grid3d.js
   -- which is INSIDE m3Boot, after it set its in-flight flag and before the
   first .then -- fire three webglcontextrestored events at the canvas and
   measure, synchronously, whether any of them started a second boot. Doing it
   from inside the fetch stub is what makes the test deterministic: there is no
   window to miss and no timing to lose to the environment. */
async function boot(assets, reentryProbe) {
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

  await page.evaluateOnNewDocument((assets, reentryProbe) => {
    let s = 1234567;
    Math.random = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };

    /* THE INSTRUMENT FOR ASSERTION 3. Count SCHEDULES, not callbacks: a panel
       that never goes still is a panel that never stops ASKING for a frame.
       Installed before any page script runs, so nothing can slip past it. M3 is
       the only caller of requestAnimationFrame in hud.html and in webui.js (grep
       both), so this counter measures the 3D panel and nothing else. */
    window.__rafCount = 0;
    const _raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = function (cb) { window.__rafCount++; return _raf(cb); };

    window.__assetHits = [];
    window.A3API = {
      RequestFile: (p) => {
        window.__assetHits.push(p);
        const n = () => window.__assetHits.filter((h) => h === p).length;
        if (reentryProbe && p === 'ui\\html\\grid3d.js' && !window.__reFired) {
          window.__reFired = true;
          const cv = document.getElementById('mgl');
          window.__reCaught = !!(window.M3 && window.M3.booting && !window.M3.R);
          const b0 = n();
          for (let i = 0; i < 3; i++) cv.dispatchEvent(new Event('webglcontextrestored'));
          window.__reDelta = n() - b0;      // extra boots those events started
        }
        if (!Object.prototype.hasOwnProperty.call(assets, p))
          return Promise.reject(new Error('no such file: ' + p));
        return Promise.resolve(assets[p]);
      },
      SendAlert:   (msg) => { (window.__alerts = window.__alerts || []).push(msg); },
      SendConfirm: ()    => Promise.resolve(false),
      RequestTexture: (p, sz) => new Promise((res) => {
        const m = /s_(\d+)_(\d+)/.exec(p);
        const c = m ? +m[1] : 0, r = m ? +m[2] : 0;
        const cv = document.createElement('canvas'); cv.width = cv.height = sz || 128;
        const g = cv.getContext('2d');
        g.fillStyle = `rgb(${30 + (c * 7) % 60},${40 + (r * 11) % 60},${35 + ((c + r) * 5) % 50})`;
        g.fillRect(0, 0, cv.width, cv.height);
        g.strokeStyle = 'rgba(245,166,35,.15)'; g.strokeRect(0.5, 0.5, cv.width - 1, cv.width - 1);
        res(cv.toDataURL());
      }),
    };
  }, assets, !!reentryProbe);

  await page.goto('file://' + path.join(HTML, 'hud.html'), { waitUntil: 'load' });
  // The bridge is what the page is pushed through; nothing can be fed until it lands.
  await page.waitForFunction('!!window.WEBUI', { timeout: 15000 }).catch(() => {});
  return { browser, page, errors };
}

// Push through the page's OWN bus. WEBUI._emit(channel, base64) is the exact
// entry point SQF's ExecJS uses, so this exercises the real handler path --
// webui.js's decode, its last-value cache and its per-handler try/catch -- and
// not some shortcut into the page's internals.
const push = (page, ch, payload) => page.evaluate((ch, p) => {
  window.WEBUI._emit(ch, btoa(unescape(encodeURIComponent(JSON.stringify(p)))));
}, ch, payload);

/* ---- RUN 1: the 3D path -------------------------------------------------- */
async function run3d() {
  const A = await boot(FULL_ASSETS);
  await A.page.waitForFunction('window.M3 && window.M3.ready', { timeout: 25000 })
    .catch(() => {});

  /* Arm a ONE-SHOT probe on the next frame. drawBuildings is the last draw call
     in m3Draw, so this runs with the finished frame still in the drawing buffer
     -- the only moment it can be read, since preserveDrawingBuffer is false (as
     it is on the full map). Reading the framebuffer, not screenshotting the
     element, is the honest answer to "did the panel draw anything": a screenshot
     is at the mercy of when the compositor last presented.
     ONE shot, not every frame: a 208² readPixels stalls the pipeline hard enough
     to distort the very rAF timing assertion 3 measures. */
  await A.page.evaluate(() => {
    window.__lastBld = null; window.__pix = null; window.__frames = 0;
    if (!window.M3 || !window.M3.R) return;
    const inner = window.M3.R.drawBuildings;
    window.M3.R.drawBuildings = function () {
      const r = inner.apply(this, arguments);
      window.__lastBld = r; window.__frames++;
      if (!window.__pix) {
        const gl = window.M3.gl, w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
        if (w && h) {
          const buf = new Uint8Array(w * h * 4);
          gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, buf);
          const seen = new Set(); let sum = 0, mx = 0;
          for (let i = 0; i < buf.length; i += 4) {
            const k = (buf[i] << 16) | (buf[i + 1] << 8) | buf[i + 2];
            if (seen.size < 4096) seen.add(k);
            const l = buf[i] + buf[i + 1] + buf[i + 2];
            sum += l; if (l > mx) mx = l;
          }
          window.__pix = { w, h, colours: seen.size,
                           meanLum: +(sum / (w * h * 3)).toFixed(2), maxLum: +(mx / 3).toFixed(1) };
        }
      }
      return r;
    };
  });

  await push(A.page, 'hud', HUD_PAYLOAD);
  await sleep(1200);

  /* THE ASSERTION THE BUG THIS TASK FIXES WOULD HAVE FAILED. Task 4 shipped the
     chase camera and left the blips positioned by a flat top-down offset that
     only agreed with the tilted camera near the panel centre -- nothing caught
     that, which is the whole reason it shipped. This reads the FIRST mark
     (HUD_PAYLOAD.map.marks[0], 144 m from the player and well inside the rim
     whichever way the rim is measured, so it is never rim-clamped) two
     independent ways:
     window.M3.R.project() for where that world point actually falls on the GL
     canvas, converted to a page pixel via the canvas element's own
     getBoundingClientRect(); and the live DOM ".mm" span's own
     getBoundingClientRect() centre, i.e. what the page actually drew. A flat
     top-down placement and a projected one diverge by tens of pixels at this
     distance and heading (34 deg, well off both axes) -- verified by reverting
     the hud.html half of the fix and re-running this harness; see the commit /
     task-4-report.md for that run. */
  const projCheck = await A.page.evaluate((mark) => {
    const M3 = window.M3, R = M3 && M3.R;
    if (!R || !M3.ready) return { reason: 'not ready' };
    const p = R.project(mark.x, mark.y, 2);
    if (!p) return { reason: 'projected null (behind camera)', p: null };
    const cv = document.getElementById('mgl');
    const rect = cv.getBoundingClientRect();
    const vw = M3.gl.drawingBufferWidth, vh = M3.gl.drawingBufferHeight;
    const expected = { x: rect.left + p[0] / vw * rect.width,
                        y: rect.top + p[1] / vh * rect.height };
    const mm = document.querySelectorAll('#mmarks .mm')[0];
    if (!mm) return { reason: 'no .mm element', p, expected };
    const r2 = mm.getBoundingClientRect();
    const actual = { x: (r2.left + r2.right) / 2, y: (r2.top + r2.bottom) / 2 };
    return { p, expected, actual, dx: actual.x - expected.x, dy: actual.y - expected.y };
  }, HUD_PAYLOAD.map.marks[0]);

  /* THE RIM CLAMP (assertions 2g / 2h). The clip test decides two things at
     once -- whether a mark is dimmed, and whether it is dragged out to the
     5.9rem rim instead of being drawn where it belongs -- and it was being
     decided in WORLD METRES (d > R/k) while the offset came from the
     perspective projection. Those are only the same question for a flat
     top-down placement: measured on the shipped math, a mark 228 m ahead
     snapped to the rim while the panel was still drawing ground 600 m ahead.
     So both halves are asserted, from the DOM the page actually produced:
       - marks[4], 350 m ahead and plainly on the panel, must NOT be dimmed and
         must sit where R.project() puts it (same two-independent-sources method
         as 2f, plus its label);
       - marks[5], 1.5 km away, must STILL be dimmed and pinned to the rim.
     Distances are reported in rem off #mmarks' own centre, which is the origin
     `left:calc(50% + Nrem)` is resolved against, so the rim radius the page was
     asked for and the one it drew are directly comparable. */
  const rimCheck = await A.page.evaluate((marks) => {
    const M3 = window.M3, R = M3 && M3.R;
    if (!R || !M3.ready) return { reason: 'not ready' };
    const rem = parseFloat(getComputedStyle(document.documentElement).fontSize);
    const mkr = document.getElementById('mmarks').getBoundingClientRect();
    const c = { x: (mkr.left + mkr.right) / 2, y: (mkr.top + mkr.bottom) / 2 };
    const cv = document.getElementById('mgl').getBoundingClientRect();
    const vw = M3.gl.drawingBufferWidth, vh = M3.gl.drawingBufferHeight;
    const mid = (e) => { const r = e.getBoundingClientRect();
      return { x: (r.left + r.right) / 2, y: (r.top + r.bottom) / 2 }; };
    const rad = (q) => +(Math.hypot(q.x - c.x, q.y - c.y) / rem).toFixed(3);
    const els = document.querySelectorAll('#mmarks .mm');
    const read = (i, mark) => {
      if (!els[i]) return { reason: 'no .mm[' + i + ']' };
      const a = mid(els[i]), p = R.project(mark.x, mark.y, 2);
      const exp = p ? { x: cv.left + p[0] / vw * cv.width,
                        y: cv.top  + p[1] / vh * cv.height } : null;
      return { dim: els[i].className.indexOf('dim') >= 0, drawnRem: rad(a),
               projRem: exp ? rad(exp) : null,
               dx: exp ? +(a.x - exp.x).toFixed(2) : null,
               dy: exp ? +(a.y - exp.y).toFixed(2) : null };
    };
    const lab = {};
    document.querySelectorAll('#mmarks .mml').forEach((l) => {
      lab[l.textContent] = { dim: l.className.indexOf('dim') >= 0, drawnRem: rad(mid(l)) };
    });
    return { rem: rem, on: read(4, marks[4]), off: read(5, marks[5]), labels: lab };
  }, HUD_PAYLOAD.map.marks);

  // A burst on the fast lane, at the real 12 Hz push rate, walking north-east.
  const rafBefore = await A.page.evaluate(() => window.__rafCount);
  for (let i = 1; i <= 24; i++) {
    await push(A.page, 'hudmap', {
      pos: [START[0] + i * 6, START[1] + i * 4],
      dir: (34 + i * 1.5) % 360,
    });
    await sleep(83);
  }
  const rafAfterBurst = await A.page.evaluate(() => window.__rafCount);

  /* Let every in-flight satellite tile and every follow-up frame the renderer
     asked for drain, THEN start measuring stillness. Without this drain the test
     would be flaky rather than strict: an arriving tile legitimately asks for
     one more frame, and that is the system working. */
  await sleep(2000);
  const rafIdle0 = await A.page.evaluate(() => window.__rafCount);
  await sleep(3000);
  const rafIdle1 = await A.page.evaluate(() => window.__rafCount);

  const probe = await A.page.evaluate(() => {
    const M3 = window.M3, R = M3 && M3.R;
    return {
      ready: !!(M3 && M3.ready), on: !!(M3 && M3.on), raf: M3 ? M3.raf : null,
      lostCount: M3 ? (M3.lost || 0) : null,
      hasR: !!R, contextLost: !!(M3 && M3.gl && M3.gl.isContextLost()),
      hf: R && R.hf ? { n: R.hf.n, cell: R.hf.cell } : null,
      terr: R && R.terr ? { ni: R.terr.ni, grid: R.terr.grid, vbo: !!R.terr.vbo } : null,
      water: R && R.water ? { vbo: !!R.water.vbo } : null,
      bldCount: R ? R.bldCount : null,
      sectors: R && R.sectors ? R.sectors.length : null,
      sectorsM: R ? (R.sectorsM ? R.sectorsM.length : null) : undefined,
      meshes: R ? (R.meshes ? Object.keys(R.meshes).length : null) : undefined,
      lastBld: window.__lastBld, pix: window.__pix, frames: window.__frames,
      mapClass: document.getElementById('map').className,
      mglClass: document.getElementById('mgl').className,
      blips: document.querySelectorAll('#mmarks .mm').length,
      tiles2d: document.querySelectorAll('#mtiles img').length,
      bootErr: window.__apBootErr || null,
      handlerErr: window.__apHandlerErr || null,
      assetHits: window.__assetHits,
    };
  });

  return { A, probe, projCheck, rimCheck,
           raf: { before: rafBefore, afterBurst: rafAfterBurst,
                  idle0: rafIdle0, idle1: rafIdle1 } };
}

let run = await run3d(), attempts = 1;
while (run.probe.contextLost && attempts < 3) {
  await run.A.browser.close();
  attempts++;
  run = await run3d();
}
const { A, probe, projCheck, rimCheck, raf } = run;

await A.page.screenshot({ path: path.join(HERE, label + '.png') });
const panel = await A.page.$('#mapwrap');
if (panel) await panel.screenshot({ path: path.join(HERE, label + '-panel.png') });

const results = [];
const check = (name, ok, detail) => { results.push({ name, ok: !!ok, detail }); return !!ok; };

check('0. the GL context survived the run (environment, not the page)',
      !probe.contextLost, 'attempts=' + attempts + ' lost=' + probe.contextLost);
check('1. boots with zero page errors and zero console errors', A.errors.length === 0,
      A.errors.length ? A.errors.join(' | ') : 'none');
/* A context loss during the run is the ENVIRONMENT (see the header). The page
   is required to come back from it and to stop claiming to be broken once it
   has -- which is exactly what this asserts, since __apBootErr is cleared only
   on a successful re-boot. The loss count is printed either way. */
check('1b. no boot error and no push-handler error left standing',
      !probe.bootErr && !probe.handlerErr,
      'bootErr=' + probe.bootErr + ' handlerErr=' + probe.handlerErr
        + ' contextLosses=' + probe.lostCount);
check('1c. never fetched the mesh library (boxes only, by design)',
      !probe.assetHits.includes('ui\\html\\malden_msh.txt') && probe.meshes === null,
      'hits=' + JSON.stringify(probe.assetHits) + ' meshes=' + probe.meshes);
check('2. the renderer instance is readable through the page', probe.hasR && probe.ready,
      'hasR=' + probe.hasR + ' ready=' + probe.ready + ' hf=' + JSON.stringify(probe.hf));
check('2b. terrain present', !!(probe.terr && probe.terr.vbo && probe.terr.ni > 0),
      JSON.stringify(probe.terr) + ' water=' + JSON.stringify(probe.water));
check('2c. building count > 0 -- DRAWN, not merely parsed',
      !!(probe.lastBld && probe.lastBld.bldDrawn > 0),
      JSON.stringify(probe.lastBld) + ' of bldCount ' + probe.bldCount
        + ' in ' + probe.sectors + ' box sectors');
check('2d. the framebuffer holds an image, not a flat clear',
      !!(probe.pix && probe.pix.colours > 50 && probe.pix.maxLum > 20),
      JSON.stringify(probe.pix) + ' frames=' + probe.frames);
check('2e. panel is in 3D and the blips are still DOM over the canvas',
      probe.mapClass.indexOf('is3d') >= 0 && probe.mglClass.indexOf('on') >= 0
        && probe.blips > 0,
      'map="' + probe.mapClass + '" mgl="' + probe.mglClass + '" blips=' + probe.blips);
check('2f. a known blip lands where its world point actually projects',
      !!(projCheck && projCheck.actual
        && Math.abs(projCheck.dx) <= 3 && Math.abs(projCheck.dy) <= 3),
      JSON.stringify(projCheck));
/* 2g and 2h are the two halves of ONE rule and both must be asserted. "It got
   clamped" is worthless without "and this one did not", because a clip test
   that fires on everything passes the first check and ruins the panel. */
check('2g. a mark the panel still SHOWS is not rim-clamped, and sits where it projects',
      !!(rimCheck && rimCheck.on && !rimCheck.on.reason && !rimCheck.on.dim
        && rimCheck.on.projRem !== null && rimCheck.on.projRem < 5.9
        && Math.abs(rimCheck.on.dx) <= 3 && Math.abs(rimCheck.on.dy) <= 3
        && rimCheck.labels && rimCheck.labels.FAR350 && !rimCheck.labels.FAR350.dim),
      '350 m ahead: ' + JSON.stringify(rimCheck && rimCheck.on)
        + ' label=' + JSON.stringify(rimCheck && rimCheck.labels && rimCheck.labels.FAR350));
check('2h. a mark genuinely off the panel IS still clamped to the rim and dimmed',
      !!(rimCheck && rimCheck.off && !rimCheck.off.reason && rimCheck.off.dim
        && Math.abs(rimCheck.off.drawnRem - 5.9) <= 0.25),
      '1.5 km east: ' + JSON.stringify(rimCheck && rimCheck.off)
        + ' rem=' + (rimCheck && rimCheck.rem));
check('3. rAF CLIMBS while pushes land (proves the instrument is live)',
      raf.afterBurst > raf.before, raf.before + ' -> ' + raf.afterBurst + ' over 24 pushes');
check('3b. IDLE IS STILL: rAF stops climbing once the pushes stop',
      raf.idle1 === raf.idle0,
      raf.idle0 + ' -> ' + raf.idle1 + ' over 3s idle (M3.raf=' + probe.raf + ')');
await A.browser.close();

/* ---- RUN 2: the module cannot load -- the 2D panel must still be there ---- */
const NO_MODULE = Object.assign({}, FULL_ASSETS);
delete NO_MODULE['ui\\html\\grid3d.js'];
const B = await boot(NO_MODULE);
await push(B.page, 'hud', HUD_PAYLOAD);
await sleep(2500);
const fallback = await B.page.evaluate(() => ({
  ready: !!(window.M3 && window.M3.ready),
  bootErr: window.__apBootErr || null,
  mapClass: document.getElementById('map').className,
  mglClass: document.getElementById('mgl').className,
  tiles: document.querySelectorAll('#mtiles img').length,
  tilesWithSrc: Array.prototype.filter.call(
    document.querySelectorAll('#mtiles img'), i => i.src && i.src.length > 128).length,
  water: (() => { const c = document.getElementById('mwater');
    const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
    let n = 0; for (let i = 3; i < d.length; i += 4) if (d[i]) n++; return n; })(),
  blips: document.querySelectorAll('#mmarks .mm').length,
  raf: window.__rafCount,
}));
await B.page.screenshot({ path: path.join(HERE, label + '-fallback.png') });
const fbPanel = await B.page.$('#mapwrap');
if (fbPanel) await fbPanel.screenshot({ path: path.join(HERE, label + '-fallback-panel.png') });
check('4. 3D off -> the 2D tile panel still renders',
      !fallback.ready && fallback.mapClass.indexOf('is3d') < 0
        && fallback.mglClass.indexOf('on') < 0
        && fallback.tilesWithSrc > 0 && fallback.blips > 0,
      JSON.stringify(fallback));
check('4b. the failure said why (the in-game console is unreachable)',
      !!fallback.bootErr, String(fallback.bootErr));
check('4c. no page or console errors on the fallback path either',
      B.errors.length === 0, B.errors.length ? B.errors.join(' | ') : 'none');
await B.browser.close();

/* ---- RUN 3: a restore landing mid-boot must not start a SECOND boot ------- */
/* m3Boot's re-entry guard used to be `if (M3.R) return`, and M3.R is not
   assigned until two async hops in -- so a webglcontextrestored arriving during
   the fetch re-entered it and ran the whole boot again: two create()s, two
   initAtlases(), two loadHF/buildTerrain/loadBuildings, and every asset pulled
   twice, on a layer that never closes and therefore never gives the orphans
   back. The probe (see boot()) drives the REAL path -- the canvas's own
   restored listener, not m3Boot directly -- three times from INSIDE the
   grid3d.js fetch, i.e. at the exact instant the guard has to hold, and counts
   the extra fetches those three events caused, synchronously.
   Measuring a DELTA across the three dispatches, in one synchronous block, is
   what makes this immune to the environment: a SwiftShader context loss later
   in the run is a real second boot and a correct one, and would have made a
   total fetch count meaningless. Guarded: delta 0. Unguarded: delta 3.
   __reCaught is asserted too -- "no second boot happened" proves nothing if
   the first boot was not actually in flight when the events landed. */
const C = await boot(FULL_ASSETS, true);
await C.page.waitForFunction('window.M3 && window.M3.ready', { timeout: 25000 }).catch(() => {});
await push(C.page, 'hud', HUD_PAYLOAD);
await sleep(1200);
const reentry = await C.page.evaluate(() => ({
  caught: window.__reCaught === true, delta: window.__reDelta,
  lost: (window.M3 && window.M3.lost) || 0,
  ready: !!(window.M3 && window.M3.ready), booting: !!(window.M3 && window.M3.booting),
  mapClass: document.getElementById('map').className,
  bootErr: window.__apBootErr || null,
}));
check('5. a webglcontextrestored landing MID-BOOT does not start a second boot',
      reentry.caught && reentry.delta === 0 && reentry.ready && !reentry.booting
        && reentry.mapClass.indexOf('is3d') >= 0,
      JSON.stringify(reentry));
check('5b. no page or console errors on the re-entry path either',
      C.errors.length === 0, C.errors.length ? C.errors.join(' | ') : 'none');
await C.browser.close();

/* ---- verdict ------------------------------------------------------------- */
const out = { label, attempts, raf, errors: A.errors, fallbackErrors: B.errors,
              reentryErrors: C.errors, probe, projCheck, rimCheck, fallback,
              reentry: reentry, results };
fs.writeFileSync(path.join(HERE, label + '.json'), JSON.stringify(out, null, 2));
results.forEach(r => console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name}\n        ${r.detail}`));
const bad = results.filter(r => !r.ok).length;
console.log(`\n${results.length - bad}/${results.length} assertions passed`
            + (attempts > 1 ? `  (3D run took ${attempts} attempts: the environment lost the GL context)` : ''));
process.exit(bad === 0 ? 0 : 1);
