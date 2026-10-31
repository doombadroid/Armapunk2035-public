// f770.js — large-format industrial FDM printer (Stratasys F770 class) for Armapunk2035.
// X east, Y up, Z north, meters, origin at floor center, front = +Z. Envelope 2.24 W × 1.80 H (player height) × 1.09 D.
// Open front chamber (no door); gantry: X rails → Y bridge → head carriage (2 tips); platform on rear Z-lift.
// Animated selections: f770_bridge (X), f770_head (Y/depth), f770_platform (Z); hide-toggled f770_screen_ready / f770_screen_printing.
// Real a3 textures on big surfaces (previewed from textures/a3/…png), procedural colors on accents.
import * as THREE from 'three';

export function buildF770() {
  const G = new THREE.Group(); G.name = 'ap_printer_f770';
  const MS = o => new THREE.MeshStandardMaterial(o);
  const TL = new THREE.TextureLoader();
  const tex = (p, rx = 1, ry = 1) => { const t = TL.load('textures/' + p); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(rx, ry); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; };
  const M = {
    shell:   MS({ name: 'metal_panels_white_co', map: tex('a3/structures_f_exp/data/metal/metal_panels_white_co.png', 2, 2), color: 0xe4e6e8, roughness: .5, metalness: .25 }),
    dark:    MS({ name: 'metal_servicehangar_black_co', map: tex('a3/structures_f_enoch/data/metal/metal_servicehangar_black_co.png', 2, 1), color: 0x5c6068, roughness: .55, metalness: .5 }),
    plinth:  MS({ name: 'metalcoloureddark_co', map: tex('a3/structures_f/data/metal/metalcoloureddark_co.png', 2, 1), roughness: .65, metalness: .4 }),
    liner:   MS({ name: 'metal_seams_01_co', map: tex('a3/structures_f_exp/data/metal/metal_seams_01_co.png', 2, 1), color: 0x8a8e94, roughness: .6, metalness: .6 }),
    rail:    MS({ name: 'metal_gray_clean_co', map: tex('a3/structures_f/data/metal/metal_gray_clean_co.png'), roughness: .3, metalness: .9 }),
    tray:    MS({ name: 'metalclean1_co', map: tex('a3/structures_f/data/metal/metalclean1_co.png'), color: 0xb0b4ba, roughness: .45, metalness: .8 }),
    trim:    MS({ name: 'trim_charcoal_proc', color: 0x22242a, roughness: .7, metalness: .3 }),
    rubber:  MS({ name: 'rubber_proc', color: 0x0e0f11, roughness: 1 }),
    scrReady: MS({ name: 'ap_f770_screen_ready_co', map: tex('ap/ap_f770_screen_ready_co.png'), emissiveMap: tex('ap/ap_f770_screen_ready_co.png'), emissive: 0xffffff, emissiveIntensity: .9, roughness: .35 }),
    scrPrint: MS({ name: 'ap_f770_screen_printing_co', map: tex('ap/ap_f770_screen_printing_co.png'), emissiveMap: tex('ap/ap_f770_screen_printing_co.png'), emissive: 0xffffff, emissiveIntensity: .9, roughness: .35 }),
    led:     MS({ name: 'led_proc', color: 0xffffff, emissive: 0xf2f6ff, emissiveIntensity: 1.4 }),
    ledAmber:MS({ name: 'led_amber_proc', color: 0xffb020, emissive: 0xffa010, emissiveIntensity: 1.2 }),
    brass:   MS({ name: 'brass_proc', color: 0xc9a24a, roughness: .35, metalness: 1 }),
    heater:  MS({ name: 'heater_proc', color: 0x7a2a1a, roughness: .6, metalness: .6 }),
    belt:    MS({ name: 'belt_proc', color: 0x101013, roughness: .95 }),
    cable:   MS({ name: 'cable_proc', color: 0x141518, roughness: .9 }),
  };
  const add = (g, name, geo, mat, x = 0, y = 0, z = 0) => {
    const m = new THREE.Mesh(geo, mat); m.name = name; m.position.set(x, y, z);
    m.castShadow = m.receiveShadow = true; g.add(m); return m;
  };
  const box = (w, h, d) => new THREE.BoxGeometry(w, h, d);
  const cyl = (rt, rb, h, s = 20) => new THREE.CylinderGeometry(rt, rb, h, s);
  const B = (g, n, m, w, h, d, x, y, z) => add(g, n, box(w, h, d), m, x, y, z);
  const Cy = (g, n, m, r, h, x, y, z, axis = 'y', s = 20) => { const o = add(g, n, cyl(r, r, h, s), m, x, y, z); if (axis === 'x') o.rotation.z = Math.PI / 2; if (axis === 'z') o.rotation.x = Math.PI / 2; return o; };

  const W = 2.24, D = 1.09, H = 1.80, T = .04, hx = W / 2, hz = D / 2;
  const CAP = 1.56;               // dark top cap starts here
  const LOW = .62;                // material-bay band top
  const OX0 = -.98, OX1 = .62;    // door opening x range (1.60 wide)
  const OY0 = .70, OY1 = 1.50;    // door opening y range

  // ---- plinth + levelers ----
  B(G, 'f770_plinth', M.plinth, W - .06, .10, D - .06, 0, .15, 0);
  [[-.95, .42], [-.95, -.42], [.95, .42], [.95, -.42]].forEach(([x, z], i) => {
    Cy(G, 'f770_foot_' + (i + 1), M.rubber, .045, .10, x, .05, z);
  });

  // ---- white shell (side / back / lower front), dark cap ring + top ----
  B(G, 'f770_side_l', M.shell, T, CAP - .10, D, -hx + T / 2, (CAP + .10) / 2, 0);
  B(G, 'f770_side_r', M.shell, T, CAP - .10, D, hx - T / 2, (CAP + .10) / 2, 0);
  B(G, 'f770_back', M.shell, W - 2 * T, CAP - .10, T, 0, (CAP + .10) / 2, -hz + T / 2);
  B(G, 'f770_front_low', M.shell, W - 2 * T, LOW - .10, T, 0, (LOW + .10) / 2, hz - T / 2);
  // front wall around the chamber opening
  B(G, 'f770_pillar_l', M.shell, OX0 + hx - T, CAP - LOW, T, (-hx + T + OX0) / 2, (CAP + LOW) / 2, hz - T / 2);
  B(G, 'f770_pillar_r', M.shell, hx - T - OX1, CAP - LOW, T, (hx - T + OX1) / 2, (CAP + LOW) / 2, hz - T / 2);
  B(G, 'f770_header', M.shell, OX1 - OX0, CAP - OY1, T, (OX0 + OX1) / 2, (CAP + OY1) / 2, hz - T / 2);
  B(G, 'f770_sill', M.shell, OX1 - OX0, OY0 - LOW, T, (OX0 + OX1) / 2, (OY0 + LOW) / 2, hz - T / 2);
  // cap ring (dark) + top plate
  const capH = H - CAP;
  B(G, 'f770_cap_f', M.dark, W, capH, T, 0, CAP + capH / 2, hz - T / 2 + .002);
  B(G, 'f770_cap_b', M.dark, W, capH, T, 0, CAP + capH / 2, -hz + T / 2 - .002);
  B(G, 'f770_cap_l', M.dark, T, capH, D, -hx + T / 2 - .002, CAP + capH / 2, 0);
  B(G, 'f770_cap_r', M.dark, T, capH, D, hx - T / 2 + .002, CAP + capH / 2, 0);
  B(G, 'f770_top', M.dark, W, T, D, 0, H - T / 2, 0);
  B(G, 'f770_top_vent', M.trim, .70, .012, .40, .40, H + .004, -.15);
  [-.28, -.14, 0, .14, .28].forEach((dz, i) => B(G, 'f770_top_vent_slot_' + (i + 1), M.rubber, .62, .006, .05, .40, H + .012, -.15 + dz * .5));
  // white seam accent band (dark, recessed look) below the chamber band
  B(G, 'f770_seam_f', M.trim, W - 2 * T, .03, .008, 0, LOW, hz + .002);
  B(G, 'f770_seam_l', M.trim, .008, .03, D, -hx - .002, LOW, 0);
  B(G, 'f770_seam_r', M.trim, .008, .03, D, hx + .002, LOW, 0);

  // ---- material bay (two canister doors) + right service grille, lower front ----
  [[-.78, 1], [-.12, 2]].forEach(([x, k]) => {
    B(G, `f770_baydoor_${k}`, M.dark, .58, .40, .02, x, .36, hz + .006);
    B(G, `f770_bayhandle_${k}`, M.trim, .02, .18, .025, x + .25, .36, hz + .028);
    B(G, `f770_baylabel_${k}`, M.ledAmber, .06, .012, .004, x - .22, .52, hz + .018);
  });
  B(G, 'f770_grille', M.trim, .44, .30, .015, .80, .36, hz + .004);
  for (let i = 0; i < 6; i++) B(G, 'f770_grille_slat_' + (i + 1), M.rubber, .40, .012, .01, .80, .245 + i * .046, hz + .014);

  // ---- touchscreen + status bar on right pillar ----
  B(G, 'f770_hmi_mount', M.trim, .34, .26, .05, .87, 1.40, hz + .02);
  B(G, 'f770_screen_ready', M.scrReady, .30, .21, .006, .87, 1.41, hz + .048);
  B(G, 'f770_screen_printing', M.scrPrint, .30, .21, .006, .87, 1.41, hz + .048).visible = false;
  B(G, 'f770_hmi_btn', M.rubber, .05, .012, .006, .87, 1.285, hz + .048);
  B(G, 'f770_status_led', M.led, .60, .012, .01, (OX0 + OX1) / 2, CAP - .03, hz + .003);
  B(G, 'f770_power_led', M.ledAmber, .012, .012, .006, .70, 1.30, hz + .003);

  // ---- open chamber: fixed dark trim ring around the opening (no door) ----
  {
    const dw = OX1 - OX0, dh = OY1 - OY0, cx = (OX0 + OX1) / 2, cy = (OY0 + OY1) / 2, fr = .05, fz = hz + .006;
    B(G, 'f770_open_trim_t', M.dark, dw + 2 * fr, fr, .012, cx, OY1 + fr / 2, fz);
    B(G, 'f770_open_trim_b', M.dark, dw + 2 * fr, fr, .012, cx, OY0 - fr / 2, fz);
    B(G, 'f770_open_trim_l', M.dark, fr, dh, .012, OX0 - fr / 2, cy, fz);
    B(G, 'f770_open_trim_r', M.dark, fr, dh, .012, OX1 + fr / 2, cy, fz);
  }

  // ---- chamber liner (dark interior) ----
  const IX0 = OX0, IX1 = OX1, IZ0 = -hz + T + .01, IZ1 = hz - T, IY0 = OY0, IY1 = 1.53;
  const iw = IX1 - IX0, id = IZ1 - IZ0, icx = (IX0 + IX1) / 2, icz = (IZ0 + IZ1) / 2;
  B(G, 'f770_liner_back', M.liner, iw, IY1 - IY0, .02, icx, (IY0 + IY1) / 2, IZ0 + .01);
  B(G, 'f770_liner_floor', M.liner, iw, .02, id, icx, IY0 + .01, icz);
  B(G, 'f770_liner_ceil', M.liner, iw, .02, id, icx, IY1 - .01, icz);
  B(G, 'f770_liner_l', M.liner, .02, IY1 - IY0, id, IX0 + .01, (IY0 + IY1) / 2, icz);
  B(G, 'f770_liner_r', M.liner, .02, IY1 - IY0, id, IX1 - .01, (IY0 + IY1) / 2, icz);
  B(G, 'f770_chamber_led_l', M.led, .012, .01, .80, IX0 + .04, IY1 - .025, icz);
  B(G, 'f770_chamber_led_r', M.led, .012, .01, .80, IX1 - .04, IY1 - .025, icz);

  // ---- gantry: fixed X rails (front/back, along x) ----
  const RY = 1.44, RZ = .34, PX = -.18;   // rail height, rail depth offset, platform/head center x
  for (const [s, n] of [[1, 'f'], [-1, 'b']]) {
    B(G, `f770_xrail_${n}`, M.rail, iw - .06, .045, .045, icx, RY, s * RZ);
    B(G, `f770_xrail_${n}_mount_l`, M.trim, .06, .08, .06, IX0 + .05, RY - .02, s * RZ);
    B(G, `f770_xrail_${n}_mount_r`, M.trim, .06, .08, .06, IX1 - .05, RY - .02, s * RZ);
    B(G, `f770_xbelt_${n}`, M.belt, iw - .12, .008, .003, icx, RY - .04, s * (RZ + .03));
  }
  B(G, 'f770_xmotor', M.trim, .09, .09, .09, IX1 - .07, RY - .09, -RZ);

  // ---- Y bridge (moves along x on the rails) — pivot at x=PX ----
  const bridge = new THREE.Group(); bridge.name = 'f770_bridge'; bridge.position.set(PX, 0, 0); G.add(bridge);
  B(bridge, 'f770_bridge_beam', M.rail, .07, .06, 2 * RZ - .02, 0, RY - .07, 0);
  B(bridge, 'f770_bridge_car_f', M.trim, .12, .09, .11, 0, RY, RZ);
  B(bridge, 'f770_bridge_car_b', M.trim, .12, .09, .11, 0, RY, -RZ);
  B(bridge, 'f770_ymotor', M.trim, .07, .07, .07, 0, RY - .02, -RZ - .10);
  B(bridge, 'f770_ybelt', M.belt, .003, .008, 2 * RZ - .10, .045, RY - .05, 0);

  // ---- head carriage (moves along z on the bridge) — child of the bridge, pivot at z=0 ----
  const head = new THREE.Group(); head.name = 'f770_head'; head.position.set(0, 0, 0); bridge.add(head);
  B(head, 'f770_head_car', M.trim, .14, .07, .12, 0, RY - .07, 0);
  B(head, 'f770_head_body', M.dark, .17, .20, .16, 0, RY - .21, .02);
  B(head, 'f770_head_cover', M.shell, .18, .06, .17, 0, RY - .13, .02);
  B(head, 'f770_head_heater', M.heater, .12, .035, .07, 0, RY - .325, .02);
  Cy(head, 'f770_tip_model', M.brass, .006, .05, -.025, RY - .355, .02, 'y', 12);
  Cy(head, 'f770_tip_support', M.brass, .006, .05, .025, RY - .355, .02, 'y', 12);
  B(head, 'f770_head_fan', M.trim, .06, .06, .012, 0, RY - .21, .105);
  Cy(head, 'f770_head_fan_blade', M.rubber, .024, .008, 0, RY - .21, .113, 'z', 16);
  B(head, 'f770_head_cable', M.cable, .03, .22, .012, .06, RY - .16, -.085);

  // ---- platform on rear Z-lift (moves along y) — pivot at platform top y=PY ----
  const PY = 1.05;  // sheet top; tips end at RY-.38 = 1.06 → printing 1 cm above the bed
  const plat = new THREE.Group(); plat.name = 'f770_platform'; plat.position.set(0, 0, 0); G.add(plat);
  B(plat, 'f770_tray', M.tray, 1.02, .03, .63, PX, PY - .017, 0);
  B(plat, 'f770_sheet', M.trim, 1.00, .004, .61, PX, PY, 0);
  B(plat, 'f770_tray_arm', M.trim, 1.00, .06, .10, PX, PY - .04, -.36);
  [[-.58, 1], [.22, 2]].forEach(([x, k]) => B(plat, 'f770_zcar_' + k, M.trim, .10, .16, .08, x, PY - .03, -.44));
  // fixed Z-lift columns (leadscrews + linear rails) at the back wall
  [[-.58, 1], [.22, 2]].forEach(([x, k]) => {
    Cy(G, 'f770_leadscrew_' + k, M.rail, .012, IY1 - IY0 - .10, x, (IY0 + IY1) / 2, -.44, 'y', 14);
    B(G, 'f770_zrail_' + k, M.rail, .04, IY1 - IY0 - .06, .02, x + .07, (IY0 + IY1) / 2, -.46);
    B(G, 'f770_zmotor_' + k, M.trim, .08, .08, .08, x, IY0 + .06, -.44);
  });

  G.userData.anim = { PX, RZ, PY, RY, OX0, OX1, OY0, OY1, hz, ledOn: M.led, ledIdle: M.ledAmber };
  return G;
}

// Print-cycle pose driver for the viewer (mirrors the SQF loop in the handoff).
// Wall-clock t → print/idle cycle: PRINT_S seconds of motion, then IDLE_S seconds frozen (head only moves while a job runs).
export const PRINT_S = 12, IDLE_S = 6;
export function poseF770(G, t) {
  const cyc = PRINT_S + IDLE_S, n = Math.floor(t / cyc), ph = t % cyc;
  const printing = ph < PRINT_S;
  t = n * PRINT_S + Math.min(ph, PRINT_S);            // accumulated print time; frozen during idle
  G.userData.printing = printing;
  const A = G.userData.anim;
  const bridge = G.getObjectByName('f770_bridge'), head = G.getObjectByName('f770_head');
  const plat = G.getObjectByName('f770_platform');
  const PASS = 1.3, XT = .28, ZT = .16, NPASS = 20;  // pass time, ±x travel over the part, ±z travel, passes per layer
  const p = Math.floor(t / PASS), k = (t % PASS) / PASS, e = k * k * (3 - 2 * k);
  const dir = p % 2 ? -1 : 1;
  bridge.position.x = A.PX + dir * (-XT + 2 * XT * e);
  const layer = Math.floor(p / NPASS), i = p % NPASS, sweep = layer % 2 ? NPASS - 1 - i : i;
  head.position.z = -ZT + (2 * ZT) * sweep / (NPASS - 1);
  plat.position.y = -(layer % 12) * .003;               // 12 layers then reset (demo loop)
  const led = G.getObjectByName('f770_status_led'); if (led) led.material = printing ? A.ledOn : A.ledIdle;
  G.getObjectByName('f770_screen_ready').visible = !printing;
  G.getObjectByName('f770_screen_printing').visible = printing;
}
