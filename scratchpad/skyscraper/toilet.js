// toilet.js — luxury wall-hung toilet with integrated bidet (Arma prop). Higher polycount:
// lathed/extruded shells rather than boxes. X east, Y up, Z north, meters, origin at plan center,
// base y=0, front faces +Z (cistern panel against the wall at z=-.29).
import * as THREE from 'three';

export function buildToilet() {
  const G = new THREE.Group(); G.name = 'ap_lux_toilet_bidet';
  const TL = new THREE.TextureLoader();
  const tex = p => { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  const M = {
    porc:  new THREE.MeshStandardMaterial({ name: 'porcelain_white_proc', color: 0xf2f1ec, roughness: .12, metalness: .04 }),
    seat:  new THREE.MeshStandardMaterial({ name: 'seat_white_proc', color: 0xe9e8e2, roughness: .2, metalness: .02 }),
    black: new THREE.MeshStandardMaterial({ name: 'matte_black_proc', color: 0x141619, roughness: .55, metalness: .3 }),
    steel: new THREE.MeshStandardMaterial({ name: 'steel_proc', color: 0xc4c9cd, roughness: .22, metalness: .9 }),
    marble: new THREE.MeshStandardMaterial({ name: 'marble_tiles_02_co', map: tex('a3/structures_f_exp/data/tiles/marble_tiles_02_co.png'), roughness: .25, metalness: .08 }),
    water: new THREE.MeshStandardMaterial({ name: 'water_proc', color: 0x9fd8e6, roughness: .05, metalness: .1, transparent: true, opacity: .55 }),
    glass: new THREE.MeshStandardMaterial({ name: 'glass_panel_proc', color: 0x1b1f24, roughness: .1, metalness: .35 }),
    led:   new THREE.MeshStandardMaterial({ name: 'led_warm_proc', color: 0xfff2d8, emissive: 0xffe7b8, emissiveIntensity: 1.5, roughness: .3 }),
  };
  const add = (name, geo, mat) => {
    const m = new THREE.Mesh(geo, mat); m.name = name;
    m.castShadow = m.receiveShadow = true; G.add(m); return m;
  };
  const place = (g, x, y, z, rx = 0, ry = 0, rz = 0) => {
    g.rotateX(rx); g.rotateY(ry); g.rotateZ(rz); g.translate(x, y, z); return g;
  };
  function worldUV(g, s = .5) {
    const p = g.attributes.position, n = g.attributes.normal, uv = g.attributes.uv;
    if (!uv) return g;
    for (let i = 0; i < p.count; i++) {
      const ax = Math.abs(n.getX(i)), ay = Math.abs(n.getY(i)), az = Math.abs(n.getZ(i));
      let u, v;
      if (ay >= ax && ay >= az) { u = p.getX(i); v = p.getZ(i); }
      else if (ax >= az)        { u = p.getZ(i); v = p.getY(i); }
      else                      { u = p.getX(i); v = p.getY(i); }
      uv.setXY(i, u / s, v / s);
    }
    return g;
  }
  // rounded-rect (squircle) outline used for the bowl, seat and lid — half-width a, half-depth b,
  // waisted toward the back so it reads as a real elongated pan
  function panOutline(a, b, taper = .72, n = 64) {
    const pts = [];
    for (let k = 0; k < n; k++) {
      const t = k / n * Math.PI * 2, ct = Math.cos(t), st = Math.sin(t);
      const p = 2.6, w = a * (st > 0 ? 1 : taper + (1 - taper) * (1 + st));
      const sx = Math.sign(ct) * Math.pow(Math.abs(ct), 2 / p);
      const sz = Math.sign(st) * Math.pow(Math.abs(st), 2 / p);
      pts.push(new THREE.Vector2(sx * w, sz * b));
    }
    return pts;
  }
  // sweep an outline between y0..y1 with a per-height scale profile → smooth shell (high poly)
  function shell(outline, steps, prof, closeTop = false, closeBottom = false) {
    const rings = [], n = outline.length;
    for (let s = 0; s <= steps; s++) {
      const t = s / steps, [y, k, kz] = prof(t);
      rings.push(outline.map(p => new THREE.Vector3(p.x * k, y, p.y * (kz ?? k))));
    }
    const pos = [], nor = [], uv = [];
    const push = (a, b, c) => {
      const n1 = new THREE.Vector3().subVectors(b, a).cross(new THREE.Vector3().subVectors(c, a)).normalize();
      for (const v of [a, b, c]) { pos.push(v.x, v.y, v.z); nor.push(n1.x, n1.y, n1.z); uv.push(v.x, v.z); }
    };
    for (let s = 0; s < steps; s++) for (let i = 0; i < n; i++) {
      const j = (i + 1) % n, A = rings[s][i], B = rings[s][j], C = rings[s + 1][j], D = rings[s + 1][i];
      push(A, C, B); push(A, D, C);
    }
    const cap = (ring, up) => {
      const c = new THREE.Vector3(0, ring[0].y, 0);
      for (let i = 0; i < n; i++) {
        const j = (i + 1) % n;
        if (up) push(c, ring[j], ring[i]); else push(c, ring[i], ring[j]);
      }
    };
    if (closeBottom) cap(rings[0], false);
    if (closeTop) cap(rings[steps], true);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    return g;
  }
  const ring = (outline, y, k, kz) => outline.map(p => new THREE.Vector3(p.x * k, y, p.y * (kz ?? k)));
  function band(outline, y0, k0, y1, k1) { // thin flat band between two scaled rings (rim, seat top)
    const a = ring(outline, y0, k0), b = ring(outline, y1, k1), n = outline.length;
    const pos = [], nor = [], uv = [];
    const push = (p, q, r) => {
      const nn = new THREE.Vector3().subVectors(q, p).cross(new THREE.Vector3().subVectors(r, p)).normalize();
      for (const v of [p, q, r]) { pos.push(v.x, v.y, v.z); nor.push(nn.x, nn.y, nn.z); uv.push(v.x, v.z); }
    };
    for (let i = 0; i < n; i++) { const j = (i + 1) % n; push(a[i], b[i], b[j]); push(a[i], b[j], a[j]); }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
    return g;
  }

  const PAN = panOutline(.185, .3);        // bowl outline: 37 cm wide, 60 cm long
  const RIM_Y = .40;                       // rim height (wall-hung, comfort height)

  // ---- cistern panel + marble shelf (wall side) ----
  add('TLT_panel', worldUV(place(new THREE.BoxGeometry(.56, 1.05, .1), 0, .525, -.29)), M.marble);
  add('TLT_panel_shelf', worldUV(place(new THREE.BoxGeometry(.62, .035, .16), 0, 1.06, -.26)), M.marble);
  add('TLT_panel_led', place(new THREE.BoxGeometry(.5, .012, .018), 0, 1.036, -.205), M.led);
  // flush plate: black glass with two steel pads
  add('TLT_flush_plate', place(new THREE.BoxGeometry(.19, .13, .014), 0, .88, -.232), M.glass);
  add('TLT_flush_pad_1', place(new THREE.CylinderGeometry(.028, .028, .01, 28), -.045, .905, -.222, Math.PI / 2), M.steel);
  add('TLT_flush_pad_2', place(new THREE.CylinderGeometry(.019, .019, .01, 24), .045, .895, -.222, Math.PI / 2), M.steel);

  // ---- bowl: outer shell (skirted, wall-hung) ----
  add('TLT_bowl_outer', shell(PAN, 22, t => {
    const y = .14 + t * (RIM_Y - .14);
    const k = .74 + .26 * Math.pow(t, .55);          // flares from the underside up to the rim
    return [y, k, k];
  }, false, false), M.porc);
  // underside: rounded closing dome
  add('TLT_bowl_under', shell(PAN, 12, t => {
    const y = .075 + t * .065, k = .74 * Math.sin(Math.acos(1 - t * .999) * .5 + .18) / Math.sin(.18 + Math.PI / 2 * .999 * .5);
    return [y, Math.min(k, .74), Math.min(k, .74)];
  }, false, true), M.porc);
  // rim band + inner basin funnel + sump
  add('TLT_bowl_rim', band(PAN, RIM_Y, 1.0, RIM_Y - .004, .86), M.porc);
  add('TLT_bowl_inner', shell(PAN, 20, t => {
    const y = RIM_Y - .004 - t * .175;
    const k = .86 - .56 * Math.pow(t, .8);
    return [y, k, k];
  }, false, false), M.porc);
  add('TLT_bowl_sump', shell(PAN, 10, t => {
    const y = .221 - t * .03, k = .30 * Math.cos(t * Math.PI / 2 * .9);
    return [y, Math.max(k, .05), Math.max(k, .05)];
  }, false, true), M.porc);
  add('TLT_water', band(PAN, .245, .295, .245, .02), M.water);

  // ---- seat + lid (soft-close hinge at the back) ----
  add('TLT_seat', shell(PAN, 16, t => {
    const y = RIM_Y + .004 + t * .026, k = .995 + .01 * Math.sin(t * Math.PI);
    return [y, k, k];
  }, false, false), M.seat);
  add('TLT_seat_top', band(PAN, RIM_Y + .03, 1.0, RIM_Y + .03, .68), M.seat);
  add('TLT_seat_inner', shell(PAN, 8, t => [RIM_Y + .03 - t * .026, .68, .68], false, false), M.seat);
  // lid raised to ~78° against the panel
  const lidG = new THREE.Group();
  const lidShell = shell(PAN, 14, t => {
    const y = 0 + t * .022, k = .99 + .012 * Math.sin(t * Math.PI);
    return [y, k, k];
  }, true, true);
  lidShell.translate(0, 0, .26);
  lidShell.rotateX(-1.36);
  lidShell.translate(0, RIM_Y + .05, -.26);
  add('TLT_lid', lidShell, M.seat);
  add('TLT_hinge_l', place(new THREE.CylinderGeometry(.019, .019, .075, 20), -.085, RIM_Y + .05, -.255, 0, 0, Math.PI / 2), M.steel);
  add('TLT_hinge_r', place(new THREE.CylinderGeometry(.019, .019, .075, 20), .085, RIM_Y + .05, -.255, 0, 0, Math.PI / 2), M.steel);

  // ---- integrated bidet: wand housing under the rim + telescoping nozzle ----
  add('TLT_bidet_housing', place(new THREE.BoxGeometry(.115, .042, .085), 0, RIM_Y - .028, -.235, .18), M.seat);
  add('TLT_bidet_arm', place(new THREE.CylinderGeometry(.016, .018, .13, 20), 0, RIM_Y - .042, -.165, Math.PI / 2 - .18), M.steel);
  add('TLT_bidet_nozzle', place(new THREE.CylinderGeometry(.009, .013, .05, 16), 0, RIM_Y - .053, -.09, Math.PI / 2 - .18), M.steel);
  add('TLT_bidet_tip', place(new THREE.SphereGeometry(.0105, 16, 12), 0, RIM_Y - .057, -.068), M.steel);
  // bidet control panel on the right, arm-rest style
  add('TLT_ctrl_body', worldUV(place(new THREE.BoxGeometry(.145, .05, .3), .2025, RIM_Y - .015, -.09)), M.seat);
  add('TLT_ctrl_face', place(new THREE.BoxGeometry(.084, .012, .27), .225, RIM_Y + .015, -.09), M.glass);
  [-.09, -.03, .03, .09].forEach((dz, k) =>
    add('TLT_ctrl_btn_' + (k + 1), place(new THREE.CylinderGeometry(.016, .016, .012, 20), .225, RIM_Y + .024, -.09 + dz), M.steel));
  add('TLT_ctrl_led', place(new THREE.BoxGeometry(.006, .004, .22), .272, RIM_Y + .012, -.09), M.led);

  // ---- supply + mounting details ----
  add('TLT_supply_valve', place(new THREE.CylinderGeometry(.022, .026, .04, 20), -.115, .2, -.222, Math.PI / 2), M.steel);
  add('TLT_supply_pipe', place(new THREE.CylinderGeometry(.011, .011, .085, 16), -.115, .155, -.222), M.steel);
  add('TLT_bolt_cap_l', place(new THREE.SphereGeometry(.012, 14, 10), -.155, .155, -.225), M.steel);
  add('TLT_bolt_cap_r', place(new THREE.SphereGeometry(.012, 14, 10), .155, .155, -.225), M.steel);

  // ---- stand the pan proud of the wall: everything except the wall-side panel/flush/supply
  // moves +7 cm in z, so the bowl reads as hung in front of the panel rather than sunk into it ----
  // FWD must stay ≤ .06: the bowl's authored back plane is z −.30 and the panel face is −.24,
  // so a bigger shift lifts the pan off its carrier. TLT_ctrl_* is anchored to the wall and stays put.
  const FWD = .05, WALLSIDE = /^TLT_(panel|flush|supply|bolt|ctrl)/;
  for (const m of G.children) if (!WALLSIDE.test(m.name)) m.geometry.translate(0, 0, FWD);

  return G;
}
