# Handoff: NewDrachma Holographic Shop Icon (3D)

## Overview
A 3D holographic "NewDrachma" currency coin that floats above shops in an Arma 3 game mode. It recreates the 2D coin logo (cyan Đ glyph with double strike-through, magenta dashed outer ring, dark disc with teal scanlines) as an emissive, slightly transparent hologram.

## About the Design Files
The files in this bundle are **design references created in HTML/three.js** — a prototype showing the intended geometry, materials, and look. They are not production game assets. The task is to get this model into the Arma 3 content pipeline: export the mesh from the viewer (GLB), bring it into Blender, and convert to P3D via Object Builder / the Arma Toolbox, recreating the emissive treatment with Arma's material system (RVMAT).

## Fidelity
**High-fidelity.** Geometry, proportions, colors, and emissive values are final. Match them exactly.

## How to get the mesh
Open `newdrachma-holo.html` in a browser (needs internet for three.js CDN). The toolbar offers:
- **Download GLB** — preferred. Keeps part hierarchy, PBR materials, emissive colors/intensities, and the baked scanline emissive textures (embedded PNGs).
- **Download OBJ + MTL** — geometry + flat material colors only; scanline textures are lost.

The model is also built 100% programmatically in the `<script type="module">` block of `newdrachma-holo.html` — that code is the authoritative spec for every dimension.

## Model spec
Units: meters, y-up, coin faces ±Z, overall diameter **1.0 m** (group scale 1.052 applied to the base coordinates below), lowest point at y=0 (floats in-game; pivot at bottom).

Parts (mesh names as exported):
- `disc` — dark backing disc. Cylinder r 0.40, thickness 0.03, 96 segments. Material `holo_panel`.
- `ring_outer` — magenta ring, annulus r 0.432→0.475, extruded 0.050. Material `holo_magenta`.
- `ring_trace` — thin teal circle, annulus r 0.345→0.353, extruded 0.044. Material `holo_trace`.
- `glyph_D` — the Đ letterform, extruded 0.056. Stem left edge x −0.157, stem width 0.058, cap height 0.534 (y ±0.267), bowl arc centered (−0.06, 0), outer radius 0.267, inner radius 0.209. Material `holo_cyan`.
- `slash_upper` / `slash_lower` — cyan strike bars, 0.55 × 0.036, extruded 0.072, rotated 19.6° (0.342 rad), centers (−0.09, −0.021) and (−0.09, −0.108). Material `holo_cyan`.
- `slash_gap_upper` / `slash_gap_lower` — dark backing bars behind the slashes (create the "cut" outline), 0.57 × 0.062, extruded 0.064, same centers/angle. Material `holo_void`.

Z-layering (all centered on z=0): disc ±0.015 < trace ±0.022 < ring ±0.025 < glyph ±0.028 < gap bars ±0.032 < slashes ±0.036. Keep these offsets — they prevent z-fighting and produce the layered holo look.

## Materials (PBR values)
All MeshStandardMaterial. Scanline textures are 8×64 canvas stripes, nearest-filtered, repeat-wrapped (see `stripes()` in the HTML).

- `holo_cyan` — base #07242a, emissive **#8df6ff** × 2.3, roughness 0.35, metalness 0.1. Emissive map: white with 18% black horizontal lines, 34 repeats/m.
- `holo_magenta` — base #2a0616, emissive **#ff2e8e** × 2.1, roughness 0.35, metalness 0.1. Emissive map: white with 30% black lines, 21 repeats/m.
- `holo_trace` — base #06181b, emissive **#2fa3ac** × 1.5, roughness 0.4. Emissive map: white with 20% black lines, 34 repeats/m.
- `holo_panel` — base #081118, emissive **#2a7d84** × 0.6, transparent, opacity 0.92, roughness 0.6. Emissive map: black with 12% white lines (inverted — glowing lines on dark), 27 repeats, rotated 90° (cylinder cap UVs).
- `holo_void` — base #04080b, no emissive, roughness 0.85.

Scanlines run **horizontally** across the coin face on every part.

## Arma 3 implementation notes
- In RVMAT, drive the glow from the emissive channel; the GLB's emissive strengths (>1) indicate relative glow intensity (cyan hottest, panel faintest).
- `holo_panel` should be alpha-blended (~92% opaque); everything else can be opaque.
- Intended behavior in-game: slow turntable rotation (the HTML viewer's autorotate mimics this) and a gentle vertical bob, hovering above the shop. Both faces are valid (back shows mirrored glyph, as a hologram would).
- Suggested scale: 1 m diameter reads well at shop-sign height; scale uniformly if needed.

## Assets
- `newdrachma_coin.jpg` — original 2D logo (source reference, user-provided).
- Scanline emissive textures are generated in code and embedded in the GLB; no external texture files.

## Files
- `newdrachma-holo.html` — viewer + authoritative model-building code (the module script at the bottom).
- `three-d-stage.js` — viewer shell (lighting, orbit controls, OBJ/GLB export). Not part of the deliverable model.
- `newdrachma_coin.jpg` — reference image.
