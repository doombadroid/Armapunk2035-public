// jewelry-case.js — storefront jewelry display case (Arma prop) + smashed/robbed variant.
// X east, Y up, Z north, meters, origin at plan center, base y=0. Front faces +Z.
// 1.84 × 0.64 footprint, 1.32 m tall. Every structural mesh = ONE convex box.
// buildCase(false) = pristine (ap_jewelry_case); buildCase(true) = smashed (ap_jewelry_case_smashed):
// front + top glass reduced to jagged remnants, shards on deck/floor, displays toppled, jewelry stolen.
import * as THREE from 'three';

export function buildCase(mode = false) {
  const open = mode === 'open', smashed = mode === true || mode === 'smashed';
  const G = new THREE.Group();
  G.name = smashed ? 'ap_jewelry_case_smashed' : open ? 'ap_jewelry_case_open' : 'ap_jewelry_case';
  const TL = new THREE.TextureLoader();
  const tex = p => { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  const M = {
    marble: new THREE.MeshStandardMaterial({ name: 'marble_tiles_02_co', map: tex('a3/structures_f_exp/data/tiles/marble_tiles_02_co.png'), roughness: .25, metalness: .1 }),
    dark:   new THREE.MeshStandardMaterial({ name: 'metal_dark_proc', color: 0x23272d, roughness: .45, metalness: .4 }),
    brass:  new THREE.MeshStandardMaterial({ name: 'brass_proc', color: 0xc9a24d, roughness: .3, metalness: .85 }),
    silver: new THREE.MeshStandardMaterial({ name: 'silver_proc', color: 0xd8dde2, roughness: .25, metalness: .9 }),
    velvet: new THREE.MeshStandardMaterial({ name: 'velvet_proc', color: 0x2c1f4a, roughness: 1 }),
    glass:  new THREE.MeshStandardMaterial({ name: 'glass_clear_proc', color: 0xdff2f7, roughness: .05, metalness: .1, transparent: true, opacity: .18, side: THREE.DoubleSide, depthWrite: false }),
    led:    new THREE.MeshStandardMaterial({ name: 'led_white_proc', color: 0xffffff, emissive: 0xfff4dc, emissiveIntensity: 2.2, roughness: .3 }),
    ledOff: new THREE.MeshStandardMaterial({ name: 'led_dead_proc', color: 0xb9b4a6, roughness: .5 }),
    char:   new THREE.MeshStandardMaterial({ name: 'torch_char_proc', color: 0x141210, roughness: 1 }),
    torch:  new THREE.MeshStandardMaterial({ name: 'torch_glow_proc', color: 0xff8a34, emissive: 0xff5a14, emissiveIntensity: 2.4, roughness: .3 }),
    plaque: new THREE.MeshStandardMaterial({ name: 'white_marking_proc', color: 0xe9e7e0, roughness: .6 }),
    ruby:   new THREE.MeshStandardMaterial({ name: 'gem_ruby_proc', color: 0xe0244a, emissive: 0x8f0f2c, emissiveIntensity: .8, roughness: .15 }),
    emerald:new THREE.MeshStandardMaterial({ name: 'gem_emerald_proc', color: 0x1fc47a, emissive: 0x0c7343, emissiveIntensity: .8, roughness: .15 }),
  };
  function worldUV(g, s) {
    const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
    for (let i = 0; i < p.count; i++) {
      const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
      let u, v;
      if (ay >= ax && ay >= az) { u = p.getX(i); v = p.getZ(i); }
      else if (ax >= az)        { u = p.getZ(i); v = p.getY(i); }
      else                      { u = p.getX(i); v = p.getY(i); }
      uv.setXY(i, u / s, v / s);
    }
  }
  function box(name, mat, w, h, d, cx, cy, cz, uvS = 2, rx = 0, ry = 0, rz = 0) {
    const g = new THREE.BoxGeometry(w, h, d);
    g.rotateX(rx); g.rotateY(ry); g.rotateZ(rz);
    g.translate(cx, cy, cz); worldUV(g, uvS);
    const m = new THREE.Mesh(g, mat); m.name = name;
    m.castShadow = m.receiveShadow = true; G.add(m); return m;
  }
  function prim(name, geo, mat, cx, cy, cz, rx = 0, ry = 0, rz = 0) {
    geo.rotateX(rx); geo.rotateY(ry); geo.rotateZ(rz); geo.translate(cx, cy, cz);
    const m = new THREE.Mesh(geo, mat); m.name = name;
    m.castShadow = m.receiveShadow = true; G.add(m); return m;
  }
  let seed = 7; const rnd = () => (seed = seed * 16807 % 2147483647) / 2147483647;

  // ---- structure (shared) ----
  box('CASE_plinth', M.dark, 1.7, .08, .5, 0, .04, 0);
  box('CASE_cabinet', M.dark, 1.8, .82, .6, 0, .08 + .41, 0);
  box('CASE_kickline', M.brass, 1.802, .02, .602, 0, .13, 0);
  if (!smashed) {
    box('CASE_top_marble', M.marble, 1.84, .05, .64, 0, .925, 0, .5);
  } else {
    // counter top with torch-cut bites: big chunk gone front-right (with the post), notch front-left
    box('CASE_top_marble_a', M.marble, 1.84, .05, .36, 0, .925, -.14, .5);          // back band
    box('CASE_top_marble_b', M.marble, .442, .05, .28, -.699, .925, .18, .5);       // front-left
    box('CASE_top_marble_c', M.marble, .096, .05, .2, -.43, .925, .14, .5);         // behind the notch
    box('CASE_top_marble_d', M.marble, .962, .05, .28, .099, .925, .18, .5);        // front-mid
    // charred kerf faces + molten lips on every cut
    box('CUT_char_1', M.char, .012, .052, .28, .58, .925, .18);
    box('CUT_char_2', M.char, .34, .052, .012, .75, .925, .04);
    box('CUT_char_3', M.char, .012, .052, .08, -.478, .925, .28);
    box('CUT_char_4', M.char, .012, .052, .08, -.382, .925, .28);
    box('CUT_char_5', M.char, .096, .052, .012, -.43, .925, .24);
    box('CUT_glow_1', M.torch, .012, .005, .28, .58, .9515, .18);
    box('CUT_glow_2', M.torch, .34, .005, .012, .75, .9515, .04);
    box('CUT_glow_3', M.torch, .012, .005, .08, -.478, .9515, .28);
    box('CUT_glow_4', M.torch, .012, .005, .08, -.382, .9515, .28);
    box('CUT_glow_5', M.torch, .096, .005, .012, -.43, .9515, .24);
    box('CUT_kerf', M.char, .25, .004, .012, .1, .9515, .3, 2, 0, .06, 0);          // abandoned cut
  }
  const g0 = .925, g1 = 1.30;
  for (const [k, sx, sz] of [[1, -1, -1], [2, 1, -1], [3, 1, 1], [4, -1, 1]]) {
    if (smashed && k === 3) {                                          // front-right post torch-cut off
      box('CASE_post_03_stub', M.brass, .028, .06, .028, .886, .955, .286);
      box('CUT_post_char', M.char, .03, .008, .03, .886, .988, .286);
      box('CASE_post_03_fallen', M.brass, .028, .385, .028, .72, .017, .62, 2, Math.PI / 2, .45, 0);
      continue;
    }
    box('CASE_post_0' + k, M.brass, .028, .385, .028, sx * .886, .925 + .19, sz * .286);
  }
  if (!smashed) {
    // slim copper ring frame — the top is glass, not a solid lid
    box('CASE_topframe_b', M.brass, 1.828, .028, .05, 0, 1.314, -.289);
    box('CASE_topframe_f', M.brass, 1.828, .028, .05, 0, 1.314, .289);
    box('CASE_topframe_l', M.brass, .05, .028, .528, -.889, 1.314, 0);
    box('CASE_topframe_r', M.brass, .05, .028, .528, .889, 1.314, 0);
  } else {
    // top copper frame torch-cut apart: back/left survive (racked), right rail ends at the cut-off
    // post, front rail has a chunk burned out; charred ends with molten lips; one rail on the floor
    box('CASE_topframe_b', M.brass, 1.828, .028, .05, 0, 1.308, -.289, 2, 0, 0, .012);
    box('CASE_topframe_l', M.brass, .05, .028, .528, -.889, 1.306, 0);
    box('CASE_topframe_r', M.brass, .05, .028, .314, .889, 1.308, -.107);
    box('CASE_topframe_f1', M.brass, 1.164, .028, .05, -.332, 1.31, .289, 2, 0, 0, .01);
    box('CASE_topframe_f2', M.brass, .14, .028, .05, .55, 1.306, .289, 2, 0, 0, -.02);
    box('CUT_tf_char_1', M.char, .012, .032, .052, .25, 1.308, .289);
    box('CUT_tf_char_2', M.char, .012, .032, .052, .48, 1.306, .289);
    box('CUT_tf_char_3', M.char, .012, .032, .052, .62, 1.306, .289);
    box('CUT_tf_char_4', M.char, .052, .032, .012, .889, 1.308, .05);
    box('CUT_tf_glow_1', M.torch, .014, .005, .054, .25, 1.3245, .289);
    box('CUT_tf_glow_2', M.torch, .014, .005, .054, .48, 1.3225, .289);
    box('CUT_tf_glow_3', M.torch, .014, .005, .054, .62, 1.3225, .289);
    box('CUT_tf_glow_4', M.torch, .054, .005, .014, .889, 1.3245, .05);
    box('DEBRIS_frame_rail', M.brass, .05, .028, .42, .92, .015, .78, 2, 0, .8, 0);
    box('CUT_tf_char_5', M.char, .052, .03, .012, .766, .015, .943, 2, 0, .8, 0); // charred end of the fallen rail
  }
  box('GLASS_back', M.glass, 1.74, g1 - g0 + .02, .008, 0, (g0 + g1) / 2, -.282);
  box('GLASS_left', M.glass, .008, g1 - g0 + .02, .54, -.882, (g0 + g1) / 2, 0);
  box('GLASS_right', M.glass, .008, g1 - g0 + .02, .54, .882, (g0 + g1) / 2, 0);
  if (smashed) {
    // deck cut back where the counter chunk was torched out; burnt velvet edges
    box('DECK_velvet', M.velvet, 1.44, .022, .52, -.14, .961, 0);
    box('DECK_velvet_b', M.velvet, .28, .022, .3, .72, .961, -.11);
    box('DECK_char_1', M.char, .012, .026, .22, .58, .961, .15);
    box('DECK_char_2', M.char, .28, .026, .012, .72, .961, .04);
  } else {
    box('DECK_velvet', M.velvet, 1.72, .022, .52, 0, .95 + .011, 0);
  }
  const dy = .972;

  if (!smashed) {
    box('GLASS_front', M.glass, 1.74, g1 - g0 + .02, .008, 0, (g0 + g1) / 2, .282);
    if (open) {
      // top pane swung 100° about the back-rail hinge line, resting past vertical
      const gt = new THREE.BoxGeometry(1.74, .008, .54);
      gt.translate(0, .004, .27); gt.rotateX(-1.75); gt.translate(0, 1.302, -.27);
      const mt = new THREE.Mesh(gt, M.glass); mt.name = 'GLASS_top';
      mt.castShadow = mt.receiveShadow = true; G.add(mt);
      box('CASE_hinge_1', M.brass, .06, .022, .032, -.5, 1.312, -.276);
      box('CASE_hinge_2', M.brass, .06, .022, .032, .5, 1.312, -.276);
    } else {
      box('GLASS_top', M.glass, 1.74, .008, .54, 0, 1.298, 0);
    }
    box('CASE_led_f', M.led, 1.7, .012, .02, 0, 1.288, .26);
    box('CASE_led_b', M.led, 1.7, .012, .02, 0, 1.288, -.26);
    box('GLASS_shelf', M.glass, 1.55, .01, .3, 0, 1.13, -.09);
    box('CASE_bracket_l', M.brass, .02, .05, .26, -.75, 1.105, -.09);
    box('CASE_bracket_r', M.brass, .02, .05, .26, .75, 1.105, -.09);
    // displays (none in the open/emptied variant)
    if (!open) {
    [-.62, -.44, -.26].forEach((x, i) => {
      prim(`JWL_ringcone_${i + 1}`, new THREE.CylinderGeometry(.012, .034, .07, 10), M.velvet, x, dy + .035, .15);
      prim(`JWL_ring_${i + 1}`, new THREE.TorusGeometry(.017, .0035, 8, 18), [M.brass, M.silver, M.brass][i], x, dy + .073, .15, Math.PI / 2.6);
    });
    prim('JWL_watch_pad', new THREE.CylinderGeometry(.038, .042, .035, 12), M.velvet, .02, dy + .017, .15);
    prim('JWL_watch_band', new THREE.TorusGeometry(.03, .007, 8, 20), M.silver, .02, dy + .052, .15, Math.PI / 2);
    prim('JWL_watch_face', new THREE.CylinderGeometry(.016, .016, .016, 12), M.brass, .02, dy + .052, .143, Math.PI / 2);
    prim('JWL_tbar_post', new THREE.CylinderGeometry(.008, .01, .09, 8), M.dark, .32, dy + .045, .15);
    prim('JWL_tbar', new THREE.CylinderGeometry(.007, .007, .16, 8), M.dark, .32, dy + .095, .15, 0, 0, Math.PI / 2);
    prim('JWL_bangle_1', new THREE.TorusGeometry(.026, .004, 8, 18), M.brass, .28, dy + .07, .15, .25);
    prim('JWL_bangle_2', new THREE.TorusGeometry(.026, .004, 8, 18), M.silver, .36, dy + .07, .15, -.2);
    [[-.45, M.brass, M.ruby], [.62, M.silver, M.emerald]].forEach(([x, chain, gem], i) => {
      const b = new THREE.CylinderGeometry(.05, .078, .17, 12); b.scale(1, 1, .42);
      prim(`JWL_bust_${i + 1}`, b, M.velvet, x, dy + .085, -.12);
      prim(`JWL_chain_${i + 1}`, new THREE.TorusGeometry(.045, .0028, 6, 16, Math.PI), chain, x, dy + .12, -.094, .28, 0, Math.PI);
      prim(`JWL_pendant_${i + 1}`, new THREE.OctahedronGeometry(.011), gem, x, dy + .072, -.088);
    });
    prim('JWL_earring_card', new THREE.BoxGeometry(.07, .095, .004), M.plaque, .17, dy + .048, -.12, -.35);
    prim('JWL_stud_1', new THREE.OctahedronGeometry(.006), M.ruby, .155, dy + .06, -.108);
    prim('JWL_stud_2', new THREE.OctahedronGeometry(.006), M.emerald, .185, dy + .06, -.108);
    [-.5, -.36, -.22].forEach((x, i) =>
      prim(`JWL_shelf_ring_${i + 1}`, new THREE.TorusGeometry(.016, .0035, 8, 18), i === 1 ? M.silver : M.brass, x, 1.135 + .016, -.09, Math.PI / 2.8));
    prim('JWL_coil', new THREE.TorusGeometry(.035, .004, 8, 22), M.brass, .3, 1.135 + .005, -.09, Math.PI / 2);
    prim('JWL_coil_gem', new THREE.OctahedronGeometry(.01), M.ruby, .345, 1.135 + .012, -.09);
    }
    [[-.44, .05], [.02, .05], [.45, .05]].forEach(([x, z], i) =>
      prim(`CASE_plaque_${i + 1}`, new THREE.BoxGeometry(.05, .014, .003), M.plaque, x, dy + .008, z, -.9));
    return G;
  }

  // ---- smashed / robbed ----
  // front pane: jagged teeth along the bottom + one hanging corner remnant
  [[-.78, .11, .16], [-.55, .07, .12], [-.28, .13, .2], [.02, .06, .1], [.31, .1, .17]]
    .forEach(([x, h, w], i) =>
      box(`SHARD_front_${i + 1}`, M.glass, w, h, .008, x, g0 + h / 2 - .005, .282, 2, 0, 0, (rnd() - .5) * .5));
  box('SHARD_front_corner', M.glass, .34, .22, .008, -.72, g1 - .09, .282, 2, 0, 0, .5);
  // top pane: two corner remnants, rest gone
  box('SHARD_top_1', M.glass, .3, .008, .22, -.7, 1.298, -.14, 2, 0, .2, 0);
  box('SHARD_top_2', M.glass, .22, .008, .16, -.78, 1.298, .12, 2, 0, -.3, 0);
  // LED: back strip alive, front strip dead and hanging by one end
  box('CASE_led_b', M.led, 1.7, .012, .02, 0, 1.288, -.26);
  box('CASE_led_f', M.ledOff, 1.1, .012, .02, -.28, 1.2, .27, 2, 0, 0, .16);
  // shelf: left half survives (tilted), right bracket bent, right half = shards below
  box('GLASS_shelf', M.glass, .8, .01, .3, -.38, 1.124, -.09, 2, 0, 0, -.035);
  box('CASE_bracket_l', M.brass, .02, .05, .26, -.75, 1.105, -.09);
  box('CASE_bracket_r', M.brass, .02, .05, .26, .755, 1.1, -.085, 2, .35, .25, .3);
  // glass shards: on the deck and on the floor out front
  for (let i = 0; i < 12; i++) {
    const w = .03 + rnd() * .07, d = .03 + rnd() * .06;
    box(`SHARD_deck_${String(i + 1).padStart(2, '0')}`, M.glass, w, .006, d,
        -.8 + rnd() * 1.6, dy + .004, -.22 + rnd() * .44, 2, (rnd() - .5) * .3, rnd() * Math.PI, (rnd() - .5) * .3);
  }
  for (let i = 0; i < 9; i++) {
    const w = .04 + rnd() * .09, d = .03 + rnd() * .07;
    box(`SHARD_floor_${String(i + 1).padStart(2, '0')}`, M.glass, w, .006, d,
        -.7 + rnd() * 1.5, .004, .36 + rnd() * .5, 2, 0, rnd() * Math.PI, 0);
  }
  // marble chunks + slag where the corner was cut out
  box('DEBRIS_marble_1', M.marble, .16, .05, .12, .78, .028, .48, .5, .1, .5, .08);
  box('DEBRIS_marble_2', M.marble, .1, .05, .08, .55, .026, .66, .5, 0, 1.1, .14);
  box('DEBRIS_marble_3', M.marble, .07, .04, .06, .7, .92, .1, .5, 0, .7, .2);
  box('SLAG_1', M.torch, .02, .008, .016, .66, .006, .42, 2, 0, .4, 0);
  box('SLAG_2', M.torch, .014, .006, .012, .84, .006, .55, 2, 0, 1.2, 0);
  box('SLAG_3', M.torch, .016, .006, .014, .6, .903, .07, 2, 0, .9, 0);
  // displays: toppled, emptied. One ring cone still standing, the rest knocked over.
  prim('JWL_ringcone_1', new THREE.CylinderGeometry(.012, .034, .07, 10), M.velvet, -.62, dy + .035, .15);
  prim('JWL_ringcone_2', new THREE.CylinderGeometry(.012, .034, .07, 10), M.velvet, -.41, dy + .032, .19, 1.45, .6, 0);
  prim('JWL_ringcone_3', new THREE.CylinderGeometry(.012, .034, .07, 10), M.velvet, -.22, dy + .032, .1, -1.5, 2.2, 0);
  prim('JWL_watch_pad', new THREE.CylinderGeometry(.038, .042, .035, 12), M.velvet, .09, dy + .02, .21, .5, 0, .4);
  prim('JWL_tbar_post', new THREE.CylinderGeometry(.008, .01, .09, 8), M.dark, .34, dy + .01, .18, Math.PI / 2, 0, .4);
  prim('JWL_tbar', new THREE.CylinderGeometry(.007, .007, .16, 8), M.dark, .28, dy + .008, .08, 0, .9, Math.PI / 2);
  const b1 = new THREE.CylinderGeometry(.05, .078, .17, 12); b1.scale(1, 1, .42);
  prim('JWL_bust_1', b1, M.velvet, -.42, dy + .04, -.08, 1.5, 0, .3);       // toppled, stripped
  const b2 = new THREE.CylinderGeometry(.05, .078, .17, 12); b2.scale(1, 1, .42);
  prim('JWL_bust_2', b2, M.velvet, .62, dy + .085, -.12);                   // standing, stripped
  prim('JWL_earring_card', new THREE.BoxGeometry(.07, .095, .004), M.plaque, .2, dy + .013, -.06, -Math.PI / 2 + .12, .5, 0);
  // what the thieves missed
  prim('JWL_ring_dropped', new THREE.TorusGeometry(.017, .0035, 8, 18), M.brass, .52, .008, .55, Math.PI / 2);
  prim('JWL_stud_left', new THREE.OctahedronGeometry(.006), M.emerald, .23, dy + .012, -.05);
  prim('JWL_pendant_dropped', new THREE.OctahedronGeometry(.011), M.ruby, -.35, dy + .015, .05);
  // plaques flung around, one face-down on the floor
  prim('CASE_plaque_1', new THREE.BoxGeometry(.05, .014, .003), M.plaque, -.5, dy + .008, .02, -1.5, 1.1, 0);
  prim('CASE_plaque_2', new THREE.BoxGeometry(.05, .014, .003), M.plaque, .4, dy + .006, .18, -1.6, 2.4, 0);
  prim('CASE_plaque_3', new THREE.BoxGeometry(.05, .014, .003), M.plaque, .15, .003, .62, -Math.PI / 2, .8, 0);
  return G;
}
