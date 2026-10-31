#!/usr/bin/env python3
"""
Install the designer's casino tables into the mission.

The delivered pages are browser-review artifacts. Three things have to change
before they work in game, and doing it here rather than by hand means a re-drop
is one command and the diff against the designer's file stays readable.

 1. THE BRIDGE SHIM. window.WEBUI does not exist while a page's own script runs
    -- it is injected afterwards -- so a page that touches it at load is deaf.
    The pages also expect an `AP` global; the library exposes `WEBUI`. The shim
    defines AP SYNCHRONOUSLY in <head>, before their script, which also means
    their `if (typeof AP === "undefined")` dev stub never installs itself. Calls
    and subscriptions made before the bridge lands are queued and flushed.

 2. "coin" -> "coinflip". The pages send the table id "coin"; the server engine
    and APS_fnc_casinoSRV call it "coinflip".

 3. The landing's <a href> tiles become table-switch calls -- there is no
    navigation inside the control, so SQF closes this dialog and opens another.

Usage:  python3 tools/install_casino_pages.py <src_dir> [table ...]

RUN IT FOR THE TABLES YOU ARE ACTUALLY SHIPPING. With no table names it does all
of them, which is right for a full re-drop and WRONG for a delivery that only
revised one page: the source directory is whatever the designer last exported,
so a blanket run quietly replaces six shipped tables with whatever snapshot
happens to be sitting next to the one you wanted. The hold'em delivery was
exactly that case -- eight files in the drop, two of them in scope.

  python3 tools/install_casino_pages.py <src_dir> holdem landing
"""
import sys, re, pathlib

SRC = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
ONLY = [t.lower() for t in sys.argv[2:]]
DST = pathlib.Path(__file__).resolve().parent.parent / "mission/Armapunk2035.Malden/ui/html/casino"
DST.mkdir(parents=True, exist_ok=True)

SHIM = """<script>
/* ---- BRIDGE SHIM (installed by tools/install_casino_pages.py) --------------
   window.WEBUI does not exist while this page's own script runs; the bridge is
   INJECTED afterwards. Anything that touches it at load is silently deaf, which
   is how the first web shop shipped.

   AP is defined here, synchronously, before the page's script -- so its
   `if (typeof AP === "undefined")` dev stub never installs, and every on()/call()
   made before the bridge lands is queued and flushed when it does. -------- */
(function () {
  var subs = {}, queued = [], W = null;
  window.WEBUIReady = new Promise(function (r) { window.__webuiReady = r; });
  /* Instrumentation for AP_fnc_casinoDiag. The browser console is unreachable
     in game -- Esc opens it and closes the dialog -- so a deaf page has to be
     able to say why on its own surface. */
  window.__apSubs = subs;
  /* A throw inside a channel handler is CAUGHT by webui.js and console.error'd,
     and the console is unreachable in game -- so a payload the page cannot read
     looks exactly like a payload that never arrived. Wrapping every handler
     records the first failure where the diagnostic can print it. */
  function guard(n, f) {
    return function (v) {
      try { return f(v); }
      catch (e) { if (!window.__apHandlerErr) window.__apHandlerErr = n + ": " + e; throw e; }
    };
  }
  window.AP = {
    __shim: true,
    on: function (n, f) {
      (subs[n] = subs[n] || []).push(guard(n, f));
      if (W) W.on(n, subs[n][subs[n].length - 1]);
    },
    call: function (n, a) {
      if (W) return W.call(n, a || [], 20000);
      return new Promise(function (res, rej) { queued.push([n, a || [], res, rej]); });
    },
    handle: function (n, f) { if (W) W.handle(n, f); }
  };
  /* SOME PAGES CALL BACK, THEY DO NOT AWAIT. holdem.html's helper is
     AP.call(name, args, cb) -- a third argument webui.js's promise-returning
     call(name, args, timeout) knows nothing about. Unbridged, every hSit/hAct
     answer resolves into nothing: a refused seat or an illegal raise returns
     {ok:false,err:"..."} and the page never runs the flash() that would show it,
     so the click looks like it did nothing at all. Same shape the duty terminal
     needed (fn dutyTermBridge / duty_maxsec.html), same fix.
     A REJECTED promise -- the 20 s shim timeout, or an SQF handler that threw --
     becomes the page's own refusal shape too, carrying BOTH keys because the
     older tables read r.msg and holdem.html reads r.err. The wrapper still
     returns the promise, so the .then() callers are untouched. */
  var _rawCall = window.AP.call;
  window.AP.call = function (n, a, cb) {
    var p = _rawCall(n, a).catch(function () {
      return { ok: false, err: "NO ANSWER FROM THE SERVER -- TRY AGAIN",
                          msg: "NO ANSWER FROM THE SERVER -- TRY AGAIN" };
    });
    if (typeof cb !== "function") { return p; }
    p.then(function (v) {
      try { cb(v); }
      catch (e) { if (!window.__apCbErr) window.__apCbErr = n + ": " + e; }
    });
    return p;
  };
  window.WEBUIReady.then(function (w) {
    W = w;
    Object.keys(subs).forEach(function (n) { subs[n].forEach(function (f) { W.on(n, f); }); });
    W.on("casino", function () { window.__apGotCasino = true; });
    queued.forEach(function (q) { W.call(q[0], q[1], 20000).then(q[2], q[3]); });
    queued = [];
  });
  /* A <script src> cannot work here -- the page has no resolvable base URL and
     the src quietly resolves to nothing. SQF injects the same file too and
     webui.js is idempotent, so whichever lands first wins. */
  if (typeof A3API !== "undefined" && A3API.RequestFile) {
    A3API.RequestFile("webui\\\\ui\\\\webui.js")
      .then(function (s) { try { (0, eval)(s); } catch (e) { window.__apBootErr = "eval: " + e; } })
      .catch(function (e) { window.__apBootErr = "RequestFile: " + e; });
  } else {
    window.__apBootErr = "no A3API on this page";
  }
})();
</script>
"""

TABLES = ["landing", "wheel", "crash", "slots", "roulette", "coinflip", "hilo", "blackjack", "holdem"]
if ONLY:
    unknown = [t for t in ONLY if t not in TABLES]
    assert not unknown, f"no such table: {unknown} (known: {TABLES})"
report = []
for t in TABLES:
    if ONLY and t not in ONLY:
        continue
    src = SRC / f"casino-{t}.html"
    if not src.exists():
        report.append((t, "MISSING")); continue
    s = src.read_text(encoding="utf-8")

    if "BRIDGE SHIM" not in s:
        i = s.find("<style>")
        assert i > 0, f"{t}: no <style> to anchor before"
        s = s[:i] + SHIM + s[i:]

    # THE TABLE IS CALLED "coinflip". The page calls it "coin" in four places and
    # only one of them is the outgoing call -- the other three are the guard that
    # decides whether an arriving result belongs to this table, plus the dev stub.
    # Rewriting only the call left `if (r.game !== "coin") return;` in place, so
    # every result the server sent was dropped and the coin never came down.
    # Explicit strings, because "coin" is also the canvas id and the #coin selector.
    _coin = [r'"coin"\s*,\s*"play"', r'a\[0\] !== "coin"', r'game:"coin"', r'r\.game !== "coin"']
    n_coin = sum(len(re.findall(x, s)) for x in _coin)
    s = re.sub(r'"coin"(\s*,\s*"play")', r'"coinflip"\1', s)
    s = s.replace('a[0] !== "coin"', 'a[0] !== "coinflip"')
    s = s.replace('game:"coin"', 'game:"coinflip"')
    s = s.replace('r.game !== "coin"', 'r.game !== "coinflip"')

    # A table's BACK link is <a href="casino-landing.html"> -- a navigation. There
    # is no base URL for it to resolve against, and even if the file did load, a
    # page the control navigates to itself never gets A3API bound and is deaf.
    # Leaving the floor is SQF's job, same as arriving at a table.
    n_back = s.count('href="casino-landing.html"')
    s = s.replace('<a class="back" href="casino-landing.html">',
                  '<a class="back" href="#" onclick="AP.call(\'casTable\',[\'landing\']);return false;">')

    # CRASH growth rate. The server climbs at K=0.1386 ("MUST match the client
    # render loop"), the page at 0.13. The page therefore displays a multiplier
    # BELOW the real one for the whole round -- at ~17s it reads 9.1x where the
    # server is at 10.5x -- so a bust lands while the number on screen is still
    # short of the bust point, which reads as the table cheating.
    n_k = s.count("const K = 0.13,")
    s = s.replace("const K = 0.13,", "const K = 0.1386,")

    # HI-LO first-card test. The page looks for the tag "deal"; the server sends
    # "" on the deal and "win"/"lose"/"cashout" after. So `first` was never true
    # and the deal rendered as a won streak. prevCard is -1 only on the deal.
    n_first = s.count('const first = p[6] === "deal";')
    s = s.replace('const first = p[6] === "deal";',
                  'const first = p[5] === -1;   /* server sends tag "" on the deal; prevCard -1 is the marker */')

    n_rig = len(re.findall(r'.*DEMO RIG.*\n', s))
    s = re.sub(r'.*DEMO RIG.*\n', '', s)

    # CLICKS THAT NEED A SECOND TRY. renderActions() and renderSeats() rewrite
    # their container's innerHTML on EVERY bj:table snapshot, and a snapshot
    # arrives on every clock tick. So the button is destroyed and rebuilt under
    # the cursor: if the rebuild lands between mousedown and mouseup, the element
    # that got the mousedown no longer exists and no click event is ever fired.
    # Reported in game and reproduced in the standalone page, which is exactly
    # what you would expect -- the mock ticks its own clock the same way.
    #
    # Event delegation does NOT fix this; the element still vanishes mid-gesture.
    # The fix is to stop rebuilding markup that has not changed.
    n_click = 0
    if t == "blackjack":
        old_acts = s[s.index("function renderActions() {"):s.index("const PU_META = {")]
        new_acts = """function renderActions() {
  const box = $("#actions");
  if (!table) { box.innerHTML = ""; box.dataset.sig = ""; return; }
  const me = table.seats.find(s => s.you);
  const showClock = !!(me && table.clock && table.clock.seat === me.seat && table.phase === "acting");
  const acts = (me && me.actions && me.actions.length) ? me.actions : [];
  /* Rebuild ONLY when the offered moves change. The clock is a width, not markup. */
  const sig = (showClock ? "c" : "-") + "|" + acts.join(",");
  if (box.dataset.sig !== sig) {
    box.dataset.sig = sig;
    let html = "";
    if (showClock) html += \'<div class="clock"><span></span></div>\';
    if (acts.length) html += \'<div class="actRow">\' + acts.map(a => \'<button class="act" data-a="\' + a + \'">\' + a.toUpperCase() + "</button>").join("") + "</div>";
    box.innerHTML = html;
    [...box.querySelectorAll(".act")].forEach(b => b.onclick = () => { AP.call("bjAct", [b.dataset.a]).then(r => { if (r && r.ok === false) say("// " + (r.msg || "").toUpperCase(), "bad"); }); felt.kick(4000); });
  }
  if (showClock) {
    const c = box.querySelector(".clock");
    if (c) {
      c.classList.toggle("low", table.clock.secs <= 5);
      c.firstElementChild.style.width = Math.max(0, table.clock.secs / 20 * 100) + "%";
    }
  }
}
"""
        s = s.replace(old_acts, new_acts)
        n_click += 1

        # same disease on the seat plate: SIT is a button inside a container that
        # is rewritten wholesale every tick
        # The seat plate has the same disease. It has to be BUILT first and
        # compared before the write -- checking innerHTML afterwards is too late,
        # the buttons are already gone by then.
        a1 = '  $("#seats").innerHTML = table.seats.map(s => {'
        a2 = '  }).join("");\n  [...document.querySelectorAll(".sitBtn")]'
        if a1 in s and a2 in s:
            s = s.replace(a1, '  const __h = table.seats.map(s => {')
            s = s.replace(a2, '''  }).join("");
  /* Skip the write when nothing changed, or SIT is destroyed under the cursor
     exactly the way the action buttons were. */
  if (__h === __seatHTML) return;
  __seatHTML = __h;
  $("#seats").innerHTML = __h;
  [...document.querySelectorAll(".sitBtn")]''')
            s = s.replace('function renderSeats() {', 'let __seatHTML = "";\nfunction renderSeats() {', 1)
            n_click += 1

    n_href = 0
    if t == "landing":
        # tiles navigate by href for browser review; in game SQF swaps the dialog
        before = s
        s = s.replace("const href = t.built ? ' href=\"' + t.href + '\"' : \"\";",
                      "const href = t.built ? ' data-table=\"' + t.id + '\"' : \"\";")
        n_href = 0 if s == before else 1
        if "casTable" not in s:
            s = s.replace("</body>", """<script>
/* In game there is no navigation inside the control: SQF closes this dialog and
   opens the table's own. Added by the installer. */
document.addEventListener("click", function (ev) {
  var a = ev.target.closest && ev.target.closest("[data-table]");
  if (!a) return;
  ev.preventDefault();
  AP.call("casTable", [a.getAttribute("data-table")]);
});
</script>
</body>""")

    (DST / f"{t}.html").write_text(s, encoding="utf-8")
    report.append((t, f"shim+  coin->coinflip:{n_coin}  href->call:{n_href}  back->call:{n_back}  K:{n_k}  first:{n_first}  rig:{n_rig}  click:{n_click}  {len(s)//1024}KB"))

for t, r in report: print(f"  {t:<10} {r}")
print(f"\ninstalled into {DST}")
