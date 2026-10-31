// bake_neon_ads.mjs — renders the After-Dark billboard ads (4 ads x 3 frames,
// 1024x512) used by custom_p3ds/malden_neon.sqf. Fonts are the menu's
// OFL woff2s (fonts/). Deps: playwright — run with the menu worktree's
// node_modules, e.g.:
//   NODE_PATH=~/Armapunk2035-menu/menu/node_modules node bake_neon_ads.mjs
// then convert: python3 png_to_paa.py
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { mkdir, writeFile } from 'fs/promises';

const here = dirname(fileURLToPath(import.meta.url));
const PINK = '#ff2a6d', CYAN = '#05d9e8', INK = '#1c0b16';   // v3: night panels need self-luminous base, not ink

const ADS = [
  { id: 'ad_drachma', kicker: 'NEW DRACHMA', title: 'MINE THE FUTURE', tag: 'ND // ACCEPTED EVERYWHERE THAT MATTERS', accent: PINK },
  { id: 'ad_doomba', kicker: 'DOOMBA COLLECTIVE', title: 'THE FUTURE IS ALREADY BROKEN', tag: 'EST. 2035 // MALDEN', accent: CYAN },
  { id: 'ad_chrome', kicker: 'RIPPERDOC CERTIFIED', title: 'CHROME UP.', tag: 'STAY HUMAN(ISH) // CYBERWARE CLINIC', accent: PINK },
  { id: 'ad_darknet', kicker: 'MALDEN DARKNET', title: '47 OPERATORS ONLINE', tag: 'JACK IN // relay.malden-04', accent: CYAN },
];

// frame 0 = lit, 1 = surge (bright), 2 = brownout w/ RGB split
const fontCss = './fonts/fonts.css';
const html = (ad, f) => {
  const glow = [1.6, 2.4, 0.8][f];   // v3: brighter across all frames
  const dim = [1, 1, 0.62][f];
  const split = f === 2 ? `text-shadow: -4px 0 ${CYAN}, 4px 0 ${PINK};` : '';
  const other = ad.accent === PINK ? CYAN : PINK;
  return `<!doctype html><html><head><meta charset="utf-8">
  <link rel="stylesheet" href="${fontCss}">
  <style>
    html,body { margin:0; width:1024px; height:512px; overflow:hidden;
      background: radial-gradient(ellipse at 30% 35%, #2a1220 0%, ${INK} 55%, #12060e 100%); }
    .wrap { position:absolute; inset:0; font-family:'Space Mono',monospace; opacity:${dim}; }
    .frame { position:absolute; inset:14px; border:2px solid ${ad.accent}; opacity:.6;
             box-shadow:0 0 ${18 * glow}px ${ad.accent}; }
    .kicker { position:absolute; left:56px; top:64px; color:${other}; font-size:26px;
              letter-spacing:10px; text-shadow:0 0 ${10 * glow}px ${other}; }
    .title { position:absolute; left:52px; top:150px; width:920px; color:#fff8ea;
             font-family:Michroma; font-size:64px; line-height:1.14; letter-spacing:3px;
             text-shadow:0 0 ${14 * glow}px ${ad.accent}, 0 0 ${52 * glow}px ${ad.accent}; ${split} }
    .tag { position:absolute; left:56px; bottom:66px; color:${ad.accent}; font-size:23px;
           letter-spacing:5px; text-shadow:0 0 ${9 * glow}px ${ad.accent}; }
    .scan { position:absolute; inset:0; background:repeating-linear-gradient(0deg,
            rgba(0,0,0,.28) 0 3px, transparent 3px 7px); }
    .vig { position:absolute; inset:0; background:radial-gradient(ellipse at center,
           transparent 55%, rgba(0,0,0,.55)); }
  </style></head><body>
  <div class="wrap">
    <div class="frame"></div>
    <div class="kicker">${ad.kicker}</div>
    <div class="title">${ad.title}</div>
    <div class="tag">${ad.tag}</div>
  </div>
  <div class="scan"></div><div class="vig"></div>
  </body></html>`;
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 512 } });
await mkdir(join(here, 'png'), { recursive: true });
for (const ad of ADS) {
  for (let f = 0; f < 3; f++) {
    await writeFile(join(here, '_frame.html'), html(ad, f));
    await page.goto('file://' + join(here, '_frame.html'), { waitUntil: 'load' });
    await page.evaluate(async () => {
      // fonts.ready lies for lazily-used faces — force-load by name and verify
      await Promise.all([
        document.fonts.load("64px Michroma", "CHROME UP"),
        document.fonts.load("26px 'Space Mono'", "MALDEN //"),
      ]);
      await document.fonts.ready;
    });
    const ok = await page.evaluate(`[...document.fonts].filter(f => f.status === 'loaded' && f.family.includes('Michroma')).length`);
    if (!ok) throw new Error('Michroma failed to load');
    await page.screenshot({ path: join(here, 'png', `${ad.id}_f${f}.png`) });
  }
  console.log(ad.id, 'x3');
}
await browser.close();
