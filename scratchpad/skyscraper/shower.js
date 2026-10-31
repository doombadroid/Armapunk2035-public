// shower.js — luxury walk-in shower (Arma prop). ONE model.
// X east, Y up, Z north, meters, origin at plan center, base y=0. Open/entry side faces +Z.
// 1.7 × 1.3 corner unit: marble back+left walls, stone tray, glass right panel + front panel
// with entry gap, rainfall head, wand, mixer, bench, wall niche. Every structural mesh = ONE convex box.
import * as THREE from 'three';

export function buildShower() {
  const G = new THREE.Group(); G.name = 'ap_lux_shower';
  const TL = new THREE.TextureLoader();
  const tex = p => { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  const M = {
    marble: new THREE.MeshStandardMaterial({ name: 'marble_tiles_02_co', map: tex('a3/structures_f_exp/data/tiles/marble_tiles_02_co.png'), roughness: .25, metalness: .08 }),
    light:  new THREE.MeshStandardMaterial({ name: 'marble_tiles_01_co', map: tex('a3/structures_f_exp/data/tiles/marble_tiles_01_co.png'), roughness: .3, metalness: .05 }),
    steel:  new THREE.MeshStandardMaterial({ name: 'steel_proc', color: 0xc4c9cd, roughness: .22, metalness: .9 }),
    dark:   new THREE.MeshStandardMaterial({ name: 'metal_dark_proc', color: 0x23272d, roughness: .45, metalness: .4 }),
    glass:  new THREE.MeshStandardMaterial({ name: 'glass_clear_proc', color: 0xdff2f7, roughness: .05, metalness: .1, transparent: true, opacity: .16, side: THREE.DoubleSide, depthWrite: false }),
    led:    new THREE.MeshStandardMaterial({ name: 'led_warm_proc', color: 0xfff2d8, emissive: 0xffe7b8, emissiveIntensity: 1.6, roughness: .3 }),
    black:  new THREE.MeshStandardMaterial({ name: 'matte_black_proc', color: 0x141619, roughness: .55, metalness: .3 }),
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
  function box(name, mat, w, h, d, cx, cy, cz, uvS = 1) {
    const g = new THREE.BoxGeometry(w, h, d);
    g.translate(cx, cy, cz); worldUV(g, uvS);
    const m = new THREE.Mesh(g, mat); m.name = name;
    m.castShadow = m.receiveShadow = true; G.add(m); return m;
  }
  function prim(name, geo, mat, cx, cy, cz, rx = 0, ry = 0, rz = 0) {
    geo.rotateX(rx); geo.rotateY(ry); geo.rotateZ(rz); geo.translate(cx, cy, cz);
    const m = new THREE.Mesh(geo, mat); m.name = name;
    m.castShadow = m.receiveShadow = true; G.add(m); return m;
  }

  // ---- tray + walls (back wall at z=-.65, left wall at x=-.85; walls 6 cm thick, 2.4 m tall) ----
  box('SHW_tray', M.light, 1.7, .1, 1.3, 0, .05, 0, .5);
  box('SHW_tray_lip', M.light, 1.696, .14, .05, 0, .07, .628, .5);        // entry curb, 3 mm proud of the tray face
  box('SHW_wall_back', M.marble, 1.7, 2.4, .06, 0, 1.2, -.68, .6);
  box('SHW_wall_left', M.marble, .06, 2.4, 1.36, -.88, 1.2, -.03, .6);
  box('SHW_ceiling', M.marble, 1.76, .06, 1.42, -.03, 2.43, -.03, .6);
  // wall niche (shelf recess illusion: dark back plate + light marble shelves, proud 1 mm sets)
  box('SHW_niche_back', M.dark, .62, .62, .012, .25, 1.5, -.643);
  box('SHW_niche_shelf1', M.light, .62, .025, .1, .25, 1.21, -.6, .5);
  box('SHW_niche_shelf2', M.light, .62, .025, .1, .25, 1.51, -.6, .5);
  box('SHW_niche_trim', M.steel, .66, .02, .105, .25, 1.815, -.598);
  // LED strip washing the niche
  box('SHW_niche_led', M.led, .6, .012, .02, .25, 1.79, -.61);

  // ---- glass: right panel full depth, front panel partial (entry gap x -.85..-.05) ----
  box('GLASS_right', M.glass, .008, 2.05, 1.3, .846, 1.125, 0);
  box('GLASS_front', M.glass, .8, 2.05, .008, .45, 1.125, .646);
  box('SHW_glass_clamp_1', M.steel, .03, .06, .03, .846, 2.12, -.6);
  box('SHW_glass_clamp_2', M.steel, .03, .06, .03, .846, 2.12, .6);
  box('SHW_glass_clamp_3', M.steel, .03, .06, .03, .09, 2.12, .646);
  box('SHW_glass_rail', M.steel, .84, .025, .025, .45, 2.16, .646);      // top stabilizer bar, front
  box('SHW_glass_rail_r', M.steel, .025, .025, 1.32, .846, 2.16, -.02);

  // ---- matte-black square shower system on the LEFT wall (opposite the full-depth glass) ----
  // rain head: square escutcheon → square arm → large square head tilted 12° out from the wall
  box('SHW_head_escut', M.black, .026, .13, .13, -.836, 2.05, -.1);
  box('SHW_head_arm', M.black, .3, .055, .055, -.7, 2.03, -.1);
  prim('SHW_head', new THREE.BoxGeometry(.3, .05, .3), M.black, -.49, 1.955, -.1, 0, 0, -.21);
  prim('SHW_head_face', new THREE.BoxGeometry(.276, .014, .276), M.dark, -.484, 1.925, -.1, 0, 0, -.21);
  // slide bar with square handheld wand + wall outlet, further along the wall
  box('SHW_slide_bar', M.black, .034, .95, .034, -.828, 1.5, .25);
  box('SHW_slide_bracket_t', M.black, .03, .06, .06, -.834, 1.94, .25);
  box('SHW_slide_bracket_b', M.black, .03, .06, .06, -.834, 1.06, .25);
  box('SHW_wand_holder', M.black, .07, .07, .05, -.785, 1.62, .25);
  prim('SHW_wand', new THREE.BoxGeometry(.05, .3, .05), M.black, -.75, 1.5, .25, 0, 0, -.28);
  prim('SHW_wand_head', new THREE.BoxGeometry(.075, .05, .075), M.black, -.703, 1.655, .25, 0, 0, -.28);
  box('SHW_wand_outlet', M.black, .024, .095, .095, -.838, 1.5, .55);
  // hose: sagging chain computed between the outlet front face and the wand base (a single arc
  // can't touch both anchors — their chord is nearly level, so it is built segment by segment)
  {
    const A = new THREE.Vector3(-.826, 1.50, .55), B = new THREE.Vector3(-.791, 1.362, .25), SAG = .085, N = 7;
    const pt = t => new THREE.Vector3(
      A.x + (B.x - A.x) * t,
      A.y + (B.y - A.y) * t - SAG * Math.sin(Math.PI * t),
      A.z + (B.z - A.z) * t);
    for (let k = 0; k < N; k++) {
      const p0 = pt(k / N), p1 = pt((k + 1) / N), d = new THREE.Vector3().subVectors(p1, p0);
      const m = new THREE.Mesh(new THREE.CylinderGeometry(.009, .009, d.length() + .007, 8), M.black);
      m.name = 'SHW_wand_hose_' + String(k + 1).padStart(2, '0');
      m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.clone().normalize());
      m.position.copy(p0).add(p1).multiplyScalar(.5);
      m.castShadow = m.receiveShadow = true; G.add(m);
    }
  }
  // thermostatic valve: square plate, three round buttons, round temperature knob
  box('SHW_valve_plate', M.black, .028, .24, .24, -.836, 1.18, -.45);
  [-.07, 0, .07].forEach((dz, k) =>
    prim('SHW_valve_btn_' + (k + 1), new THREE.CylinderGeometry(.022, .022, .018, 14), M.black, -.813, 1.25, -.45 + dz, 0, 0, Math.PI / 2));
  prim('SHW_valve_knob', new THREE.CylinderGeometry(.048, .052, .046, 18), M.black, -.801, 1.13, -.45, 0, 0, Math.PI / 2);
  prim('SHW_valve_knob_grip', new THREE.BoxGeometry(.012, .05, .012), M.dark, -.777, 1.13, -.45, Math.PI / 2, 0, 0);

  // ---- bench along the back + drain ----
  box('SHW_bench', M.dark, .62, .38, .34, -.42, .29, -.44);
  box('SHW_bench_top', M.light, .66, .04, .38, -.42, .5, -.44, .5);
  box('SHW_bench_led', M.led, .6, .012, .015, -.42, .105, -.265);
  box('SHW_drain', M.steel, .5, .012, .07, .3, .102, .42);
  const slots = [];
  for (let k = 0; k < 5; k++) slots.push(k);
  slots.forEach(k => box('SHW_drain_slot_' + (k + 1), M.dark, .07, .014, .012, .12 + k * .09, .103, .42));

  return G;
}
