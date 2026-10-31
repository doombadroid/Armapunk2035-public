// render.mjs — deterministic captures of the main-menu design (v2: pink/blue,
// 3 items, aspect variants, background-only video master).
//   --check            load + font gate + reference stills (16:9 full design)
//   --bake             overlay-texture shots + measured layout.json (16:9, scale 1)
//   --frames intro169|intro219   background-only design t=0..10s (plays once)
//   --frames loop169|loop219     held-state loop t=10..70s (glitch-burst edges)
import { chromium } from 'playwright';
import { fileURLToPath } from 'url';
import { dirname, join, extname } from 'path';
import { createServer } from 'http';
import { readFile, mkdir, writeFile } from 'fs/promises';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, 'out');
const FPS = 30;
const LOOP = 15;

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.jsx': 'text/plain', '.css': 'text/css', '.woff2': 'font/woff2' };
const server = createServer(async (req, res) => {
  try {
    const p = join(here, decodeURIComponent(new URL(req.url, 'http://x').pathname));
    if (!p.startsWith(here)) throw new Error('path escape');
    const body = await readFile(p);
    res.writeHead(200, { 'content-type': MIME[extname(p)] || 'application/octet-stream' });
    res.end(body);
  } catch { res.writeHead(404); res.end(); }
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch({ args: ['--force-color-profile=srgb'] });

async function openPage(cfg, vw, vh) {
  const page = await browser.newPage({ viewport: { width: vw, height: vh } });
  page.on('console', (m) => m.type() === 'error' && console.log('PAGE-ERR:', m.text()));
  page.on('pageerror', (e) => console.log('PAGE-EXC:', String(e)));
  await page.addInitScript((c) => { window.__HARNESS_CFG = c; }, cfg);
  await page.goto(base + '/harness/index.html');
  await page.waitForFunction('window.__loaded === true || !!window.__loadError', null, { timeout: 30000 });
  const err = await page.evaluate('window.__loadError');
  if (err) { console.error('LOAD ERROR:\n' + err); process.exit(1); }
  await page.evaluate(async () => {
    const faces = ['116px Michroma', '29px Michroma', '21px "Space Mono"', '700 21px "Space Mono"'];
    await Promise.all(faces.map((f) => document.fonts.load(f, 'ARMAPUNK2035//>█▮')));
    await document.fonts.ready;
  });
  const loadedFonts = await page.evaluate(`[...document.fonts].filter(f => f.status === 'loaded').length`);
  if (loadedFonts < 3) { console.error(`FONT GATE: only ${loadedFonts} faces loaded`); process.exit(1); }
  return page;
}
const seek = (page, t) => page.evaluate((tt) => window.__seek(tt), t);
const shot = (page, path, transparent = false) =>
  page.screenshot({ path, omitBackground: transparent, animations: 'disabled' });

const mode = process.argv[2] || '--check';
await mkdir(out, { recursive: true });

if (mode === '--check') {
  const page = await openPage({ bgOnly: false, aspect: '16:9', res: '1080p' }, 1920, 1080);
  await seek(page, 8.5);
  await shot(page, join(out, 'check_t8.5.png'));
  const bg = await openPage({ bgOnly: true, aspect: '21:9', res: '1080p' }, 2580, 1080);
  await seek(bg, 8.5);
  await shot(bg, join(out, 'check_bg219_t8.5.png'));
  console.log('OK -> out/check_t8.5.png + out/check_bg219_t8.5.png');
}

if (mode === '--bake') {
  const page = await openPage({ bgOnly: false, aspect: '16:9', res: '1080p' }, 1920, 1080);
  await page.evaluate(() => {
    window.__transparent = true;
    document.documentElement.style.background = 'transparent';
    document.body.style.background = 'transparent';
  });
  let bakeSeq = 0;
  const bake = async (custom, bakeArgs, name) => {
    await page.evaluate(([c, b]) => {
      window.__custom = window.__customs[c];
      window.__bake = b;
      window.__bakeHintOnly = c === 'bakeHint';
    }, [custom, bakeArgs]);
    // unique t per shot so React re-commits; 99.x keeps armed-blink visible
    await seek(page, 99.1 + 0.004 * bakeSeq++);
    await shot(page, join(out, `bake_${name}.png`), true);
  };
  await bake('bakeMenu', { sel: -1, pulse: 0 }, 'menu_dim');
  const layout = { rows: await page.evaluate(`window.__measure('menu')`) };
  for (let k = 0; k < 3; k++) await bake('bakeMenu', { sel: k, pulse: 0 }, `menu_sel_${k}`);
  for (let k = 0; k < 3; k++) await bake('bakeMenu', { sel: k, pulse: 1 }, `menu_pulse_${k}`);
  for (let k = 0; k < 3; k++) await bake('bakeHint', { sel: k, arm: false }, `hint_${k}`);
  await bake('bakeHint', { sel: 2, arm: true }, 'hint_armed');
  layout.hint = await page.evaluate(`window.__measure('hint')`);
  await writeFile(join(out, 'layout.json'), JSON.stringify(layout, null, 2));
  const rows = layout.rows;
  if (rows.length !== 3 || rows.some((r) => Math.round(r.h) !== 62)) throw new Error('row geometry drifted: ' + JSON.stringify(rows));
  console.log('OK 11 bake shots + layout.json');
}

if (mode === '--frames') {
  const which = process.argv[3];
  const spec = {
    intro169: { aspect: '16:9', vw: 1920, t0: 0, dur: 10, held: false },
    intro219: { aspect: '21:9', vw: 2580, t0: 0, dur: 10, held: false },
    loop169: { aspect: '16:9', vw: 1920, t0: 10, dur: 60, held: true },
    loop219: { aspect: '21:9', vw: 2580, t0: 10, dur: 60, held: true },
  }[which];
  if (!spec) throw new Error('which: intro169|intro219|loop169|loop219');
  const page = await openPage({ bgOnly: true, aspect: spec.aspect, res: '1080p' }, spec.vw, 1080);
  await page.evaluate((held) => {
    window.__noJitter = true; // engine overlays can't shear with the video
    if (held) window.__custom = window.__customs.held;
  }, spec.held);
  const dir = join(out, 'frames', which);
  await mkdir(dir, { recursive: true });
  const n = spec.dur * FPS;
  for (let i = 0; i < n; i++) {
    await seek(page, spec.t0 + i / FPS);
    await shot(page, join(dir, `f${String(i).padStart(4, '0')}.png`));
    if (i % 300 === 0) console.log(`${which} ${i}/${n}`);
  }
  await seek(page, spec.t0 + spec.dur); // wrap/cut reference for the gates
  await shot(page, join(dir, 'seam_end.png'));
  console.log(`OK ${n} frames -> ${dir}`);
}

await browser.close();
server.close();
