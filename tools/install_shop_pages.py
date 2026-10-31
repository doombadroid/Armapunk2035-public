#!/usr/bin/env python3
"""
Install the designer's shop pages (shop-armory.html -> ui/html/armory.html).

Same jobs as the casino installer, same reasons:
 1. THE BRIDGE SHIM in <head> -- window.WEBUI does not exist while the page's own
    script runs, and defining AP synchronously keeps the dev stub from
    installing. This shim also carries AP.texture -> A3API.RequestTexture,
    which needs no bridge at all.
 2. Nothing else: the page's contract (wshop/cash/wsBuy/wsBuyAddon) is
    implemented by SQF as written.

Usage:  python3 tools/install_shop_pages.py <src_dir>
"""
import sys, pathlib

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
DST = pathlib.Path(__file__).resolve().parent.parent / "mission/Armapunk2035.Malden/ui/html"

SHIM = """<script>
/* ---- BRIDGE SHIM (installed by tools/install_shop_pages.py) ---------------
   AP defined synchronously so the page's dev stub never installs; on()/call()
   queue until webui.js lands. AP.texture goes straight to A3API -- no bridge
   round-trip, cached by the page. */
(function () {
  var subs = {}, queued = [], W = null;
  window.WEBUIReady = new Promise(function (r) { window.__webuiReady = r; });
  window.__apSubs = subs;
  window.AP = {
    __shim: true,
    on: function (n, f) { (subs[n] = subs[n] || []).push(f); if (W) W.on(n, f); },
    call: function (n, a) {
      if (W) return W.call(n, a || [], 20000);
      return new Promise(function (res, rej) { queued.push([n, a || [], res, rej]); });
    },
    texture: function (p, s) {
      if (typeof A3API === "undefined" || !A3API.RequestTexture) return Promise.reject(new Error("no A3API"));
      /* ALPHA TRIM. BI gear icons draw the art left-aligned inside a large
         transparent canvas, so object-fit:contain centres the CANVAS, not the
         weapon. Crop to the alpha bounding box before handing it to the page. */
      return A3API.RequestTexture(p, s).then(function (durl) {
        return new Promise(function (res) {
          var im = new Image();
          im.onload = function () {
            try {
              var cv = document.createElement("canvas");
              cv.width = im.width; cv.height = im.height;
              var g = cv.getContext("2d");
              g.drawImage(im, 0, 0);
              var d = g.getImageData(0, 0, cv.width, cv.height).data;
              var x0 = cv.width, y0 = cv.height, x1 = 0, y1 = 0;
              for (var y = 0; y < cv.height; y++) for (var x = 0; x < cv.width; x++) {
                if (d[(y * cv.width + x) * 4 + 3] > 10) {
                  if (x < x0) x0 = x; if (x > x1) x1 = x;
                  if (y < y0) y0 = y; if (y > y1) y1 = y;
                }
              }
              if (x1 <= x0 || y1 <= y0) return res(durl);
              var pad = 2, w = x1 - x0 + 1 + pad * 2, h = y1 - y0 + 1 + pad * 2;
              var out = document.createElement("canvas"); out.width = w; out.height = h;
              out.getContext("2d").drawImage(cv, x0 - pad, y0 - pad, w, h, 0, 0, w, h);
              res(out.toDataURL("image/png"));
            } catch (e) { res(durl); }
          };
          im.onerror = function () { res(durl); };
          im.src = durl;
        });
      });
    },
    handle: function (n, f) { if (W) W.handle(n, f); }
  };
  window.WEBUIReady.then(function (w) {
    W = w;
    Object.keys(subs).forEach(function (n) { subs[n].forEach(function (f) { W.on(n, f); }); });
    queued.forEach(function (q) { W.call(q[0], q[1], 20000).then(q[2], q[3]); });
    queued = [];
    W.call("log", ["armory page up"]);   // instant readiness drain
    /* FLAIR: same page, three uniforms. The payload names the theme; the shim
       applies it so the designer's file stays untouched. */
    ["wshop", "cshop"].forEach(function (ch) {
      W.on(ch, function (v) {
        if (v && v.flair !== undefined) document.body.setAttribute("data-flair", v.flair || "");
      });
    });
  });
  if (typeof A3API !== "undefined" && A3API.RequestFile) {
    A3API.RequestFile("webui\\\\ui\\\\webui.js")
      .then(function (s) { try { (0, eval)(s); } catch (e) { window.__apBootErr = "eval: " + e; } })
      .catch(function (e) { window.__apBootErr = "RequestFile: " + e; });
  } else { window.__apBootErr = "no A3API on this page"; }
})();
</script>
"""

# (src, dst, remW, remH, extra page CSS). rem = min(controlW/remW, controlH/remH)
PAGES = [
    ("shop-armory.html", "armory.html", 50, 35, ""),
    ("loot-card.html", "loot.html", 21, 26, """
/* windowed: the card IS the control; the crosshair + stage belong to the game */
#card{position:fixed!important;inset:0!important;left:0!important;top:0!important;width:auto!important}
#stage{background:transparent!important}
#frame::before{display:none!important}
.xhair{display:none!important}
"""),
    ("shop-fitting-room.html", "fitting.html", 24, 36, """
/* windowed: the card IS the control; the mannequin zone belongs to the game world */
#shop{position:fixed!important;inset:0!important;width:auto!important}
.world{display:none!important}
/* owner deviation: wider card -- let names + [ARMOR n] breathe */
.row .nm{white-space:normal!important;line-height:1.25}
"""),
]
for src_name, dst_name, rem_w, rem_h, extra in PAGES:
    src = SRC / src_name
    if not src.exists():
        print(f"  {src_name}: MISSING"); continue
    s = src.read_text(encoding="utf-8")
    if "BRIDGE SHIM" not in s:
        i = s.find("<style>")
        assert i > 0, f"{src_name}: no <style>"
        s = s[:i] + SHIM + s[i:]

    # WINDOWED FIT. The page was authored against the fullscreen letterbox --
    # #stage paints a dark slab across the whole control around the 50x35rem
    # card, and html{font-size:16px} never scales. In a windowed control the
    # slab is a visible box and the card ignores the size slider. Make the
    # chrome transparent and derive the rem from the control, card centred.
    if "__WINFIT__" not in s:
        s = s.replace("</body>", """<style>
/* __WINFIT__ (installer): windowed control -- no letterbox slab, rem follows the control */
__EXTRA__
/* flair: APD amber, NG green -- the payload's word, applied by the shim */
body[data-flair="tal"]{--gold:#f5a623;--acc:#f5a623;--acc2:#54b0ff;--line:rgba(245,166,35,.15);
  --panel:#0c1622;--panel2:#0e1a28;--scr2:#0a121c;--ink:#dbe6f2;--dim:#7d8b9e;--faint:#3c4a5c}
body[data-flair="med"]{--gold:#7ad06d;--acc:#7ad06d;--line:rgba(122,208,109,.16)}
html,body{background:transparent!important}
#stage{background:transparent!important}
#frame{width:100%!important;height:100%!important;aspect-ratio:auto!important}
</style>
<script>
/* WHEEL SHIM: scroll the nearest scrollable ancestor by hand. Native wheel
   scrolling has not proven itself in a WINDOWED control; this is deterministic
   either way, and preventDefault stops any double-scroll where native works. */
document.addEventListener("wheel", function (e) {
  var el = e.target;
  while (el && el !== document.body) {
    var st = getComputedStyle(el);
    if (/(auto|scroll)/.test(st.overflowY) && el.scrollHeight > el.clientHeight + 1) {
      el.scrollTop += e.deltaY;
      e.preventDefault();
      return;
    }
    el = el.parentElement;
  }
}, { passive: false });
(function __winfit(){
  function fit(){
    var w = window.innerWidth, h = window.innerHeight;
    document.documentElement.style.fontSize = Math.max(9, Math.min(w/__REMW__, h/__REMH__)) + "px";
  }
  window.addEventListener("resize", fit); fit();
})();
</script>
</body>""")
    s = s.replace("__REMW__", str(rem_w)).replace("__REMH__", str(rem_h)).replace("__EXTRA__", extra)
    (DST / dst_name).write_text(s, encoding="utf-8")
    print(f"  {src_name} -> {dst_name}  {len(s)//1024}KB")
print(f"installed into {DST}")
