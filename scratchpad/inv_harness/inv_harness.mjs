// Offline drive of ui/html/inventory.html against its own dev stub (§7 sample data).
//
// Run:  node scratchpad/inv_harness/inv_harness.mjs
// Needs puppeteer (this box: the npx cache path below; elsewhere `npm i puppeteer`
// and point the require at it) -- it launches its own bundled Chrome.
//
// What it proves (one PASS line each, exit 1 on any FAIL):
//   boot        first push rendered 3 container panels + 8 slot cards, no page errors
//   no-overflow no horizontal scroll at 1600x880 and 1280x704 (html and #frame)
//   gunsmith    double-click PRIMARY -> #gs visible with 4 sockets + the mag row
//   mount       drag the RCO fits row onto the optic socket -> stub saw invMount, socket = RCO,
//               backpack lost its RCO row
//   refuse      drag the Apple bag row onto the optic socket -> status strip = VIRTUAL string
//   search      typing "app" leaves only Apple in the bag
//   use         double-click Apple -> bagUse, qty 6 -> 5
//   tal         ?tal renders body.tal
// Screenshots land beside this file.
import { createRequire } from 'module';
import fs from 'fs';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const OUT = new URL('.', import.meta.url).pathname;
const url = 'file://' + MISSION + '/ui/html/inventory.html';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let fails = 0;
const ok = (name, cond, extra) => { console.log((cond ? 'PASS ' : 'FAIL ') + name + (extra ? '  ' + extra : '')); if (!cond) fails++; };

async function open(browser, w, h, q) {
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h });
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + (e && e.message || e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console.error: ' + m.text()); });
  await page.goto(url + (q || ''), { waitUntil: 'load' });
  await page.waitForFunction(() => document.querySelectorAll('#fig .slot').length === 9 && document.querySelectorAll('#cont-uniform .row').length > 0, { timeout: 5000 });
  await sleep(150);
  return { page, errors };
}
const center = async (page, sel) => {
  const b = await page.$eval(sel, (el) => { const r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; });
  return b;
};
async function drag(page, fromSel, toSel) {
  const a = await center(page, fromSel), b = await center(page, toSel);
  await page.mouse.move(a.x, a.y); await page.mouse.down();
  for (let i = 1; i <= 12; i++) { await page.mouse.move(a.x + (b.x - a.x) * i / 12, a.y + (b.y - a.y) * i / 12); await sleep(12); }
  await sleep(40);
  await page.mouse.up();
  await sleep(120);
}

const browser = await puppeteer.launch({ headless: true, args: ['--allow-file-access-from-files'] });
try {
  // ---- 1600x880 main pass
  let { page, errors } = await open(browser, 1600, 880);
  const boot = await page.evaluate(() => ({
    conts: document.querySelectorAll('#c2 > .panel:not([hidden])').length,
    slots: document.querySelectorAll('#fig .slot').length,
    filled: document.querySelectorAll('#fig .slot:not(.vacant)').length,
    msg: document.getElementById('msg').textContent,
    rem: getComputedStyle(document.documentElement).fontSize,
  }));
  ok('boot', boot.conts === 3 && boot.slots === 9 && boot.filled === 7 && boot.msg === 'READY' && errors.length === 0,
     JSON.stringify(boot) + (errors.length ? ' errors=' + JSON.stringify(errors) : ''));
  const ov = await page.evaluate(() => ({
    html: [document.documentElement.scrollWidth, document.documentElement.clientWidth],
    frame: [document.getElementById('frame').scrollWidth, document.getElementById('frame').clientWidth],
    body: [document.getElementById('bd').scrollHeight, document.getElementById('bd').clientHeight],
  }));
  ok('no-overflow-1600', ov.html[0] <= ov.html[1] && ov.frame[0] <= ov.frame[1] && ov.body[0] <= ov.body[1] + 1, JSON.stringify(ov));
  await page.screenshot({ path: OUT + 'shot-1600.png' });

  // the figure strip was reported for the native body camera: four fractions of the frame, sane size
  const fig = await page.evaluate(() => {
    const l = (AP.__log || []).filter((x) => x[0] === 'invFigureBox');
    const box = l.length ? l[l.length - 1].slice(1) : null;   // log entries are [name, ...args]
    document.body.classList.add('figlive');
    const hidden = getComputedStyle(document.querySelector('#fig svg.body')).visibility === 'hidden';
    document.body.classList.remove('figlive');
    return { n: l.length, box, hidden };
  });
  // [fx, fy, fw, fh] fractions of the viewport, then vw, vh, dpr, frameL, frameT, frameW, frameH (calibration tail)
  ok('figure-box', fig.n >= 1 && Array.isArray(fig.box) && fig.box.length === 11 && fig.box.slice(0, 4).every((v) => v > 0 && v < 1) && fig.box[2] > 0.1 && fig.box[2] < 0.2 && fig.box[3] > 0.4 && fig.box[4] === 1600 && fig.hidden, JSON.stringify(fig));

  // select a row -> SELECTED fills
  await page.click('#cont-vest .row');
  await sleep(80);
  const selName = await page.$eval('#sel .head .nm', (el) => el.textContent).catch(() => '');
  ok('select', selName.indexOf('5.56') === 0, selName);

  // gunsmith
  const prim = await center(page, '#fig .slot[data-slot="primary"]');
  await page.mouse.click(prim.x, prim.y, { clickCount: 2 });
  await page.waitForFunction(() => !document.getElementById('gs').hidden, { timeout: 3000 }).catch(() => {});
  await sleep(120);
  const gs = await page.evaluate(() => ({
    visible: !document.getElementById('gs').hidden,
    socks: document.querySelectorAll('#socks .sock:not(.mag)').length,
    mag: document.querySelector('#socks .sock.mag .sv').textContent,
    open: document.querySelectorAll('#fig .slot.open').length,
    sling: document.getElementById('sling').classList.contains('on'),
    fits: document.querySelectorAll('#fits .row').length,
    dimmed: document.getElementById('bag').classList.contains('dimmed'),
  }));
  ok('gunsmith', gs.visible && gs.socks === 4 && /23 \/ 30/.test(gs.mag) && gs.open === 1 && gs.sling && gs.fits === 3 && gs.dimmed, JSON.stringify(gs));
  await page.screenshot({ path: OUT + 'shot-gunsmith.png' });

  // mount RCO by drag onto the optic socket
  const rcoSel = await page.evaluate(() => { const r = Array.from(document.querySelectorAll('#fits .row')).find((e) => e.dataset.id.indexOf('optic_Hamr') > -1); return r ? '[data-key="' + r.dataset.key + '"]' : ''; });
  ok('fits-has-rco', !!rcoSel, rcoSel);
  await drag(page, '#fits ' + rcoSel, '#socks .sock[data-sock="optic"]');
  await sleep(150);
  const mount = await page.evaluate(() => ({
    log: AP.__log.filter((l) => l[0] === 'invMount').map((l) => l.join(',')),
    optic: document.querySelector('#socks .sock[data-sock="optic"] .sv').textContent,
    backpackHasRco: Array.from(document.querySelectorAll('#cont-backpack .row')).some((e) => e.dataset.id.indexOf('optic_Hamr') > -1),
    stubBackpack: AP.__st.cont.backpack.map((r) => r.cls),
    status: document.getElementById('msg').textContent,
  }));
  ok('mount', mount.log.length === 1 && mount.optic === 'RCO' && !mount.stubBackpack.includes('optic_Hamr') && mount.stubBackpack.includes('optic_Aco'), JSON.stringify(mount));

  // refused: bag row onto the socket
  await drag(page, '#bagList .row[data-id="apple"]', '#socks .sock[data-sock="optic"]');
  const refuse = await page.evaluate(() => ({ status: document.getElementById('msg').textContent, cls: document.getElementById('msg').className }));
  ok('refuse-virtual', refuse.status === "VIRTUAL ITEMS CAN'T BE MOUNTED. WITHDRAW IT FIRST." && /bad/.test(refuse.cls), JSON.stringify(refuse));

  // back out of the gunsmith
  await page.click('#gsBack');
  await page.waitForFunction(() => document.getElementById('gs').hidden, { timeout: 3000 }).catch(() => {});
  await sleep(100);
  const closed = await page.evaluate(() => ({ hidden: document.getElementById('gs').hidden, conts: document.querySelectorAll('#c2 > .panel:not([hidden])').length,
    backpackRows: Array.from(document.querySelectorAll('#cont-backpack .row')).map((e) => e.dataset.id) }));
  ok('gunsmith-close', closed.hidden && closed.conts === 3 && closed.backpackRows.some((i) => i.indexOf('optic_Aco') > -1), JSON.stringify(closed));

  // search
  await page.type('#bagSearch', 'app');
  await sleep(80);
  const search = await page.evaluate(() => Array.from(document.querySelectorAll('#bagList .row')).map((e) => e.dataset.id));
  ok('search', search.length === 1 && search[0] === 'apple', JSON.stringify(search));

  // use by double-click
  const apple = await center(page, '#bagList .row[data-id="apple"]');
  await page.mouse.click(apple.x, apple.y, { clickCount: 2 });
  await sleep(150);
  const used = await page.evaluate(() => ({ log: AP.__log.filter((l) => l[0] === 'bagUse').length, qty: AP.__st.bag.find((b) => b.id === 'apple').qty,
    mt: document.querySelector('#bagList .row[data-id="apple"] .mt').textContent }));
  ok('use', used.log === 1 && used.qty === 5 && /×5/.test(used.mt), JSON.stringify(used));

  // container move by drag: FAK uniform -> backpack
  await page.evaluate(() => { document.getElementById('bagSearch').value = ''; document.getElementById('bagSearch').dispatchEvent(new Event('input')); });
  await drag(page, '#cont-uniform .row', '#cont-backpack');
  const moved = await page.evaluate(() => ({ log: AP.__log.filter((l) => l[0] === 'invMove').map((l) => l.join(',')),
    uni: AP.__st.cont.uniform.map((r) => r.cls + 'x' + r.qty), bp: AP.__st.cont.backpack.map((r) => r.cls + 'x' + r.qty) }));
  ok('move-drag', moved.log.length === 1 && /uniform,uniform\|FirstAidKit\|-1,backpack,3/.test(moved.log[0]) && moved.uni.length === 0 && moved.bp.includes('FirstAidKitx3'), JSON.stringify(moved));

  // invalid drop: physical row onto the bag -> no call, no message
  const before = await page.evaluate(() => AP.__log.length);
  await drag(page, '#cont-vest .row', '#bag');
  const inval = await page.evaluate((b) => ({ calls: AP.__log.length - b, status: document.getElementById('msg').textContent }), before);
  ok('invalid-silent', inval.calls === 0, JSON.stringify(inval));

  ok('no-errors-1600', errors.length === 0, JSON.stringify(errors));
  await page.close();

  // ---- 1280x704
  ({ page, errors } = await open(browser, 1280, 704));
  const ov2 = await page.evaluate(() => ({
    html: [document.documentElement.scrollWidth, document.documentElement.clientWidth],
    frame: [document.getElementById('frame').scrollWidth, document.getElementById('frame').clientWidth],
    body: [document.getElementById('bd').scrollHeight, document.getElementById('bd').clientHeight],
  }));
  ok('no-overflow-1280', ov2.html[0] <= ov2.html[1] && ov2.frame[0] <= ov2.frame[1] && ov2.body[0] <= ov2.body[1] + 1, JSON.stringify(ov2));
  await page.screenshot({ path: OUT + 'shot-1280.png' });
  ok('no-errors-1280', errors.length === 0, JSON.stringify(errors));
  await page.close();

  // ---- tal
  ({ page, errors } = await open(browser, 1600, 880, '?tal'));
  const tal = await page.evaluate(() => ({ tal: document.body.classList.contains('tal'), side: document.getElementById('hSide').textContent }));
  ok('tal', tal.tal && tal.side === 'COP', JSON.stringify(tal));
  await page.screenshot({ path: OUT + 'shot-tal.png' });
  await page.close();
} finally {
  await browser.close();
}
console.log(fails ? 'FAILED ' + fails : 'ALL PASS');
process.exit(fails ? 1 : 0);
