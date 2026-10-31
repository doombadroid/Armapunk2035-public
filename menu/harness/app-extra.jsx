// app-extra.jsx — appended to the (patched) design source in one Babel scope,
// so it can reuse the design's internal components verbatim.

// Held loop for the live menu: the settled post-intro state (logo lit, feed
// scrolling, hint muted — rows/hint are engine overlays). gt continues the
// intro's absolute clock, so grid/rain/feed/clock stay phase-continuous
// across the 10 s cut, and the loop runs t=10..70 with all periods dividing
// 60 s (loader patches). A glitch burst is baked at both loop edges so the
// engine's restart gap hides inside an on-theme glitch flash.
function HeldScene({ t }) {
  const g = MOTION.gate(t, 3, (window.TWEAK_DEFAULTS && window.TWEAK_DEFAULTS.glitch) || 1);
  const burst = Math.max(0, 1 - Math.abs(t - 10) / 0.3) + Math.max(0, 1 - Math.abs(t - 70) / 0.3);
  const fx = Math.min(1.1, g + burst * (0.55 + 0.45 * hash(Math.floor(t * 30))));
  return (
    <Frame power={1} fx={fx} label="Held">
      <LogoBlock lt={99} />
      <SidePanel lt={99} feedT={t - 6.9} />
      <Coords lt={99} />
      <BottomBar lt={99} sel={0} arm={false} mute={true} />
    </Frame>
  );
}

// PAA bake stages: bare elements on a transparent page (16:9, scale 1 — the
// layout manifest is measured in design px).
function BakeMenu() {
  const b = window.__bake || { sel: -1, pulse: 0 };
  return (
    <div style={{ position: 'absolute', inset: 0 }} data-bake="menu">
      <MenuListC lt={99} sel={b.sel} pulse={b.pulse} />
    </div>
  );
}
function BakeHint() {
  const b = window.__bake || { sel: 0, arm: false };
  return (
    <div style={{ position: 'absolute', inset: 0 }} data-bake="hint">
      <BottomBar lt={99} sel={b.sel} arm={b.arm} mute={false} />
    </div>
  );
}
window.__customs = { held: HeldScene, bakeMenu: BakeMenu, bakeHint: BakeHint };

// Rect reporting for crop + engine-layout generation (design-px == CSS px at
// scale 1).
window.__measure = (kind) => {
  const stage = document.getElementById('stage');
  const r0 = stage.getBoundingClientRect();
  const rel = (r) => ({ x: r.x - r0.x, y: r.y - r0.y, w: r.width, h: r.height });
  if (kind === 'menu') {
    const box = stage.querySelector('[data-bake="menu"] > div');
    return Array.from(box.children).map((row) => rel(row.getBoundingClientRect()));
  }
  if (kind === 'hint') {
    const bar = stage.querySelector('[data-bake="hint"] > div');
    return rel(bar.children[1].getBoundingClientRect());
  }
  return null;
};

function HarnessApp() {
  const [t] = useTweaks(window.TWEAK_DEFAULTS);
  const aspect = t.aspect || '16:9', res = t.res || '1080p';
  const dw = aspect === '21:9' ? 2580 : 1920;
  const s = res === '4K' ? 2 : res === '1440p' ? 4 / 3 : 1;
  const ctx = Object.assign({}, t, { dw: dw, s: s });
  return (
    <TweaksCtx.Provider value={ctx}>
      {/* opaque ink comes from the body CSS; bakes make the body transparent at runtime */}
      <div style={{ position: 'fixed', inset: 0, background: 'transparent' }}>
        <SceneStage width={Math.round(dw * s)} height={Math.round(1080 * s)} scenes={window.OM_SCENES} playback={window.OM_PLAYBACK} bg={INK}>
          {{ Boot: Boot, Logo: LogoScene, Menu: MenuScene, Idle: IdleScene }}
        </SceneStage>
      </div>
    </TweaksCtx.Provider>
  );
}
window.HarnessApp = HarnessApp;
