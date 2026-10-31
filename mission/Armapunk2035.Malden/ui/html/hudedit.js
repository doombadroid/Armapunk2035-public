/*  hudedit.js -- the HUD UI EDITOR's drag overlay. Spec: hudeditor.md §3.

    Loaded INTO ui/html/hud.html at runtime, by the bootstrap that core/web/fn_hudEditOpen.sqf
    injects, and only ever inside dialog 938400. hud.html itself is never modified: its header
    says a designer re-drop replaces the whole document and keeps only the bridge shim, so
    anything written into that file would be silently lost on the next art update.

    ---- WHAT IT MAY AND MAY NOT TOUCH -------------------------------------------------------

    hud.html's render() rewrites, every tick:
        style.bottom  on #p_hp / #p_h2o / #p_food   (line 285) and on #chips (line 308)
        className     on #p_hp / #p_h2o / #p_food   (line 288) and on #wplate (line 298)

    So this file never writes bottom/top/left on a target and never adds a class to one -- both
    would be gone within 83 ms. Position rides on `transform`, which the page writes nowhere on
    #stack, #p_*, #wplate, #chips or #mapwrap, and every outline the editor draws lives on a
    separate overlay layer that mirrors the targets' bounding boxes instead of decorating them.

    ---- THE COORDINATE SYSTEM ---------------------------------------------------------------

    Offsets are VIEWPORT FRACTIONS, not pixels: dx = px / innerWidth. The browser control is the
    full safezone, so a layout built at one resolution or UI scale lands in the same relative
    place at another. Seven triples [dx, dy, s], in the order fn_hudLayoutApply.sqf and the database agree on:

        0 group   1 hp   2 h2o   3 food   4 wanted   5 chips   6 minimap

    The plates are CHILDREN of #stack, so the group's transform moves them for free; #chips is a
    sibling and has to add the group's variables to its own. That asymmetry is the only reason
    the two are written differently in the stylesheet below.

    ---- SCALE (v2, hudeditor.md §9) -----------------------------------------------------------

    The third number of every handle is a uniform scale in [0.25, 3], carried as `scale(var(--apXs))`
    in the SAME transform declaration with a fixed transform-origin: right bottom for everything in
    the bottom-right corner, left top for the minimap. Members divide their translate by the group
    scale so [dx,dy] stays a true screen fraction; #chips gets the product scale and -12.15rem*(sg-1)
    on Y so it rides a scaled stack. All of that is CSS the browser resolves -- the editor only ever
    reads live boxes back with getBoundingClientRect and moves T / s. Resizing keeps one screen point
    fixed (the grip's opposite corner, or the centre for wheel and keys): scaling about the origin
    corner moves that point to o + (f - o)*ratio, so T is pulled back by (f - o)*(1 - ratio).

    ---- THE PIN -----------------------------------------------------------------------------

    With a bounty on screen the page shifts the three plates and the chips up 3.15rem to clear
    room for #wplate. Once a plate has been pulled out of the stack that shift is a visible jump,
    so the bottoms are pinned -- at the WANTED-PRESENT values, because pinning at the other set
    would put #p_food and #wplate both at bottom:0, overlapping. The pin arms in breakout mode (any
    member offset non-zero) and when the GROUP is scaled (the plates' shove would be 3.15*sg and the
    chips' 3.15 -- they would separate), so a player who only moves things keeps the page's stock
    behaviour exactly.
*/
(function () {
  "use strict";

  if (window.APHE) return;                       /* idempotent: a second inject must not double the overlay */

  var D = document, root = D.documentElement;

  /* ---------------------------------------------------------------- handles ---------- */
  var H = [
    { k: "g", id: "stack",   lbl: "VITALS GROUP", group: true },
    { k: "h", id: "p_hp",    lbl: "HP",      member: true },
    { k: "w", id: "p_h2o",   lbl: "H2O",     member: true },
    { k: "f", id: "p_food",  lbl: "FOOD",    member: true },
    { k: "b", id: "wplate",  lbl: "WANTED",  member: true },
    { k: "c", id: "chips",   lbl: "CHIPS",   member: true },
    { k: "m", id: "mapwrap", lbl: "MINIMAP" }
  ];

  var SMIN = 0.25, SMAX = 3;                     /* the server rejects outside this; we clamp */
  function clampS(s) { return Math.max(SMIN, Math.min(SMAX, Math.round(s * 1e5) / 1e5)); }

  var L = [];                                    /* the live layout, 7 triples [dx, dy, s] */
  (function seed() {
    var init = window.APHE_INIT;
    for (var i = 0; i < 7; i++) {
      var p = (init && init[i]) || [0, 0, 1];
      var x = +p[0], y = +p[1], s = p.length > 2 ? +p[2] : 1;   /* a v1 pair reads as scale 1 */
      L.push([isFinite(x) ? x : 0, isFinite(y) ? y : 0, isFinite(s) ? clampS(s) : 1]);
    }
  })();

  var sel = 0;                                   /* selected handle index */
  var drag = null;                               /* {i, sx, sy, ox, oy} while moving */
  var rs = null;                                 /* {i, s0, r0, fx, fy} while resizing by a grip */
  var guides = [];                               /* [{v:true,px:n}] drawn during a drag */

  /* ---------------------------------------------------------------- the page's CSS --- */
  /* Identical rules to core/web/fn_hudLayoutApply.sqf. The two have to agree or a layout
     would land somewhere else the moment it left the editor. calc REQUIRES the spaces around
     the + in the #chips rule; without them the whole expression is invalid and dropped. */
  var RULES =
    "#stack{transform-origin:right bottom;transform:translate(calc(var(--apgx)*100vw),calc(var(--apgy)*100vh)) scale(var(--apgs))}" +
    "#p_hp{transform-origin:right bottom;transform:translate(calc(var(--aphx)*100vw/var(--apgs)),calc(var(--aphy)*100vh/var(--apgs))) scale(var(--aphs))}" +
    "#p_h2o{transform-origin:right bottom;transform:translate(calc(var(--apwx)*100vw/var(--apgs)),calc(var(--apwy)*100vh/var(--apgs))) scale(var(--apws))}" +
    "#p_food{transform-origin:right bottom;transform:translate(calc(var(--apfx)*100vw/var(--apgs)),calc(var(--apfy)*100vh/var(--apgs))) scale(var(--apfs))}" +
    "#wplate{transform-origin:right bottom;transform:translate(calc(var(--apbx)*100vw/var(--apgs)),calc(var(--apby)*100vh/var(--apgs))) scale(var(--apbs))}" +
    "#chips{transform-origin:right bottom;transform:translate(calc((var(--apgx) + var(--apcx))*100vw),calc((var(--apgy) + var(--apcy))*100vh - 12.15rem*(var(--apgs) - 1))) scale(calc(var(--apgs)*var(--apcs)))}" +
    "#mapwrap{transform-origin:left top;transform:translate(calc(var(--apmx)*100vw),calc(var(--apmy)*100vh)) scale(var(--apms))}";

  var PIN =
    "#p_hp{bottom:9.05rem!important}" +
    "#p_h2o{bottom:6.1rem!important}" +
    "#p_food{bottom:3.15rem!important}" +
    "#chips{bottom:14.15rem!important}";

  var pageSheet = D.createElement("style");
  pageSheet.id = "apEd";
  (D.head || root).appendChild(pageSheet);

  function breakout() {
    if (L[0][2] !== 1) return true;              /* a scaled group separates plates from chips */
    for (var i = 1; i <= 5; i++) if (L[i][0] !== 0 || L[i][1] !== 0) return true;
    return false;
  }

  function applyLayout() {
    pageSheet.textContent = RULES + (breakout() ? PIN : "");
    /* Inline on the root element, so these beat the sheet's own :root block and there is only
       ever one place the live value lives. */
    for (var i = 0; i < 7; i++) {
      root.style.setProperty("--ap" + H[i].k + "x", L[i][0].toFixed(5));
      root.style.setProperty("--ap" + H[i].k + "y", L[i][1].toFixed(5));
      root.style.setProperty("--ap" + H[i].k + "s", L[i][2].toFixed(5));
    }
  }

  /* ---------------------------------------------------------------- overlay chrome --- */
  var ov = D.createElement("div");
  ov.id = "apEdOv";
  var css = D.createElement("style");
  css.textContent =
    "#apEdOv{position:fixed;inset:0;z-index:2147483000;pointer-events:none;" +
      "font-family:ui-monospace,'JetBrains Mono',Menlo,Consolas,monospace}" +
    "#apEdOv .box{position:absolute;pointer-events:auto;cursor:move;" +
      "border:1px dashed rgba(201,226,26,.55);background:rgba(201,226,26,.05)}" +
    "#apEdOv .box.sel{border:1px solid #c9e21a;background:rgba(201,226,26,.13);" +
      "box-shadow:0 0 0 1px rgba(7,13,17,.8),0 0 1.2rem rgba(201,226,26,.35)}" +
    "#apEdOv .tag{position:absolute;transform:translateY(-100%);white-space:nowrap;" +
      "font-size:9px;font-weight:800;letter-spacing:.14em;padding:2px 5px;color:#070d11;" +
      "background:rgba(201,226,26,.85);pointer-events:none}" +
    "#apEdOv .box.sel .tag{background:#c9e21a}" +
    "#apEdOv .gp{display:none;position:absolute;width:8px;height:8px;background:#c9e21a;" +
      "border:1px solid #070d11;pointer-events:auto}" +
    "#apEdOv .box.sel .gp{display:block}" +
    "#apEdOv .gp[data-g=tl]{left:-4px;top:-4px;cursor:nwse-resize}" +
    "#apEdOv .gp[data-g=br]{right:-4px;bottom:-4px;cursor:nwse-resize}" +
    "#apEdOv .gp[data-g=tr]{right:-4px;top:-4px;cursor:nesw-resize}" +
    "#apEdOv .gp[data-g=bl]{left:-4px;bottom:-4px;cursor:nesw-resize}" +
    "#apEdOv .gd{position:absolute;background:#ff3d81;pointer-events:none;opacity:.9}" +
    "#apEdOv .gd.v{top:0;bottom:0;width:1px}" +
    "#apEdOv .gd.h{left:0;right:0;height:1px}" +
    "#apEdBar{position:fixed;left:50%;top:1.2rem;transform:translateX(-50%);z-index:2147483001;" +
      "pointer-events:auto;display:flex;gap:.4rem;align-items:center;padding:.45rem .55rem;" +
      "background:rgba(7,13,17,.92);border:1px solid rgba(220,239,224,.22);" +
      "font-family:ui-monospace,'JetBrains Mono',Menlo,Consolas,monospace}" +
    "#apEdBar b{font-size:10px;letter-spacing:.18em;color:#c9e21a;margin-right:.35rem}" +
    "#apEdBar button{font:inherit;font-size:10px;font-weight:800;letter-spacing:.12em;" +
      "padding:.32rem .6rem;cursor:pointer;color:#dcefe0;background:rgba(220,239,224,.08);" +
      "border:1px solid rgba(220,239,224,.28)}" +
    "#apEdBar button:hover{background:rgba(220,239,224,.18)}" +
    "#apEdBar button.go{color:#070d11;background:#c9e21a;border-color:#c9e21a}" +
    "#apEdBar button.no{color:#ff5a3c;border-color:rgba(255,90,60,.45)}" +
    "#apEdHint{position:fixed;left:50%;top:4.2rem;transform:translateX(-50%);z-index:2147483001;" +
      "pointer-events:none;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:9px;" +
      "letter-spacing:.16em;color:#7f938a;text-shadow:0 0 .4rem rgba(7,13,17,.95)}";
  (D.head || root).appendChild(css);
  D.body.appendChild(ov);

  var bar = D.createElement("div");
  bar.id = "apEdBar";
  bar.innerHTML =
    "<b>HUD EDITOR</b>" +
    '<button data-a="rs">RESET THIS</button>' +
    '<button data-a="ra">RESET ALL</button>' +
    '<button class="no" data-a="ca">CANCEL</button>' +
    '<button class="go" data-a="sv">SAVE</button>';
  D.body.appendChild(bar);

  var hint = D.createElement("div");
  hint.id = "apEdHint";
  hint.textContent = "CLICK SELECT · DRAG MOVE · CORNERS/WHEEL/+- RESIZE · ARROWS NUDGE · SHIFT ×10";
  D.body.appendChild(hint);

  /* One box + one tag per handle, created once and repositioned every frame. Creating them per
     frame would make them unclickable: a pointerdown lands on an element that is replaced
     before the pointermove arrives. */
  var boxes = H.map(function (h, i) {
    var b = D.createElement("div");
    b.className = "box";
    b.setAttribute("data-i", i);
    var t = D.createElement("div");
    t.className = "tag";
    t.textContent = h.lbl;
    b.appendChild(t);                            /* FIRST child: paint() addresses the tag as firstChild */
    /* Four corner grips, shown only while selected. Dragging one rescales the handle with the
       opposite corner held still. */
    ["tl", "tr", "bl", "br"].forEach(function (g) {
      var e = D.createElement("div");
      e.className = "gp";
      e.setAttribute("data-g", g);
      b.appendChild(e);
    });
    ov.appendChild(b);
    return b;
  });

  /* ---------------------------------------------------------------- geometry --------- */
  function el(i) { return D.getElementById(H[i].id); }

  function vw() { return window.innerWidth || root.clientWidth; }
  function vh() { return window.innerHeight || root.clientHeight; }

  /* The translate CURRENTLY applied to handle i, in pixels. The plates and the chips inherit or
     re-add the group's, which is why this is not simply L[i]. */
  function appliedPx(i) {
    var gx = L[0][0] * vw(), gy = L[0][1] * vh();
    if (i === 0) return [gx, gy];
    if (i === 6) return [L[6][0] * vw(), L[6][1] * vh()];
    return [gx + L[i][0] * vw(), gy + L[i][1] * vh()];
  }

  /* Rect of handle i as it would sit with NO offset applied at all -- the anchor the offset is
     measured from. Read live rather than cached: the page resizes #stack and re-renders the
     chips, so a value captured at open would be stale by the first bounty. */
  function anchorRect(i) {
    var e = el(i);
    if (!e) return null;
    var r = e.getBoundingClientRect();
    var a = appliedPx(i);
    var out = { l: r.left - a[0], t: r.top - a[1], w: r.width, h: r.height };
    if (H[i].group) {
      /* The group's box is the union of the plates' container and the chips, because the chips
         are part of the group and sit outside #stack's own box. */
      var c = D.getElementById("chips");
      if (c) {
        var cr = c.getBoundingClientRect();
        var ca = appliedPx(5);
        var cl = cr.left - ca[0], ct = cr.top - ca[1];
        var l = Math.min(out.l, cl), t = Math.min(out.t, ct);
        out = { l: l, t: t,
                w: Math.max(out.l + out.w, cl + cr.width) - l,
                h: Math.max(out.t + out.h, ct + cr.height) - t };
      }
    }
    return out;
  }

  /* Where handle i actually is right now, offset included. */
  function liveRect(i) {
    var a = anchorRect(i);
    if (!a) return null;
    var p = appliedPx(i);
    return { l: a.l + p[0], t: a.t + p[1], w: a.w, h: a.h };
  }

  /* ---------------------------------------------------------------- clamp + snap ----- */
  /* Nothing may be dragged off the screen. The clamp is applied to the handle's own box, so a
     member pulled out of the group is bounded by where IT ends up, not by where the group is. */
  function clamp(i, dx, dy) {
    var a = anchorRect(i);
    if (!a) return [dx, dy];
    var gx = (i > 0 && i < 6) ? L[0][0] * vw() : 0;
    var gy = (i > 0 && i < 6) ? L[0][1] * vh() : 0;
    var minX = -a.l - gx, maxX = vw() - a.w - a.l - gx;
    var minY = -a.t - gy, maxY = vh() - a.h - a.t - gy;
    /* An element wider than the viewport would give min > max; keep it pinned at the left/top
       edge rather than letting the clamp invert and throw it off the other side. */
    if (maxX < minX) maxX = minX;
    if (maxY < minY) maxY = minY;
    return [Math.max(minX, Math.min(maxX, dx)), Math.max(minY, Math.min(maxY, dy))];
  }

  var SNAP = 6;

  /* Candidate lines to snap against: the viewport's own edges, centre and thirds, plus every
     other handle's edges and centre. Returns the corrected pixel delta and records the guides
     that were hit so the overlay can draw them. */
  function snap(i, px, py) {
    var a = anchorRect(i);
    if (!a) return [px, py];
    var gx = (i > 0 && i < 6) ? L[0][0] * vw() : 0;
    var gy = (i > 0 && i < 6) ? L[0][1] * vh() : 0;
    var l = a.l + gx + px, t = a.t + gy + py, w = a.w, h = a.h;

    var xs = [0, vw() / 3, vw() / 2, (2 * vw()) / 3, vw()];
    var ys = [0, vh() / 3, vh() / 2, (2 * vh()) / 3, vh()];
    for (var j = 0; j < 7; j++) {
      if (j === i) continue;
      /* A member is inside the group it is being dragged out of; snapping it to the group's own
         union box tells you nothing useful, so the group is not a snap target for its members. */
      if (H[j].group && H[i].member) continue;
      var r = liveRect(j);
      if (!r) continue;
      xs.push(r.l, r.l + r.w / 2, r.l + r.w);
      ys.push(r.t, r.t + r.h / 2, r.t + r.h);
    }

    guides = [];
    var bestX = null, bestXd = SNAP + 1, bestXg = 0;
    var mine = [l, l + w / 2, l + w];
    for (var xi = 0; xi < xs.length; xi++) {
      for (var mi = 0; mi < 3; mi++) {
        var d = xs[xi] - mine[mi];
        if (Math.abs(d) < Math.abs(bestXd)) { bestXd = d; bestX = xs[xi]; bestXg = d; }
      }
    }
    if (bestX !== null && Math.abs(bestXd) <= SNAP) { px += bestXg; guides.push({ v: true, px: bestX }); }

    var bestY = null, bestYd = SNAP + 1, bestYg = 0;
    var miney = [t, t + h / 2, t + h];
    for (var yi = 0; yi < ys.length; yi++) {
      for (var mj = 0; mj < 3; mj++) {
        var e = ys[yi] - miney[mj];
        if (Math.abs(e) < Math.abs(bestYd)) { bestYd = e; bestY = ys[yi]; bestYg = e; }
      }
    }
    if (bestY !== null && Math.abs(bestYd) <= SNAP) { py += bestYg; guides.push({ v: false, px: bestY }); }

    return [px, py];
  }

  function setPx(i, px, py) {
    var c = clamp(i, px, py);
    L[i][0] = c[0] / vw();
    L[i][1] = c[1] / vh();
    applyLayout();
  }

  /* The transform-origin corner of handle i's live box: right-bottom for everything anchored in
     that corner, left-top for the minimap. Scaling in CSS happens about this point. */
  function originOf(i, r) {
    return (i === 6) ? [r.l, r.t] : [r.l + r.w, r.t + r.h];
  }

  /* Set handle i's OWN scale, keeping screen point (fx, fy) where it is. Scaling about the origin
     corner o carries f to o + (f - o)*ratio; the translate is pulled back by the difference. For a
     member the effective scale is sg*own, but sg is constant here so the ratio is the same. */
  function setScale(i, sNew, fx, fy) {
    var r = liveRect(i);
    if (!r) return;
    sNew = clampS(sNew);
    var ratio = sNew / L[i][2];
    if (ratio === 1) return;
    var o = originOf(i, r);
    var dx = (fx - o[0]) * (1 - ratio), dy = (fy - o[1]) * (1 - ratio);
    L[i][2] = sNew;
    applyLayout();
    var a = appliedPx(i);
    var gx = (i > 0 && i < 6) ? L[0][0] * vw() : 0;
    var gy = (i > 0 && i < 6) ? L[0][1] * vh() : 0;
    setPx(i, a[0] - gx + dx, a[1] - gy + dy);
  }

  function centreScale(i, delta) {
    var r = liveRect(i);
    if (!r) return;
    setScale(i, L[i][2] + delta, r.l + r.w / 2, r.t + r.h / 2);
  }

  /* ---------------------------------------------------------------- drawing ---------- */
  var gdEls = [];
  function drawGuides() {
    while (gdEls.length > guides.length) ov.removeChild(gdEls.pop());
    while (gdEls.length < guides.length) {
      var g = D.createElement("div");
      g.className = "gd";
      ov.appendChild(g);
      gdEls.push(g);
    }
    for (var i = 0; i < guides.length; i++) {
      var e = gdEls[i];
      e.className = "gd " + (guides[i].v ? "v" : "h");
      if (guides[i].v) { e.style.left = guides[i].px + "px"; e.style.top = ""; }
      else { e.style.top = guides[i].px + "px"; e.style.left = ""; }
    }
  }

  function paint() {
    for (var i = 0; i < 7; i++) {
      var r = liveRect(i);
      var b = boxes[i];
      if (!r || r.w <= 0 || r.h <= 0) { b.style.display = "none"; continue; }
      b.style.display = "";
      b.style.left = r.l + "px";
      b.style.top = r.t + "px";
      b.style.width = r.w + "px";
      b.style.height = r.h + "px";
      b.className = "box" + (i === sel ? " sel" : "");
      /* The tag hangs above its box, except at the very top of the screen where it would be
         off-viewport and unreadable. */
      b.firstChild.style.top = (r.t < 14 ? r.h + "px" : "0px");
      b.firstChild.style.transform = (r.t < 14 ? "translateY(0)" : "translateY(-100%)");
      b.firstChild.style.left = "0px";
    }
    drawGuides();
    requestAnimationFrame(paint);
  }
  requestAnimationFrame(paint);

  /* ---------------------------------------------------------------- input ------------ */
  /* The group's box is the union of every member, so it sits UNDER all of them in hit order --
     which is why the boxes are appended group-first and the members after it: a click inside a
     plate reaches the plate, and a click in the group box but outside every plate reaches the
     group. */
  ov.addEventListener("pointerdown", function (ev) {
    var t = ev.target, grip = null;
    while (t && t !== ov && !t.hasAttribute("data-i")) {
      if (t.hasAttribute("data-g")) grip = t.getAttribute("data-g");
      t = t.parentNode;
    }
    if (!t || t === ov) return;
    var i = +t.getAttribute("data-i");
    sel = i;
    if (grip) {
      /* Resize: the grip's opposite corner is the fixed point for the whole gesture. */
      var r = liveRect(i);
      if (!r) return;
      rs = { i: i, s0: L[i][2], r0: r,
             fx: (grip === "tl" || grip === "bl") ? r.l + r.w : r.l,
             fy: (grip === "tl" || grip === "tr") ? r.t + r.h : r.t };
      try { t.setPointerCapture(ev.pointerId); } catch (e) { /* not fatal */ }
      ev.preventDefault();
      return;
    }
    var a = appliedPx(i);
    var gx = (i > 0 && i < 6) ? L[0][0] * vw() : 0;
    var gy = (i > 0 && i < 6) ? L[0][1] * vh() : 0;
    drag = { i: i, sx: ev.clientX, sy: ev.clientY, ox: a[0] - gx, oy: a[1] - gy };
    try { t.setPointerCapture(ev.pointerId); } catch (e) { /* not fatal: the window handlers below still fire */ }
    ev.preventDefault();
  });

  window.addEventListener("pointermove", function (ev) {
    if (rs) {
      /* Uniform: the dominant axis wins, so the box follows whichever way the cursor pulled
         harder and never distorts. Measured against the START box, so the gesture is absolute
         and a jittery pointer cannot ratchet the scale. */
      var w1 = Math.abs(ev.clientX - rs.fx), h1 = Math.abs(ev.clientY - rs.fy);
      var ratio = Math.max(w1 / rs.r0.w, h1 / rs.r0.h);
      setScale(rs.i, rs.s0 * ratio, rs.fx, rs.fy);
      ev.preventDefault();
      return;
    }
    if (!drag) return;
    var px = drag.ox + (ev.clientX - drag.sx);
    var py = drag.oy + (ev.clientY - drag.sy);
    var s = snap(drag.i, px, py);
    setPx(drag.i, s[0], s[1]);
    ev.preventDefault();
  });

  window.addEventListener("pointerup", function () {
    rs = null;
    if (!drag) return;
    drag = null;
    guides = [];
  });

  /* Wheel over a handle: 2 % per notch about its centre. Selects it too, so the keys follow. */
  window.addEventListener("wheel", function (ev) {
    var t = ev.target;
    while (t && t !== ov && !(t.hasAttribute && t.hasAttribute("data-i"))) t = t.parentNode;
    if (!t || t === ov) return;
    var i = +t.getAttribute("data-i");
    sel = i;
    centreScale(i, ev.deltaY < 0 ? 0.02 : -0.02);
    ev.preventDefault();
  }, { passive: false });

  /* Page-side keydown is proven in this mission: terminal.html is the breach minigame and the
     player types commands into it, single characters with preventDefault. */
  window.addEventListener("keydown", function (ev) {
    var step = ev.shiftKey ? 10 : 1;
    var dx = 0, dy = 0;
    if (ev.key === "ArrowLeft") dx = -step;
    else if (ev.key === "ArrowRight") dx = step;
    else if (ev.key === "ArrowUp") dy = -step;
    else if (ev.key === "ArrowDown") dy = step;
    else if (ev.key === "Tab") { sel = (sel + (ev.shiftKey ? 6 : 1)) % 7; ev.preventDefault(); return; }
    else if (ev.key === "+" || ev.key === "=") { centreScale(sel, ev.shiftKey ? 0.05 : 0.01); ev.preventDefault(); return; }
    else if (ev.key === "-" || ev.key === "_") { centreScale(sel, ev.shiftKey ? -0.05 : -0.01); ev.preventDefault(); return; }
    else return;
    var gx = (sel > 0 && sel < 6) ? L[0][0] * vw() : 0;
    var gy = (sel > 0 && sel < 6) ? L[0][1] * vh() : 0;
    var cur = appliedPx(sel);
    setPx(sel, cur[0] - gx + dx, cur[1] - gy + dy);
    ev.preventDefault();
  });

  /* A resize (the player changing UI scale mid-edit, or an alt-tab that re-lays out the page)
     changes what a fraction means in pixels but not the fraction itself, so nothing has to be
     recomputed -- except the clamp, which may now be violated. Re-clamp everything. */
  window.addEventListener("resize", function () {
    for (var i = 0; i < 7; i++) {
      var gx = (i > 0 && i < 6) ? L[0][0] * vw() : 0;
      var gy = (i > 0 && i < 6) ? L[0][1] * vh() : 0;
      var a = appliedPx(i);
      setPx(i, a[0] - gx, a[1] - gy);
    }
  });

  /* ---------------------------------------------------------------- toolbar ---------- */
  function call(name, args) {
    if (window.WEBUI && window.WEBUI.call) return window.WEBUI.call(name, args || []);
    return null;
  }

  bar.addEventListener("click", function (ev) {
    var a = ev.target && ev.target.getAttribute && ev.target.getAttribute("data-a");
    if (!a) return;
    if (a === "rs") { L[sel] = [0, 0, 1]; applyLayout(); }
    else if (a === "ra") { for (var i = 0; i < 7; i++) L[i] = [0, 0, 1]; applyLayout(); }
    else if (a === "ca") { call("hudLayoutCancel", []); }
    else if (a === "sv") {
      /* Rounded before it leaves: five decimals of a viewport fraction is a fraction of a pixel
         at any resolution, and it keeps the JSON in the database short and diffable. */
      var out = L.map(function (p) { return [+p[0].toFixed(5), +p[1].toFixed(5), +p[2].toFixed(5)]; });
      call("hudLayoutSet", [out]);
    }
  });

  /* ---------------------------------------------------------------- go --------------- */
  applyLayout();

  window.APHE = {
    /* Re-assert the editor's own view of the layout over anything that has touched the page
       since. Nothing calls this on the normal path -- SQF deliberately does not push a layout
       into an open editor, because a late answer landing mid-edit would throw away work in
       progress -- but it is the recovery if something ever does. */
    sync: applyLayout,
    get: function () { return L; }
  };

  call("log", ["editor overlay up, " + JSON.stringify(L)]);
})();
