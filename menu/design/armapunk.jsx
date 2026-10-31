// armapunk.jsx — ARMAPUNK 2035 main-menu animation (scenes for SceneStage)
const { SceneStage, useScene, useTimeline, TweaksPanel, TweakSection, TweakSlider, TweakToggle, TweakRadio, TweakColor, useTweaks } = window;
const W = 1920, H = 1080;
const RED = '#ff5544', INK = '#050302';
const MONO = "'Space Mono', monospace", DISP = "'Michroma', sans-serif";
const TweaksCtx = React.createContext(null);
const BG_ONLY = !!window.ARMAPUNK_BG_ONLY; // background-video variant: no menu items / hints
const useTw = () => React.useContext(TweaksCtx);
const c01 = v => Math.max(0, Math.min(1, v));
const hash = n => { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); };
// The only three motion helpers — everything animates through these.
const MOTION = {
  enter: (t, delay, dur) => { const p = c01((t - delay) / dur); return 1 - Math.pow(1 - p, 3); },
  flick: (p, seed) => { // neon tube turn-on: stutters, guaranteed 0 at p<=0 and 1 at p>=0.96
    if (p <= 0) return 0; if (p >= 0.96) return 1;
    const k = Math.floor(p * 26) + seed * 97, r = hash(k);
    return r < p * 1.3 ? 0.6 + 0.4 * hash(k + 1) : (r > 0.94 ? 0.25 : 0);
  },
  gate: (t, seed, level) => { // sparse glitch bursts, deterministic
    const k = Math.floor(t * 7) + seed * 131, r = hash(k);
    return r > 1 - 0.11 * level ? hash(k + 7) : 0;
  },
};
const edge = p => c01(Math.min(p, 1 - p) * 12); // force effects to 0 at scene edges

// ── content ──────────────────────────────────────────────────────────
const BOOT = [
  'DOOMBA BIOS v2.0.35 — ARMAPUNK KERNEL', '(c) 2035 DOOMBA COLLECTIVE', '',
  'MEM CHECK ............... 2048TB OK', 'NEURO-GPU RV/STRIX ...... OK',
  'NEURAL UPLINK ........... SYNCED', 'DECRYPTING MALDEN GRID .. %%BAR%%', '',
  'MOUNTING /pbo ...', '  cba_a3.pbo ............ LOADED', '  ace_cyberware.pbo ..... LOADED',
  '  doomba_core.pbo ....... LOADED', '  doomba_neon.pbo ....... LOADED',
  '  humanity.pbo .......... MISSING (skipped)', 'INJECTING synthwave.dll . OK',
  'BYPASSING NATO DRM ...... OK', 'DARKNET RELAYS .......... 3/3 ONLINE',
  'RAIN ENGINE ............. ENABLED', 'SCANLINES ............... ENABLED', '',
  'BOOT COMPLETE — LAUNCHING INTERFACE',
];
const BOOT_T = (() => { let t = 0.16; return BOOT.map((l, i) => { const cur = t; t += (l === '' ? 0.04 : 0.035 + hash(i) * 0.06) + (l.includes('%%BAR%%') ? 0.5 : 0); return cur; }); })();
const FEED = [
  '[NET] relay.malden-04 handshake OK', '[SYS] doomba.sys heartbeat .. OK', '[NET] 47 operators on darknet',
  '[TRD] arsenal restock T-00:12:44', '[WRN] storm cell over pyrgos grid', '[NET] contract: GHOST RUN // 12,000c',
  '[SYS] cyberware daemon pid 2035', '[NET] uplink jitter 3ms nominal', '[TRD] black ICE detected, sector 7',
  '[NET] contract: SILENT CARGO // 8,500c', '[SYS] ram spike quarantined', '[WRN] nato patrol rerouted E-260',
  '[NET] operator K0BR4 jacked in', '[TRD] chrome vendor moved: kavala', '[NET] packet loss 0.02% nominal',
  '[SYS] rain.fx driver reloaded', '[NET] contract: DATA HEIST // 21,000c', '[WRN] curfew active in athira',
  '[NET] operator V1PER extracted', '[SYS] neon grid draw 60fps',
];
const MENU = ['DEPLOY', 'OPTIONS', 'EXIT'];
const HINTS = ['> JACK INTO THE MALDEN DARKNET', '> RECALIBRATE NEURAL LINK', '> RETURN TO MEATSPACE'];
const BLD_F = Array.from({ length: 32 }, (_, i) => ({ w: 42 + hash(i * 3 + 1) * 110, h: 90 + hash(i * 3 + 2) * 240, g: hash(i * 3 + 3) }));
const BLD_N = Array.from({ length: 20 }, (_, i) => ({ w: 85 + hash(i * 7 + 11) * 170, h: 70 + hash(i * 7 + 12) * 180, g: hash(i * 7 + 13) }));
const DROPS = Array.from({ length: 34 }, (_, i) => ({ x: hash(i + 5) * 2580, l: 80 + hash(i + 40) * 70, sp: 900 + hash(i + 80) * 520, ph: hash(i + 120) * 1700, o: 0.3 + hash(i + 160) * 0.7 }));

// ── persistent stage ─────────────────────────────────────────────────
function Bg({ power }) {
  const gt = useTimeline().time, tw = useTw(), A = tw.palette[0], B = tw.palette[1];
  const fl = 0.88 + 0.12 * hash(Math.floor(gt * 12)); // ambient CRT flicker
  const p = power * fl;
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg,#030203 0%,#0a0504 46%,#160b05 61%,#080503 100%)', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', left: '10%', top: 380, width: '80%', height: 480, background: `radial-gradient(ellipse 60% 45% at 50% 52%, ${A}2e, transparent 70%)`, opacity: p }} />
      <div style={{ position: 'absolute', left: -40, bottom: H - 622, display: 'flex', alignItems: 'flex-end' }}>
        {BLD_F.map((b, i) => (
          <div key={i} style={{ width: b.w, height: b.h, background: '#150c07', marginLeft: 2, position: 'relative' }}>
            {b.g > 0.72 && <div style={{ position: 'absolute', left: '18%', top: 14, width: '58%', height: 7, background: B, opacity: p * (0.25 + 0.3 * hash(Math.floor(gt * 2) + i)), boxShadow: `0 0 16px ${B}` }} />}
          </div>
        ))}
      </div>
      <div style={{ position: 'absolute', left: -60, bottom: H - 626, display: 'flex', alignItems: 'flex-end' }}>
        {BLD_N.map((b, i) => (
          <div key={i} style={{ width: b.w, height: b.h, background: '#0a0504', marginLeft: 3, position: 'relative', backgroundImage: `repeating-linear-gradient(0deg, transparent 0 16px, ${A}12 16px 18px)` }}>
            {b.g > 0.62 && <div style={{ position: 'absolute', left: '46%', top: -34, width: 2, height: 34, background: '#1a100a' }} />}
            {b.g > 0.62 && <div style={{ position: 'absolute', left: '46%', top: -38, width: 5, height: 5, borderRadius: 3, background: RED, marginLeft: -1, opacity: p * (hash(Math.floor(gt * 1.4) + i * 9) > 0.5 ? 0.9 : 0.15), boxShadow: `0 0 10px ${RED}` }} />}
          </div>
        ))}
      </div>
      <div style={{ position: 'absolute', left: 0, top: 620, width: '100%', height: 2, background: `linear-gradient(90deg, transparent, ${A}66 30%, ${A}88 50%, ${A}66 70%, transparent)`, opacity: p, boxShadow: `0 0 22px ${A}55` }} />
      <div style={{ position: 'absolute', left: '-35%', top: 622, width: '170%', height: 980, transformOrigin: 'top center', transform: 'perspective(540px) rotateX(63deg)', opacity: p * 0.55, backgroundImage: `repeating-linear-gradient(90deg, ${B}30 0 2px, transparent 2px 92px), repeating-linear-gradient(0deg, ${B}34 0 2px, transparent 2px 74px)`, backgroundPosition: `0px ${((gt * 44) % 74).toFixed(1)}px` }} />
      <div style={{ position: 'absolute', left: 0, top: 620, width: '100%', height: 460, background: 'linear-gradient(180deg, transparent, rgba(5,3,2,0.9) 88%)' }} />
      <div style={{ position: 'absolute', inset: -80, transform: 'rotate(9deg)', opacity: p * 0.55 }}>
        {DROPS.map((d, i) => (
          <div key={i} style={{ position: 'absolute', left: d.x, top: ((gt * d.sp + d.ph) % (H + 300)) - 150, width: 2, height: d.l, opacity: d.o * 0.35, background: `linear-gradient(180deg, transparent, ${B})` }} />
        ))}
      </div>
    </div>
  );
}

function Overlays({ fx }) {
  const gt = useTimeline().time, tw = useTw(), A = tw.palette[0], B = tw.palette[1];
  const bandY = ((gt * 120) % (H + 420)) - 210;
  return (
    <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
      {fx > 0 && [0, 1, 2].map(i => {
        const k = Math.floor(gt * 9) + i * 31;
        return <div key={i} style={{ position: 'absolute', left: 0, top: hash(k) * H, width: '100%', height: 2 + hash(k + 3) * 10, background: i % 2 ? B : A, opacity: fx * 0.38, mixBlendMode: 'screen', transform: `translateX(${(hash(k + 5) - 0.5) * 70 * fx}px)` }} />;
      })}
      {tw.scanlines && <div style={{ position: 'absolute', inset: 0, backgroundImage: 'repeating-linear-gradient(0deg, rgba(0,0,0,0.26) 0 2px, transparent 2px 5px)' }} />}
      {tw.scanlines && <div style={{ position: 'absolute', left: 0, top: bandY, width: '100%', height: 260, background: 'linear-gradient(180deg, transparent, rgba(255,240,210,0.045), transparent)' }} />}
      <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at center, transparent 52%, rgba(0,0,0,0.5) 100%)' }} />
    </div>
  );
}

function Corners({ o }) {
  const tw = useTw(), B = tw.palette[1];
  const L = (st) => <div style={{ position: 'absolute', width: 30, height: 30, opacity: 0.55 * o, ...st }} />;
  const b = `2px solid ${B}`;
  return <div style={{ position: 'absolute', inset: 26, pointerEvents: 'none' }}>
    {L({ left: 0, top: 0, borderLeft: b, borderTop: b })}{L({ right: 0, top: 0, borderRight: b, borderTop: b })}
    {L({ left: 0, bottom: 0, borderLeft: b, borderBottom: b })}{L({ right: 0, bottom: 0, borderRight: b, borderBottom: b })}
  </div>;
}

// One frame wrapper per scene: bg + jittered content + overlays.
function Frame({ power, fx, label, children }) {
  const gt = useTimeline().time; const tw = useTw();
  const jx = (hash(Math.floor(gt * 24)) - 0.5) * 24 * fx;
  return (
    <div data-screen-label={label} style={{ position: 'absolute', left: 0, top: 0, width: tw.dw, height: 1080, transform: `scale(${tw.s})`, transformOrigin: 'top left', background: INK, overflow: 'hidden', fontFamily: MONO }}>
      <Bg power={power} />
      <div style={{ position: 'absolute', inset: 0, transform: `translateX(${jx.toFixed(1)}px)` }}>{children}</div>
      <Corners o={power} />
      <Overlays fx={fx} />
    </div>
  );
}

// ── UI pieces ────────────────────────────────────────────────────────
function LogoBlock({ lt }) {
  const gt = useTimeline().time, tw = useTw(), A = tw.palette[0], B = tw.palette[1];
  const over = MOTION.enter(lt, 0.12, 0.6);
  const f1 = MOTION.flick(c01((lt - 0.55) / 1.15), 3);
  const f2 = MOTION.flick(c01((lt - 1.15) / 0.95), 7);
  const chip = MOTION.enter(lt, 2.0, 0.4), rule = MOTION.enter(lt, 2.25, 0.5);
  const breathe = 0.86 + 0.14 * Math.sin(gt * 2.1);
  const ov = '// THE FUTURE IS ALREADY BROKEN';
  const split = f1 > 0 && f1 < 1 ? `${(-7 * (1 - f1)).toFixed(1)}px 0 ${B}, ${(5 * (1 - f1)).toFixed(1)}px 0 ${RED}, ` : '';
  return (
    <div style={{ position: 'absolute', left: 140, top: 200 }}>
      <div style={{ fontFamily: MONO, fontSize: 19, letterSpacing: 5, color: B, opacity: 0.85, height: 26 }}>
        {ov.slice(0, Math.floor(over * ov.length))}{over > 0 && over < 1 ? '█' : ''}
      </div>
      <div style={{ fontFamily: DISP, fontSize: 116, lineHeight: 1.08, color: `color-mix(in oklab, ${A} 26%, #fff8ea)`, opacity: f1, textShadow: `${split}0 0 16px ${A}99, 0 0 60px ${A}${Math.round(40 * breathe).toString(16).padStart(2, '0')}` }}>
        ARMAPUNK
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 34, marginTop: 6 }}>
        <div style={{ fontFamily: DISP, fontSize: 108, color: 'transparent', WebkitTextStroke: `2.5px ${B}`, opacity: f2, textShadow: `0 0 26px ${B}44` }}>2035</div>
        <div style={{ border: `1px solid ${A}99`, color: A, fontFamily: MONO, fontSize: 20, letterSpacing: 7, padding: '9px 18px 7px', opacity: chip, transform: `translateY(${(1 - chip) * 18}px)`, background: `${A}14` }}>BY DOOMBA</div>
      </div>
      <div style={{ marginTop: 22, height: 2, width: 640 * rule, background: `linear-gradient(90deg, ${A}, ${A}55 60%, transparent)`, boxShadow: `0 0 12px ${A}66` }} />
    </div>
  );
}

function MenuListC({ lt, sel, pulse }) {
  const tw = useTw(), A = tw.palette[0], B = tw.palette[1];
  return (
    <div style={{ position: 'absolute', left: 140, top: 512 }}>
      {MENU.map((m, i) => {
        const e = MOTION.enter(lt, 0.35 + i * 0.18, 0.32);
        const isSel = i === sel, arm = isSel && m === 'EXIT';
        const col = arm ? RED : (isSel ? A : 'rgba(255,236,208,0.5)');
        const glow = isSel ? `0 0 ${14 + pulse * 22}px ${arm ? RED : A}88` : 'none';
        return (
          <div key={m} style={{ display: 'flex', alignItems: 'center', gap: 22, height: 62, opacity: e, transform: `translateX(${(1 - e) * -30 + (isSel ? 16 : 0)}px)` }}>
            <div style={{ width: 5, height: 34, background: isSel ? (arm ? RED : A) : 'transparent', boxShadow: isSel ? `0 0 12px ${arm ? RED : A}` : 'none' }} />
            <div style={{ fontFamily: MONO, fontSize: 17, color: B, opacity: isSel ? 0.95 : 0.45, width: 34 }}>0{i + 1}</div>
            <div style={{ fontFamily: DISP, fontSize: 29, letterSpacing: 5, color: col, textShadow: glow }}>
              {m.slice(0, Math.max(0, Math.floor(e * m.length)))}{e > 0 && e < 1 ? '█' : ''}
            </div>
            {isSel && <div style={{ fontFamily: MONO, fontSize: 20, color: arm ? RED : A, opacity: 0.6 + pulse * 0.4 }}>{'<<'}</div>}
          </div>
        );
      })}
    </div>
  );
}

function SidePanel({ lt, feedT }) {
  const gt = useTimeline().time, tw = useTw(), A = tw.palette[0], B = tw.palette[1];
  const e = MOTION.enter(lt, 0.5, 0.5);
  const n = feedT * 3.4, whole = Math.floor(n), lineH = 30, VIS = 13;
  const rows = [];
  for (let i = Math.max(0, whole - VIS); i < whole; i++) rows.push(i);
  const colFor = s => s.startsWith('[WRN]') ? A : s.startsWith('[TRD]') ? `color-mix(in oklab, ${A} 60%, #fff)` : s.startsWith('[SYS]') ? 'rgba(255,240,220,0.5)' : B;
  return (
    <div style={{ position: 'absolute', right: 120, top: 200, width: 560, opacity: e, transform: `translateX(${(1 - e) * 90}px)` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: `${B}1c`, border: `1px solid ${B}55`, borderBottom: 'none', padding: '10px 16px', fontFamily: MONO, fontSize: 17, letterSpacing: 3, color: B }}>
        <div style={{ width: 9, height: 9, borderRadius: 5, background: B, opacity: Math.floor(gt * 2) % 2 ? 1 : 0.25, boxShadow: `0 0 8px ${B}` }} />
        NET_FEED // doomba.sys
      </div>
      <div style={{ border: `1px solid ${B}40`, background: 'rgba(4,10,9,0.55)', height: VIS * lineH + 20, overflow: 'hidden', padding: '10px 16px 0', position: 'relative' }}>
        <div style={{ transform: `translateY(${(-(n - whole) * lineH).toFixed(1)}px)` }}>
          {rows.map(i => (
            <div key={i} style={{ height: lineH, fontFamily: MONO, fontSize: 17, whiteSpace: 'nowrap', color: colFor(FEED[i % FEED.length]), opacity: 0.85 }}>
              {FEED[i % FEED.length]}
            </div>
          ))}
          <div style={{ height: lineH, fontFamily: MONO, fontSize: 17, color: B }}>{Math.floor(gt * 3) % 2 ? '█' : ''}</div>
        </div>
      </div>
      <div style={{ border: `1px solid ${B}40`, borderTop: 'none', padding: '12px 16px 14px', display: 'flex', alignItems: 'flex-end', gap: 6 }}>
        <div style={{ fontFamily: MONO, fontSize: 15, color: 'rgba(255,240,220,0.45)', marginRight: 14, letterSpacing: 2 }}>SIGNAL // relay.malden-04</div>
        {Array.from({ length: 14 }, (_, i) => (
          <div key={i} style={{ width: 10, height: 5 + hash(Math.floor(gt * 3.2) + i * 17) * 26, background: B, opacity: 0.65 }} />
        ))}
      </div>
    </div>
  );
}

function BottomBar({ lt, sel, arm, mute }) {
  const gt = useTimeline().time, tw = useTw(), A = tw.palette[0], B = tw.palette[1];
  const e = MOTION.enter(lt, 1.5, 0.5);
  const hint = mute ? '' : arm ? 'EXIT? [Y/N] █' : HINTS[sel];
  const blink = arm && Math.floor(gt * 5) % 2 === 0;
  return (
    <div style={{ position: 'absolute', left: 0, bottom: 0, width: '100%', height: 58, transform: `translateY(${(1 - e) * 58}px)`, borderTop: `1px solid ${A}44`, background: 'rgba(8,5,3,0.78)', display: 'flex', alignItems: 'center', padding: '0 48px', gap: 40, fontFamily: MONO, fontSize: 17, boxSizing: 'border-box' }}>
      <div style={{ color: 'rgba(255,236,208,0.45)', letterSpacing: 2 }}>ARMAPUNK 2035 // BUILD 0.9.7-BETA</div>
      <div style={{ color: arm ? RED : A, letterSpacing: 2, opacity: blink ? 0.25 : 1, flex: 1 }}>{hint}</div>
      <div style={{ color: B, letterSpacing: 2, display: 'flex', gap: 14 }}>
        <span>UPLINK {'▮▮▮▮'}<span style={{ opacity: 0.3 }}>▮</span></span>
        <span style={{ opacity: 0.7 }}>47 OPERATORS ONLINE</span>
      </div>
    </div>
  );
}

function Coords({ lt }) {
  const gt = useTimeline().time, tw = useTw(), B = tw.palette[1];
  const e = MOTION.enter(lt, 1.7, 0.4);
  const ss = String((14 + Math.floor(gt)) % 60).padStart(2, '0');
  return <div style={{ position: 'absolute', right: 122, top: 152, fontFamily: MONO, fontSize: 16, letterSpacing: 3, color: B, opacity: 0.55 * e }}>GRID 034071 // MALDEN // 03:12:{ss}</div>;
}

// ── scenes ───────────────────────────────────────────────────────────
function Boot() {
  const { localTime: lt, progress: p } = useScene(); const tw = useTw();
  const A = tw.palette[0], B = tw.palette[1];
  const power = 0.15 + 0.85 * MOTION.enter(lt, 2.05, 0.75);
  const wipe = MOTION.enter(lt, 2.3, 0.4);
  const flash = Math.sin(c01((lt - 2.05) / 0.55) * Math.PI) * 0.12;
  const fx = MOTION.gate(lt, 1, tw.glitch * 0.6) * edge(p) * power;
  const vis = BOOT.map((l, i) => ({ l, t: BOOT_T[i], i })).filter(o => o.t <= lt).slice(-19);
  const colFor = (l, i) => l.includes('MISSING') ? RED : i < 2 ? 'rgba(255,240,220,0.6)' : l.includes('BOOT COMPLETE') ? A : `${B}dd`;
  return (
    <Frame power={power} fx={fx} label={`Boot t+${Math.floor(lt)}s`}>
      {wipe < 1 && (
        <div style={{ position: 'absolute', left: 130, top: 110, opacity: 1 - wipe, transform: `translateY(${-26 * wipe}px)` }}>
          {vis.map(o => {
            let txt = o.l;
            if (txt.includes('%%BAR%%')) {
              const bp = c01((lt - o.t) / 0.5), nB = Math.floor(bp * 14);
              txt = txt.replace('%%BAR%%', '█'.repeat(nB) + '░'.repeat(14 - nB) + ' ' + Math.round(bp * 100) + '%');
            }
            return <div key={o.i} style={{ fontFamily: MONO, fontSize: 21, lineHeight: '31px', whiteSpace: 'pre', color: colFor(o.l, o.i), textShadow: `0 0 8px ${B}33` }}>{o.l ? '> ' + txt : ' '}</div>;
          })}
          {lt > 0.14 && <div style={{ fontFamily: MONO, fontSize: 21, lineHeight: '31px', color: B, opacity: Math.floor(lt * 3) % 2 ? 1 : 0 }}>{'> █'}</div>}
        </div>
      )}
      {flash > 0 && <div style={{ position: 'absolute', inset: 0, background: A, opacity: flash }} />}
    </Frame>
  );
}

function LogoScene() {
  const { localTime: lt, progress: p } = useScene(); const tw = useTw();
  const burst = (lt > 0.5 && lt < 1.9 ? 0.5 : 0) * MOTION.gate(lt, 4, tw.glitch * 2);
  const fx = (MOTION.gate(lt, 2, tw.glitch) + burst) * edge(p);
  return (
    <Frame power={1} fx={fx} label={`Logo t+${Math.floor(lt)}s`}>
      <LogoBlock lt={lt} />
    </Frame>
  );
}

function MenuScene() {
  const { localTime: lt, progress: p } = useScene(); const tw = useTw();
  const fx = MOTION.gate(lt, 3, tw.glitch) * edge(p);
  const selIn = MOTION.enter(lt, 2.2, 0.3);
  return (
    <Frame power={1} fx={fx} label={`Menu t+${Math.floor(lt)}s`}>
      <LogoBlock lt={99} />
      {!BG_ONLY && <MenuListC lt={lt} sel={selIn > 0 ? 0 : -1} pulse={selIn < 1 ? 1 - selIn : 0} />}
      <SidePanel lt={lt} feedT={Math.max(0, lt - 0.9)} />
      <Coords lt={lt} />
      <BottomBar lt={lt} sel={0} arm={false} mute={BG_ONLY} />
    </Frame>
  );
}

function IdleScene() {
  const { localTime: lt, progress: p } = useScene(); const tw = useTw();
  const sel = Math.min(2, Math.floor(lt / 0.55));
  const ph = (lt % 0.55) / 0.55;
  const pulse = lt < 1.65 ? (1 - MOTION.enter(ph, 0, 0.6)) * Math.min(1, sel) : 0;
  const arm = lt > 2.2;
  const d = MOTION.enter(lt, 4.25, 0.5); // CRT power-down
  const power = 1 - 0.85 * MOTION.enter(lt, 4.3, 0.55);
  const preFx = MOTION.gate(lt, 5, tw.glitch) * edge(p) * power;
  const dieFx = Math.sin(c01((lt - 4.1) / 0.5) * Math.PI) * 0.9 * edge(p) * power;
  return (
    <Frame power={power} fx={Math.max(preFx, dieFx)} label={`Idle t+${Math.floor(lt)}s`}>
      <div style={{ position: 'absolute', inset: 0, opacity: 1 - d, transform: `scaleY(${Math.max(0.002, 1 - d * 0.998)}) scaleX(${1 + d * 0.4})`, transformOrigin: 'center 55%' }}>
        <LogoBlock lt={99} />
        {!BG_ONLY && <MenuListC lt={99} sel={sel} pulse={pulse} />}
        <SidePanel lt={99} feedT={3.1 + lt} />
        <Coords lt={99} />
        <BottomBar lt={99} sel={sel} arm={arm && !BG_ONLY} mute={BG_ONLY} />
      </div>
      {d > 0 && d < 1 && <div style={{ position: 'absolute', left: 0, top: '55%', width: '100%', height: 3, background: '#fff6e2', opacity: Math.sin(d * Math.PI), boxShadow: `0 0 30px ${tw.palette[0]}` }} />}
    </Frame>
  );
}

// ── app ──────────────────────────────────────────────────────────────
function ArmapunkMenu() {
  const [t, setTweak] = useTweaks(window.TWEAK_DEFAULTS);
  const aspect = t.aspect || '16:9', res = t.res || '1440p';
  const dw = aspect === '21:9' ? 2580 : 1920;
  const s = res === '4K' ? 2 : res === '1440p' ? 4 / 3 : 1;
  const ctx = Object.assign({}, t, { dw: dw, s: s });
  return (
    <TweaksCtx.Provider value={ctx}>
      <div style={{ position: 'fixed', inset: 0, background: INK }}>
        <SceneStage width={Math.round(dw * s)} height={Math.round(1080 * s)} scenes={window.OM_SCENES} playback={window.OM_PLAYBACK} bg={INK}>
          {{ Boot: Boot, Logo: LogoScene, Menu: MenuScene, Idle: IdleScene }}
        </SceneStage>
        <TweaksPanel>
          <TweakSection label="Format" />
          <TweakRadio label="Aspect" value={aspect} options={['16:9', '21:9']} onChange={v => setTweak('aspect', v)} />
          <TweakRadio label="Resolution" value={res} options={['1080p', '1440p', '4K']} onChange={v => setTweak('res', v)} />
          <TweakSection label="Look" />
          <TweakColor label="Neon palette" value={t.palette}
            options={[['#ffb300', '#00e5c7'], ['#00f0ff', '#ff2bd6'], ['#ff2a6d', '#05d9e8'], ['#a3ff12', '#8b5cf6']]}
            onChange={v => setTweak('palette', v)} />
          <TweakToggle label="Scanlines" value={t.scanlines} onChange={v => setTweak('scanlines', v)} />
          <TweakSlider label="Glitch level" value={t.glitch} min={0} max={2} step={0.1} onChange={v => setTweak('glitch', v)} />
          <TweakSection label="Editor" />
          <TweakToggle label="Motion editor" value={t.motionEditor} onChange={v => setTweak('motionEditor', v)} />
        </TweaksPanel>
      </div>
    </TweaksCtx.Provider>
  );
}
window.ArmapunkMenu = ArmapunkMenu;
