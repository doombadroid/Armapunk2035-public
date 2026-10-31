# `.paa` removal index

**Date:** 2026-08-18 · 649 textures, ~62 MB total — **down from 694 / 86.6 MB.** The 24 unreferenced ones in Tier 1 are gone, and `images/ads` (21 files, 21 MB) went with the holo-billboards when the owner cut them on 2026-08-18. Mission PBO: 230M → 207M.

Answers one question: which `.paa` files can be deleted, and which only *look*
deletable. Three tiers — **delete now**, **delete when the UI fallbacks go**, and
**do not touch**.

---

## Read this before deleting anything

Two ways a texture in this repo is referenced without its name ever appearing in
the source. Both were hit while building this index; both produce a deletion
list that looks clean and is catastrophic.

**1. Paths are built at runtime.** `format ["images\cyberdeck\icons\%1.paa", _id]`
means no icon in that directory is named anywhere. Seventeen such patterns exist:

```
images\ads\%N              images\casino\%N            images\casino\coin_%N
images\casino\slot_%N      images\casino\wheel_%N      images\cyberdeck\icons\%N
images\cyberdeck\qicons\%N images\cyberdeck\ring_pd_hl_%N
images\wallpapers\%N       outlw_magRepack\Images\bulletCount\%N
\armapunk_menu\ui\hint_%N  \armapunk_menu\ui\row_%N
\armapunk_menu\video\intro_%N  \armapunk_menu\video\loop_%N
mpmissions\__cur_mp.%N
```

A first pass of this audit truncated those prefixes one path level too far
(`images\cyberdeck\icons\%1.paa` → `images\cyberdeck`) and reported **84 live
icons as unreferenced** — every quickhack ring icon and every quickhack app
icon. The numbers below come from the corrected pass.

**2. Substring matches.** `grep -F "target.paa"` matches `hud_target.paa`. Three
of the candidates below appeared "referenced" for exactly that reason and
survived only because the match was inspected rather than counted.

**3. Two bugs in this audit's own extractor, both found by contradiction.**
Matching on *filename* marked root `gun.paa` live because `icons/grphex/gun.paa`
is referenced — a different file. And `format["<img image='%1icons\rook.paa'",
MISSION_ROOT]` was read as a reference to `1icons\rook.paa` (the `1` came from
`%1`), which nearly condemned two live icons. The final pass matches whole path
components and strips `%N` prefixes first. If you regenerate this index, verify
against a file you *know* is live before believing any of it.

Adding a texture that is loaded by `format` puts its whole directory beyond
static analysis. That is the cost of the pattern and it is worth knowing before
adding the eighteenth one.

---

## Tier 1 — delete now: 24 files, 3.60 MB

Zero references of any kind: no literal path, no runtime-built path covering
their directory, no concatenation (nothing in this repo appends `".paa"` —
checked). Verified by **component-wise full-path** matching, not by filename.

| File | Bytes | Note |
|---|---:|---|
| `images/cyberdeck/backdrop.paa` | 2,796,412 | **77% of this tier.** The backdrop `cyberdeck_seq` (940000) was painted on. That dialog was deleted 2026-08-14 and replaced by `web_breach` / `web_terminal`, which say so in their own headers. Its siblings `backdrop_home.paa` and `backdrop_tal.paa` are still drawn by `cyberdeck_home.hpp` / `tal_home.hpp` — **those two stay** |
| `icons/robotaxi.paa` | 87,559 | |
| `jewelry.paa` · `images/jewelry.paa` | 61,617 ×2 | identical pair, both dead |
| `tourism.paa` · `images/tourism.paa` | 60,662 ×2 | identical pair, both dead |
| `commodities.paa` · `images/commodities.paa` | 60,595 ×2 | identical pair, both dead |
| `market.paa` · `images/market.paa` | 60,476 ×2 | identical pair, both dead |
| `general.paa` · `images/general.paa` | 58,352 ×2 | identical pair, both dead |
| `gun.paa` · `images/gun.paa` | 58,001 ×2 | identical pair, both dead. `icons/grphex/gun.paa` is a **different, live** file |
| `images/phone.paa` | 46,762 | |
| `images/dispensary.paa` | 31,881 | |
| `images/utils/helipad.paa` | 28,219 | |
| `icons/deck_phone.paa` | 22,016 | |
| `icons/loonazon_app.paa` | 22,016 | |
| `icons/cannabis.paa` | 5,625 | |
| `icons/food.paa` | 5,625 | `hud_food.paa` is the live one |
| `icons/target.paa` | 5,625 | `hud_target.paa` is the live one |
| `icons/towRope.paa` | 5,625 | |
| `icons/health.paa` | 2,881 | `hud_health.paa` is the live one |

Six of these sit at the mission root, which independently matches the
`unreferenced:6` that `PAA_INDEX.md`'s own table records for `.`.

The shop-icon names (`jewelry`, `market`, `general`, `commodities`, `tourism`,
`dispensary`) still exist as shop *ids* throughout the code — that is why a stem
grep lights up for all of them. The ids are live; these textures are not.

---

## Tier 2 — delete when the fallback binds go: 12 files, 3.48 MB

**Not removable today.** The three HTML screens became primary on 2026-08-18,
but the native dialogs are deliberately still wired one modifier away
(`CTRL+SHIFT+Y`, `SHIFT+TAB`, `CTRL+SHIFT+T`) so a page that misbehaves in front
of players is a keypress from working. Deleting this art now breaks the fallback
it exists to protect.

These become dead the moment those binds are removed from
`evh/fn_keyDownHandler.sqf` and `core/radio/fn_radioKeys.sqf`.

**Visor dock (941300)** — 2 files, 2.59 MB · *the single biggest win in the repo*

| File | Bytes |
|---|---:|
| `images/cyberdeck/vr_visor.paa` | 2,592,148 |
| `images/cyberdeck/vrglow.paa` | 126,141 |

**Radial radio (515500)** — 10 files, 0.88 MB

| File | Bytes |
|---|---:|
| `images/ui/radial_wedge.paa` | 349,710 |
| `images/ui/radial_ic_anarchy.paa` | 87,559 |
| `images/ui/radial_ic_classico.paa` | 87,559 |
| `images/ui/radial_ic_khr.paa` | 87,559 |
| `images/ui/radial_ic_origin.paa` | 87,559 |
| `images/ui/radial_ic_pulse.paa` | 87,559 |
| `images/ui/radial_power.paa` | 87,559 |
| `images/ui/ap_madmax.paa` | 22,016 |
| `images/ui/ap_normal.paa` | 22,016 |
| `images/ui/ap_sloth.paa` | 22,016 |

The new pages replace all of this with inline SVG, which is why the saving is
this large — no station icon ships as a texture any more.

**TrunkMenu (4500)** — **0 files.** Its two textures are shared with other
dialogs. Storage's promotion frees no art at all.

`images/ui/radial_rim.paa` is named in `fn_radioRadial.sqf:60` but does not
exist and never shipped; the line is a comment about a removed overlay. Nothing
to delete, and nothing to fix.

---

## Tier 3 — do not touch: 233 files, 33.7 MB

Every texture in a directory addressed by one of the seventeen `%N` patterns
above. Static analysis cannot clear any of them, and "grep found nothing" is the
expected result for a live file here, not evidence.

Clearing this tier needs the id lists that feed those `format` calls — the ring
pools in `core/configuration.sqf`, the quickhack catalogue in
`core/config/fn_qhCfg.sqf` and the casino tables — cross-referenced against the
directory contents. That is a separate job and worth doing: it is still the
largest tier.

`images\ads` used to head this list at 21 MB and is no longer in it. It was not
cleared by analysis — the owner deleted the feature that drew it. That is worth
noting as the general shape of this tier: a `format[]`-addressed directory is
usually freed by removing its consumer, not by proving the files dead.

---

## Doing it

```bash
cd mission/Armapunk2035.Malden
git rm images/cyberdeck/backdrop.paa \
       commodities.paa general.paa gun.paa jewelry.paa market.paa tourism.paa \
       images/commodities.paa images/general.paa images/gun.paa \
       images/jewelry.paa images/market.paa images/tourism.paa \
       images/phone.paa images/dispensary.paa images/utils/helipad.paa \
       icons/robotaxi.paa icons/loonazon_app.paa icons/deck_phone.paa \
       icons/cannabis.paa icons/food.paa icons/target.paa \
       icons/towRope.paa icons/health.paa
```

Then deploy and read the boot log. A missing texture does **not** stop the
mission — the control renders empty and the RPT logs `Cannot load texture`,
which is exactly the failure mode this index exists to avoid, so grep for it:

```bash
grep -i "cannot load texture" /home/timb/arma3server_dev/loonydev.log
```

## Relationship to `PAA_INDEX.md`

`PAA_INDEX.md` (2026-08-14) is the strategy document — which families are stuck
with the engine, and what porting each screen would buy. Keep it. Three of its
claims are now out of date:

- **The four Loonazon `.paa` are gone, not just deletable.** `images/loonazon_van.paa`
  (the vehicle skin `PAA_INDEX.md` names as a world-texture holdout),
  `images/loonazon_logo.paa`, `images/loonazon_rule.paa` and
  `images/browser_bg_port_loonazon.paa` were removed 2026-09-02 with the rest of
  the Loonazon feature. None of the four ever appeared in this audit's tiers —
  they were live-referenced as of 2026-08-18, not dead weight — so there is
  nothing to strike from Tier 1/2/3 here; the removal just pre-empted the
  question this audit would otherwise have had to answer for them.

- Its correction says **"there are now zero unreferenced PAAs in the mission."**
  That is not true: 24 remain, and its own table still records `unreferenced:6`
  for the mission root, which this audit independently reproduces.
- Its **order of attack #1 — "Cyberdeck backdrops (33 MB): port the breach
  minigames"** — has since been done. `cyberdeck_seq.hpp` was deleted and
  `web_breach` / `web_terminal` replaced it. `backdrop.paa` falling into Tier 1
  is the tail of that job, and the next-largest items in its list should be
  re-checked the same way before anyone plans against them.
