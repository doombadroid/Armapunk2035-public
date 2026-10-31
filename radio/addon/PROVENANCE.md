# @Armapunk2035 — third-party content provenance

Every PBO in this mod is built from one `radio/addon/<name>/` source tree, where `<name>` is also
the PBO prefix. Two of those trees are third-party work. This file records where each came from and
what we are permitted to do with it. Keep it accurate — it is the only place the permission status
is written down, and one of the two entries below is **not** cleared for release.

## maldenradio — ours

Original work (Doomba). Radio marker class + the streaming extension DLL. No third-party content.

## armapunk_menu — ours, with OFL fonts baked into rasters

Original work (Doomba): the main-menu replacement — two Theora videos and 25 PAA overlay strips,
all rendered from `menu/design/` by the committed pipeline (`menu/PIPELINE.md`).

- **Fonts:** Michroma (Vernon Adams) and Space Mono (Colophon Foundry), both from Google Fonts
  under the **SIL Open Font License 1.1**. They appear here only as rasterized pixels inside the
  videos/textures; the OFL explicitly permits this and places no requirement on rasterized output
  (the licence keeps applying to the font *files*, which ship in `menu/harness/*.woff2` for
  pipeline reproducibility, not in the built PBO). Credit here is a courtesy, not an obligation.
- **Everything else** (layout, copy, art direction, code) is in-house; the design prototype was
  produced for this project and is committed at `menu/design/`.

## zee_fsof — Fifty Shades of Female (FSOF), by Zeealex

- **Creator:** Zeealex (also credited as "Zee"; Workshop display name Frau Farbissina)
- **Upstream:** Steam Workshop item `374775446`, "Fifty Shades of Female (formerly FEMAL3 Heads)"
- **What it is:** 210 `CfgFaces` entries and 44 head models — Caucasian ×2 (four tones each), Asian
  and Black female heads, in eye-colour and hair-colour combinations, registered against the vanilla
  `G_CIVIL_female` identity type. Requires only `A3_Characters_F_BLUFOR`.
- **Permission: GRANTED.** The author's Workshop description states:

  > "You can repack, retexture, re-configure, do anything you want, just make sure credit is given,
  > and if you have time a quick message or comment about it would be great."

- **Our obligation:** credit, which is carried in `CfgPatches >> zee_fsof >> author`, in the mod.cpp
  description shown by the launcher, and here. The author also invites a courtesy message about
  reuse — worth sending, and not yet sent.
- **Modifications:** none to her assets. The only file we changed is the `CfgPatches` block at the
  top of `config.cpp`; the ~3,180 lines of `CfgFaces`/`CfgHeads` below it are hers, unaltered,
  including her own `cfgMods { author="Zee" }` stamp.
- **Note:** the upstream Workshop item is delisted from public browsing (still installs for existing
  subscribers). That is why the source tree is vendored here rather than consumed as a dependency.

## JAS_GPNVG18 — GPNVG-18 Panoramic Night Vision, by SweetJason

- **Creator:** SweetJason, in-config author string "ColdJason"
- **Upstream:** Steam Workshop item `1714019280`, "Jason's GPNVG-18 Night Vision"
- **What it is:** six `CfgWeapons` NVG classes — Tan and Black, each in plain, thermal (TI), and
  full-screen "Overwatch" TI variants. Standalone; uses the vanilla `nvg_proxy` model.
  All six are `scope=1`, i.e. spawnable by classname but hidden from Arsenal and the editor.
- **Permission: GRANTED by the author, 2026-08-02.** SweetJason was asked directly on Discord and
  agreed to inclusion here. The upstream release carries no written licence and the author never
  answered an equivalent public request back in April 2021, so this conversation is the *entire*
  permission record for this tree — there is no published grant to fall back on.
- **Keep the evidence.** Because the permission is a private message rather than a public licence,
  save a copy (screenshot or exported transcript) somewhere durable outside Discord and note where
  it lives here. If the account, server or DM ever goes away, the grant is unverifiable.
- **Scope to be aware of:** the grant was given for inclusion in this mod. If @Armapunk2035 is later
  published publicly on the Steam Workshop and that was not explicitly part of what was agreed, it
  costs one message to confirm, and confirming is cheaper than a takedown.
- **Our obligation:** credit, carried in `CfgPatches >> JAS_GPNVG18 >> author`, in the mod.cpp
  description shown by the launcher, and here.
- **Modifications:** none to his assets. Only the `CfgPatches` block at the top of `config.cpp` is
  ours; his `cfgMods { author="ColdJason" }` stamp is preserved.

## `ap_vcity` — Vertical City tower (own work)

Authored in this repo (`design/vertical-city/`, source `source/vertical-city-hs.blend`). It has
**no source tree under `addon/`**: the PBO is binarized by that project's own pipeline
(`export_visual_lods.py` → `build_arma.py` → `build_native.py` → `validate_release.py` →
`engine_smoke.py`), and the validated PBO is copied into `dist/@Armapunk2035/addons/` and signed
with the mod key (`armake2 sign`). `build_addon.sh` therefore does not rebuild it — and since
that script wipes `dist/@Armapunk2035/`, re-copy and re-sign `ap_vcity.pbo` after running it.
The shipped PBO's SHA256 is recorded in `design/vertical-city/HARDSURFACE_LOG.md`
(2026-09-23: `1aeab8a8…0f2b`, futuristic interiors). Classes `Land_vc_*`, functions `VCITY_fnc_*` (postInit
`VCITY_fnc_ambientLighting`: client-local, 1 Hz `nearestObjects` 85 m scan; disable with
`VCITY_ambientLightingEnabled = false`). Placing towers needs the addon on the **server** too.

**Third-party content inside `ap_vcity` (furniture, 2026-09-23): Poly Haven, CC0.** Texture sets
`rough_linen`, `smoked_walnut_veneer`, `poly_wool_herringbone`, `leather_white` (recoloured) from
polyhaven.com. (Four Poly Haven models shipped briefly in PBO `83bd0b4e`; the futuristic pass
replaced them with in-house models, and no Poly Haven model ships from the next build on.) CC0 1.0 = public-domain dedication: no attribution required, no
restrictions on modification, redistribution or commercial use. Credit is a courtesy. The exact
list with source URLs is in `design/vertical-city/source/ph/MANIFEST.json`.

## Rules for adding third-party content to this mod

1. Establish permission **before** vendoring, and record it here with the exact wording and its
   source. "No licence found" means ask, not yes.
2. Keep the upstream prefix as the directory name. Model and material files hardcode absolute paths
   (`\zee_fsof\Data\...`), so a renamed prefix unloads every texture with no error in the log.
3. Never strip or rewrite an upstream author's `CfgPatches` name, `author` field, or `cfgMods`
   stamp. Add ours alongside; do not replace theirs.
4. Credit belongs in three places: the addon's `CfgPatches`, the launcher description in
   `addon/mod.cpp`, and this file.
