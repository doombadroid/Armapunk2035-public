// Offline reproduction of the JS half of webui_fnc_serve against the REAL deck page.
//
// Run:  node scratchpad/serve_harness/serve_harness.mjs
// Needs puppeteer (this box: the npx cache path below; elsewhere `npm i puppeteer`
// and point the require at it) -- it launches its own bundled Chrome.
//
// 2026-09-02 result: all five scenarios pass (served document boots, subscribes,
// receives the phone channel, no WAITING placeholder, no JS errors). To make the
// served copy distinguishable, stamp server/AP_server/web/ui/html/deck.html
// (PAGE_BUILD) and drop a one-shot WEBUI.call("log", ...) into its "phone"
// handler; the PBO copy stays as shipped. Revert the stamp afterwards, or the
// handshake will ship that page to every client.
// Loads mission/ui/html/deck.html (the PBO baseline) in headless Chrome with an
// A3API stub, lets its self-boot stub pull the real webui.js, then emulates what
// SQF does on a deck open: wait for HELLO, _setRoot, push the phone channel, and
// _serve() the instrumented server copy. Reports whether the served document
// (a) came up (PAGE_BUILD), (b) subscribed and received the phone channel, and
// (c) left the WAITING placeholder behind.
import { createRequire } from 'module';
import fs from 'fs';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const MISSION = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden';
const OUT = new URL('.', import.meta.url).pathname;   // screenshots land beside this file
const webuiJs = fs.readFileSync(MISSION + '/webui/ui/webui.js', 'utf8');
const pboUrl = 'file://' + MISSION + '/ui/html/deck.html';
const servedHtml = fs.readFileSync('/home/timb/Armapunk2035/server/AP_server/web/ui/html/deck.html', 'utf8');

// Engine ToBase64 encodes the UTF-8 bytes; fn_push/_apply feed it toJSON output.
const b64 = (s) => Buffer.from(s, 'utf8').toString('base64');
const j = (v) => JSON.stringify(v);

const app = (id, cat, glyph) => ({ id, name: id, cat, glyph, badge: '' });
const phonePayload = {
  side: 'civ', restart: '45m', batt: 87, cash: 1234, bank: 56789, clock: '12:34',
  apps: [app('Phone', 'comms', 'phone'), app('Message', 'comms', 'message'), app('My Gang', 'gang', 'mygang'),
         app('Market', 'economy', 'market'), app('Map', 'system', 'map'), app('Settings', 'system', 'settings')],
  favs: [{ id: 'ICEBREAKER OS', name: 'ICEBREAKER OS', glyph: 'cyberdeck', sub: '', hero: true },
         { id: 'Market', name: 'Market', glyph: 'market', sub: '', hero: false },
         { id: 'Keychain', name: 'Keychain', glyph: 'keychain', sub: '2 KEYS', hero: false }],
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function scenario(name, steps) {
  const browser = await puppeteer.launch({ headless: true, args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 2040, height: 1020 });
  const alerts = [];   // every page -> SQF message, in order
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + (e && e.message || e)));
  page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errors.push('console.' + m.type() + ': ' + m.text()); });

  // SQF side of the JSDialog handler: answer CALLs the way fn_init + the deck's handlers would.
  await page.exposeFunction('__harnessAlert', (msg) => {
    alerts.push(msg);
    let req; try { req = JSON.parse(msg); } catch { return; }
    if (!Array.isArray(req) || req[0] !== 'CALL') return;
    const [, id, fname] = req;
    let reply;
    switch (fname) {
      case 'log': reply = { ok: true, msg: '' }; break;
      case 'refresh': reply = { ok: true, msg: '' }; break;
      case 'qh': reply = []; break;
      case 'settingsGet': reply = {}; break;
      default: reply = null;
    }
    // Asynchronous, like the spawned SQF handler + ExecJS leg.
    setTimeout(() => {
      page.evaluate((id, b) => { window.WEBUI && WEBUI._resolve(id, true, b); }, id, b64(j(reply))).catch(() => {});
    }, 15);
  });

  await page.evaluateOnNewDocument((src) => {
    window.A3API = {
      SendAlert: (m) => { window.__harnessAlert(String(m)); },
      SendConfirm: () => Promise.resolve(true),
      RequestFile: (p) => Promise.resolve(/webui\.js$/i.test(String(p)) ? src : ''),
      RequestPreprocessedFile: () => Promise.resolve(''),
      RequestTexture: () => Promise.resolve('data:image/png;base64,' + 'A'.repeat(400)),
    };
  }, webuiJs);

  await page.goto(pboUrl, { waitUntil: 'load' });

  // webui_fnc_init: hold until HELLO proves the bridge, then drain.
  const t0 = Date.now();
  while (!alerts.some((a) => a.startsWith('["HELLO"')) && Date.now() - t0 < 5000) await sleep(20);
  const hello = alerts.some((a) => a.startsWith('["HELLO"'));
  await page.evaluate((b) => { window.WEBUI && WEBUI._setRoot(b); }, b64(j('mpmissions\\__CUR_MP.Malden\\')));

  const exec = (js) => page.evaluate((s) => { try { eval(s); return true; } catch (e) { return 'THREW ' + e.message; } }, js);
  const PUSH = `window.WEBUI && WEBUI._emit('phone','${b64(j(phonePayload))}');`;
  const SERVE = `window.WEBUI && WEBUI._serve('${b64(j(servedHtml))}');`;

  const log = [];
  for (const step of steps) {
    if (step === 'push') log.push('push -> ' + await exec(PUSH));
    else if (step === 'serve') log.push('serve -> ' + await exec(SERVE));
    else if (step === 'batch:serve,push') log.push('batch serve;push -> ' + await exec(SERVE + '\n' + PUSH));
    else if (step === 'batch:push,serve') log.push('batch push;serve -> ' + await exec(PUSH + '\n' + SERVE));
    else if (typeof step === 'number') await sleep(step);
  }

  const state = await page.evaluate(async () => {
    const readyRace = await Promise.race([
      (window.WEBUIReady || Promise.reject(new Error('no WEBUIReady'))).then(() => 'resolved'),
      new Promise((r) => setTimeout(() => r('PENDING'), 500)),
    ]).catch((e) => 'rejected: ' + e.message);
    return {
      build: typeof PAGE_BUILD !== 'undefined' ? PAGE_BUILD : 'ABSENT',
      probePhone: !!window.__probePhone,
      getPhone: !!(window.WEBUI && WEBUI.get('phone')),
      waitingPlaceholder: /WAITING FOR THE HANDSET/.test(document.body ? document.body.innerText : ''),
      readyPromise: readyRace,
      href: location.href.slice(0, 40),
      bodyChars: document.body ? document.body.innerHTML.length : -1,
    };
  });
  await page.screenshot({ path: `${OUT}/${name}.png` });
  await browser.close();

  const calls = alerts.filter((a) => a.startsWith('["CALL"')).map((a) => { try { const r = JSON.parse(a); return r[2] + (r[2] === 'log' ? ': ' + String(r[3][0]).slice(0, 90) : ''); } catch { return a.slice(0, 60); } });
  console.log(`\n=== ${name} ===`);
  console.log('hello:', hello, '| steps:', log.join(' | '));
  console.log('state:', j(state));
  console.log('page->SQF calls:', j(calls));
  if (errors.length) console.log('errors:', j(errors.slice(0, 8)));
}

await scenario('A_push_then_serve', ['push', 300, 'serve', 2000]);
await scenario('B_serve_then_push', ['serve', 2000, 'push', 800]);
await scenario('C_batch_serve_push', ['batch:serve,push', 2000]);
await scenario('D_batch_push_serve', ['batch:push,serve', 2000]);
await scenario('E_pbo_only_control', ['push', 1500]);
