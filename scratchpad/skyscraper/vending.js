// vending.js — classic closed-front soda vending machine (Vendo-style), 1:1 scale, unbranded.
// Meters, Y-up, origin at floor centre. 0.81 w × 1.83 h × 0.84 d; flat lit front panel.
// LOGO_* meshes carry their own materials so custom .paa art drops in per machine.
import * as THREE from 'three';

export function buildVending() {
  const G = new THREE.Group(); G.name = 'ap_vending_machine';
  const TL = new THREE.TextureLoader();
  const tex = p => { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  const S = (name, o) => { const m = new THREE.MeshStandardMaterial(o); m.name = name; return m; };
  const M = {
    shell: S('metal_panels_white_co', { map: tex('a3/structures_f_exp/data/metal/metal_panels_white_co.png'), color: 0x17181c, roughness: .32, metalness: .6 }),
    frame: S('metal_seams_01_co', { map: tex('a3/structures_f_exp/data/metal/metal_seams_01_co.png'), color: 0x101114, roughness: .38, metalness: .65 }),
    plate: S('vend_plate_proc', { color: 0x2a2c33, roughness: .35, metalness: .6 }),
    dark:  S('vend_dark_proc',  { color: 0x0b0c0f, roughness: .6 }),
    // logo faces — lit sign panels, one material each; swap texture per machine
    logoF: S('LOGO_front_ca',  { color: 0x1e3f8f, emissive: 0x16307a, emissiveIntensity: .5, roughness: .35 }),
    logoL: S('LOGO_side_l_ca', { color: 0x1a2f66, emissive: 0x101f4a, emissiveIntensity: .25, roughness: .4 }),
    logoR: S('LOGO_side_r_ca', { color: 0x1a2f66, emissive: 0x101f4a, emissiveIntensity: .25, roughness: .4 }),
    btn:   S('vend_button_proc', { color: 0x23252c, roughness: .4, metalness: .3 }),
    btnLb: S('vend_label_proc',  { color: 0xb8bdc6, emissive: 0x6a6f78, emissiveIntensity: .35, roughness: .5 }),
    steel: S('vend_steel_proc',  { color: 0x8e939c, roughness: .3, metalness: .8 }),
    slot:  S('vend_slot_proc',   { color: 0x3a3d45, roughness: .35, metalness: .7 }),
    card:  S('vend_card_proc',   { color: 0xd8d4c8, roughness: .8 }),
    flap:  S('vend_flap_proc',   { color: 0x1c1d22, roughness: .5, metalness: .4 }),
    vent:  S('vend_vent_proc',   { color: 0x0e0f12, roughness: .7 }),
  };
  function worldUV(g, s = 1) {
    const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
    for (let i = 0; i < p.count; i++) {
      const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
      let u, v;
      if (ay >= ax && ay >= az) { u = p.getX(i); v = p.getZ(i); }
      else if (ax >= az) { u = p.getZ(i); v = p.getY(i); }
      else { u = p.getX(i); v = p.getY(i); }
      uv.setXY(i, u / s, v / s);
    }
  }
  let n = 0;
  const add = (name, geo, mat, x = 0, y = 0, z = 0, o = {}) => {
    if (o.rx) geo.rotateX(o.rx); if (o.ry) geo.rotateY(o.ry); if (o.rz) geo.rotateZ(o.rz);
    geo.translate(x, y, z);
    if (geo.attributes.uv && o.wuv !== false) worldUV(geo, o.s || 1);
    const m = new THREE.Mesh(geo, mat);
    m.name = name + '_' + String(++n).padStart(3, '0');
    m.castShadow = m.receiveShadow = true; G.add(m); return m;
  };
  const box = (name, mat, x0, x1, y0, y1, z0, z1, o = {}) =>
    add(name, new THREE.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, o);

  const W = .405, D = .42, H = 1.83;             // half-w, half-d, height

  // ---- cabinet ----
  box('body', M.shell, -W, W, .09, H - .045, -D, D, { s: .7 });
  box('top_cap', M.frame, -W - .006, W + .006, H - .045, H, -D - .006, D + .006, { s: .5 });
  box('base', M.frame, -W + .02, W - .02, 0, .09, -D + .02, D - .02, { s: .5 });
  // vent grille on the base front
  for (let i = 0; i < 6; i++)
    box('vent_' + i, M.vent, -W + .06 + i * .075, -W + .11 + i * .075, .022, .072, D - .022, D - .014);
  // feet
  for (const [fx, fz] of [[-W + .07, -D + .08], [W - .07, -D + .08], [-W + .07, D - .08], [W - .07, D - .08]])
    add('foot', new THREE.CylinderGeometry(.028, .036, .05, 10), M.frame, fx, .025, fz, { wuv: false });

  // ---- flat lit front panel (the sign face) ----
  // x -0.385..0.165, sits 0.012 proud of the body front
  const chord = .55, cx = -.11, pz = D + .012, py0 = .14, py1 = H - .075;
  add('LOGO_front', new THREE.PlaneGeometry(chord, py1 - py0), M.logoF, cx, (py0 + py1) / 2, pz + .001, { wuv: false });
  // panel frame: top/bottom sills plus side rails
  box('panel_sill_t', M.frame, cx - chord / 2, cx + chord / 2, py1, py1 + .035, D - .01, pz, { s: .4 });
  box('panel_sill_b', M.frame, cx - chord / 2, cx + chord / 2, py0 - .035, py0, D - .01, pz, { s: .4 });
  box('panel_rail_l', M.frame, -W, -W + .022, py0 - .035, py1 + .035, D - .01, D + .012, { s: .4 });
  box('panel_rail_r', M.frame, .165, .187, py0 - .035, py1 + .035, D - .01, D + .012, { s: .4 });

  // ---- pickup flap set into the panel, bottom centre ----
  box('flap_frame', M.frame, -.325, .075, .225, .43, D + .008, D + .028, { s: .3 });
  add('flap_door', new THREE.PlaneGeometry(.34, .15), M.flap, -.125, .318, D + .0295, { wuv: false });
  box('flap_recess', M.dark, -.305, .055, .245, .258, D + .016, D + .03);
  box('flap_push', M.steel, -.185, -.065, .388, .404, D + .022, D + .032);

  // ---- selection column, right of the panel (x .187..W) ----
  const c0 = .187, c1 = W - .022, cf = D + .004;
  box('col_face', M.frame, c0, c1, .14, H - .075, D - .012, cf, { s: .4 });
  // instruction card, top
  box('card_frame', M.plate, c0 + .014, c1 - .014, H - .27, H - .095, cf, cf + .008);
  add('inst_card', new THREE.PlaneGeometry(c1 - c0 - .052, .145), M.card, (c0 + c1) / 2, H - .1825, cf + .0095, { wuv: false });
  // coin mech: slot, price window, return button
  box('coin_plate', M.plate, c0 + .014, c1 - .014, H - .50, H - .285, cf, cf + .01);
  box('coin_slot_bezel', M.steel, (c0 + c1) / 2 + .022, (c0 + c1) / 2 + .062, H - .345, H - .305, cf + .01, cf + .018);
  box('coin_slot', M.dark, (c0 + c1) / 2 + .034, (c0 + c1) / 2 + .05, H - .338, H - .312, cf + .014, cf + .02);
  box('price_win', M.dark, c0 + .026, (c0 + c1) / 2 - .01, H - .35, H - .30, cf + .008, cf + .014);
  add('coin_return', new THREE.CylinderGeometry(.019, .019, .014, 14), M.steel, (c0 + c1) / 2 + .042, H - .41, cf + .014, { rx: Math.PI / 2, wuv: false });
  box('return_cup', M.dark, c0 + .022, c0 + .092, H - .475, H - .415, cf + .006, cf + .016);
  // bill acceptor
  box('bill_plate', M.plate, c0 + .014, c1 - .014, H - .60, H - .515, cf, cf + .012);
  box('bill_slit', M.dark, c0 + .034, c1 - .034, H - .566, H - .552, cf + .012, cf + .016);
  // selection buttons — 9 rows with label windows
  for (let r = 0; r < 9; r++) {
    const by = H - .655 - r * .062;
    box(`sel_btn_${r}`, M.btn, c0 + .016, c0 + .066, by - .046, by, cf, cf + .014);
    box(`sel_lbl_${r}`, M.btnLb, c0 + .074, c1 - .016, by - .042, by - .004, cf, cf + .009);
  }
  // lock cylinder, low on the column
  add('lock', new THREE.CylinderGeometry(.013, .013, .016, 12), M.steel, (c0 + c1) / 2, .215, cf + .008, { rx: Math.PI / 2, wuv: false });

  // ---- door seam + hinge line ----
  box('door_seam', M.dark, -W + .012, -W + .018, .10, H - .05, D - .002, D + .002);
  for (const hy of [.32, .95, 1.58])
    box('hinge', M.frame, -W - .008, -W + .006, hy, hy + .11, D - .05, D - .014, { s: .3 });

  // ---- side logo panels ----
  add('LOGO_side_L', new THREE.PlaneGeometry(.66, 1.38), M.logoL, -W - .001, 1.02, 0, { ry: -Math.PI / 2, wuv: false });
  add('LOGO_side_R', new THREE.PlaneGeometry(.66, 1.38), M.logoR, W + .001, 1.02, 0, { ry: Math.PI / 2, wuv: false });

  return G;
}
