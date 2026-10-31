// skinlab/render.mjs -- see an HTML skin without launching Arma.
//
//   node scratchpad/skinlab/render.mjs [skin ...]        (default: every page in the server's skins/)
//
// Owns the page's runtime surface (the design-handoff rule): the ONE thing a skin page asks the
// engine for is A3API.RequestTexture(<paa path>), and the harness answers it from
// scratchpad/skinlab/textures/<basename>.png as a data URL -- the same base sheet the engine would
// hand it. Then it waits for the page to settle, screenshots the 1024 canvas, and writes
//   out/<skin>_page.png      what the texture IS
//   out/<skin>_over.png      the page over the base sheet at 50%, seams drawn -- "does it follow
//                            the islands?"
// The composite is done in Python (compose.py) after this; this file only produces _page.png.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const puppeteer = require('/home/timb/.npm/_npx/ab5cd9f6d13a2312/node_modules/puppeteer');

const HERE = path.dirname(new URL(import.meta.url).pathname);
const SKINS = path.resolve(HERE, '../../server/AP_server/web/ui/html/skins');
const TEX = path.join(HERE, 'textures');
const OUT = path.join(HERE, 'out');
fs.mkdirSync(OUT, { recursive: true });

// paa path -> PNG data URL, by basename, lowercase. Missing = reject, like a bad path in game.
const texMap = {};
for (const f of fs.readdirSync(TEX)) if (f.endsWith('.png'))
  texMap[f.slice(0, -4).toLowerCase()] = 'data:image/png;base64,' + fs.readFileSync(path.join(TEX, f)).toString('base64');

const wanted = process.argv.slice(2);
const pages = fs.readdirSync(SKINS).filter(f => f.endsWith('.html')).map(f => f.slice(0, -5))
  .filter(id => !wanted.length || wanted.includes(id));

const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-gpu'] });
for (const id of pages) {
  const page = await browser.newPage();
  await page.setViewport({ width: 1024, height: 1024, deviceScaleFactor: 1 });
  await page.evaluateOnNewDocument((texMap) => {
    window.A3API = {
      RequestTexture: (p, max) => {
        const key = p.replace(/\\/g, '/').split('/').pop().replace(/\.paa$/i, '').toLowerCase();
        return key in texMap ? Promise.resolve(texMap[key]) : Promise.reject(new Error('no such texture in skinlab/textures: ' + key));
      },
      RequestFile: () => Promise.reject(new Error('harness')),
      SendAlert: () => {}, SendConfirm: () => Promise.resolve(false),
    };
  }, texMap);
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto('file://' + path.join(SKINS, id + '.html'));
  await new Promise(r => setTimeout(r, 1800));   // base sheet decode + a second of animation
  const readyTxt = await page.evaluate(() => document.title);
  await page.screenshot({ path: path.join(OUT, id + '_page.png'), clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  console.log(`${id.padEnd(16)} rendered${errs.length ? '  JS ERRORS: ' + errs.join(' | ') : ''}`);
  await page.close();
}
await browser.close();
