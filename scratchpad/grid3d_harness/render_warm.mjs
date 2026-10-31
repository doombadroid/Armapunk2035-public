// Offline harness for the CONNECT-TIME CACHE WORKER (ui/html/warm.html) and for
// the landing screen's loading bar (ui/html/landing.html).
//
//   node scratchpad/grid3d_harness/render_warm.mjs <label>
//
// Writes <label>.json and <label>-landing.png beside this file, prints a PASS/FAIL
// line per assertion, and exits non-zero if any of them fail.
//
// WHY THIS EXISTS. Neither of these two pages has ever had a harness, and the
// failures they can produce are all invisible from SQF: a queue that parks on the
// first missing icon looks exactly like a slow client, a miscounted denominator
// looks exactly like a bar that is telling the truth, and a PLAY button gated on a
// background texture cache looks exactly like a player who did not press it. So
// this asserts the five things that would otherwise only ever fail in front of a
// player:
//
//   1. ORDER. The three map text assets go out before the tile and icon bulk. They
//      are what MALDEN GRID and the HUD's 3D minimap block on at boot; everything
//      after them is pop-in.
//   2. LANES. Concurrency never exceeds 3. The engine's texture conversion is not
//      free and the point of the warmer is to be invisible.
//   3. A MISS DOES NOT STALL THE PUMP -- the single most likely real-world failure.
//      RequestTexture RESOLVES with a ~23 char stub for a path the game filesystem
//      does not have and RequestFile REJECTS, so the stub below does both, on real
//      entries, and the queue is required to drain anyway.
//   4. The reported progress is monotonic, starts below 100, and lands on exactly
//      100 when the queue drains.
//   5. The total the page reports is what the queue actually HOLDS -- 3 files, the
//      tile set at two mips, one entry per .paa in the mission's icons/ directory
//      (counted off the real directory here), and the weapon pictures SQF pushed.
//      A stale ICONS list warms fewer icons and is harmless; a denominator that does
//      not match the queue makes the bar lie, which is the whole thing this feature
//      exists to stop.
//   6. THE WEAPON THUMBNAILS. warm.html cannot know them -- the armory resolves them
//      out of CfgWeapons per row -- so it asks (warmReady) and SQF answers on the
//      "warmGuns" channel. The stub below answers exactly as AP_fnc_warmCatalogue
//      does, in chunks, and three things are asserted about the result: they are
//      requested at 128 and only 128 (512 is the hero preview, one image on demand,
//      and warming it would quadruple the memory for a pane a player may never open);
//      they come AFTER the map, tile and icon entries; and NO requested path begins
//      with a backslash. That last one is the silent-404 trap fn_armoryOpen.sqf:61-65
//      records -- a config picture path leads with "\" and RequestTexture wants it
//      without one, and with it every texture 404s with no error anywhere, which
//      looks exactly like the slow shop this whole feature exists to fix. The fixture
//      therefore hands the page some paths WITH the backslash still on.
//
// And on the landing side: pushed loadPct values render, and PLAY is NOT gated --
// it is clickable and advances at 3%, which is the requirement the page used to
// violate (its welcome->faction step tested loadPct >= 100 back when loadPct was a
// hardcoded 100).
//
// A3API is overridden BEFORE either page's own script runs, exactly as render_map.mjs
// and render_hud.mjs do it, and Math.random is seeded so the stub's per-request
// latency is the same every run.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE    = new URL('.', import.meta.url).pathname;
const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const HTML    = path.join(MISSION, 'ui/html');
const label   = process.argv[2] || 'warm';
const sleep   = (ms) => new Promise(r => setTimeout(r, ms));

// The truth the page is measured against, read off the real tree rather than
// restated here: if somebody adds an icon and forgets to regenerate warm.html's
// ICONS list, assertion 5 is what says so.
const ICONS_ON_DISK = fs.readdirSync(path.join(MISSION, 'icons')).filter(f => f.endsWith('.paa')).length;
const GRID = 13;
const EXPECT_FILES = 3;
const EXPECT_TILES = GRID * GRID * 2;

// What AP_fnc_warmCatalogue pushes, standing in for a config read there is no offline
// runtime for. Real gear_*_CA.paa paths; SIX of them still carry the leading backslash
// the config hands out, so the page's own strip is under test and not merely present.
// Every entry is distinct AFTER the strip, so the request count is the entry count.
const GUN_PICS = [
  "\\A3\\Weapons_F\\Rifles\\MX\\Data\\UI\\gear_mx_X_CA.paa",
  "\\A3\\Weapons_F\\Rifles\\MX\\Data\\UI\\gear_mxc_X_CA.paa",
  "\\A3\\Weapons_F\\Rifles\\MX\\Data\\UI\\gear_mxm_X_CA.paa",
  "\\A3\\Weapons_F\\Rifles\\Khaybar\\Data\\UI\\gear_arifle_khaybar_X_CA.paa",
  "\\A3\\Weapons_F\\Rifles\\Mk20\\Data\\UI\\gear_mk20_rifle_X_CA.paa",
  "\\A3\\Weapons_F\\Pistols\\P07\\Data\\UI\\gear_P07_X_CA.paa",
  "A3\\Weapons_F\\SMGs\\SMG_02\\Data\\UI\\gear_SMG_02_X_CA.paa",
  "A3\\Weapons_F\\SMGs\\SMG_01\\Data\\UI\\gear_SMG_01_X_CA.paa",
  "A3\\Weapons_F\\LongRangeRifles\\DMR_01\\Data\\UI\\gear_dmr_01_X_CA.paa",
  "A3\\Weapons_F\\LongRangeRifles\\EBR\\Data\\UI\\gear_ebr_X_CA.paa",
  "A3\\Weapons_F\\MachineGuns\\M200\\Data\\UI\\gear_m200_X_CA.paa",
  "A3\\Weapons_F\\MachineGuns\\Zafir\\Data\\UI\\gear_zafir_X_CA.paa",
  "A3\\Weapons_F\\Launchers\\RPG32\\Data\\UI\\gear_rpg32_X_CA.paa",
  "A3\\Weapons_F_Exp\\Rifles\\SPAR_01\\Data\\UI\\gear_SPAR_01_black_X_CA.paa",
  "A3\\Weapons_F_Exp\\Rifles\\SPAR_02\\Data\\UI\\gear_SPAR_02_black_X_CA.paa",
  "A3\\Weapons_F_Exp\\Rifles\\SPAR_03\\Data\\UI\\gear_SPAR_03_black_X_CA.paa",
  "A3\\Weapons_F_Tank\\Rifles\\MSBS\\Data\\UI\\gear_msbs65_black_X_CA.paa",
  "A3\\Weapons_F_Tacops\\Rifles\\ARX\\Data\\UI\\gear_arx_blk_X_CA.paa",
  "A3\\Weapons_F_Enoch\\Rifles\\AK12\\Data\\UI\\gear_ak12_X_CA.paa",
  "A3\\Weapons_F_Enoch\\Rifles\\RPK12\\Data\\UI\\gear_rpk12_X_CA.paa",
  "A3\\Weapons_F\\Pistols\\Rook40\\Data\\UI\\gear_rook40_X_CA.paa",
  "A3\\Weapons_F\\Pistols\\ACPC2\\Data\\UI\\gear_acp_c2_X_CA.paa",
  "A3\\Weapons_F\\Items\\data\\UI\\gear_toolkit_CA.paa",
  "A3\\Weapons_F\\Items\\data\\UI\\gear_medikit_CA.paa",
];
const GUN_WANT = GUN_PICS.map(p => (p.charAt(0) === '\\' ? p.slice(1) : p));
const EXPECT_GUNS = GUN_WANT.length;
const EXPECT_TOTAL = EXPECT_FILES + EXPECT_TILES + ICONS_ON_DISK + EXPECT_GUNS;

const files = {
  'ui\\html\\malden_hf.txt':  fs.readFileSync(path.join(HTML, 'malden_hf.txt'),  'utf8').slice(0, 4096),
  'ui\\html\\malden_bld.txt': fs.readFileSync(path.join(HTML, 'malden_bld.txt'), 'utf8').slice(0, 4096),
  'webui\\ui\\webui.js':      fs.readFileSync(path.join(MISSION, 'webui/ui/webui.js'), 'utf8'),
  // malden_msh.txt is DELIBERATELY ABSENT: a reject in the priority head is the
  // harshest version of assertion 3, because it is the one entry whose failure
  // would strand the queue before it ever reached a tile.
};

const results = [];
const check = (name, ok, detail) => { results.push({ name, ok: !!ok, detail }); return !!ok; };

/* ------------------------------------------------------------------ shared stub */
const installStub = (page, assets, guns) => page.evaluateOnNewDocument((assets, guns) => {
  let s = 1234567;
  Math.random = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };

  const BOOT = 'webui\\ui\\webui.js';
  window.__hits = [];        // queue-originated requests, in call order
  window.__sizes = [];       // the mip asked for, index-aligned with __hits (0 = RequestFile)
  window.__alerts = [];      // the page -> SQF wire, verbatim
  window.__misses = { stub: 0, reject: 0 };
  window.__missPaths = [];   // which paths got the miss, so a miss can be pinned to a lane
  window.__maxInflight = 0;
  let inflight = 0;

  /* The webui.js boot fetch is a real concurrent request but it is not the PUMP's,
     so it is excluded from both the order log and the lane count -- otherwise
     assertion 1 would be asserting the boot stub's position and assertion 2 would
     be measuring 4 lanes where the pump only ever opens 3. */
  const track = (p, counted) => {
    if (!counted) return p;
    inflight += 1;
    if (inflight > window.__maxInflight) window.__maxInflight = inflight;
    const off = () => { inflight -= 1; };
    return p.then(v => { off(); return v; }, e => { off(); throw e; });
  };
  const delay = (ms) => new Promise(r => setTimeout(r, ms));

  window.A3API = {
    RequestFile: (p) => {
      const counted = p !== BOOT;
      if (counted) { window.__hits.push(p); window.__sizes.push(0); }
      return track(delay(1 + Math.floor(Math.random() * 3)).then(() => {
        if (Object.prototype.hasOwnProperty.call(assets, p)) return assets[p];
        if (counted) { window.__misses.reject += 1; window.__missPaths.push(p); }
        throw new Error('no such file: ' + p);       // RequestFile REJECTS on a miss
      }), counted);
    },
    /* RequestTexture RESOLVES with a ~23 char stub for a path the game filesystem
       does not have -- webui.js's textureWithRoot() length-checks for exactly that.
       Every 7th request answers with the stub so a miss is exercised on both the
       tile run and the icon run without making the whole set a miss. */
    RequestTexture: (p, sz) => {
      window.__hits.push(p); window.__sizes.push(sz);
      const n = window.__hits.length;
      return track(delay(1 + Math.floor(Math.random() * 3)).then(() => {
        if (n % 7 === 0) {
          window.__misses.stub += 1; window.__missPaths.push(p);
          return 'data:image/png;base64,';
        }
        return 'data:image/png;base64,' + new Array(200).join('A') + '#' + sz;
      }), true);
    },
    /* Answer CALLs the way SQF does, so nothing in either page is left waiting on
       webui.js's 10 s timeout and no unhandled rejection lands in the console. */
    SendAlert: (msg) => {
      window.__alerts.push(msg);
      try {
        const m = JSON.parse(msg);
        if (m && m[0] === 'CALL') {
          const seq = m[1], name = m[2];
          setTimeout(() => {
            if (window.WEBUI && window.WEBUI._resolve) window.WEBUI._resolve(seq, true, btoa('null'));
            /* AP_fnc_warmCatalogue's half of the handshake: the paths arrive in chunks on
               "warmGuns", each one [[path,...], isLastChunk], only ever AFTER the page has
               subscribed -- which is the whole reason the page asks rather than being told.
               Chunked here too (smaller, so more of them) because a page that only handles
               the last chunk would otherwise pass. */
            if (name === 'warmReady' && guns && guns.length) {
              const CH = 5;
              for (let i = 0; i < guns.length; i += CH) {
                const slice = guns.slice(i, i + CH), last = (i + CH) >= guns.length;
                setTimeout(() => {
                  if (!(window.WEBUI && window.WEBUI._emit)) return;
                  window.WEBUI._emit('warmGuns',
                    btoa(unescape(encodeURIComponent(JSON.stringify([slice, last])))));
                }, 0);
              }
            }
          }, 0);
        }
      } catch (e) { /* HELLO and anything malformed: nothing to answer */ }
    },
    SendConfirm: () => Promise.resolve(false),
  };
}, assets, guns);

const newPage = async (browser, assets, guns) => {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720, deviceScaleFactor: 1 });
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console',   m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await installStub(page, assets, guns || []);
  return { page, errors };
};

const browser = await puppeteer.launch({
  headless: 'new',
  args: ['--no-sandbox', '--disable-lcd-text', '--force-device-scale-factor=1'],
});

/* ---- RUN 1: the cache worker ---------------------------------------------- */
const A = await newPage(browser, files, GUN_PICS);
await A.page.goto('file://' + path.join(HTML, 'warm.html'), { waitUntil: 'load' });
await A.page.waitForFunction('window.__warm && window.__warm.drained === true', { timeout: 60000 })
  .catch(() => {});
await sleep(1200);              // let the final report and the 500 ms ticker settle

const warm = await A.page.evaluate((gunWant) => {
  const prog = [];
  window.__alerts.forEach((m) => {
    let a; try { a = JSON.parse(m); } catch (e) { return; }
    if (a && a[0] === 'CALL' && a[2] === 'warmProgress') {
      prog.push({ args: a[3], bytes: new Blob([m]).size });
    }
  });
  const isTxt = (p) => /\.txt$/.test(p);
  const hits = window.__hits;
  /* The weapon pictures are matched by PATH, against what the stub pushed AFTER its own
     backslash strip -- so a page that forwarded a leading-backslash path verbatim scores
     zero gun hits here as well as failing the backslash assertion outright. */
  const gunSet = new Set(gunWant.map(x => x.toLowerCase()));
  const gunIdx = [], iconIdx = [];
  hits.forEach((p, i) => {
    if (gunSet.has(p.toLowerCase())) gunIdx.push(i);
    else if (p.indexOf('icons\\') === 0) iconIdx.push(i);
  });
  return {
    guns: window.__warm.guns,
    finalized: window.__warm.finalized,
    gunHits: gunIdx.length,
    gunSizes: Array.from(new Set(gunIdx.map(i => window.__sizes[i]))).sort(),
    firstGun: gunIdx.length ? gunIdx[0] : -1,
    lastIcon: iconIdx.length ? iconIdx[iconIdx.length - 1] : -1,
    gunMisses: window.__missPaths.filter(p => gunSet.has(p.toLowerCase())).length,
    backslashed: hits.filter(p => p.charAt(0) === '\\').slice(0, 5),
    total: window.__warm.total, done: window.__warm.done, pct: window.__warm.pct,
    drained: window.__warm.drained, pageErr: window.__warm.err,
    bootErr: window.__warmBootErr || null,
    hits: hits.length,
    head: hits.slice(0, 4),
    txtAfterHead: hits.slice(3).filter(isTxt),
    tiles: hits.filter(p => p.indexOf('map_malden') >= 0).length,
    icons: hits.filter(p => p.indexOf('icons\\') === 0).length,
    maxInflight: window.__maxInflight,
    misses: window.__misses,
    prog: prog.map(x => x.args),
    maxBytes: prog.reduce((n, x) => Math.max(n, x.bytes), 0),
    haveWebui: !!(window.WEBUI && window.WEBUI.call),
  };
}, GUN_WANT);

const pcts = warm.prog.map(a => a[0]);
const monotonic = pcts.every((v, i) => i === 0 || v >= pcts[i - 1]);
const headSorted = warm.head.slice(0, 3).slice().sort().join('|');
const wantHead = ['ui\\html\\malden_hf.txt', 'ui\\html\\malden_bld.txt', 'ui\\html\\malden_msh.txt']
  .slice().sort().join('|');

check('0. the worker page boots with no page errors and no console errors',
      A.errors.length === 0, A.errors.length ? A.errors.join(' | ') : 'none');
check('0b. the bridge came up, so the reports below are the real wire',
      warm.haveWebui && !warm.bootErr && !warm.pageErr,
      'webui=' + warm.haveWebui + ' bootErr=' + warm.bootErr + ' pageErr=' + warm.pageErr);
check('1. the three map text assets are requested BEFORE the tile and icon bulk',
      headSorted === wantHead && warm.txtAfterHead.length === 0,
      'head=' + JSON.stringify(warm.head) + ' strayTxt=' + JSON.stringify(warm.txtAfterHead));
check('1b. the weapon pictures go LAST -- after the map, tile and icon entries',
      warm.gunHits === EXPECT_GUNS && warm.firstGun === warm.hits - EXPECT_GUNS
        && warm.firstGun > warm.lastIcon && warm.lastIcon > 0,
      'gunHits=' + warm.gunHits + '/' + EXPECT_GUNS + ' firstGun=' + warm.firstGun
        + ' lastIcon=' + warm.lastIcon + ' of ' + warm.hits);
check('2. concurrency never exceeds 3 in flight (and the lanes were really used)',
      warm.maxInflight === 3, 'maxInflight=' + warm.maxInflight);
check('3. a miss does not stall the pump: the queue drains to completion anyway',
      warm.drained && warm.done === warm.total
        && warm.misses.reject >= 1 && warm.misses.stub >= 1,
      'drained=' + warm.drained + ' done=' + warm.done + '/' + warm.total
        + ' misses=' + JSON.stringify(warm.misses));
check('3b. a MISS among the weapon pictures does not stall the pump either',
      warm.gunMisses >= 1 && warm.drained && warm.gunHits === EXPECT_GUNS,
      'gunMisses=' + warm.gunMisses + ' gunHits=' + warm.gunHits + ' drained=' + warm.drained);
check('4. progress is monotonic, starts below 100 and lands on exactly 100',
      pcts.length >= 2 && monotonic && pcts[0] < 100 && pcts[pcts.length - 1] === 100,
      'n=' + pcts.length + ' first=' + pcts[0] + ' last=' + pcts[pcts.length - 1]
        + ' monotonic=' + monotonic);
check('5. the reported total is what the queue HOLDS (3 files + ' + EXPECT_TILES
        + ' tiles + ' + ICONS_ON_DISK + ' icons on disk + ' + EXPECT_GUNS + ' weapon pictures)',
      warm.total === EXPECT_TOTAL && warm.hits === EXPECT_TOTAL
        && warm.tiles === EXPECT_TILES && warm.icons === ICONS_ON_DISK
        && warm.guns === EXPECT_GUNS && warm.finalized
        && warm.prog.every(a => a[2] === EXPECT_TOTAL),
      'total=' + warm.total + ' expected=' + EXPECT_TOTAL + ' requests=' + warm.hits
        + ' tiles=' + warm.tiles + ' icons=' + warm.icons + ' guns=' + warm.guns);
check('5c. every weapon picture is warmed at 128 and at NO other mip (512 is the '
        + 'one-image hero preview, on demand)',
      warm.gunSizes.length === 1 && warm.gunSizes[0] === 128,
      'sizes=' + JSON.stringify(warm.gunSizes));
check('5d. NOT ONE requested path begins with a backslash (the silent-404 trap)',
      warm.backslashed.length === 0, JSON.stringify(warm.backslashed));
check('5b. every progress message is far inside webui.js\'s 10240 byte page->SQF cap',
      warm.maxBytes > 0 && warm.maxBytes < 10240, 'maxBytes=' + warm.maxBytes);
await A.page.close();

/* ---- RUN 2: the landing bar ----------------------------------------------- */
const B = await newPage(browser, files);
await B.page.goto('file://' + path.join(HTML, 'landing.html'), { waitUntil: 'load' });
await B.page.waitForFunction('window.WEBUI && window.WEBUI._emit', { timeout: 20000 }).catch(() => {});
await sleep(400);

const push = (page, pct) => page.evaluate((pct) => {
  const payload = { name: 'HARNESS', players: 7, cap: 60, build: 'ALPHA  b0000', loadPct: pct,
                    factions: [{ id: 'solo', locked: false, note: '' },
                               { id: 'maxsec', locked: true, note: 'NOT WHITELISTED' },
                               { id: 'trauma', locked: true, note: 'NOT WHITELISTED' }] };
  window.WEBUI._emit('landing', btoa(unescape(encodeURIComponent(JSON.stringify(payload)))));
}, pct);
const shot = (page) => page.evaluate(() => ({
  pct: document.getElementById('pct').textContent,
  loadrow: document.getElementById('loadrow').className,
  play: document.getElementById('play').className,
  welcomeOff: document.getElementById('s-welcome').className.indexOf('off') >= 0,
  factionOff: document.getElementById('s-faction').className.indexOf('off') >= 0,
  bootErr: window.__apBootErr || null,
}));

await push(B.page, 0);   await sleep(120); const at0  = await shot(B.page);
await push(B.page, 37);  await sleep(120); const at37 = await shot(B.page);
await push(B.page, 3);   await sleep(120); const at3  = await shot(B.page);
await B.page.screenshot({ path: path.join(HERE, label + '-landing.png') });
await B.page.click('#play');
await sleep(200);
const clicked = await shot(B.page);
await push(B.page, 100); await sleep(120); const at100 = await shot(B.page);

check('6. the landing page renders the pushed loadPct verbatim',
      at0.pct === '0%' && at37.pct === '37%' && at3.pct === '3%' && at100.pct === '100%',
      [at0.pct, at37.pct, at3.pct, at100.pct].join(' -> '));
check('7. PLAY IS NOT GATED: lit at every value, including 3%',
      at0.play === 'ready' && at3.play === 'ready' && at100.play === 'ready',
      'at0=' + at0.play + ' at3=' + at3.play + ' at100=' + at100.play);
check('8. clicking PLAY at 3% advances to faction select',
      !at3.factionOff === false && clicked.welcomeOff && !clicked.factionOff,
      'before: welcomeOff=' + at3.welcomeOff + ' factionOff=' + at3.factionOff
        + ' | after: welcomeOff=' + clicked.welcomeOff + ' factionOff=' + clicked.factionOff);
check('9. the row still flips to its done state at 100',
      at100.loadrow === 'done' && at37.loadrow === '',
      'at37="' + at37.loadrow + '" at100="' + at100.loadrow + '"');
check('9b. the landing page boots with no page errors and no console errors',
      B.errors.length === 0 && !at100.bootErr,
      (B.errors.length ? B.errors.join(' | ') : 'none') + ' bootErr=' + at100.bootErr);
await B.page.close();
await browser.close();

/* ---- verdict -------------------------------------------------------------- */
const out = { label, expect: { files: EXPECT_FILES, tiles: EXPECT_TILES, icons: ICONS_ON_DISK,
                               guns: EXPECT_GUNS, total: EXPECT_TOTAL },
              warmErrors: A.errors, landingErrors: B.errors, warm,
              landing: { at0, at37, at3, clicked, at100 }, results };
fs.writeFileSync(path.join(HERE, label + '.json'), JSON.stringify(out, null, 2));
results.forEach(r => console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name}\n        ${r.detail}`));
const bad = results.filter(r => !r.ok).length;
console.log(`\n${results.length - bad}/${results.length} assertions passed`);
process.exit(bad === 0 ? 0 : 1);
