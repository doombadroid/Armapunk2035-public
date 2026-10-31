// Chromium checks for the production death screen (ui/html/death.html).
//
//   node scratchpad/death_harness/check_death.mjs
//
// Writes death_<w>x<h>.png beside this file and prints a PASS/FAIL table.
//
// WHAT THIS CAN AND CANNOT PROVE. It drives the page through its OWN standalone
// stub and through pushes shaped like the real ones, so it proves composition,
// wiring and state rendering. It does NOT touch SQF: the bridge, both clocks, the
// cooldowns, the corpse camera behind a transparent surface and every lifecycle
// transition are in-game checks and are reported separately. A green run here is
// not a claim about the game.
//
// The layout assertions are the approved-design acceptance criteria, mechanised:
// FLATLINED. must be ONE LINE (one client rect, no wrap) at 1080p and ultrawide,
// the console must not overlap the headline, and nothing may overflow sideways.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE = new URL('.', import.meta.url).pathname;
const PAGE = '/home/timb/Armapunk2035/mission/Armapunk2035.Malden/ui/html/death.html';

const results = [];
const ok = (name, pass, detail) => results.push({ name, pass: !!pass, detail: detail ?? '' });

const browser = await puppeteer.launch({
  headless: 'new',
  args: ['--no-sandbox', '--disable-lcd-text', '--force-device-scale-factor=1'],
});

// A payload shaped exactly like AP_fnc_deathState's, pushed through the page's own
// stub bus so the real subscriber path runs.
const push = (page, patch) => page.evaluate((p) => {
  Object.assign(window.__stubState, p);
  window.__bus._push('death', window.__stubState);
}, patch);

for (const [w, h, label] of [[1920, 1080, '1920x1080'], [3440, 1440, '3440x1440'], [1280, 800, '1280x800']]) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  await page.setViewport({ width: w, height: h, deviceScaleFactor: 1 });
  await page.goto('file://' + PAGE, { waitUntil: 'load' });
  // expose the stub bus so the harness can push authoritative-shaped state
  await page.evaluate(() => {
    const orig = window.__webuiReady;
    // the page already resolved; grab the bus off the resolved promise instead
    return window.WEBUIReady.then(b => { window.__bus = b; });
  });
  await new Promise(r => setTimeout(r, 400));

  const geo = await page.evaluate(() => {
    const t = document.querySelector('.large-title');
    const p = document.querySelector('.panel');
    const tr = t.getBoundingClientRect(), pr = p.getBoundingClientRect();
    // The headline's own text node, not the block: rect count is the wrap test.
    const rng = document.createRange();
    rng.setStart(t.firstChild, 0);
    rng.setEnd(t.firstChild, t.firstChild.length);
    const lines = rng.getClientRects().length;
    return {
      text: t.firstChild.textContent,
      lines,
      overlap: !(tr.right <= pr.left || pr.right <= tr.left || tr.bottom <= pr.top || pr.bottom <= tr.top),
      titleRight: Math.round(tr.right), panelLeft: Math.round(pr.left),
      panelW: Math.round(pr.width), panelH: Math.round(pr.height),
      scrollW: document.documentElement.scrollWidth, clientW: document.documentElement.clientWidth,
      fontPx: Math.round(parseFloat(getComputedStyle(t).fontSize)),
      nowrap: getComputedStyle(t).whiteSpace === 'nowrap',
      titleShadow: getComputedStyle(t).textShadow,
      subShadow: getComputedStyle(t.querySelector('small')).textShadow,
    };
  });

  ok(`${label} no JS errors`, errors.length === 0, errors.join(' | '));
  ok(`${label} headline text is FLATLINED.`, geo.text === 'FLATLINED.', geo.text);
  ok(`${label} FLATLINED. on ONE line`, geo.lines === 1, `${geo.lines} line box(es), nowrap=${geo.nowrap}, ${geo.fontPx}px`);
  ok(`${label} console does not overlap headline`, !geo.overlap,
     `title right ${geo.titleRight} vs panel left ${geo.panelLeft}`);
  ok(`${label} no horizontal overflow`, geo.scrollW <= geo.clientW,
     `scrollWidth ${geo.scrollW} vs clientWidth ${geo.clientW}`);
  ok(`${label} console readable width`, geo.panelW >= 320 && geo.panelH >= 320, `${geo.panelW}x${geo.panelH}`);
  /* Both lines of the left block sit directly on the death camera with no panel
     behind them, so each needs its own legibility treatment. Asserted because it is
     invisible in a white-background screenshot and easy to strip by accident. */
  ok(`${label} headline+subtitle carry a shadow over the camera`,
     geo.titleShadow !== 'none' && geo.subShadow !== 'none',
     `title=${geo.titleShadow} sub=${geo.subShadow}`);

  /* SCREENSHOT OVER A STAND-IN CAMERA, not over Chromium's white page. The page
     body is transparent because the real backdrop is the corpse camera; shot
     against white it looks nothing like what a player sees, and the legibility
     question the composition actually has to answer -- pale headline over a bright
     daytime Malden -- is invisible. This paints a mid-tone gradient behind the
     document purely for the capture and removes it again. */
  await page.evaluate(() => {
    const d = document.createElement('div');
    d.id = '__camstandin';
    d.style.cssText = 'position:fixed;inset:0;z-index:-1;background:' +
      'linear-gradient(160deg,#8fa3b5 0%,#5d6f63 38%,#2b332c 72%,#12160f 100%)';
    document.body.appendChild(d);
  });
  await page.screenshot({ path: path.join(HERE, `death_${label}.png`) });
  await page.evaluate(() => { const d = document.getElementById('__camstandin'); if (d) d.remove(); });
  if (label === '1920x1080') {
    // ---- state rendering, on the widest realistic frame ----
    const read = () => page.evaluate(() => ({
      timer: document.querySelector('#timer').textContent,
      timerLabel: document.querySelector('#timerLabel').textContent,
      online: document.querySelector('#online').textContent,
      nearest: document.querySelector('#nearest').textContent,
      status: document.querySelector('#status').textContent,
      headline: document.querySelector('#headline').textContent,
      request: { t: document.querySelector('#request').textContent, d: document.querySelector('#request').disabled },
      allow: { t: document.querySelector('#allow').textContent, d: document.querySelector('#allow').disabled },
      respawn: { t: document.querySelector('#respawn').textContent, d: document.querySelector('#respawn').disabled },
      confirmHidden: document.querySelector('#confirm').hidden,
      question: document.querySelector('#question').textContent,
    }));

    await push(page, { stage: 'lock', remain: 36, canRespawn: false, paused: false, nearest: 842, online: 3 });
    await new Promise(r => setTimeout(r, 120));
    let v = await read();
    ok('lock stage: respawn disabled', v.respawn.d, JSON.stringify(v.respawn));
    ok('lock stage: label is RESPAWN UNLOCKS IN', v.timerLabel === 'RESPAWN UNLOCKS IN', v.timerLabel);
    ok('lock stage: distance in metres', v.nearest === '842 m', v.nearest);

    await push(page, { nearest: -1 });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('no responders renders None (not 0 m)', v.nearest === 'None', v.nearest);

    await push(page, { stage: 'bleed', remain: 1800, canRespawn: true, nearest: 842 });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('bleed stage: respawn enabled', !v.respawn.d, JSON.stringify(v.respawn));
    ok('bleed stage: label is BLEEDOUT REMAINING', v.timerLabel === 'BLEEDOUT REMAINING', v.timerLabel);

    // request -> confirm -> verb
    await page.click('#request');
    v = await read();
    ok('request asks for confirmation', !v.confirmHidden && /Trauma Team/.test(v.question), v.question);
    await page.click('#no');
    v = await read();
    ok('cancel closes the confirmation and sends nothing', v.confirmHidden && !v.request.d, JSON.stringify(v.request));

    await page.click('#request'); await page.click('#yes');
    await new Promise(r => setTimeout(r, 250));
    v = await read();
    ok('confirmed request disables BOTH medical actions', v.request.d && v.allow.d,
       `${v.request.t} / ${v.allow.t}`);
    ok('request cooldown is shown on the button', /Request sent/.test(v.request.t), v.request.t);

    // paused
    await push(page, { paused: true });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('paused shows PAUSED, not a countdown', v.timer === 'PAUSED', v.timer);
    ok('paused headline is the revive line', /Stay with us/.test(v.headline), v.headline);
    ok('paused leaves respawn available (documented deviation)', !v.respawn.d, JSON.stringify(v.respawn));
    await page.click('#respawn');
    v = await read();
    ok('respawn confirm warns a medic is working', /medic is working/.test(v.question), v.question);
    await page.click('#no');

    // restricted (suicide vest). CLEARED FIRST: with the request cooldown from the
    // previous step still live, both buttons are already disabled and this check
    // would pass without the restriction doing anything at all.
    await push(page, { paused: false, restricted: false, canRequest: true, canAllow: true,
                       reqCd: 0, allowCd: 0, allowed: false, requested: false, reason: '' });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('control: actions are enabled before the restriction', !v.request.d && !v.allow.d,
       `${v.request.t} / ${v.allow.t}`);
    await push(page, { restricted: true, canRequest: false, canAllow: false,
                       reason: 'NO REMAINS TO TREAT -- MEDICAL CHANNEL CLOSED' });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('restricted disables both medical actions', v.request.d && v.allow.d, `${v.request.t} / ${v.allow.t}`);
    ok('restricted explains itself in the status area', /MEDICAL CHANNEL CLOSED/.test(v.status), v.status);

    // allow-only, from a clean state
    await push(page, { restricted: false, canRequest: true, canAllow: true, reason: '',
                       reqCd: 0, allowCd: 0, allowed: false, requested: false });
    await new Promise(r => setTimeout(r, 120));
    await page.click('#allow');
    await new Promise(r => setTimeout(r, 250));
    v = await read();
    ok('allow needs no confirmation and locks only itself', v.allow.d && !v.request.d,
       `${v.request.t} / ${v.allow.t}`);

    // ---- dragger (owner 2026-09-16, body dragging) ----
    // CLEAN SLATE FIRST. The stub's deathRequest above left responder="TT Medic Voss"
    // in the shared state, and the allow step left a cooldown; either would change
    // which idle line wins and let a precedence check pass for the wrong reason.
    await push(page, { stage: 'bleed', paused: false, restricted: false, reason: '', responder: '',
                       dragger: '', reqCd: 0, allowCd: 0, allowed: false, requested: false,
                       canRequest: true, canAllow: true });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('dragger control: no drag line before any drag', !/BEING MOVED/.test(v.status), v.status);

    await push(page, { dragger: 'Voss' });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('dragger: status says BEING MOVED BY VOSS', v.status.includes('YOUR BODY IS BEING MOVED BY VOSS'), v.status);

    await push(page, { dragger: '' });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('dragger "": the drag line is gone within one push', !/BEING MOVED/.test(v.status), v.status);

    await push(page, { dragger: 'Voss', paused: true });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('paused + dragger: medic-attending line wins',
       /Medic attending/.test(v.status) && !/BEING MOVED/.test(v.status), v.status);

    await push(page, { paused: false, dragger: 'Voss', reason: 'NO REMAINS TO TREAT -- MEDICAL CHANNEL CLOSED' });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('reason + dragger: reason wins',
       /MEDICAL CHANNEL CLOSED/.test(v.status) && !/BEING MOVED/.test(v.status), v.status);

    await push(page, { reason: '', dragger: 'Voss', responder: 'TT Medic Kade' });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('dragger outranks the responder line',
       v.status.includes('BEING MOVED BY VOSS') && !/en route/.test(v.status), v.status);

    // A player name is attacker-controlled text. It must land as literal characters:
    // no <b> element created, the entity not decoded, the tags merely upper-cased.
    await push(page, { responder: '', dragger: '<b>X</b>&amp;' });
    await new Promise(r => setTimeout(r, 120));
    const inj = await page.evaluate(() => {
      const el = document.querySelector('#status');
      return { text: el.textContent, kids: el.childElementCount, html: el.innerHTML };
    });
    ok('dragger name renders literally (no HTML injection)',
       inj.text === '● YOUR BODY IS BEING MOVED BY <B>X</B>&AMP;' && inj.kids === 0,
       `text=${inj.text} children=${inj.kids} html=${inj.html}`);

    // A client older than the served page sends no `dragger` key at all. The key is
    // DELETED in the page, not pushed as undefined: puppeteer's argument serialisation
    // drops undefined-valued keys, so push(page, {dragger: undefined}) arrives as {}
    // and silently changes nothing (measured 2026-09-16).
    await page.evaluate(() => {
      delete window.__stubState.dragger;
      window.__bus._push('death', window.__stubState);
    });
    await new Promise(r => setTimeout(r, 120));
    v = await read();
    ok('missing dragger key (older client) renders no drag line', !/BEING MOVED/.test(v.status), v.status);
    ok('dragger pushes raised no JS errors', errors.length === 0, errors.join(' | '));

    const rm = await page.evaluate(() => {
      const st = getComputedStyle(document.querySelector('.wave .trace'));
      return st.animationName;
    });
    ok('waveform animates by default', rm === 'trace', rm);
    await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
    const rm2 = await page.evaluate(() => getComputedStyle(document.querySelector('.wave .trace')).animationName);
    ok('reduced motion disables the animation', rm2 === 'none', rm2);
  }
  await page.close();
}
await browser.close();

const pad = (s, n) => (s + ' '.repeat(n)).slice(0, n);
let fail = 0;
for (const r of results) {
  if (!r.pass) fail++;
  console.log(`${r.pass ? 'PASS' : 'FAIL'}  ${pad(r.name, 52)} ${r.detail}`);
}
console.log(`\n-- ${results.length - fail} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
