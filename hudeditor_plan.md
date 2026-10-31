# HUD editor v2 (resize) — build plan

> Design: `hudeditor.md` §9. DONE 2026-09-07 (ba0d52f0, dev b0991; owner walk-test §9.7 pending). Execution: inline, this session (owner: "approved, write the spec and go",
> 2026-09-07). Steps use `- [ ]`. Commit straight to main (CLAUDE.md, 2026-08-21 rule).

**Goal:** every HUD editor handle also carries a uniform scale `s` (0.25–3.0), set by corner grips,
mouse wheel or `+`/`-`, persisted as `[dx,dy,s]` triples, applied identically by the live layer and
the editor.

**Architecture:** scale rides in the same injected `transform` the v1 position uses (`render()` never
writes transform), with a fixed `transform-origin` per element. Members nest in the scaled `#stack`
(effective scale = group × own; translate divided by group scale keeps offsets screen fractions);
`#chips` gets the product scale and a `−12.15rem·(sg−1)` Y term so it rides the stack. Pin arms on
breakout OR group scale ≠ 1. Client normaliser clamps, server rejects (unchanged asymmetry).

**Tech:** SQF (Arma 3 2.22), arma-webui bridge, `hudedit.js` injected at runtime (hud.html untouched),
Postgres jsonb column (no schema change), node harness `tools/test_hudedit.js`, parity gate
`tools/hudlayout_parity.py`.

## Global constraints

- `hud.html` is NOT edited (designer re-drop rule, hudeditor.md §2.2).
- No `compile` anywhere; column read with `parseSimpleArray`; no `profileNamespace`.
- Server identity = `remoteExecutedOwner` captured first frame (carrier pattern already in file).
- CSS emitted by `fn_hudLayoutApply.sqf` and `hudedit.js` must stay byte-identical (parity gate).
- Numbers only via `toFixed 5` / `toFixed(5)` — SQF `format %1` may emit exponent form.
- Commit trailer: `Co-Authored-By: <defunct AI>` name only, rotate (no Anthropic trailer).
- `docs/` is gitignored → this plan lives at repo root like `inventory_plan.md`.

## Contract (both emitters + both validators build against THIS)

Entry `i` = `[dx, dy, s]`; dx,dy ∈ [-1,1], s ∈ [0.25,3]; default `[0,0,1]`. Handle order unchanged:
`0 g group · 1 h hp · 2 w h2o · 3 f food · 4 b wanted · 5 c chips · 6 m minimap`.
CSS vars: `--ap<k>x --ap<k>y --ap<k>s`.

RULES (exact string, concatenated, no whitespace between rules):
```
#stack{transform-origin:right bottom;transform:translate(calc(var(--apgx)*100vw),calc(var(--apgy)*100vh)) scale(var(--apgs))}
#p_hp{transform-origin:right bottom;transform:translate(calc(var(--aphx)*100vw/var(--apgs)),calc(var(--aphy)*100vh/var(--apgs))) scale(var(--aphs))}
#p_h2o{transform-origin:right bottom;transform:translate(calc(var(--apwx)*100vw/var(--apgs)),calc(var(--apwy)*100vh/var(--apgs))) scale(var(--apws))}
#p_food{transform-origin:right bottom;transform:translate(calc(var(--apfx)*100vw/var(--apgs)),calc(var(--apfy)*100vh/var(--apgs))) scale(var(--apfs))}
#wplate{transform-origin:right bottom;transform:translate(calc(var(--apbx)*100vw/var(--apgs)),calc(var(--apby)*100vh/var(--apgs))) scale(var(--apbs))}
#chips{transform-origin:right bottom;transform:translate(calc((var(--apgx) + var(--apcx))*100vw),calc((var(--apgy) + var(--apcy))*100vh - 12.15rem*(var(--apgs) - 1))) scale(calc(var(--apgs)*var(--apcs)))}
#mapwrap{transform-origin:left top;transform:translate(calc(var(--apmx)*100vw),calc(var(--apmy)*100vh)) scale(var(--apms))}
```
PIN: unchanged from v1. Pin condition: `breakout || sg != 1`. Empty sheet: all dx,dy = 0 and all s = 1.

Editor geometry (JS): `sEff(i) = i in 1..5 ? L[0][2]*L[i][2] : L[i][2]`; origin corner RB for 0..5,
LT for 6. `baseRect(i)`: from live rect `r` and applied translate `T`: `w=r.width/sEff, h=r.height/sEff`,
RB: `right=r.right−Tx, bottom=r.bottom−Ty`; LT: `left=r.left−Tx, top=r.top−Ty`. Group base = union of
stack base and chips base. `liveRect(i)` = base scaled about origin corner + T.

## Task 1 — client normaliser + apply (SQF)

- [x] `fn_hudLayoutNorm.sqf`: `_s = _p param [2, 1]`; if number and finite → `(_s max 0.25) min 3` else 1;
      pushBack `[_x,_y,_s]`. Header: triples, legacy pairs.
- [x] `fn_hudLayoutApply.sqf`: emit `--ap%1s:%2;` too; `_moved` true if any s≠1; `_breakout` OR
      `(_L#0#2) != 1`; RULES per contract. Update header (chips term, origin table, pin condition).
- [x] Observe red first: `python3 tools/hudlayout_parity.py` must FAIL after the SQF edit and before
      the JS edit (proves the gate binds on the new anchors).

## Task 2 — server validator (SQF)

- [x] `fn_hudLayoutSRV.sqf`: `_fnNorm` takes `[_in, _strict]`. Entry count 2 (only if `!_strict`) or 3;
      s default 1 for pairs; s must be finite and in [0.25,3]. `get` calls with `false`, `set` with
      `true`. `_zero` → seven `[0,0,1]`. JSON `[%1,%2,%3]` toFixed 5. Header: v2 note.
- [x] Dry-run the SQL shape unchanged (jsonb, same statements) — no DB step needed; note it.

## Task 3 — editor open payload

- [x] `fn_hudEditOpen.sqf`: `APHE_INIT` built as `[x,y,s]` triples via toFixed 5.

## Task 4 — harness first (red), then hudedit.js

- [x] `tools/test_hudedit.js`: stub geometry gains scale: `getBoundingClientRect` applies
      `s = sEff` about the origin corner (RB for stack/plates/wplate/chips, LT for mapwrap); members'
      translate = `var·VW/sg` (+ group translate). Chips Y gets `−12.15·REM·(sg−1)`.
      New assertions:
      1. seed shape = seven triples, s = 1; legacy `APHE_INIT` pairs read as s = 1.
      2. wheel over minimap box +1 notch → s = 1.02, centre unchanged (<0.5 px).
      3. drag HP's top-left grip outward → s > 1, HP bottom-right corner unchanged (<0.5 px).
      4. group grip drag → HP and chips scale, chips bottom rises with the stack.
      5. `+` key ×n clamps at 3.0; `-` clamps at 0.25.
      6. group scale ≠ 1 arms the pin; member scale alone does not.
      7. save payload: seven triples, s within range, ≤5 decimals; RESET THIS → `[0,0,1]`.
      Existing pair-based assertions updated to triples.
- [x] Run: `node tools/test_hudedit.js` → expect FAIL (red) on the new assertions.
- [x] `hudedit.js`: `L` triples; RULES per contract; `sEff`, `originRB`, `baseRect`, `liveRect`,
      `appliedPx` (unchanged formula), `clamp`/`snap` on live rects; 4 grips on `.box.sel`
      (`data-g` = tl/tr/bl/br); grip drag → `s'` per §9.3 with fixed opposite corner + translate
      compensation; `wheel` ±2% centre-fixed; keys `+`/`=`/`-` ±1% (Shift ×5) centre-fixed;
      RESET semantics; hint; payload triples.
- [x] `node tools/test_hudedit.js` → all PASS. `python3 tools/hudlayout_parity.py` → identical.

## Task 5 — gates + docs + commit

- [x] `bash tools/run_checks.sh` all pass; `node --check`; `python3 tools/sqf_balance.py`;
      `python3 tools/sqf_cmd_check.py` on the four SQF files.
- [x] Dev deploy `bash /home/timb/arma3server_dev/reload-armapunk2035.sh`; wait for `read from bank`;
      grep server log for `[HUDLAY]`/script errors.
- [x] Commit (rotating defunct-AI trailer). Owner walk-test list = hudeditor.md §9.7.
