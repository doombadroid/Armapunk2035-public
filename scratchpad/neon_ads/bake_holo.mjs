// bake_holo.mjs — renders the 3D hologram crown textures (3 designs x 3
// frames, 1024x1024 RGBA with TRANSPARENT background) used by the billboard
// holo layer in custom_p3ds/malden_neon.sqf. The planes carry an
// emissive rvmat in-game, so everything here should read as pure light:
// bright saturated strokes on nothing.
//   NODE_PATH=~/Armapunk2035-menu/menu/node_modules node bake_holo.mjs
//   python3 holo_to_paa.py
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { mkdir, writeFile } from 'fs/promises';

const here = dirname(fileURLToPath(import.meta.url));
const PINK = '#ff2a6d', CYAN = '#05d9e8';

const HOLOS = [
  { id: 'holo_drachma', glyph: '&#8367;', label: 'NEW DRACHMA', sub: 'ND//35', accent: CYAN },
  { id: 'holo_apk', glyph: 'A', label: 'ARMAPUNK 2035', sub: 'MALDEN GRID', accent: PINK },
  { id: 'holo_chrome', glyph: '&#10013;', label: 'CHROME UP', sub: 'RIPPERDOC CERT.', accent: CYAN },
];

// frame 0 = steady, 1 = surge, 2 = glitch (RGB split + sliced)
const html = (h, f) => {
  const glow = [2.2, 3.2, 1.6][f];
  const dim = [1, 1, 0.82][f];
  const other = h.accent === PINK ? CYAN : PINK;
  const split = f === 2 ? `text-shadow:-6px 0 ${CYAN},6px 0 ${PINK},0 0 ${28 * glow}px ${h.accent};` : '';
  const slice = f === 2 ? `clip-path:polygon(0 0,100% 0,100% 38%,3% 38%,3% 42%,100% 42%,100% 100%,0 100%);transform:translateX(8px);` : '';
  return `<!doctype html><html><head><meta charset="utf-8">
  <link rel="stylesheet" href="./fonts/fonts.css">
  <style>
    html,body { margin:0; width:1024px; height:1024px; overflow:hidden; background:transparent; }
    .wrap { position:absolute; inset:0; opacity:${dim};
      /* scanlines must CUT alpha, not paint black, so they live in a mask */
      -webkit-mask-image:repeating-linear-gradient(0deg, #000 0 12px, rgba(0,0,0,.78) 12px 16px);
      mask-image:repeating-linear-gradient(0deg, #000 0 12px, rgba(0,0,0,.78) 12px 16px); }
    .ring { position:absolute; left:112px; top:112px; width:800px; height:800px;
      border-radius:50%; border:14px solid ${h.accent};
      box-shadow:0 0 ${34 * glow}px ${h.accent}, 0 0 ${90 * glow}px ${h.accent}, inset 0 0 ${34 * glow}px ${h.accent}; opacity:.95; }
    .ring2 { position:absolute; left:172px; top:172px; width:680px; height:680px;
      border-radius:50%; border:3px dashed ${other}; opacity:.6; }
    .tick { position:absolute; left:52px; top:502px; width:920px; height:26px;
      background:repeating-linear-gradient(90deg, ${h.accent} 0 7px, transparent 7px 46px); opacity:.7; }
    .glyph { position:absolute; inset:0; display:flex; align-items:center; justify-content:center;
      font-family:Michroma; font-size:470px; color:#ffffff; -webkit-text-stroke:8px #ffffff; ${slice}
      text-shadow:0 0 6px #ffffff, 0 0 ${24 * glow}px ${h.accent}, 0 0 ${60 * glow}px ${h.accent}, 0 0 ${120 * glow}px ${h.accent}; ${split} }
    .label { position:absolute; left:0; right:0; top:836px; text-align:center;
      font-family:'Space Mono',monospace; font-size:58px; font-weight:bold; letter-spacing:16px; color:#ffffff;
      text-shadow:0 0 4px #fff, 0 0 ${20 * glow}px ${h.accent}, 0 0 ${48 * glow}px ${h.accent}; }
    .sub { position:absolute; left:0; right:0; top:118px; text-align:center;
      font-family:'Space Mono',monospace; font-size:34px; letter-spacing:10px; color:${other};
      text-shadow:0 0 ${12 * glow}px ${other}; }
  </style></head><body>
  <div class="wrap">
    <div class="ring"></div><div class="ring2"></div><div class="tick"></div>
    <div class="glyph">${h.glyph}</div>
    <div class="sub">${h.sub}</div>
    <div class="label">${h.label}</div>
  </div>
  </body></html>`;
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
await mkdir(join(here, 'png'), { recursive: true });
for (const h of HOLOS) {
  for (let f = 0; f < 3; f++) {
    await writeFile(join(here, '_holo.html'), html(h, f));
    await page.goto('file://' + join(here, '_holo.html'), { waitUntil: 'load' });
    await page.evaluate(async () => {
      await Promise.all([
        document.fonts.load('430px Michroma', 'A'),
        document.fonts.load("54px 'Space Mono'", 'ND//35'),
      ]);
      await document.fonts.ready;
    });
    const ok = await page.evaluate(`[...document.fonts].filter(f => f.status === 'loaded' && f.family.includes('Michroma')).length`);
    if (!ok) throw new Error('Michroma failed to load');
    await page.screenshot({ path: join(here, 'png', `${h.id}_f${f}.png`), omitBackground: true });
  }
  console.log(h.id, 'x3');
}
await browser.close();
