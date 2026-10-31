// kitchen.js — integrated kitchen run (Arma prop). ONE model.
// X east, Y up, Z north, meters, origin at plan center, base y=0. Front faces +Z (wall at back).
// 3.0 m straight run: base cabinets + worktop with inset sink + 60 cm oven column w/ 4-burner
// stove above. Every structural mesh = ONE convex box.
import * as THREE from 'three';

export function buildKitchen() {
  const G = new THREE.Group(); G.name = 'ap_kitchen_run';
  const TL = new THREE.TextureLoader();
  const tex = p => { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  const M = {
    top:    new THREE.MeshStandardMaterial({ name: 'native_house_stone_floor_co', map: tex('a3/structures_f_exp/data/stone/native_house_stone_floor_co.png'), roughness: .35, metalness: .05 }),
    cab:    new THREE.MeshStandardMaterial({ name: 'woodfine_01_co', map: tex('a3/structures_f_enoch/data/wood/woodfine_01_co.png'), roughness: .6 }),
    steel:  new THREE.MeshStandardMaterial({ name: 'steel_proc', color: 0xc4c9cd, roughness: .22, metalness: .9 }),
    dark:   new THREE.MeshStandardMaterial({ name: 'metal_dark_proc', color: 0x23272d, roughness: .45, metalness: .4 }),
    black:  new THREE.MeshStandardMaterial({ name: 'glass_black_proc', color: 0x0e1114, roughness: .15, metalness: .3 }),
    white:  new THREE.MeshStandardMaterial({ name: 'white_marking_proc', color: 0xe9e7e0, roughness: .6 }),
    burner: new THREE.MeshStandardMaterial({ name: 'burner_proc', color: 0x111111, roughness: .8 }),
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

  // ---- carcass: 3.0 wide, 0.6 deep, worktop at 0.9. Oven column x 0.6..1.2 (from left edge -1.5) ----
  // plinth + cabinet body (cabinet split around the sink void is unnecessary — sink basin sits IN the top)
  box('KIT_plinth', M.dark, 2.9, .1, .55, 0, .05, -.01);
  // left cabinets: 5 convex boxes around the sink void (nothing solid inside the basin)
  box('KIT_carcass_l1', M.cab, .13, .76, .6, -1.435, .1 + .38, 0);
  box('KIT_carcass_l2', M.cab, .13, .76, .6, -.665, .1 + .38, 0);
  box('KIT_carcass_l3', M.cab, .64, .76, .10, -1.05, .1 + .38, .25);
  box('KIT_carcass_l4', M.cab, .64, .76, .07, -1.05, .1 + .38, -.265);
  box('KIT_carcass_l5', M.cab, .64, .50, .43, -1.05, .1 + .25, -.015);   // under-basin box, top at 0.60 < basin floor 0.62
  box('KIT_carcass_r', M.cab, 1.5, .76, .6, .75, .1 + .38, 0);           // right cabinets (contiguous with oven bay)
  // oven column between: x -0.6..-0.3 left of? No: oven bay x -0.6..0.0? Keep column x -0.6..0.3? -> bay x -0.6..0.3 is 0.9 wide; standard 0.6: x -0.6..0.0
  box('KIT_oven_bay', M.dark, .6, .76, .58, -.3, .1 + .38, -.01);        // oven housing box
  // worktop with sink cutout: 4 convex pieces around the basin (basin x -1.35..-.75, z -.21..+.19)
  const t0 = .86, t1 = .9;
  box('KIT_top_l', M.top, .15, t1 - t0, .6, -1.425, (t0 + t1) / 2, 0, .35);
  box('KIT_top_r', M.top, 2.25, t1 - t0, .6, .375, (t0 + t1) / 2, 0, .35);
  box('KIT_top_f', M.top, .6, t1 - t0, .11, -1.05, (t0 + t1) / 2, .245, .35);
  box('KIT_top_b', M.top, .6, t1 - t0, .09, -1.05, (t0 + t1) / 2, -.255, .35);
  box('KIT_splash', M.top, 2.9, .45, .02, 0, t1 + .225, -.29, .35);
  // doors + drawers (2 mm proud), steel bar pulls
  box('KIT_door_l1', M.cab, .42, .62, .018, -1.27, .47, .309);
  box('KIT_door_l2', M.cab, .42, .62, .018, -.83, .47, .309);
  box('KIT_drawer_r1', M.cab, .69, .18, .018, .345, .77, .309);
  box('KIT_drawer_r2', M.cab, .69, .18, .018, .345, .57, .309);
  box('KIT_door_r1', M.cab, .69, .36, .018, .345, .28, .309);
  box('KIT_door_r2', M.cab, .55, .62, .018, 1.21, .47, .309);
  const pulls = [[-1.11, .72, 'l1'], [-.99, .72, 'l2'], [.345, .77, 'r1'], [.345, .57, 'r2'], [.345, .41, 'r3'], [1.05, .72, 'r4']];
  pulls.forEach(([x, y, k]) => box('KIT_pull_' + k, M.steel, k[0] === 'r' && k !== 'r4' ? .3 : .02, .02, .03, x, y, .325));
  // kickline reveal
  box('KIT_kick_led', M.dark, 2.86, .015, .01, 0, .105, .27);

  // ---- sink (basin walls = 4 boxes + floor, inset below top) ----
  // ---- sink: ONE welded basin mesh (walls + floor merged), deep-recessed 0.28 m ----
  const s = { x0: -1.35, x1: -.75, z0: -.21, z1: .19, top: t1, depth: .28 };
  {
    const parts = [];
    const nb = (w, h, d, cx, cy, cz) => { const g = new THREE.BoxGeometry(w, h, d).toNonIndexed(); g.translate(cx, cy, cz); worldUV(g, .3); parts.push(g); };
    nb(.6, s.depth, .02, -1.05, t1 - s.depth / 2, s.z1 - .01);
    nb(.6, s.depth, .02, -1.05, t1 - s.depth / 2, s.z0 + .01);
    nb(.02, s.depth, .36, s.x0 + .01, t1 - s.depth / 2, -.01);
    nb(.02, s.depth, .36, s.x1 - .01, t1 - s.depth / 2, -.01);
    nb(.6, .015, .4, -1.05, t1 - s.depth, -.01);
    const pos = [], nor = [], uv = [];
    for (const g of parts) { pos.push(...g.attributes.position.array); nor.push(...g.attributes.normal.array); uv.push(...g.attributes.uv.array); }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    const m = new THREE.Mesh(g, M.steel); m.name = 'SINK_basin';
    m.castShadow = m.receiveShadow = true; G.add(m);
  }
  prim('SINK_drain', new THREE.CylinderGeometry(.022, .022, .006, 12), M.dark, -1.05, t1 - s.depth + .011, -.01);
  // faucet: column + arc spout + lever
  // faucet: gooseneck — column up to the arc, arc arches forward, nozzle drops over the basin, lever on the column top
  prim('SINK_faucet_col', new THREE.CylinderGeometry(.016, .02, .24, 10), M.steel, -1.05, t1 + .12, -.245);
  prim('SINK_faucet_arc', new THREE.TorusGeometry(.09, .012, 8, 16, Math.PI), M.steel, -1.05, t1 + .24, -.155, 0, Math.PI / 2, 0);
  prim('SINK_faucet_tip', new THREE.CylinderGeometry(.011, .013, .08, 8), M.steel, -1.05, t1 + .20, -.065);
  prim('SINK_lever', new THREE.CylinderGeometry(.007, .009, .1, 8), M.steel, -1.005, t1 + .263, -.245, 0, 0, -1.1);

  // ---- oven (in the column, door face flush with fronts) ----
  box('OVEN_frame', M.steel, .58, .6, .02, -.3, .46, .3);
  box('OVEN_door', M.black, .5, .44, .015, -.3, .40, .312);
  box('OVEN_handle', M.steel, .5, .022, .03, -.3, .655, .33);
  box('OVEN_panel', M.dark, .5, .07, .012, -.3, .70, .312);
  [[-.42, 0], [-.34, 1], [-.26, 2]].forEach(([x, i]) =>
    prim(`OVEN_knob_${i + 1}`, new THREE.CylinderGeometry(.016, .018, .022, 10), M.steel, x, .70, .318, Math.PI / 2));
  box('OVEN_window', M.dark, .36, .3, .004, -.3, .40, .321);

  // ---- stove: black ceramic hob on the worktop above the oven + 4 burners + knob strip ----
  box('STOVE_hob', M.black, .58, .012, .52, -.3, t1 + .006, -.02, .5);
  [[-.44, -.15], [-.16, -.15], [-.44, .13], [-.16, .13]].forEach(([x, z], i) =>
    prim(`STOVE_burner_${i + 1}`, new THREE.CylinderGeometry(i % 3 === 0 ? .09 : .07, i % 3 === 0 ? .09 : .07, .006, 18), M.burner, x, t1 + .015, z));
  [[-.44, -.15], [-.16, -.15], [-.44, .13], [-.16, .13]].forEach(([x, z], i) =>
    prim(`STOVE_grate_${i + 1}`, new THREE.TorusGeometry(i % 3 === 0 ? .075 : .058, .006, 6, 14), M.dark, x, t1 + .02, z, Math.PI / 2));

  return G;
}
