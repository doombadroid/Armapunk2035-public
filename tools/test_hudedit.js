/* Offline harness for ui/html/hudedit.js.

   Stubs just enough DOM to load the editor and drive it, then asserts the things that are
   expensive to debug in-game: that the offset maths round-trips, that the clamp keeps every
   handle inside the viewport, that breakout arms the pin only on a MEMBER move, and that the
   payload handed to hudLayoutSet is the seven number pairs the server validator demands.

   The element geometry is modelled the way the browser would resolve it: a base rect from the
   page's own CSS, plus the translate implied by the custom properties the editor sets. That is
   what makes the clamp assertions real -- they are measured against a rect that actually moves.
*/
"use strict";

const VW = 1920, VH = 1080, REM = 16;

/* Base (untranslated) rects, from hud.html's CSS at 1920x1080. */
const BASE = {
  stack:   { l: VW - 2*REM - 19.5*REM, t: VH - 2*REM - 12.2*REM, w: 19.5*REM, h: 12.2*REM },
  chips:   { l: VW - 2*REM - 12*REM,   t: VH - 14.15*REM - 1*REM, w: 12*REM,   h: 1*REM },   /* pinned bottom: the editor always shows the wanted payload */
  p_hp:    { l: VW - 2*REM - 17.8*REM, t: VH - 2*REM - 9.05*REM - 2.55*REM, w: 17.8*REM, h: 2.55*REM },
  p_h2o:   { l: VW - 2*REM - 18.65*REM,t: VH - 2*REM - 6.10*REM - 2.55*REM, w: 18.65*REM, h: 2.55*REM },
  p_food:  { l: VW - 2*REM - 19.5*REM, t: VH - 2*REM - 3.15*REM - 2.55*REM, w: 19.5*REM, h: 2.55*REM },
  wplate:  { l: VW - 2*REM - 19.5*REM, t: VH - 2*REM - 2.75*REM, w: 19.5*REM, h: 2.75*REM },
  mapwrap: { l: 2*REM, t: 2*REM, w: 13*REM, h: 14.75*REM }
};

/* Which custom properties drive which element. `own` is the var prefix; `member` elements are
   children of the scaled #stack, so their base geometry scales about the stack's right-bottom
   corner by the GROUP scale before their own scale applies. */
const VARS = {
  stack:   { own: "g", member: false },
  p_hp:    { own: "h", member: true },
  p_h2o:   { own: "w", member: true },
  p_food:  { own: "f", member: true },
  wplate:  { own: "b", member: true },
  chips:   { own: "c", member: false, chips: true },
  mapwrap: { own: "m", member: false, lt: true }
};

const props = Object.create(null);

/* What the browser would resolve for hudeditor.md §9.2's stylesheet: a fixed transform-origin
   (right bottom for everything but the minimap), scale, then the translate the vars imply.
   Members: translate is own*100vw/sg in child px, times sg by the parent -> own*VW on screen, plus
   the group's. Chips: product scale, Y gets -12.15rem*(sg-1). Measured against real Chromium at
   1920x1080 (scratchpad csscheck, 2026-09-07): stack RB (1888,1048) at sg 1.5, hp offset 192 px for
   dx 0.1, chips bottom 756.4. */
function liveRectOf(id) {
  const b = BASE[id], v = VARS[id];
  if (!b) return { left: 0, top: 0, width: 0, height: 0, right: 0, bottom: 0 };
  const sg = num1(props["--apgs"]);
  const own = num1(props["--ap" + v.own + "s"]);
  const gx = num(props["--apgx"]) * VW, gy = num(props["--apgy"]) * VH;
  const ox = num(props["--ap" + v.own + "x"]) * VW, oy = num(props["--ap" + v.own + "y"]) * VH;
  let r, btm, w, h, l, t;
  if (v.lt) {                                    /* minimap: left-top origin */
    w = b.w * own; h = b.h * own; l = b.l + ox; t = b.t + oy;
    return { left: l, top: t, width: w, height: h, right: l + w, bottom: t + h };
  }
  const bs = BASE.stack;
  if (id === "stack") {
    w = b.w * sg; h = b.h * sg; r = b.l + b.w + gx; btm = b.t + b.h + gy;
  } else if (v.chips) {
    const s = sg * own;
    w = b.w * s; h = b.h * s; r = b.l + b.w + gx + ox; btm = b.t + b.h + gy + oy - 12.15 * REM * (sg - 1);
  } else {                                       /* member: ride the scaled stack, then own scale */
    const s = sg * own;
    w = b.w * s; h = b.h * s;
    const stackR = bs.l + bs.w + gx, stackB = bs.t + bs.h + gy;
    r = stackR + ((b.l + b.w) - (bs.l + bs.w)) * sg + ox;
    btm = stackB + ((b.t + b.h) - (bs.t + bs.h)) * sg + oy;
  }
  return { left: r - w, top: btm - h, width: w, height: h, right: r, bottom: btm };
}

function mkEl(id) {
  const listeners = {};
  const el = {
    id, style: { setProperty: (k, v) => { props[k] = v; } },
    className: "", textContent: "", innerHTML: "",
    childNodes: [], firstChild: null, parentNode: null,
    attrs: Object.create(null),
    setAttribute(k, v) { this.attrs[k] = String(v); },
    getAttribute(k) { return k in this.attrs ? this.attrs[k] : null; },
    hasAttribute(k) { return k in this.attrs; },
    appendChild(c) { this.childNodes.push(c); c.parentNode = this; if (!this.firstChild) this.firstChild = c; return c; },
    removeChild(c) { const i = this.childNodes.indexOf(c); if (i >= 0) this.childNodes.splice(i, 1); return c; },
    addEventListener(t, f) { (listeners[t] = listeners[t] || []).push(f); },
    fire(t, ev) { (listeners[t] || []).forEach(f => f(ev)); },
    setPointerCapture() {},
    closest(sel) {
      /* only [data-act] is ever asked for, and nothing in this harness carries it */
      let n = this;
      while (n) { if (n.hasAttribute && n.hasAttribute(sel.replace(/[[\]]/g, ""))) return n; n = n.parentNode; }
      return null;
    },
    getBoundingClientRect() { return liveRectOf(id); }
  };
  return el;
}
function num(s) { const n = parseFloat(s); return isFinite(n) ? n : 0; }
function num1(s) { const n = parseFloat(s); return isFinite(n) ? n : 1; }

const els = Object.create(null);
Object.keys(BASE).forEach(id => { els[id] = mkEl(id); });

const root = mkEl("__root");
const head = mkEl("__head");
const body = mkEl("__body");

global.document = {
  documentElement: root, head, body,
  getElementById: id => els[id] || null,
  createElement: () => mkEl("__new"),
  addEventListener: () => {}
};
const winListeners = {};
global.window = {
  innerWidth: VW, innerHeight: VH,
  addEventListener: (t, f) => { (winListeners[t] = winListeners[t] || []).push(f); },
  fire: (t, ev) => { (winListeners[t] || []).forEach(f => f(ev)); },
  APHE_INIT: null,
  WEBUI: { call: (n, a) => { calls.push([n, a]); return { then: () => {} }; } }
};
global.requestAnimationFrame = () => {};   /* paint() self-schedules; one pass is enough */
const calls = [];

/* ------------------------------------------------------------------ load it -------- */
const TARGET = process.argv[2] ||
  require("path").join(__dirname, "..", "mission", "Armapunk2035.Malden", "ui", "html", "hudedit.js");
const src = require("fs").readFileSync(TARGET, "utf8");
(0, eval)(src);

const APHE = window.APHE;
if (!APHE) { console.error("FAIL: hudedit.js did not export window.APHE"); process.exit(1); }

/* ------------------------------------------------------------------ assertions ----- */
let pass = 0, fail = 0;
function ok(name, cond, extra) {
  if (cond) { pass++; console.log("  PASS  " + name); }
  else { fail++; console.log("  FAIL  " + name + (extra ? "  -- " + extra : "")); }
}
function sheet() {
  /* the editor's page stylesheet is the first <style> it appended to head */
  const s = head.childNodes.find(c => c.id === "apEd");
  return s ? s.textContent : "";
}
function rectOf(id) { return els[id].getBoundingClientRect(); }
function inView(r) { return r.left >= -0.5 && r.top >= -0.5 && r.left + r.width <= VW + 0.5 && r.top + r.height <= VH + 0.5; }

const L = APHE.get();

console.log("\n== shape ==");
ok("seven triples", L.length === 7 && L.every(p => p.length === 3 && p.every(n => typeof n === "number")));
ok("seeded at the designer's layout, scale 1", L.every(p => p[0] === 0 && p[1] === 0 && p[2] === 1));
ok("rules carry scale and origins", sheet().indexOf("scale(var(--apgs))") !== -1 && sheet().indexOf("transform-origin:left top") !== -1);
ok("no pin while nothing has moved", sheet().indexOf("!important") === -1);
ok("transform rules present", sheet().indexOf("#stack{transform-origin:right bottom;transform:translate(") === 0);

const barEl0 = body.childNodes.find(c => c.id === "apEdBar");
const mkBtn0 = a => ({ getAttribute: k => (k === "data-a" ? a : null) });

console.log("\n== drag: a group move takes the members with it ==");
const hpBefore = rectOf("p_hp"), chipsBefore = rectOf("chips"), mapBefore = rectOf("mapwrap"), stBefore = rectOf("stack");
els.stack.attrs["data-i"] = "0";
/* the overlay's box for handle 0 -- reach the editor the way a real pointerdown does */
const ovEl = body.childNodes.find(c => c.id === "apEdOv");
const box0 = ovEl.childNodes[0];
ovEl.fire("pointerdown", { target: box0, clientX: 100, clientY: 100, pointerId: 1, preventDefault(){} });
window.fire("pointermove", { clientX: 100 - 200, clientY: 100 - 300, preventDefault(){} });
window.fire("pointerup", {});
const hpAfter = rectOf("p_hp"), chipsAfter = rectOf("chips"), mapAfter = rectOf("mapwrap"), stAfter = rectOf("stack");
/* Compared to the STACK's own travel, not the raw mouse delta: snap may pull the group a few px
   onto a guide, and the property under test is that the members ride along exactly. */
const sdx = stAfter.left - stBefore.left, sdy = stAfter.top - stBefore.top;
ok("group actually travelled", Math.abs(sdx + 200) < 8 && Math.abs(sdy + 300) < 8, `dx=${sdx.toFixed(1)} dy=${sdy.toFixed(1)}`);
ok("hp moved with the group",    Math.abs((hpAfter.left - hpBefore.left) - sdx) < 0.5 && Math.abs((hpAfter.top - hpBefore.top) - sdy) < 0.5,
   `dx=${(hpAfter.left-hpBefore.left).toFixed(1)} dy=${(hpAfter.top-hpBefore.top).toFixed(1)}`);
ok("chips moved with the group", Math.abs((chipsAfter.left - chipsBefore.left) - sdx) < 0.5 && Math.abs((chipsAfter.top - chipsBefore.top) - sdy) < 0.5,
   `dx=${(chipsAfter.left-chipsBefore.left).toFixed(1)}`);
ok("minimap did NOT move",       chipsAfter && mapAfter.left === mapBefore.left && mapAfter.top === mapBefore.top);
ok("still no pin (group move is not breakout)", sheet().indexOf("!important") === -1);

console.log("\n== breakout: one member arms the pin ==");
const box1 = ovEl.childNodes[1];               /* HP */
ovEl.fire("pointerdown", { target: box1, clientX: 500, clientY: 500, pointerId: 2, preventDefault(){} });
window.fire("pointermove", { clientX: 460, clientY: 500, preventDefault(){} });
window.fire("pointerup", {});
ok("pin armed", sheet().indexOf("#p_hp{bottom:9.05rem!important}") !== -1);
ok("pin covers all four", ["#p_hp{bottom:9.05rem", "#p_h2o{bottom:6.1rem", "#p_food{bottom:3.15rem", "#chips{bottom:14.15rem"]
   .every(s => sheet().indexOf(s) !== -1));
ok("HP moved relative to its siblings", Math.abs(rectOf("p_hp").left - rectOf("p_food").left - (BASE.p_hp.l - BASE.p_food.l)) > 5);

console.log("\n== clamp: nothing can leave the viewport ==");
[["stack",0],["p_hp",1],["p_h2o",2],["p_food",3],["wplate",4],["chips",5],["mapwrap",6]].forEach(([id,i]) => {
  const b = ovEl.childNodes[i];
  ovEl.fire("pointerdown", { target: b, clientX: 900, clientY: 500, pointerId: 10+i, preventDefault(){} });
  window.fire("pointermove", { clientX: 900 - 9000, clientY: 500 - 9000, preventDefault(){} });
  window.fire("pointerup", {});
  ok("top-left clamp holds for " + id, inView(rectOf(id)), JSON.stringify(rectOf(id)));
  ovEl.fire("pointerdown", { target: b, clientX: 900, clientY: 500, pointerId: 30+i, preventDefault(){} });
  window.fire("pointermove", { clientX: 900 + 9000, clientY: 500 + 9000, preventDefault(){} });
  window.fire("pointerup", {});
  ok("bottom-right clamp holds for " + id, inView(rectOf(id)), JSON.stringify(rectOf(id)));
});

console.log("\n== nudge ==");
/* The clamp block above deliberately leaves every handle jammed into a corner, and a nudge
   INTO the wall is correctly refused -- so measure the refusal first (it is a real property),
   then clear the layout and measure the movement away from any edge. */
ovEl.fire("pointerdown", { target: ovEl.childNodes[6], clientX: 200, clientY: 200, pointerId: 99, preventDefault(){} });
window.fire("pointerup", {});
const atWall = rectOf("mapwrap").left;
window.fire("keydown", { key: "ArrowRight", shiftKey: false, preventDefault(){} });
ok("nudge into the viewport edge is refused", Math.abs(rectOf("mapwrap").left - atWall) < 0.01,
   `moved ${(rectOf("mapwrap").left - atWall).toFixed(3)}`);
window.fire("keydown", { key: "ArrowLeft", shiftKey: false, preventDefault(){} });
ok("arrow nudges 1px off the wall", Math.abs(rectOf("mapwrap").left - atWall + 1) < 0.01,
   `moved ${(rectOf("mapwrap").left - atWall).toFixed(3)}`);

barEl0.fire("click", { target: mkBtn0("ra") });
const before = rectOf("mapwrap").left;
window.fire("keydown", { key: "ArrowRight", shiftKey: false, preventDefault(){} });
ok("arrow nudges 1px", Math.abs(rectOf("mapwrap").left - before - 1) < 0.01, `moved ${(rectOf("mapwrap").left-before).toFixed(3)}`);
window.fire("keydown", { key: "ArrowRight", shiftKey: true, preventDefault(){} });
ok("shift+arrow nudges 10px", Math.abs(rectOf("mapwrap").left - before - 11) < 0.01, `moved ${(rectOf("mapwrap").left-before).toFixed(3)}`);
window.fire("keydown", { key: "ArrowUp", shiftKey: true, preventDefault(){} });
ok("shift+arrow up nudges 10px", Math.abs(rectOf("mapwrap").top - (BASE.mapwrap.t - 10)) < 0.01,
   `top ${rectOf("mapwrap").top.toFixed(3)} base ${BASE.mapwrap.t}`);

console.log("\n== resize: wheel, centre-fixed ==");
barEl0.fire("click", { target: mkBtn0("ra") });
const mapBox = ovEl.childNodes[6];
const m0 = rectOf("mapwrap");
const cx0 = m0.left + m0.width / 2, cy0 = m0.top + m0.height / 2;
window.fire("wheel", { target: mapBox, deltaY: -100, preventDefault(){} });
const m1 = rectOf("mapwrap");
ok("wheel up scales the minimap by 2%", Math.abs(m1.width / m0.width - 1.02) < 1e-6, `ratio ${(m1.width/m0.width).toFixed(4)}`);
ok("wheel keeps the centre fixed", Math.abs(m1.left + m1.width / 2 - cx0) < 0.5 && Math.abs(m1.top + m1.height / 2 - cy0) < 0.5,
   `dc=(${(m1.left+m1.width/2-cx0).toFixed(2)},${(m1.top+m1.height/2-cy0).toFixed(2)})`);
ok("scale stored on handle 6", Math.abs(APHE.get()[6][2] - 1.02) < 1e-6, APHE.get()[6][2]);
ok("minimap scale does not arm the pin", sheet().indexOf("!important") === -1);

console.log("\n== resize: corner grip, opposite corner fixed ==");
barEl0.fire("click", { target: mkBtn0("ra") });
const hpBox = ovEl.childNodes[1];
/* select HP so its grips are live, then find its top-left grip */
ovEl.fire("pointerdown", { target: hpBox, clientX: 10, clientY: 10, pointerId: 40, preventDefault(){} });
window.fire("pointerup", {});
const hpGripTL = hpBox.childNodes.find(c => c.getAttribute && c.getAttribute("data-g") === "tl");
ok("selected box carries four grips", ["tl","tr","bl","br"].every(g => hpBox.childNodes.some(c => c.getAttribute && c.getAttribute("data-g") === g)));
const h0 = rectOf("p_hp");
ovEl.fire("pointerdown", { target: hpGripTL, clientX: h0.left, clientY: h0.top, pointerId: 41, preventDefault(){} });
window.fire("pointermove", { clientX: h0.left - h0.width * 0.5, clientY: h0.top - 10, preventDefault(){} });
window.fire("pointerup", {});
const h1 = rectOf("p_hp");
ok("HP grew (dominant axis wins)", Math.abs(h1.width / h0.width - 1.5) < 1e-3, `ratio ${(h1.width/h0.width).toFixed(4)}`);
ok("HP bottom-right corner did not move", Math.abs(h1.right - h0.right) < 0.5 && Math.abs(h1.bottom - h0.bottom) < 0.5,
   `dr=${(h1.right-h0.right).toFixed(2)} db=${(h1.bottom-h0.bottom).toFixed(2)}`);
ok("member scale alone does not arm the pin (no offset moved)", sheet().indexOf("!important") === -1 || APHE.get().slice(1,6).some(p => p[0] !== 0 || p[1] !== 0));
const f0 = rectOf("p_food");
ok("FOOD untouched by HP's resize", Math.abs(f0.width - BASE.p_food.w) < 1e-6);

console.log("\n== resize: group scale ==");
barEl0.fire("click", { target: mkBtn0("ra") });
const st0 = rectOf("stack"), ch0 = rectOf("chips"), hp0 = rectOf("p_hp");
window.fire("wheel", { target: ovEl.childNodes[0], deltaY: -100, preventDefault(){} });
const st1 = rectOf("stack"), ch1 = rectOf("chips"), hp1 = rectOf("p_hp");
ok("group wheel scales the stack", Math.abs(st1.width / st0.width - 1.02) < 1e-6);
ok("members scale with the group", Math.abs(hp1.width / hp0.width - 1.02) < 1e-6);
ok("chips scale with the group", Math.abs(ch1.width / ch0.width - 1.02) < 1e-6);
ok("chips stay above the HP plate, gap scaled with the group", ch1.bottom <= hp1.top + 0.5 && Math.abs((hp1.top - ch1.bottom) - (hp0.top - ch0.bottom) * 1.02) < 0.5,
   `gap0 ${(hp0.top-ch0.bottom).toFixed(2)} gap1 ${(hp1.top-ch1.bottom).toFixed(2)}`);
ok("group scale arms the pin", sheet().indexOf("#chips{bottom:14.15rem!important}") !== -1);

console.log("\n== resize: keys and limits ==");
barEl0.fire("click", { target: mkBtn0("ra") });
ovEl.fire("pointerdown", { target: mapBox, clientX: 100, clientY: 100, pointerId: 50, preventDefault(){} });
window.fire("pointerup", {});
window.fire("keydown", { key: "+", shiftKey: true, preventDefault(){} });
ok("shift + steps 5%", Math.abs(APHE.get()[6][2] - 1.05) < 1e-6, APHE.get()[6][2]);
window.fire("keydown", { key: "-", shiftKey: false, preventDefault(){} });
ok("minus steps 1%", Math.abs(APHE.get()[6][2] - 1.04) < 1e-6, APHE.get()[6][2]);
for (let k = 0; k < 80; k++) window.fire("keydown", { key: "+", shiftKey: true, preventDefault(){} });
ok("scale clamps at 3.0", APHE.get()[6][2] === 3, APHE.get()[6][2]);
ok("3x minimap still inside the viewport", inView(rectOf("mapwrap")), JSON.stringify(rectOf("mapwrap")));
for (let k = 0; k < 200; k++) window.fire("keydown", { key: "-", shiftKey: true, preventDefault(){} });
ok("scale clamps at 0.25", APHE.get()[6][2] === 0.25, APHE.get()[6][2]);
window.fire("keydown", { key: "+", shiftKey: false, preventDefault(){} });
barEl0.fire("click", { target: mkBtn0("rs") });
ok("RESET THIS restores [0,0,1]", APHE.get()[6].join() === "0,0,1", APHE.get()[6].join());

console.log("\n== the payload the server will validate ==");
const barEl = body.childNodes.find(c => c.id === "apEdBar");
const mkBtn = a => ({ getAttribute: k => (k === "data-a" ? a : null) });
calls.length = 0;
barEl.fire("click", { target: mkBtn("sv") });
const sent = calls.find(c => c[0] === "hudLayoutSet");
ok("hudLayoutSet fired", !!sent);
const payload = sent && sent[1][0];
ok("seven triples: dx,dy finite in [-1,1], s finite in [0.25,3]",
   !!payload && payload.length === 7 && payload.every(p => Array.isArray(p) && p.length === 3 &&
     p.slice(0, 2).every(n => typeof n === "number" && isFinite(n) && n >= -1 && n <= 1) &&
     typeof p[2] === "number" && isFinite(p[2]) && p[2] >= 0.25 && p[2] <= 3),
   JSON.stringify(payload));
ok("five decimals or fewer", !!payload && payload.every(p => p.every(n => {
  const s = String(n); const dot = s.indexOf("."); return dot === -1 || s.length - dot - 1 <= 5;
})), JSON.stringify(payload));

console.log("\n== reset ==");
calls.length = 0;
barEl.fire("click", { target: mkBtn("ra") });
ok("reset all zeroes every offset and restores scale 1", APHE.get().every(p => p[0] === 0 && p[1] === 0 && p[2] === 1));
ok("reset all clears the pin", sheet().indexOf("!important") === -1);
barEl.fire("click", { target: mkBtn("ca") });
ok("cancel calls hudLayoutCancel", calls.some(c => c[0] === "hudLayoutCancel"));

console.log("\n-- " + pass + " passed, " + fail + " failed");
process.exit(fail ? 1 : 0);
