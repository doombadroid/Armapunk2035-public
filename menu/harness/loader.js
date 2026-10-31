// loader.js — fetches the pristine design source, applies validated patches,
// appends harness extensions, transforms with Babel, evaluates.
// Every patch asserts its needle occurs exactly once in the source; a miss
// throws (window.__loadError) instead of silently rendering a stale design.
//
// v2 design: background-only mode (ARMAPUNK_BG_ONLY), aspect/res tweaks and
// hint muting are native now — the only patches left are the chrome-off
// hooks for hint-only PAA bakes.
async function loadDesign() {
  const src = await (await fetch('../design/armapunk.jsx')).text();
  const patches = [
    // -- 60 s held-loop periodicity (imperceptible constant nudges; the live
    //    menu holds on a looping settled state, so every background period
    //    must divide 60 s -- see PIPELINE.md) --
    ['feedT * 3.4', 'feedT * (10/3)'],
    ['(gt * 44) % 74', '(gt * 44.4) % 74'],
    ['(gt * 120) % (H + 420)', '(gt * 125) % (H + 420)'],
    ['sp: 900 + hash(i + 80) * 520', 'sp: 23 * Math.round((900 + hash(i + 80) * 520) / 23)'],
    ['Math.sin(gt * 2.1)', 'Math.sin(gt * (Math.PI * 42 / 60))'],
    // Static engine overlays cannot shear with the video -- suppress frame
    // jitter in rendered variants (slivers stay; they do not move content).
    [
      'const jx = (hash(Math.floor(gt * 24)) - 0.5) * 24 * fx;',
      'const jx = window.__noJitter ? 0 : (hash(Math.floor(gt * 24)) - 0.5) * 24 * fx;',
    ],
    // BottomBar chrome-off mode for hint-only PAA bakes (layout preserved).
    [
      "borderTop: `1px solid ${A}44`, background: 'rgba(8,5,3,0.78)'",
      "borderTop: window.__bakeHintOnly ? 'none' : `1px solid ${A}44`, background: window.__bakeHintOnly ? 'transparent' : 'rgba(8,5,3,0.78)'",
    ],
    [
      "<div style={{ color: 'rgba(255,236,208,0.45)', letterSpacing: 2 }}>ARMAPUNK 2035 // BUILD 0.9.7-BETA</div>",
      "<div style={{ color: 'rgba(255,236,208,0.45)', letterSpacing: 2, visibility: window.__bakeHintOnly ? 'hidden' : 'visible' }}>ARMAPUNK 2035 // BUILD 0.9.7-BETA</div>",
    ],
    [
      "<div style={{ color: B, letterSpacing: 2, display: 'flex', gap: 14 }}>",
      "<div style={{ color: B, letterSpacing: 2, display: 'flex', gap: 14, visibility: window.__bakeHintOnly ? 'hidden' : 'visible' }}>",
    ],
  ];
  let out = src;
  for (const [needle, repl] of patches) {
    const n = out.split(needle).length - 1;
    if (n !== 1) throw new Error(`patch needle x${n} (want 1): ${needle.slice(0, 60)}`);
    out = out.replace(needle, repl);
  }

  const extra = await (await fetch('./app-extra.jsx')).text();
  const full = out + '\n' + extra;
  const js = Babel.transform(full, {
    presets: [['react', { runtime: 'classic', pragma: 'React.createElement', pragmaFrag: 'React.Fragment' }]],
  }).code;
  new Function(js)();
  const root = document.getElementById('root');
  ReactDOM.createRoot(root).render(React.createElement(window.HarnessApp));
}
loadDesign()
  .then(() => (window.__loaded = true))
  .catch((e) => {
    window.__loadError = String(e && e.stack ? e.stack : e);
    console.error(e);
  });
