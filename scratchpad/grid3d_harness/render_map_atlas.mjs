// Offline harness for the ATLAS path of MALDEN GRID (ui/html/map.html).
//
//   node scratchpad/grid3d_harness/render_map_atlas.mjs
//
// Writes atlas.png / atlas.json beside this file and prints a PASS/FAIL line per
// assertion. Exits non-zero if any assertion fails.
//
// WHY THIS IS NOT render_map.mjs. That harness serves NEITHER composed atlas, so
// the page's RequestFile for them rejects and it takes the per-tile path; its
// "png byte-identical to baseline" is therefore the FALLBACK gate, and it has to
// stay byte-identical, which means it can never exercise the thing being built.
// This one serves both atlases and asserts absolutes about the path that only
// exists when they are there.
//
//   1. both stages are stamped: [MAPTIME] atlas128 and atlas256;
//   2. ZERO A3API.RequestTexture calls at 128 and at 256 -- the whole point. The
//      stub records every call's size; only the hero window (>= 512) may still
//      ask, and only once the camera is pinned close enough to want one.
//      READ THIS BEFORE READING A RESULT: the 128 tier never cost an engine round
//      trip on map.html anyway. The page carries all 169 thumbnails inline as
//      window.EMB and the pump answers a 128 want from them, so 128 costs 169
//      base64 decodes and 169 cell uploads, not 169 fetches; the 76 calls at 256
//      are the only engine traffic the satellite layer ever generated here. So
//      "zero at 128" is about main-thread work and "zero at 256" is about round
//      trips, and 4d/4e below are what actually prove each tier came as one image;
//   3. each tier arrives as ONE image: sampled continuously from boot, the number
//      of cells present at a tier is only ever 0 or 169, never a count climbing
//      through the middle, and R.tiles.count() is 169 per tier;
//   4. the settled frame is real imagery: NOT byte-identical to baseline.png
//      (which is the stub's flat per-tile colours) and not a flat clear either --
//      readPixels over the drawing buffer has to show a picture;
//   5. a WRONG-SIZE atlas is rejected and the page falls back cleanly, in both
//      places it can happen: a bad 128 (nothing is served from an atlas, every
//      tier goes per-tile, and the 256 atlas is never even fetched) and a bad 256
//      after a good 128 (the wide layer is still one image, the close tier goes
//      per-tile). No page errors either time, and tiles still arrive.
//
// Same puppeteer path, same SwiftShader flags, same seeded Math.random, same real
// assets and the same pinned camera and timings as render_map.mjs, deliberately --
// two harnesses disagreeing about the environment is a bug factory, and assertion
// 4 compares against a png that harness produced.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE    = new URL('.', import.meta.url).pathname;
const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const HTML    = path.join(MISSION, 'ui/html');

const baseAssets = {
  'ui\\html\\malden_hf.txt':  fs.readFileSync(path.join(HTML, 'malden_hf.txt'),  'utf8'),
  'ui\\html\\malden_bld.txt': fs.readFileSync(path.join(HTML, 'malden_bld.txt'), 'utf8'),
  'ui\\html\\malden_msh.txt': fs.readFileSync(path.join(HTML, 'malden_msh.txt'), 'utf8'),
  'ui\\html\\malden_fen.txt': fs.readFileSync(path.join(HTML, 'malden_fen.txt'), 'utf8'),
  'ui\\html\\grid3d.js':      fs.readFileSync(path.join(HTML, 'grid3d.js'),      'utf8'),
  'webui\\ui\\webui.js':      fs.readFileSync(path.join(MISSION, 'webui/ui/webui.js'), 'utf8'),
};
const SAT = {
  128: fs.readFileSync(path.join(HTML, 'malden_sat128.txt'), 'utf8'),
  256: fs.readFileSync(path.join(HTML, 'malden_sat256.txt'), 'utf8'),
};

/* A deliberately WRONG-SIZE atlas, built here rather than committed: a solid
   PNG of `size` square, which is what a stylized drop-in re-encoded at the wrong
   scale looks like to the page. Hand-rolled because this harness has no image
   library and does not want one; zlib is stdlib and a PNG is four chunks. */
function crc32(buf) {
  let c, t = crc32._t;
  if (!t) { t = crc32._t = new Int32Array(256);
    for (let n = 0; n < 256; n++) { c = n;
      for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
      t[n] = c; } }
  c = -1;
  for (let i = 0; i < buf.length; i++) c = t[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function flatPng(size, rgb) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;   // 8-bit truecolour
  const row = Buffer.alloc(1 + size * 3);
  for (let x = 0; x < size; x++) { row[1 + x*3] = rgb[0]; row[2 + x*3] = rgb[1]; row[3 + x*3] = rgb[2]; }
  const raw = Buffer.concat(new Array(size).fill(row));
  const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),
                             chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)),
                             chunk('IEND', Buffer.alloc(0))]);
  return 'data:image/png;base64,' + png.toString('base64') + '\n';
}

/* One page load. `sat` says what each tier's asset file contains, or omits it
   entirely (an older PBO). Everything else is render_map.mjs's environment. */
async function run(sat, wantShot) {
  const assets = Object.assign({}, baseAssets);
  for (const res of [128, 256]) if (sat[res]) assets['ui\\html\\malden_sat' + res + '.txt'] = sat[res];

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
    window.__texHits = [];            // {p, sz} for every RequestTexture -- assertion 2
    /* Assertion 3 wants "how many cells were present at each tier, at every
       moment", not just at the end: a tier that arrived as one image only ever
       reads 0 or 169, while a per-tile tier walks up through the middle. A
       millisecond poll cannot miss a synchronous 0 -> 169 step, and it is the
       INTERMEDIATE readings that would fail this, so a coarse sampler is the
       conservative direction. */
    window.__tierSeen = { 128: {}, 256: {} };
    /* EVERY IMAGE THE PAGE DECODES, by src. The sampler above cannot separate
       "one atlas" from "169 thumbnails" on its own: the EMB branch of the pump
       fires all 169 Image loads in one burst with no in-flight limit, and the
       browser drains that whole task queue without ever servicing a 1 ms timer,
       so both paths read 0 then 169 and nothing in between. This does not
       sample -- it records. Cross-referenced against window.EMB's own values in
       the probe, it says exactly how many cells were decoded one at a time,
       which is the quantity this change exists to move. */
    window.__imgSrcs = [];
    var NativeImage = window.Image;
    window.Image = function (w, h) {
      var im = new NativeImage(w, h);
      Object.defineProperty(im, 'src', {
        configurable: true,
        get: function () { return im.getAttribute('src') || ''; },
        set: function (v) { window.__imgSrcs.push(String(v)); im.setAttribute('src', v); }
      });
      return im;
    };
    window.Image.prototype = NativeImage.prototype;
    setInterval(() => {
      const R = window.R;
      if (!R || !R.tiles || !R.tiles.have) return;
      let n128 = 0, n256 = 0;
      for (const k in R.tiles.have) {
        if (k.slice(-4) === '_128') n128++; else if (k.slice(-4) === '_256') n256++;
      }
      window.__tierSeen[128][n128] = 1; window.__tierSeen[256][n256] = 1;
    }, 1);

    window.A3API = {
      RequestFile: (p) => {
        window.__assetHits.push(p);
        return Object.prototype.hasOwnProperty.call(assets, p)
          ? Promise.resolve(assets[p])
          : Promise.reject(new Error('no such file: ' + p));
      },
      SendAlert: (msg) => {
        (window.__alerts = window.__alerts || []).push(msg);
        try {
          const m = JSON.parse(msg);
          if (Array.isArray(m) && m[0] === 'CALL' && m[2] === 'log' && window.WEBUI && window.WEBUI._resolve) {
            const b64 = btoa(unescape(encodeURIComponent(JSON.stringify({ ok: true, msg: '' }))));
            setTimeout(() => window.WEBUI._resolve(m[1], true, b64), 0);
          }
        } catch (e) {}
      },
      SendConfirm: () => Promise.resolve(false),
      RequestTexture: (p, sz) => new Promise((res) => {
        window.__texHits.push({ p, sz });
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
  await new Promise(r => setTimeout(r, 9000));

  // Read the tier state BEFORE the camera moves: a close camera wants the hero
  // window, whose 1024 tiles would land in tilesHave and muddy the tier counts.
  const probe = await page.evaluate(() => {
    const R = window.R;
    const tiers = (res) => {
      let n = 0;
      if (R && R.tiles && R.tiles.have) for (const k in R.tiles.have) if (k.slice(-(String(res).length+1)) === '_' + res) n++;
      return n;
    };
    return {
      stages: window.MT ? JSON.parse(JSON.stringify(window.MT.st)) : null,
      sizes:  window.MT ? JSON.parse(JSON.stringify(window.MT.sz)) : null,
      count:  (R && R.tiles) ? R.tiles.count() : null,
      busy:   (R && R.tiles) ? R.tiles.busy()  : null,
      have128: tiers(128), have256: tiers(256),
      seen128: Object.keys(window.__tierSeen[128]).map(Number).sort((a, b) => a - b),
      seen256: Object.keys(window.__tierSeen[256]).map(Number).sort((a, b) => a - b),
      texAt: window.__texHits.reduce((o, h) => { o[h.sz] = (o[h.sz] || 0) + 1; return o; }, {}),
      satErr: window.__apSatAtlasErr || null,
      bootErr: window.__apBootErr || null,
      embCount: window.EMB ? Object.keys(window.EMB).length : 0,
      imgs: window.__imgSrcs.length,
      imgsFromEmb: (function () {
        const set = new Set(Object.values(window.EMB || {}));
        return window.__imgSrcs.filter(s => set.has(s)).length;
      })(),
      assetHits: window.__assetHits,
      loadingText: (document.getElementById('loading') || {}).textContent ?? null,
      loadingShown: (function () { const l = document.getElementById('loading');
        return l ? l.style.display !== 'none' : null; })(),
    };
  });

  // Pin the camera exactly as render_map.mjs does, so the shot is comparable.
  await page.evaluate(() => {
    if (typeof cam !== 'undefined') {
      cam.x = 7130; cam.y = 7909; cam.dist = 1800; cam.yaw = 0.6; cam.pitch = 0.9;
      if (typeof camClamp === 'function') camClamp();
    }
    if (typeof env !== 'undefined') { env.hour = 12; env.overcast = 0; }
    if (typeof dirty === 'function') dirty();
  });
  await new Promise(r => setTimeout(r, 2500));

  /* Assertion 4's second half. A screenshot cannot tell "an island" from "a flat
     fill of some other colour", so draw one more frame and read the buffer back
     in the SAME task -- the drawing buffer is intact until the next composite. */
  const frame = await page.evaluate(() => {
    draw(performance.now());
    const w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
    const px = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, px);
    const clr = [Math.round(R.FOG[0]*255), Math.round(R.FOG[1]*255), Math.round(R.FOG[2]*255)];
    const seen = {}; let colors = 0, nonClear = 0, n = 0;
    for (let y = 0; y < h; y += 4) for (let x = 0; x < w; x += 4) {
      const i = (y*w + x)*4, key = (px[i]<<16) | (px[i+1]<<8) | px[i+2];
      if (!seen[key]) { seen[key] = 1; colors++; }
      if (Math.abs(px[i]-clr[0]) > 3 || Math.abs(px[i+1]-clr[1]) > 3 || Math.abs(px[i+2]-clr[2]) > 3) nonClear++;
      n++;
    }
    return { w, h, colors, nonClear, sampled: n };
  });
  probe.frame = frame;
  probe.texAtEnd = await page.evaluate(() =>
    window.__texHits.reduce((o, h) => { o[h.sz] = (o[h.sz] || 0) + 1; return o; }, {}));

  if (wantShot) await page.screenshot({ path: path.join(HERE, wantShot + '.png') });
  await browser.close();
  return { errors, probe };
}

/* ---------------------------------------------------------------- assertions */
let bad = 0;
const T = (ok, name, detail) => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '  -- ' + detail : ''}`);
  if (!ok) bad++;
};
const only = (arr, allowed) => arr.every(v => allowed.indexOf(v) >= 0);
/* A rejected atlas is SUPPOSED to say so on the console -- that is the page's
   only diagnostic channel in game, and applyFeed has logged its own failures the
   same way since the mesh library was split out. So "clean" for a fallback run
   means: no pageerror at all, and no console error other than that one notice. */
const cleanExcept = (errs, res) => errs.every(e =>
  e.indexOf('console: sat atlas ' + res + ' unusable, per-tile path') === 0);

console.log('== run 1: both atlases served ==');
const A = await run({ 128: SAT[128], 256: SAT[256] }, 'atlas');
fs.writeFileSync(path.join(HERE, 'atlas.json'), JSON.stringify(A, null, 2));

T(A.errors.length === 0, '1a  no page or console errors', JSON.stringify(A.errors));
T(A.probe.bootErr === null, '1b  no boot error', String(A.probe.bootErr));
T(A.probe.satErr === null, '1c  no atlas rejection', String(A.probe.satErr));
T(A.probe.stages && A.probe.stages.atlas128 != null,
  '2a  [MAPTIME] atlas128 stamped', 'atlas128=' + (A.probe.stages || {}).atlas128 + 'ms');
T(A.probe.stages && A.probe.stages.atlas256 != null,
  '2b  [MAPTIME] atlas256 stamped', 'atlas256=' + (A.probe.stages || {}).atlas256 + 'ms');
T(A.probe.stages && A.probe.stages.tile1 != null && A.probe.stages.t256 != null,
  '2c  tile1 and t256 stamped', 'tile1=' + (A.probe.stages || {}).tile1 + ' t256=' + (A.probe.stages || {}).t256);
T(A.probe.stages && A.probe.stages.settled != null,
  '2d  settled stamped', 'settled=' + (A.probe.stages || {}).settled + 'ms');
T(!A.probe.texAtEnd[128], '3a  ZERO RequestTexture at 128', JSON.stringify(A.probe.texAtEnd));
T(!A.probe.texAtEnd[256], '3b  ZERO RequestTexture at 256', JSON.stringify(A.probe.texAtEnd));
T(Object.keys(A.probe.texAtEnd).every(k => +k >= 512),
  '3c  only the hero window (>=512) ever asks the engine', JSON.stringify(A.probe.texAtEnd));
T(A.probe.have128 === 169, '4a  169 cells present at 128', String(A.probe.have128));
T(A.probe.have256 === 169, '4b  169 cells present at 256', String(A.probe.have256));
T(A.probe.count === 338, '4c  R.tiles.count() is 338 (both tiers, nothing else)', String(A.probe.count));
T(only(A.probe.seen128, [0, 169]),
  '4d  the 128 tier was never partly present (one image, not 169)', JSON.stringify(A.probe.seen128));
T(only(A.probe.seen256, [0, 169]),
  '4e  the 256 tier was never partly present', JSON.stringify(A.probe.seen256));
/* What the 128 atlas actually replaces on THIS page. map.html has carried all 169
   thumbnails inline as window.EMB since before this change, so the 128 tier never
   cost an engine round trip -- it cost 169 base64 JPEG decodes and 169 cell
   uploads (plus 169 more for the 256 pre-fill) on the main thread, every open.
   The atlas is one decode and one upload. 4d above is what proves EMB was
   bypassed rather than raced; this records that it was there to bypass. */
T(A.probe.embCount === 169 && A.probe.imgsFromEmb === 0,
  '4g  the 169 embedded thumbnails are still on the page and NONE was decoded',
  A.probe.embCount + ' in window.EMB, ' + A.probe.imgsFromEmb + ' decoded, ' +
  A.probe.imgs + ' images decoded in all, before the camera moved (the two atlases)');
T(A.probe.loadingShown === false, '4f  the loading label was dropped', String(A.probe.loadingText));

const shot = fs.readFileSync(path.join(HERE, 'atlas.png'));
const base = fs.readFileSync(path.join(HERE, 'baseline.png'));
T(Buffer.compare(shot, base) !== 0,
  '5a  settled frame is NOT baseline.png (real imagery, not the stub)',
  `atlas ${shot.length} B vs baseline ${base.length} B`);
T(A.probe.frame.colors > 500,
  '5b  the framebuffer is a picture, not a flat fill',
  `${A.probe.frame.colors} distinct colours over ${A.probe.frame.sampled} samples`);
T(A.probe.frame.nonClear > A.probe.frame.sampled * 0.2,
  '5c  the framebuffer is not a flat clear',
  `${A.probe.frame.nonClear}/${A.probe.frame.sampled} samples differ from the clear colour`);

console.log('\n== run 2: the 128 atlas is served at the WRONG SIZE ==');
const B = await run({ 128: flatPng(13 * 100, [90, 40, 120]), 256: SAT[256] }, null);
T(cleanExcept(B.errors, 128), '6a  clean but for the fallback notice', JSON.stringify(B.errors));
T(B.probe.bootErr === null, '6b  no boot error', String(B.probe.bootErr));
T(/1300x1300/.test(B.probe.satErr || ''),
  '6c  rejected by size, and says so', String(B.probe.satErr));
T(!B.probe.stages.atlas128, '6d  atlas128 NOT stamped', String(B.probe.stages.atlas128));
T(B.probe.assetHits.indexOf('ui\\html\\malden_sat256.txt') < 0,
  '6e  the 256 atlas is never fetched when the 128 one failed');
/* THE PER-TILE 128 PATH ON THIS PAGE IS NOT THE ENGINE. map.html carries all 169
   thumbnails inline as window.EMB (tools/embed_map_thumbs.py), and the pump
   answers a 128 want from them without a RequestTexture -- so the fallback to
   prove here is "the pump served the tier a cell at a time", not "the engine was
   asked". Cell by cell is exactly what the sampler catches part-way, and it is
   what run 1 must NOT show. */
T(B.probe.imgsFromEmb === 169,
  '6f  the per-tile 128 pump took over (169 cells decoded one at a time, from window.EMB)',
  B.probe.imgsFromEmb + '/' + B.probe.embCount + ' thumbnails decoded, ' +
  B.probe.imgs + ' images in total');
T(B.probe.have128 === 169, '6g  the wide layer still fully arrived', String(B.probe.have128));
T(B.probe.stages.settled != null, '6h  it still settles', 'settled=' + B.probe.stages.settled + 'ms');
T(B.probe.frame.colors > 500, '6i  and still draws a picture',
  `${B.probe.frame.colors} distinct colours`);

console.log('\n== run 3: a good 128, the 256 atlas at the WRONG SIZE ==');
const C = await run({ 128: SAT[128], 256: flatPng(13 * 300, [20, 200, 90]) }, null);
T(cleanExcept(C.errors, 256), '7a  clean but for the fallback notice', JSON.stringify(C.errors));
T(/3900x3900/.test(C.probe.satErr || ''),
  '7b  the 256 atlas rejected by size, and says so', String(C.probe.satErr));
T(C.probe.stages.atlas128 != null && !C.probe.stages.atlas256,
  '7c  atlas128 stamped, atlas256 not',
  'atlas128=' + C.probe.stages.atlas128 + ' atlas256=' + C.probe.stages.atlas256);
T(!C.probe.texAtEnd[128] && C.probe.imgsFromEmb === 0,
  '7d  the wide layer is still ONE image (no round trips, no thumbnails)',
  JSON.stringify(C.probe.texAtEnd) + ', ' + C.probe.imgsFromEmb + ' thumbnails decoded');
T(C.probe.texAtEnd[256] > 0, '7e  the per-tile 256 path took over',
  (C.probe.texAtEnd[256] || 0) + ' RequestTexture calls at 256');
T(C.probe.frame.colors > 500, '7f  and still draws a picture',
  `${C.probe.frame.colors} distinct colours`);

console.log(bad === 0 ? '\nATLAS PATH OK' : `\n${bad} ASSERTION FAILURE(S)`);
process.exit(bad === 0 ? 0 : 1);
