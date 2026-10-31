# Feedback Tracker report — `A3API.RequestTexture` fails by resolving

Paste into <https://report.bistudio.com/projects/arma-3/general>.
Raised at Dedmen's request: *"There are actually not any checks for failure in
engine. If I get a ticket I can probably fix it."*

- **Category:** Scripting / GUI (CWebBrowser)
- **Severity:** Minor · **Reproducibility:** Always
- **Version:** 2.22.154020, Stable, Public (exe 2026-08-14) — Linux/Proton, DX11 x64

---

## Title

`A3API.RequestTexture` resolves with a short stub instead of rejecting when the
texture does not exist

## Summary

In a `CT_WEBBROWSER` (type 106) control, the page-side JS API
`A3API.RequestTexture(path, maxSize)` returns a Promise. When `path` does not
resolve to a texture in the game filesystem, that Promise **resolves** with a
23-character string rather than rejecting or resolving with `null`.

**The engine already knows the lookup failed** — it logs
`Unknown sampler texture type` to the RPT at that moment. It just does not
propagate that to the Promise. So the failure is detected and then discarded,
and a caller cannot distinguish "texture loaded" from "texture missing" except
by guessing at a length threshold on the returned data URL.

## Steps to reproduce

Minimal mission, three files. Values are copied from a working setup rather than
derived, including the `\\` in the whitelist against the single `\` in `url=`.

**`description.ext`**

```cpp
class CfgCommands
{
    // Without this the page still renders but gets no A3API binding at all.
    allowedHTMLLoadURIs[] += { "ui\\*" };
};

class BugProbe
{
    idd = 990100;
    movingEnable = 0;
    enableSimulation = 1;
    class controls
    {
        class Page
        {
            idc = 990101;
            type = 106;                 // CT_WEBBROWSER
            style = 0;
            x = 0.1; y = 0.1; w = 0.8; h = 0.8;
            colorBackground[] = {0,0,0,1};
            colorText[] = {1,1,1,1};
            font = "RobotoCondensed";
            sizeEx = 0.03;
            url = "ui\probe.html";
        };
    };
};
```

**`ui\probe.html`**

```html
<!doctype html>
<meta charset="utf-8">
<body style="background:#111;color:#eee;font:13px monospace;white-space:pre-wrap">
<div id="o"></div>
<script>
var o = document.getElementById('o');
function line(s){ o.textContent += s + "\n"; }
line("A3API present: " + (typeof A3API !== "undefined"));

var MISSING = "this\\path\\does\\not\\exist.paa";
var VALID   = "a3\\weapons_f\\rifles\\mx\\data\\ui\\gear_mx_rifle_x_ca.paa";

function probe(label, path){
  return A3API.RequestTexture(path, 256).then(
    function (v){
      line(label + " RESOLVED"
         + "  typeof=" + (typeof v)
         + "  length=" + (v === null || v === undefined ? "n/a" : String(v).length));
      line("      value=" + JSON.stringify(String(v)).slice(0, 200));
    },
    function (e){ line(label + " REJECTED  " + e); }
  );
}
probe("[missing]", MISSING).then(function (){ return probe("[valid]  ", VALID); });
</script>
</body>
```

**`init.sqf`**

```sqf
[] spawn { waitUntil { !isNull findDisplay 46 }; createDialog "BugProbe"; };
```

Launch the mission. The control prints both results.

## Current result

`[missing]` **RESOLVES** with a 23-character string — no image payload behind
it. No rejection and no exception, though `Unknown sampler texture type` does
appear in the RPT at that moment.

`[valid]` resolves with a full data URL. Measured on 2.22 against a stock
addon path and a mission-root path respectively:

```
mission-relative    : FAIL     23 chars
mission root + rel  : OK     2007 chars
a3 addon path       : OK     5463 chars
```

*(The 23 is measured, bisected against those two working cases in the same
session. The stub's exact bytes are deliberately not quoted — we have only ever
recorded its length, never captured the string. The repro above prints it, so
the first run produces that datum rather than us guessing at it.)*

## Expected result

One of, in order of preference:

1. **Reject the Promise** with a diagnosable reason, so `.catch()` works and
   `await` throws — the normal contract for an async lookup that failed.
2. Resolve with `null` or `""`, so a falsy check is sufficient.

Either is fine. What does not work is resolving with a short truthy string that
is shaped like success.

## Why it matters

Every consumer has to invent a length heuristic. Ours, shipped, is:

```js
// a failed lookup resolves with a stub, it does not reject
if (typeof url === "string" && url.length > 128) return url;
return next(i + 1);   // try the next candidate path
```

That magic `128` is a guess about how short a real data URL can be, and it is
wrong in both directions:

- **False negative.** A legitimately tiny texture — a small mip at a low
  `maxSize` — could encode to under 128 characters and be discarded as missing.
- **False positive.** If the stub ever grows past 128 characters, every consumer
  silently starts treating failure as success.

It also makes fallback logic awkward. Because a miss is indistinguishable from a
hit without the heuristic, a path-retry loop (mission-relative → mission-root →
addon path) is driven entirely off a string-length comparison rather than off
the API telling it anything.

And a typo'd path is invisible to the page: it renders as a blank image with no
error on either side of the bridge. The RPT line is the only trace, and it names
a sampler problem rather than the path that was asked for, so it does not lead
back to the call site on its own.

## Additional information

**Sibling APIs may share this.** The same control exposes `A3API.RequestFile`
and `A3API.RequestPreprocessedFile`. We use `RequestFile` heavily (57 call sites)
and have never characterised its miss behaviour — we pass it straight through
with no length guard, which means if it fails the same way we are currently
mistaking failures for empty files. Given "there are actually not any checks for
failure in engine", the whole family is worth one pass rather than three
tickets.

**Context.** Found while building HTML UI on `CT_WEBBROWSER` for an Arma 3 game
mode that draws `.paa` art into browser pages — quickhack icons, weapon-shop
imagery, and a browser-rendered map built from the terrain's own satellite tiles
(`a3\map_<world>\data\layers\s_XXX_YYY_lco.paa`). Roughly 22 `RequestTexture`
call sites, all funnelled through one wrapper specifically so the length
heuristic lives in a single place.
