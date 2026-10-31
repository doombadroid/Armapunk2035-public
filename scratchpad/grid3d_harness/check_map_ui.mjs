// Chromium checks for the MALDEN GRID interface (ui/html/map.html).
//
//   node scratchpad/grid3d_harness/check_map_ui.mjs [--page path/to/map.html] [--label name]
//
// WHAT THIS PROVES AND WHAT IT DOES NOT. It boots the real page against the real
// baked terrain assets and the real webui bridge, and stands in for SQF with an
// emulator that follows fn_mapOpen.sqf's handler contract exactly: the handler
// pushes mapDest BEFORE it answers, a failed GPS set leaves the prior route in
// place, and so on. The data is game-shaped: all 319 markers from mission.sqm and
// all 53 named places from the engine's own location dump. So it proves layout,
// wiring, state handling and rendering against realistic data. It does NOT prove
// the SQF itself, the embedded browser's input delivery, in-game frame rate, or
// server delivery -- those are in-game checks and are reported separately.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE = new URL('.', import.meta.url).pathname;
const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const HTML = path.join(MISSION, 'ui/html');
const SCR = '/tmp/claude-1000/-home-timb/ddd6c053-6319-4f0c-90ee-605d3bec597f/scratchpad';
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(k); return i >= 0 ? argv[i + 1] : d; };
const PAGE = opt('--page', path.join(HTML, 'map.html'));
const LABEL = opt('--label', 'mapui');
const ONLY_TERRAIN = argv.includes('--terrain-only');

const assets = {};
for (const f of ['malden_hf.txt', 'malden_bld.txt', 'malden_msh.txt', 'malden_fen.txt', 'grid3d.js', 'malden_sat128.txt', 'malden_sat256.txt'])
  assets['ui\\html\\' + f] = fs.readFileSync(path.join(HTML, f), 'utf8');
assets['webui\\ui\\webui.js'] = fs.readFileSync(path.join(MISSION, 'webui/ui/webui.js'), 'utf8');
const MARKUP = fs.readFileSync(PAGE, 'utf8');

// ---- game-shaped feeds ------------------------------------------------------
const sqmMarkers = JSON.parse(fs.readFileSync(path.join(SCR, 'malden_markers.json'), 'utf8'));
const locations = JSON.parse(fs.readFileSync(path.join(SCR, 'malden_locations.json'), 'utf8'));
let territories = [];
try { territories = JSON.parse(fs.readFileSync(path.join(SCR, 'malden_territories.json'), 'utf8')); } catch (_) {}
// What fn_mapOpen's _staticData emits: alpha > 0.05 and (text or type), 500 cap.
const staticMarkers = sqmMarkers.filter(m => m.alpha > 0.05 && (m.text || m.type)).slice(0, 500)
  .map(m => ({ id: m.id, x: m.x, y: m.y, text: m.text, type: m.type, color: m.color, alpha: m.alpha }));
// A player-placed marker that happens to say "WP" -- it must stay listed.
staticMarkers.push({ id: '_USER_DEFINED #2/1/0', x: 7400, y: 7650, text: 'WP', type: 'mil_dot', color: 'ColorYellow', alpha: 1 });
const SELF = { x: 7150, y: 7800, dir: 32, name: 'V', veh: 'none' };
const GROUP = [
  { id: '2:101', name: 'RAZOR', x: 6980, y: 8160, alt: 460, alive: true, leader: true, veh: 'heli', crew: 2 },
  { id: '2:102', name: 'MOTH', x: 7420, y: 7920, alive: true, leader: false, veh: 'none', crew: 1 },
  { id: '2:103', name: 'JINX', x: 7500, y: 7510, alive: false, leader: false, veh: 'none', crew: 1 },
  { id: '2:104', name: 'MOTH', x: 6900, y: 7600, alive: true, leader: false, veh: 'car', crew: 3 },
];
const ENV = { hour: 13.2, overcast: 0.15 };

const browser = await puppeteer.launch({
  headless: 'new',
  args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader', '--no-sandbox', '--disable-lcd-text', '--force-device-scale-factor=1'],
});

const results = [];
const check = (name, pass, detail) => { results.push({ name, pass: !!pass, detail: detail === undefined ? '' : detail }); };
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function openPage(w, h, { reduced = false, pushFirst = true } = {}) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await page.setViewport({ width: w, height: h, deviceScaleFactor: 1 });
  if (reduced) await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  await page.evaluateOnNewDocument((assets) => {
    let s = 1234567;
    Math.random = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    const b64 = v => btoa(unescape(encodeURIComponent(JSON.stringify(v))));
    // ---- the SQF stand-in: fn_mapOpen.sqf's handler contract, verbatim in shape ----
    const S = window.__sqf = {
      wp: [], dest: [], pts: [], typing: null, calls: [], navFail: false, wpFail: false,
      delay: { mapWaypoint: 0, mapNav: 0 }, tp: [], selfPos: null,
    };
    const push = (ch, v) => { if (window.WEBUI && window.WEBUI._emit) window.WEBUI._emit(ch, b64(v)); };
    // AP_fnc_mapRouteDecimate: ~30 m vertices plus both ends, length over every point
    const decimate = (pts) => { const out = []; let len = 0, last = [-999, -999];
      pts.forEach((p, i) => { if (i > 0) len += Math.hypot(p[0] - pts[i-1][0], p[1] - pts[i-1][1]);
        if (i === 0 || i === pts.length - 1 || Math.hypot(p[0] - last[0], p[1] - last[1]) > 30) { out.push([Math.round(p[0]*10)/10, Math.round(p[1]*10)/10]); last = p; } });
      return [out, len]; };
    const destState = () => { let nav = {};
      if (S.dest.length && S.pts.length) { const [route, len] = decimate(S.pts); nav = { x: S.dest[0], y: S.dest[1], route, len }; }
      return { wp: S.wp.length ? [S.wp[0], S.wp[1]] : [], nav }; };
    S.destState = destState;
    S.pushDest = () => push('mapDest', destState());
    // a stand-in ROAD: dense points along an L through a junction, not a straight line
    const roadTo = (x, y) => { const a = S.selfPos || [7150, 7800], pts = [], j = [x, a[1]];
      const seg = (p, q) => { const n = Math.max(2, Math.ceil(Math.hypot(q[0]-p[0], q[1]-p[1]) / 8));
        for (let i = 0; i < n; i++) pts.push([p[0] + (q[0]-p[0]) * i / n, p[1] + (q[1]-p[1]) * i / n]); };
      seg(a, j); seg(j, [x, y]); pts.push([x, y]); return pts; };
    const handlers = {
      log: () => ({ ok: true, msg: '' }),
      mapTyping: (a) => { S.typing = !!a[0]; return { ok: true }; },
      mapDest: () => destState(),
      mapWaypoint: (a) => {
        if (S.wpFail) { S.pushDest(); return { ok: false, msg: 'Waypoint refused by the test' }; }
        S.wp = a.length ? [a[0], a[1]] : []; S.pushDest(); return { ok: true, msg: '' };
      },
      mapNav: (a) => {
        if (!a.length) { S.dest = []; S.pts = []; S.pushDest(); return { ok: true, msg: 'nav cleared' }; }
        if (S.navFail) { S.pushDest(); return { ok: false, msg: 'no road route found to there' }; }
        S.pts = roadTo(a[0], a[1]); S.dest = [a[0], a[1]];
        const [route, len] = decimate(S.pts); S.pushDest();
        return { ok: true, msg: 'nav set -- ' + (len/1000).toFixed(1) + ' km by road', route, routeLen: len };
      },
      mapTeleport: (a) => { S.tp.push(a); return { ok: true, msg: 'teleported to ' + Math.round(a[0]) + ', ' + Math.round(a[1]) }; },
    };
    window.A3API = {
      RequestFile: (p) => Object.prototype.hasOwnProperty.call(assets, p) ? Promise.resolve(assets[p]) : Promise.reject(new Error('no such file: ' + p)),
      SendAlert: (msg) => {
        let m; try { m = JSON.parse(msg); } catch (e) { return; }
        if (!Array.isArray(m) || m[0] !== 'CALL') return;
        const name = m[2], args = m[3] || [];
        S.calls.push({ name, args: JSON.parse(JSON.stringify(args)), t: performance.now() });
        const h = handlers[name];
        if (!h) return;
        const reply = h(args);                        // the push (if any) happens INSIDE the handler, first
        setTimeout(() => window.WEBUI && window.WEBUI._resolve(m[1], true, b64(reply)), S.delay[name] || 0);
      },
      SendConfirm: () => Promise.resolve(false),
      RequestTexture: (p, sz) => new Promise((res) => {
        const mm = /s_(\d+)_(\d+)/.exec(p), c = mm ? +mm[1] : 0, r = mm ? +mm[2] : 0;
        const cv = document.createElement('canvas'); cv.width = cv.height = sz;
        const g = cv.getContext('2d');
        g.fillStyle = `rgb(${30 + (c * 7) % 60},${40 + (r * 11) % 60},${35 + ((c + r) * 5) % 50})`;
        g.fillRect(0, 0, sz, sz); res(cv.toDataURL());
      }),
    };
    window.__rafCount = 0;
    const raf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (fn) => raf((t) => { window.__rafCount++; fn(t); });
  }, assets);
  await page.goto('file://' + PAGE, { waitUntil: 'load' });
  return { page, errors };
}
async function feeds(page, { self = SELF, group = GROUP, markers = staticMarkers, admin = false } = {}) {
  await page.evaluate((st, lv) => {
    const b64 = v => btoa(unescape(encodeURIComponent(JSON.stringify(v))));
    window.__sqf.selfPos = [lv.self.x, lv.self.y];
    window.WEBUI._emit('mapStatic', b64(st));
    window.WEBUI._emit('map', b64(lv));
    window.__sqf.pushDest();
  }, { markers, locations, cartels: [], territories }, { self, group, env: ENV, ...(admin ? { admin: true, all: [{ name: 'STAFF-SEEN', x: 7300, y: 7700, side: 'civ', veh: 'none' }] } : {}) });
}
const pushMap = (page, lv) => page.evaluate((lv) => {
  const b64 = v => btoa(unescape(encodeURIComponent(JSON.stringify(v))));
  window.__sqf.selfPos = [lv.self.x, lv.self.y];
  window.WEBUI._emit('map', b64(lv));
}, lv);
const rect = (page, sel) => page.evaluate((s) => { const e = document.querySelector(s); if (!e || e.hidden || e.offsetParent === null) return null;
  const r = e.getBoundingClientRect(); return { x: r.left, y: r.top, r: r.right, b: r.bottom, w: r.width, h: r.height }; }, sel);
const inView = (r, w, h) => !!r && r.x >= 0 && r.y >= 0 && r.r <= w && r.b <= h && r.w > 0 && r.h > 0;
const overlap = (a, b) => !!a && !!b && a.x < b.r && a.r > b.x && a.y < b.b && a.b > b.y;
const calls = async (page, name) => (await page.evaluate(() => window.__sqf.calls)).filter(c => !name || c.name === name);
const clearCalls = page => page.evaluate(() => { window.__sqf.calls.length = 0; });
const state = page => page.evaluate(() => ({
  sel: sel ? { key: sel.key, cat: sel.cat, name: sel.name, gone: sel.gone, x: Math.round(sel.x), y: Math.round(sel.y) } : null,
  wp: DEST.wp, nav: DEST.nav ? { x: DEST.nav.x, y: DEST.nav.y, n: DEST.nav.route.length, len: Math.round(DEST.nav.len) } : null,
  busy: { wp: !!busy.wp, nav: !!busy.nav },
  status: document.getElementById('action-status').textContent,
  toast: document.getElementById('map-toast').hidden ? '' : document.getElementById('map-toast').textContent,
  bar: !document.getElementById('destination-bar').hidden,
  cam: { tx: Math.round(cam.tx), ty: Math.round(cam.ty), dist: Math.round(cam.dist), tilt: +(cam.tilt).toFixed(3), yaw: +(cam.yaw).toFixed(3) },
}));
// a screen point for a world position on the overlay canvas (page coordinates)
const screenOf = (page, x, y, lift = 2) => page.evaluate((x, y, lift) => { const p = projW(x, y, lift); if (!p) return null;
  const r = document.getElementById('gl').getBoundingClientRect(); return [p[0] + r.left, p[1] + r.top]; }, x, y, lift);
async function waitSettled(page, ms = 9000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    const ok = await page.evaluate(() => !!(window.R && R.hf && R.bldCount) && document.getElementById('loading').style.display === 'none').catch(() => false);
    if (ok) break;
    await sleep(250);
  }
  await sleep(1200);
}
const terrainProbe = page => page.evaluate(() => ({
  hf: R && R.hf ? R.hf.n : null, bld: R ? R.bldCount : null, meshes: R && R.meshes ? Object.keys(R.meshes).length : null,
  tiles: R && R.tiles ? R.tiles.count() : null, bootErr: window.__apBootErr || null,
  loadingHidden: document.getElementById('loading').style.display === 'none',
}));

// ============================ terrain parity ============================
{
  const { page, errors } = await openPage(1600, 1000);
  await waitSettled(page);
  await feeds(page);
  await sleep(1500);
  const t = await terrainProbe(page);
  fs.writeFileSync(path.join(HERE, LABEL + '_terrain.json'), JSON.stringify(t, null, 2));
  check(`[${LABEL}] terrain: heightfield, buildings, meshes, tiles loaded, no boot error`,
    t.hf === 200 && t.bld > 17000 && t.meshes > 400 && t.tiles > 100 && !t.bootErr && t.loadingHidden, t);
  check(`[${LABEL}] terrain boot: no JS errors`, errors.length === 0, errors.join(' | '));
  if (ONLY_TERRAIN) { await page.screenshot({ path: path.join(HERE, LABEL + '_1600x1000.png') }); }
  await page.close();
}
if (ONLY_TERRAIN) { await browser.close(); report(); process.exit(results.every(r => r.pass) ? 0 : 1); }

// ============================ layout at four viewports ============================
for (const [w, h] of [[1600, 1000], [1920, 1080], [1280, 720], [3440, 1440]]) {
  const tag = `${w}x${h}`;
  const { page, errors } = await openPage(w, h);
  await waitSettled(page);
  await feeds(page);
  await sleep(1000);
  const essentials = ['#directory', '#find', '[data-tab=nearby]', '[data-tab=squad]', '#place-list', '#nbtn', '#orb', '#view-2d', '#view-3d', '#zin', '#zout', '#zme', '#map-location', '#toggle-layers', '#strip'];
  const miss = [];
  for (const s of essentials) { const r = await rect(page, s); if (!inView(r, w, h)) miss.push(s); }
  check(`[${tag}] every control visible inside the viewport`, miss.length === 0, miss.join(', '));
  const hdr = await page.evaluate(() => document.querySelector('.hdr').textContent);
  check(`[${tag}] header carries no renderer/debug counters`, !/BLD|TILT|1px =|kt\b/.test(hdr) && /MALDEN GRID/.test(hdr), hdr.replace(/\s+/g, ' ').trim());
  const scrolls = await page.evaluate(() => { const l = document.getElementById('place-list'); return { sh: l.scrollHeight, ch: l.clientHeight, rows: l.querySelectorAll('.place-row').length }; });
  check(`[${tag}] result list scrolls with the full marker catalogue`, scrolls.sh > scrolls.ch && scrolls.rows > 100, scrolls);
  // selection + both destinations active: nothing overlaps
  await page.click('#place-list .place-row');
  await sleep(300);
  await page.click('#set-waypoint'); await sleep(300);
  await page.click('#set-gps'); await sleep(400);
  const R = {};
  for (const s of ['#directory', '#selection', '#set-waypoint', '#set-gps', '#map-location', '#destination-bar', '#toggle-layers', '.zbtns', '#clear-waypoint', '#clear-gps', '#focus-waypoint']) R[s] = await rect(page, s);
  const vis = ['#selection', '#set-waypoint', '#set-gps', '#destination-bar', '#clear-waypoint', '#clear-gps'].filter(s => !inView(R[s], w, h));
  check(`[${tag}] selection actions and destination controls visible`, vis.length === 0, vis.join(', ') || R['#destination-bar']);
  const pairs = [['#directory', '#destination-bar'], ['#directory', '#map-location'], ['#destination-bar', '#map-location'],
                 ['#destination-bar', '#toggle-layers'], ['#directory', '.zbtns'], ['#destination-bar', '.zbtns']];
  const bad = pairs.filter(([a, b]) => overlap(R[a], R[b])).map(p => p.join(' x '));
  check(`[${tag}] directory, player status, destination bar and controls do not overlap`, bad.length === 0, bad.join('; '));
  check(`[${tag}] no JS errors`, errors.length === 0, errors.join(' | '));
  await page.close();
}

// ============================ directory behaviour ============================
{
  const W = 1600, H = 1000;
  const { page, errors } = await openPage(W, H);
  await waitSettled(page);
  await feeds(page);
  await sleep(800);
  const withText = staticMarkers.filter(m => m.text && m.id !== 'AP_mapwp' && m.id !== 'AP_mapnav');
  let d = await page.evaluate(() => {
    const rows = [...document.querySelectorAll('#place-list .place-row')];
    return { n: rows.length, keys: rows.map(r => r.getAttribute('data-key')),
      dist: rows.map(r => r.querySelector('.place-distance').textContent), caption: document.getElementById('list-caption').textContent,
      district: document.getElementById('district').textContent };
  });
  check('Nearby lists every text-bearing marker from the real catalogue', d.n === withText.length, `${d.n} rows vs ${withText.length} markers`);
  const meters = d.dist.map(t => /km/.test(t) ? parseFloat(t) * 1000 : parseFloat(t));
  const sorted = meters.every((v, i) => i === 0 || v >= meters[i - 1] - 50);   // km rounding tolerance
  check('Nearby is ordered by direct distance from the player', sorted && d.caption === 'NEAREST TO YOU', d.dist.slice(0, 6).join(', '));
  check('Directory heading is the nearest real TOWN, not a hill or coast', d.district === 'La Trinité', d.district);
  // player-placed "WP" marker is listed; the engine's own AP_mapwp is not (set one to create it)
  await page.click('#place-list .place-row'); await sleep(200);
  await page.click('#set-waypoint'); await sleep(300);
  const withOwn = staticMarkers.concat([{ id: 'AP_mapwp', x: 7000, y: 7000, text: 'WP', type: 'mil_objective', color: 'ColorCIV', alpha: 1 }]);
  await page.evaluate((st) => { window.WEBUI._emit('mapStatic', btoa(unescape(encodeURIComponent(JSON.stringify(st))))); },
    { markers: withOwn, locations, cartels: [], territories });
  await sleep(300);
  const wpRows = await page.evaluate(() => { const f = document.getElementById('find'); f.value = 'WP'; f.dispatchEvent(new Event('input'));
    return [...document.querySelectorAll('#place-list .place-row')].map(r => r.getAttribute('data-key')); });
  check('A player marker saying "WP" is listed; the engine\'s own AP_mapwp is skipped by id', wpRows.includes('m:_USER_DEFINED #2/1/0') && !wpRows.includes('m:AP_mapwp'), wpRows);
  // search
  const search = async (q) => page.evaluate((q) => { const f = document.getElementById('find'); f.value = q; f.dispatchEvent(new Event('input'));
    return { rows: [...document.querySelectorAll('#place-list .place-row')].map(r => ({ k: r.getAttribute('data-key'), n: r.querySelector('.place-name').textContent, kind: r.querySelector('.place-kind').textContent })),
      empty: (document.querySelector('#place-list .empty') || {}).textContent || '', clear: !document.getElementById('clear-search').hidden,
      caption: document.getElementById('list-caption').textContent }; }, q);
  let r = await search('trinite');
  check('Search is accent-insensitive and crosses categories ("trinite" finds La Trinité places + markers)', r.rows.some(x => x.n === 'La Trinité') && r.caption === 'SEARCH RESULTS' && r.clear, r.rows.map(x => x.n).slice(0, 6));
  r = await search('boat shop');
  check('Seven identical "Boat Shop" markers stay seven rows, told apart by grid', r.rows.length === 7 && new Set(r.rows.map(x => x.k)).size === 7 && r.rows.every(x => /Grid \d{3} \/ \d{3}/.test(x.kind)), r.rows.map(x => x.kind));
  r = await search('moth');
  check('Two squadmates both named MOTH are two rows with distinct identities', r.rows.filter(x => x.k.startsWith('s:')).length === 2, r.rows.map(x => x.k));
  r = await search('zzzz-no-such-place');
  check('Empty search says so and offers recovery', r.rows.length === 0 && /No matching/.test(r.empty) && r.clear, r.empty);
  await page.click('#clear-search'); await sleep(100);
  check('Clear button empties the search and refocuses it', await page.evaluate(() => document.getElementById('find').value === '' && document.activeElement.id === 'find'));
  await page.type('#find', 'chapoi'); await sleep(100);
  await page.keyboard.press('Enter'); await sleep(500);
  let s = await state(page);
  check('Enter selects the first search result and moves the camera to it', s.sel && /Chapoi/i.test(s.sel.name), s.sel);
  await page.focus('#find'); await page.keyboard.press('ArrowDown');
  check('Arrow Down moves focus from search into the results', await page.evaluate(() => document.activeElement.classList.contains('place-row')));
  await page.keyboard.press('ArrowDown');
  check('Arrow keys move through result rows', await page.evaluate(() => { const rows = [...document.querySelectorAll('.place-row')]; return rows.indexOf(document.activeElement) === 1; }));
  check('Search field focus is reported to SQF (M-close guard)', (await calls(page, 'mapTyping')).some(c => c.args[0] === true) && (await calls(page, 'mapTyping')).some(c => c.args[0] === false));
  // places + squad tabs
  await page.evaluate(() => { const f = document.getElementById('find'); f.value = ''; f.dispatchEvent(new Event('input')); });
  await page.click('[data-tab=places]'); await sleep(150);
  const places = await page.evaluate(() => document.querySelectorAll('#place-list .place-row').length);
  check('Places lists every named location from the engine dump', places === locations.length, `${places} vs ${locations.length}`);
  await page.click('[data-tab=squad]'); await sleep(150);
  const sq = await page.evaluate(() => [...document.querySelectorAll('#place-list .place-row')].map(r => ({ n: r.querySelector('.place-name').textContent, k: r.querySelector('.place-kind').textContent, dead: r.classList.contains('dead') })));
  check('Squad tab: every member, dead state readable, leader and crew stated', sq.length === 4 && sq.some(x => x.dead && /Flatlined/.test(x.k)) && sq.some(x => /Squad leader/.test(x.k)) && sq.some(x => /3 crew/.test(x.k)), sq);

  // selection persistence against moving / removed entities
  const mothKey = 's:2:102';
  await page.evaluate((k) => selectKey(k, false), mothKey);
  await pushMap(page, { self: SELF, group: GROUP.map(u => u.id === '2:102' ? { ...u, x: 7600, y: 8000 } : u), env: ENV });
  await sleep(200);
  s = await state(page);
  check('A selected squadmate who moves stays selected and follows', s.sel && s.sel.key === mothKey && s.sel.x === 7600 && !s.sel.gone, s.sel);
  await pushMap(page, { self: SELF, group: GROUP.filter(u => u.id !== '2:102'), env: ENV });
  await sleep(200);
  s = await state(page);
  const selTxt = await page.evaluate(() => document.getElementById('selected-kind').textContent);
  check('A squadmate who disconnects stays selected as "no longer on the map", never swapped for the other MOTH', s.sel && s.sel.key === mothKey && s.sel.gone && /NO LONGER/.test(selTxt), { sel: s.sel, selTxt });

  // scroll + focus preserved across a 1 Hz update
  await page.click('[data-tab=nearby]'); await sleep(150);
  await pushMap(page, { self: SELF, group: GROUP, env: ENV }); await sleep(150);
  const before = await page.evaluate(() => { const l = document.getElementById('place-list'); l.scrollTop = 600; const row = l.querySelectorAll('.place-row')[15]; row.focus({ preventScroll: true });
    return { top: l.scrollTop, key: row.getAttribute('data-key') }; });
  await pushMap(page, { self: { ...SELF, x: SELF.x + 8 }, group: GROUP.map(u => ({ ...u, x: u.x + 5 })), env: ENV });
  await sleep(200);
  const after = await page.evaluate(() => ({ top: document.getElementById('place-list').scrollTop, key: document.activeElement.getAttribute('data-key') }));
  check('A 1 Hz update keeps the list\'s scroll position and focused row', after.top === before.top && after.key === before.key, { before, after });
  check('directory: no JS errors', errors.length === 0, errors.join(' | '));
  await page.close();
}

// ============================ gestures, waypoint, GPS, staff ============================
{
  const W = 1600, H = 1000;
  const { page, errors } = await openPage(W, H);
  await waitSettled(page);
  await feeds(page, { admin: true });
  await sleep(1000);
  const glRect = await rect(page, '#gl');
  // a point on open terrain well clear of panels and glyphs
  const empty = [glRect.x + glRect.w * 0.58, glRect.y + glRect.h * 0.78];

  await clearCalls(page);
  await page.mouse.click(empty[0], empty[1]);
  await sleep(200);
  let s = await state(page);
  check('Plain click on empty terrain drops a selection pin and sends nothing', s.sel && s.sel.cat === 'point' && (await calls(page)).filter(c => c.name !== 'mapTyping').length === 0, s.sel);
  const pinKey = s.sel.key;

  const camBefore = (await state(page)).cam;
  await page.mouse.move(empty[0], empty[1]); await page.mouse.down();
  await page.mouse.move(empty[0] + 60, empty[1] + 30, { steps: 6 }); await page.mouse.up();
  await sleep(200);
  s = await state(page);
  check('A drag pans the camera and neither changes selection nor sends an action', s.sel.key === pinKey && (s.cam.tx !== camBefore.tx || s.cam.ty !== camBefore.ty) && (await calls(page)).filter(c => /mapWaypoint|mapNav|mapTeleport/.test(c.name)).length === 0, { camBefore, cam: s.cam });

  // click a projected marker glyph selects it
  const target = staticMarkers.find(m => m.text === 'Bank of Malden');
  await page.evaluate((x, y) => { cam.tx = x; cam.ty = y; cam.dist = 900; cam.tilt = 0.9; cam.yaw = 0; userMoved = true; dirty(); }, target.x, target.y);
  await sleep(500);
  const gp = await screenOf(page, target.x, target.y, 2);
  await page.mouse.click(gp[0], gp[1]); await sleep(200);
  s = await state(page);
  check('Clicking a marker glyph selects that marker by its own id', s.sel && s.sel.key === 'm:' + target.id, s.sel);

  // modifiers: CTRL-click = one waypoint action, no selection change
  await clearCalls(page);
  const selBefore = (await state(page)).sel.key;
  await page.evaluate(() => { window.__mods = { s: 0, c: 1, a: 0 }; });
  await page.mouse.click(empty[0], empty[1] - 80); await sleep(300);
  await page.evaluate(() => { window.__mods = { s: 0, c: 0, a: 0 }; });
  s = await state(page);
  const wpc = await calls(page, 'mapWaypoint');
  check('CTRL-click (window.__mods from SQF) sends exactly one waypoint action and keeps the selection', wpc.length === 1 && s.sel.key === selBefore && !!s.wp, { calls: wpc.length, sel: s.sel.key, wp: s.wp });

  // armed teleport consumes its click
  await clearCalls(page);
  check('Teleport control appears only with the staff flag in the feed', await page.evaluate(() => !document.getElementById('tpbtn').hidden));
  await page.click('#tpbtn');
  const selTp = (await state(page)).sel.key;
  await page.mouse.click(empty[0] - 120, empty[1]); await sleep(300);
  s = await state(page);
  const tpc = await calls(page);
  check('An armed teleport click sends one teleport and nothing else; selection unchanged; arm spent', tpc.filter(c => c.name === 'mapTeleport').length === 1 && tpc.filter(c => /mapWaypoint|mapNav/.test(c.name)).length === 0 && s.sel.key === selTp && await page.evaluate(() => !window.__tpArm), tpc.map(c => c.name));

  // SHIFT-drag = orbit, not pan; left-button orbit pad; north; 2D/3D; my position
  await page.evaluate(() => { window.__mods = { s: 1, c: 0, a: 0 }; });
  let c0 = (await state(page)).cam;
  await page.mouse.move(empty[0], empty[1]); await page.mouse.down(); await page.mouse.move(empty[0] + 80, empty[1], { steps: 5 }); await page.mouse.up();
  await page.evaluate(() => { window.__mods = { s: 0, c: 0, a: 0 }; });
  let c1 = (await state(page)).cam;
  check('SHIFT (from SQF) + drag orbits instead of panning', c1.yaw !== c0.yaw && c1.tx === c0.tx, { c0, c1 });
  const orb = await rect(page, '#orb');
  c0 = (await state(page)).cam;
  await page.mouse.move(orb.x + orb.w / 2, orb.y + orb.h / 2); await page.mouse.down(); await page.mouse.move(orb.x + orb.w / 2 + 40, orb.y + orb.h / 2 + 20, { steps: 5 }); await page.mouse.up();
  c1 = (await state(page)).cam;
  check('Left-button Orbit pad rotates and tilts', c1.yaw !== c0.yaw && c1.tilt !== c0.tilt, { c0, c1 });
  await page.click('#nbtn'); await sleep(450);
  check('Reset north returns yaw to 0', Math.abs((await state(page)).cam.yaw) < 0.01);
  await page.click('#view-2d'); await sleep(450);
  check('2D goes top-down and marks itself pressed', await page.evaluate(() => cam.tilt < 0.02 && document.getElementById('view-2d').getAttribute('aria-pressed') === 'true'));
  await page.click('#view-3d'); await sleep(450);
  /* REGRESSION: 2D straight after a list selection, with no further input. The
     frame pump used to skip painting the final animation step, so the camera ended
     flat while the switch still said 3D -- visible only when nothing else happened
     to trigger another draw afterwards. */
  await page.click('[data-tab=nearby]'); await page.click('#place-list .place-row');
  await page.click('#view-2d'); await sleep(1200);
  check('2D right after a list selection: camera flat AND switch shows 2D (final step is painted)',
    await page.evaluate(() => cam.tilt === 0 && document.getElementById('view-2d').getAttribute('aria-pressed') === 'true'),
    await page.evaluate(() => ({ tilt: cam.tilt, aria: document.getElementById('view-2d').getAttribute('aria-pressed') })));
  await page.click('#view-3d'); await sleep(600);
  check('3D restores tilt', await page.evaluate(() => cam.tilt > 0.3 && document.getElementById('view-3d').getAttribute('aria-pressed') === 'true'));
  const dz = (await state(page)).cam.dist; await page.click('#zin'); await sleep(50);
  check('Zoom in reduces camera distance', (await state(page)).cam.dist < dz);
  await page.click('#zme'); await sleep(500);
  s = await state(page);
  check('My position centres on the player', Math.abs(s.cam.tx - SELF.x) < 5 && Math.abs(s.cam.ty - SELF.y) < 5, s.cam);

  // ---- waypoint set / pending / replace / clear ----
  await clearCalls(page);
  await page.evaluate(() => { window.__sqf.delay.mapWaypoint = 700; });
  await page.evaluate(() => selectKey('p:Larche@' + Math.round(LOC.find(l => l.name === 'Larche').x) + ',' + Math.round(LOC.find(l => l.name === 'Larche').y), false));
  await page.click('#set-waypoint');
  await page.click('#set-waypoint').catch(() => {});        // disabled while pending: must not send twice
  await sleep(100);
  const pend = await page.evaluate(() => ({ t: document.getElementById('set-waypoint').textContent, d: document.getElementById('set-waypoint').disabled }));
  check('Set waypoint shows a pending state and ignores a second click', pend.d && /Setting/.test(pend.t), pend);
  await sleep(900);
  s = await state(page);
  let wc = await calls(page, 'mapWaypoint');
  const barName = await page.evaluate(() => document.getElementById('dest-wp-name').textContent);
  check('Waypoint set: exactly one action; bar shows the destination name and direct distance', wc.length === 1 && s.bar && barName === 'Larche' && /DIRECT DISTANCE/.test(await page.evaluate(() => document.getElementById('dest-wp-dist').textContent)), { calls: wc.length, barName });
  // rapid replace while in flight: serialized, latest wins
  await clearCalls(page);
  await page.evaluate(() => { destSet('wp', 5000, 5000, 'First', null); destSet('wp', 6000, 6000, 'Second', null); destSet('wp', 6500, 6500, 'Third', null); });
  await sleep(2300);
  s = await state(page);
  wc = await calls(page, 'mapWaypoint');
  check('Rapid waypoint changes are serialized: in-flight one, then only the latest queued intent', wc.length === 2 && wc[0].args[0] === 5000 && wc[1].args[0] === 6500 && s.wp && s.wp.x === 6500, wc.map(c => c.args));
  // dismissing the selection does not clear the waypoint
  await page.click('#dismiss-selection'); await sleep(100);
  s = await state(page);
  check('Dismissing the selection leaves the waypoint in place', !s.sel && !!s.wp && s.bar);
  // refused waypoint: no false confirmation
  await page.evaluate(() => { window.__sqf.delay.mapWaypoint = 0; window.__sqf.wpFail = true; });
  const wpPrior = (await state(page)).wp;
  await page.evaluate(() => destSet('wp', 7777, 7777, 'Refused', null)); await sleep(300);
  s = await state(page);
  check('A refused waypoint changes nothing on screen and says why', s.wp.x === wpPrior.x && /refused/i.test(s.toast), { wp: s.wp, toast: s.toast });
  await page.evaluate(() => { window.__sqf.wpFail = false; });

  // ---- GPS success draws the returned road route and road length ----
  await clearCalls(page);
  await page.evaluate(() => { window.__sqf.delay.mapNav = 300; });
  await page.evaluate(() => { const m = markers.find(x => x.text === 'Federal Reserve'); selectKey(markerKey(m), false); });
  await page.click('#set-gps'); await sleep(80);
  const gpsPend = await page.evaluate(() => document.getElementById('set-gps').textContent);
  await sleep(600);
  s = await state(page);
  const expect = await page.evaluate(() => { const st = window.__sqf.destState(); return { n: st.nav.route.length, len: Math.round(st.nav.len) }; });
  check('Set GPS shows "Finding route" while pending', /Finding/.test(gpsPend), gpsPend);
  check('GPS success: the drawn route IS the returned road polyline, and road length is shown', s.nav && s.nav.n === expect.n && s.nav.len === expect.len && /by road/.test(s.status), { nav: s.nav, expect, status: s.status });
  check('The GPS set went through mapNav exactly once (the path that stores AP_gpsRoutePts)', (await calls(page, 'mapNav')).length === 1);
  // failed replacement keeps the prior route
  await page.evaluate(() => { window.__sqf.navFail = true; });
  const navPrior = (await state(page)).nav;
  await page.evaluate(() => { const m = markers.find(x => x.text === 'Mental Asylum'); selectKey(markerKey(m), false); });
  await page.click('#set-gps'); await sleep(600);
  s = await state(page);
  check('A failed GPS replacement keeps drawing the route the game kept, and says so', s.nav && s.nav.x === navPrior.x && s.nav.n === navPrior.n && /previous route is unchanged/.test(s.status), { nav: s.nav, status: s.status });
  await page.evaluate(() => { window.__sqf.navFail = false; window.__sqf.delay.mapNav = 0; });
  // ALT-click takes the same path
  await clearCalls(page);
  await page.evaluate(() => { window.__mods = { s: 0, c: 0, a: 1 }; });
  await page.mouse.click(empty[0] + 40, empty[1] - 40); await sleep(300);
  await page.evaluate(() => { window.__mods = { s: 0, c: 0, a: 0 }; });
  s = await state(page);
  check('ALT-click sends one mapNav through the same helper and updates the same route state', (await calls(page, 'mapNav')).length === 1 && s.nav && /by road/.test(s.toast), { toast: s.toast });
  // independence of the two clears
  await page.click('#clear-gps'); await sleep(300);
  s = await state(page);
  check('Clear GPS removes the route and leaves the waypoint', !s.nav && !!s.wp && (await calls(page, 'mapWaypoint')).length === 0, s);
  await page.click('#clear-waypoint'); await sleep(300);
  s = await state(page);
  check('Clear waypoint removes the waypoint and hides the bar', !s.wp && !s.bar);

  // ---- layers ----
  await page.evaluate(() => { cam.tx = 7150; cam.ty = 7900; cam.dist = 1600; cam.tilt = 0.85; cam.yaw = 0; dirty(); });
  await sleep(400);
  const tiersOn = await page.evaluate(() => ({ t: Object.assign({}, diag.tiers), squadHits: hitList.filter(h => h.key.startsWith('s:')).length, markerHits: hitList.filter(h => h.key.startsWith('m:')).length, helis: heliUnits(layers.squad).length }));
  await page.click('#toggle-layers');
  for (const l of ['markers', 'squad', 'zones']) await page.click(`[data-layer=${l}]`);
  await sleep(300);
  const tiersOff = await page.evaluate(() => ({ t: Object.assign({}, diag.tiers), squadHits: hitList.filter(h => h.key.startsWith('s:')).length, markerHits: hitList.filter(h => h.key.startsWith('m:')).length, helis: heliUnits(layers.squad).length }));
  check('Layers: squad off removes squad glyph hits, labels and group helicopter holograms', tiersOn.squadHits > 0 && tiersOff.squadHits === 0 && !tiersOff.t[80] && tiersOn.helis > tiersOff.helis, { tiersOn, tiersOff });
  check('Layers: markers off removes marker glyph hits and labels', tiersOn.markerHits > 0 && tiersOff.markerHits === 0 && !tiersOff.t[20], { on: tiersOn.markerHits, off: tiersOff.markerHits });
  check('Layers: zones off removes zone labels', (tiersOn.t[40] || 0) > 0 && !tiersOff.t[40], { on: tiersOn.t[40], off: tiersOff.t[40] });
  check('Layers never hide the player', tiersOff.t[100] === 1, tiersOff.t);
  await page.evaluate(() => { const f = document.getElementById('find'); f.value = 'razor'; f.dispatchEvent(new Event('input')); });
  check('Squad search still works with the squad layer hidden', await page.evaluate(() => document.querySelectorAll('#place-list .place-row').length === 1));
  for (const l of ['markers', 'squad', 'zones']) await page.click(`[data-layer=${l}]`);
  await page.click('#collapse-directory'); await sleep(150);
  check('Directory collapses to expose terrain', await page.evaluate(() => document.getElementById('directory').classList.contains('collapsed') && document.getElementById('directory').getBoundingClientRect().height < 150));
  await page.click('#collapse-directory');

  // ---- idle painting is event-driven ----
  await sleep(1500);
  const r0 = await page.evaluate(() => window.__rafCount); await sleep(2000);
  const r1 = await page.evaluate(() => window.__rafCount);
  check('Idle: no animation frames without input or pushes', r1 - r0 <= 1, `${r1 - r0} frames in 2 s`);
  const t0 = Date.now(); for (let i = 0; i < 5; i++) { await pushMap(page, { self: { ...SELF, x: SELF.x + i }, group: GROUP, env: ENV }); await sleep(200); }
  const r2 = await page.evaluate(() => window.__rafCount);
  check('A push paints about one frame, not a loop', r2 - r1 <= 8, `${r2 - r1} frames for 5 pushes`);
  check('gestures/actions: no JS errors', errors.length === 0, errors.join(' | '));
  await page.close();
}

// ============================ reduced motion ============================
{
  const { page, errors } = await openPage(1600, 1000, { reduced: true });
  await waitSettled(page); await feeds(page); await sleep(600);
  await page.evaluate(() => { cam.tx = 3000; cam.ty = 3000; userMoved = true; dirty(); });
  await page.click('#zme'); await sleep(30);
  const st = await page.evaluate(() => ({ tx: Math.round(cam.tx), ty: Math.round(cam.ty), anims: anims.length,
    anim: getComputedStyle(document.getElementById('selection')).animationName }));
  check('Reduced motion: camera moves are immediate, no animation queued', st.tx === SELF.x && st.ty === SELF.y && st.anims === 0, st);
  check('reduced motion: no JS errors', errors.length === 0, errors.join(' | '));
  await page.close();
}

// ============================ served-document replacement ============================
for (const order of ['push-before-serve', 'serve-before-push']) {
  const { page, errors } = await openPage(1600, 1000);
  await waitSettled(page);
  if (order === 'push-before-serve') {
    await feeds(page); await sleep(300);
    await page.evaluate(() => { window.__sqf.wp = [6100, 8600]; window.__sqf.pts = [[7150, 7800], [7150, 8200], [6000, 8200]]; window.__sqf.dest = [6000, 8200]; window.__sqf.pushDest(); });
    await sleep(200);
  }
  const gen0 = await page.evaluate(() => window.__mapGen);
  await page.evaluate((html) => { window.WEBUI._serve(btoa(unescape(encodeURIComponent(html)))); }, MARKUP);
  await sleep(2500);
  if (order === 'serve-before-push') {
    await page.evaluate(() => { window.__sqf.wp = [6100, 8600]; });
    await feeds(page);
  }
  await waitSettled(page, 12000);
  await pushMap(page, { self: { ...SELF, x: 7300 }, group: GROUP, env: ENV }); await sleep(300);
  const st = await page.evaluate(() => ({ gen: window.__mapGen, grid: document.getElementById('self-grid').textContent,
    rows: document.querySelectorAll('#place-list .place-row').length, wp: !!DEST.wp, bar: !document.getElementById('destination-bar').hidden,
    hf: R && R.hf ? R.hf.n : null, liveDot: !document.getElementById('live-dot').hidden }));
  check(`serve replacement (${order}): new document boots, reads the feed and restores the waypoint`, st.gen === gen0 + 1 && st.grid === 'GRID 073 / 078' && st.rows > 100 && st.wp && st.bar && st.hf === 200, st);
  const r0 = await page.evaluate(() => window.__rafCount); await sleep(2000);
  const r1 = await page.evaluate(() => window.__rafCount);
  check(`serve replacement (${order}): the replaced document leaves no running frame loop`, r1 - r0 <= 1, `${r1 - r0} frames idle`);
  // one push must be handled once: count row rebuild side effects via a MutationObserver
  const handled = await page.evaluate(async () => { let n = 0; const orig = onLive; window.onLive = function () { n++; return orig.apply(this, arguments); };
    const b64 = v => btoa(unescape(encodeURIComponent(JSON.stringify(v)))); window.WEBUI._emit('map', b64({ self: { x: 7310, y: 7800, dir: 0, name: 'V', veh: 'none' }, group: [], env: {} }));
    await new Promise(r => setTimeout(r, 100)); return n; });
  check(`serve replacement (${order}): a push is handled by exactly one live subscription`, handled === 1, handled);
  check(`serve replacement (${order}): no JS errors`, errors.length === 0, errors.join(' | '));
  await page.close();
}

// ============================ production screenshots ============================
async function shot(w, h, name, setup) {
  const { page } = await openPage(w, h);
  await waitSettled(page);
  await feeds(page);
  await sleep(800);
  if (setup) await setup(page);
  await sleep(1800);
  await page.screenshot({ path: path.join(HERE, `${LABEL}_${name}.png`) });
  await page.close();
}
await shot(1600, 1000, 'overview');
await shot(1920, 1080, 'waypoint', async (page) => {
  await page.evaluate(() => { const m = markers.find(x => x.text === 'Federal Reserve' ); selectKey(markerKey(m), false); });
  await page.evaluate(() => { const L = LOC.find(l => l.name === 'Larche'); selectEntry(CATIDX['p:Larche@' + Math.round(L.x) + ',' + Math.round(L.y)], false); });
  await page.click('#set-waypoint'); await sleep(300); await page.click('#set-gps'); await sleep(500);
  await page.evaluate(() => { cam.tx = 6700; cam.ty = 8200; cam.dist = 2600; cam.tilt = 0.8; cam.yaw = 0; userMoved = true; dirty(); });
});
await shot(1600, 1000, 'squad-2d', async (page) => {
  await page.click('[data-tab=squad]'); await page.click('#place-list .place-row'); await page.click('#view-2d');
});
await shot(1600, 1000, 'layers', async (page) => {
  await page.mouse.click(1000, 780); await page.click('#toggle-layers'); await page.click('[data-layer=squad]'); await page.click('[data-layer=zones]');
});
await shot(1280, 720, 'compact', async (page) => {
  await page.click('[data-tab=squad]'); await page.click('#place-list .place-row'); await page.click('#set-waypoint');
});
await shot(3440, 1440, 'ultrawide');

await browser.close();
report();
process.exit(results.every(r => r.pass) ? 0 : 1);

function report() {
  let fail = 0;
  for (const r of results) {
    if (!r.pass) fail++;
    const d = typeof r.detail === 'string' ? r.detail : JSON.stringify(r.detail);
    console.log(`${r.pass ? 'PASS' : 'FAIL'}  ${r.name}${r.pass ? '' : '\n        ' + d.slice(0, 600)}`);
  }
  console.log(`\n-- ${results.length - fail} passed, ${fail} failed`);
  fs.writeFileSync(path.join(HERE, LABEL + '_results.json'), JSON.stringify(results, null, 2));
}
