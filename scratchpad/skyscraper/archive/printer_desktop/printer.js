// Two desktop 3D printers — Arma props. Meters, Y-up, front = +Z, origin at floor center.
// buildPrinterI3(): open-frame bedslinger. buildPrinterCoreXY(): enclosed cube.
// Every mesh + material named for OBJ/MTL export. Doctrine per ARMA3_HANDOFF_PRINTER.md.
import * as THREE from 'three';

function mats() {
  const m = {
    alu:            new THREE.MeshStandardMaterial({ color: 0xb9bdc4, metalness: .9,  roughness: .38 }),
    alu_dark:       new THREE.MeshStandardMaterial({ color: 0x3d4148, metalness: .75, roughness: .5 }),
    steel:          new THREE.MeshStandardMaterial({ color: 0xd9dbe0, metalness: 1,   roughness: .22 }),
    plastic_black:  new THREE.MeshStandardMaterial({ color: 0x17181b, roughness: .85 }),
    plastic_dark:   new THREE.MeshStandardMaterial({ color: 0x2a2d33, roughness: .7 }),
    plastic_orange: new THREE.MeshStandardMaterial({ color: 0xff7a1a, roughness: .55 }),
    plastic_teal:   new THREE.MeshStandardMaterial({ color: 0x14b8ae, roughness: .55 }),
    brass:          new THREE.MeshStandardMaterial({ color: 0xd9a33c, metalness: 1, roughness: .35 }),
    pei:            new THREE.MeshStandardMaterial({ color: 0x2f2a1c, metalness: .35, roughness: .55 }),
    belt:           new THREE.MeshStandardMaterial({ color: 0x101013, roughness: .95 }),
    rubber:         new THREE.MeshStandardMaterial({ color: 0x0c0d0f, roughness: 1 }),
    motor_black:    new THREE.MeshStandardMaterial({ color: 0x212226, metalness: .45, roughness: .6 }),
    fan_dark:       new THREE.MeshStandardMaterial({ color: 0x1b1d21, roughness: .8 }),
    glass_smoke:    new THREE.MeshStandardMaterial({ color: 0x233340, transparent: true, opacity: .45, roughness: .12, metalness: .1 }),
    lcd:            new THREE.MeshStandardMaterial({ color: 0x062621, emissive: 0x17e0c8, emissiveIntensity: .9, roughness: .4 }),
    screen:         new THREE.MeshStandardMaterial({ color: 0x061422, emissive: 0x2b9df0, emissiveIntensity: .9, roughness: .35 }),
    led:            new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xf2f6ff, emissiveIntensity: 1.4 }),
    wire:           new THREE.MeshStandardMaterial({ color: 0x0e0f11, roughness: .9 }),
    filament_orange:new THREE.MeshStandardMaterial({ color: 0xff6a00, roughness: .5 }),
    filament_teal:  new THREE.MeshStandardMaterial({ color: 0x00c8bc, roughness: .5 }),
  };
  for (const k in m) m[k].name = k;
  return m;
}
// helpers -------------------------------------------------------------------
function B(g, n, mt, w, h, d, x, y, z, ry, rx, rz) {
  const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mt);
  o.name = n; o.position.set(x, y, z);
  if (ry) o.rotation.y = ry; if (rx) o.rotation.x = rx; if (rz) o.rotation.z = rz;
  g.add(o); return o;
}
function C(g, n, mt, r1, r2, h, x, y, z, axis, seg) {
  const o = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, h, seg || 18), mt);
  o.name = n; o.position.set(x, y, z);
  if (axis === 'x') o.rotation.z = Math.PI / 2;
  if (axis === 'z') o.rotation.x = Math.PI / 2;
  g.add(o); return o;
}
function T(g, n, mt, R, r, x, y, z, axis, seg1, seg2) {
  const o = new THREE.Mesh(new THREE.TorusGeometry(R, r, seg2 || 14, seg1 || 36), mt);
  o.name = n; o.position.set(x, y, z);
  if (axis === 'x') o.rotation.y = Math.PI / 2;
  if (axis === 'y') o.rotation.x = Math.PI / 2;
  g.add(o); return o;
}
function W(g, n, mt, pts, r) { // wire loom
  const o = new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts.map(p => new THREE.Vector3(...p))), 24, r, 8), mt);
  o.name = n; g.add(o); return o;
}
function fan(g, n, mt, mBlade, s, x, y, z, axis) { // square fan + blade disc
  B(g, n + '_frame', mt, axis === 'z' ? s : .01, s, axis === 'z' ? .01 : s, x, y, z);
  C(g, n + '_blade', mBlade, s * .42, s * .42, .012, x, y, z, axis, 20);
  C(g, n + '_hub', mt, s * .14, s * .14, .014, x, y, z, axis, 12);
}
function spool(g, pfx, m, mFil, x, y, z) { // axis along x
  C(g, pfx + '_rim_l', m.plastic_dark, .095, .095, .008, x - .034, y, z, 'x', 28);
  C(g, pfx + '_rim_r', m.plastic_dark, .095, .095, .008, x + .034, y, z, 'x', 28);
  C(g, pfx + '_hub', m.plastic_dark, .028, .028, .068, x, y, z, 'x', 16);
  T(g, pfx + '_filament', mFil, .059, .029, x, y, z, 'x', 36, 12);
}

// ============================== VARIANT A: i3 bedslinger =====================
export function buildPrinterI3() {
  const m = mats(), g = new THREE.Group(); g.name = 'printer_i3';
  // base frame
  for (const sx of [-1, 1]) {
    B(g, `i3_rail_${sx > 0 ? 'r' : 'l'}`, m.alu, .04, .04, .50, sx * .16, .035, 0);
    for (const sz of [-1, 1])
      B(g, `i3_foot_${sx}${sz}`, m.rubber, .042, .014, .042, sx * .16, .007, sz * .21);
  }
  B(g, 'i3_plate_front', m.alu_dark, .38, .09, .014, 0, .06, .257);
  B(g, 'i3_plate_rear', m.alu_dark, .38, .09, .014, 0, .06, -.257);
  // Y axis
  for (const sx of [-1, 1]) {
    C(g, `i3_yrod_${sx}`, m.steel, .004, .004, .47, sx * .085, .145, 0, 'z', 16);
    for (const sz of [-1, 1])
      B(g, `i3_yrodholder_${sx}${sz}`, m.plastic_black, .022, .02, .03, sx * .085, .135, sz * .225);
  }
  B(g, 'i3_ymotor', m.motor_black, .042, .042, .042, 0, .13, -.225);
  C(g, 'i3_yidler', m.steel, .009, .009, .012, 0, .13, .225, 'x', 12);
  B(g, 'i3_ybelt', m.belt, .006, .002, .43, 0, .13, 0);
  B(g, 'i3_ycarriage', m.plastic_black, .30, .006, .30, 0, .153, 0);
  // bed
  B(g, 'i3_heatbed', m.plastic_black, .25, .005, .21, 0, .1585, 0);
  B(g, 'i3_pei_sheet', m.pei, .242, .002, .202, 0, .1615, 0);
  B(g, 'i3_bed_cable_cover', m.plastic_black, .05, .012, .04, -.09, .157, -.115);
  W(g, 'i3_bed_loom', m.wire, [[-.09, .157, -.13], [-.09, .10, -.20], [-.05, .05, -.24]], .006);
  // vertical frame plate w/ window
  {
    const s = new THREE.Shape();
    s.moveTo(-.19, 0); s.lineTo(.19, 0); s.lineTo(.19, .34); s.lineTo(-.19, .34); s.closePath();
    const h = new THREE.Path();
    h.moveTo(-.15, .085); h.lineTo(.15, .085); h.lineTo(.15, .27); h.lineTo(-.15, .27); h.closePath();
    s.holes.push(h);
    const geo = new THREE.ExtrudeGeometry(s, { depth: .007, bevelEnabled: false });
    geo.translate(0, 0, -.0035);
    const o = new THREE.Mesh(geo, m.alu_dark); o.name = 'i3_frame_plate';
    o.position.set(0, .055, -.02); g.add(o);
  }
  // Z axis
  for (const sx of [-1, 1]) {
    const t = sx > 0 ? 'r' : 'l';
    B(g, `i3_zmotor_${t}`, m.motor_black, .042, .042, .042, sx * .145, .076, .012);
    C(g, `i3_zcoupler_${t}`, m.alu, .009, .009, .02, sx * .145, .105, .012, 'y', 12);
    C(g, `i3_leadscrew_${t}`, m.steel, .004, .004, .27, sx * .145, .25, .012, 'y', 16);
    C(g, `i3_zrod_${t}`, m.steel, .004, .004, .30, sx * .175, .245, -.02, 'y', 16);
    B(g, `i3_ztop_${t}`, m.plastic_orange, .05, .022, .045, sx * .16, .40, -.005);
    B(g, `i3_zcarriage_${t}`, m.plastic_orange, .055, .08, .046, sx * .16, .25, -.004);
  }
  // X gantry (posed mid-print)
  C(g, 'i3_xrod_top', m.steel, .004, .004, .27, 0, .275, -.004, 'x', 16);
  C(g, 'i3_xrod_bot', m.steel, .004, .004, .27, 0, .225, -.004, 'x', 16);
  B(g, 'i3_xmotor', m.motor_black, .042, .042, .042, -.155, .25, -.048, 0);
  B(g, 'i3_xbelt', m.belt, .27, .006, .002, 0, .25, -.023);
  // extruder + hotend
  B(g, 'i3_extruder_body', m.plastic_orange, .06, .09, .05, 0, .245, .012);
  B(g, 'i3_extruder_cover', m.plastic_black, .05, .07, .008, 0, .245, .04);
  C(g, 'i3_ptfe_stub', m.steel, .004, .004, .02, 0, .298, .012, 'y', 10);
  for (let i = 0; i < 4; i++)
    C(g, `i3_heatsink_fin_${i}`, m.alu, .011, .011, .0035, 0, .216 - i * .007, .012, 'y', 14);
  B(g, 'i3_heaterblock', m.alu, .016, .011, .023, 0, .187, .012);
  C(g, 'i3_nozzle', m.brass, .0055, .0018, .009, 0, .178, .012, 'y', 10);
  B(g, 'i3_fan_shroud', m.plastic_orange, .018, .04, .034, .034, .205, .012);
  fan(g, 'i3_hotend_fan', m.fan_dark, m.plastic_dark, .04, 0, .22, .042, 'z');
  W(g, 'i3_extruder_loom', m.wire, [[.01, .292, .012], [.05, .33, -.005], [.14, .33, -.03], [.19, .26, -.045], [.195, .22, -.05]], .006);
  B(g, 'i3_einsy_box', m.plastic_black, .014, .10, .09, -.196, .20, -.05);
  // LCD
  {
    const lcd = new THREE.Group(); lcd.name = 'i3_lcd_asm';
    lcd.position.set(0, .095, .262); lcd.rotation.x = -.42;
    const c = B(lcd, 'i3_lcd_case', m.plastic_black, .20, .062, .022, 0, 0, 0);
    B(lcd, 'i3_lcd_screen', m.lcd, .15, .04, .002, -.014, 0, .012);
    C(lcd, 'i3_lcd_knob', m.alu, .009, .009, .012, .078, .006, .014, 'z', 14);
    C(lcd, 'i3_lcd_reset', m.plastic_orange, .004, .004, .008, .078, -.018, .012, 'z', 8);
    g.add(lcd);
  }
  // PSU + switch
  B(g, 'i3_psu', m.plastic_black, .046, .09, .19, .187, .10, -.09);
  B(g, 'i3_psu_switch', m.plastic_dark, .012, .018, .014, .187, .10, .008);
  // spool holder + spool
  for (const sx of [-1, 1])
    B(g, `i3_spool_arm_${sx}`, m.plastic_orange, .02, .105, .042, sx * .048, .445, -.02);
  C(g, 'i3_spool_rod', m.steel, .005, .005, .15, 0, .50, -.02, 'x', 10);
  spool(g, 'i3_spool', m, m.filament_orange, 0, .50, -.02);
  W(g, 'i3_filament_path', m.filament_orange, [[0, .50, .07], [.005, .42, .05], [0, .34, .02], [0, .302, .012]], .0016);
  return g;
}

// ============================== VARIANT B: enclosed CoreXY ===================
export function buildPrinterCoreXY() {
  const m = mats(), g = new THREE.Group(); g.name = 'printer_corexy';
  const P = .24; // post center offset
  // feet + skirt + deck
  for (const sx of [-1, 1]) for (const sz of [-1, 1])
    C(g, `cx_foot_${sx}${sz}`, m.rubber, .02, .022, .022, sx * .21, .011, sz * .21, 'y', 14);
  B(g, 'cx_skirt_front', m.plastic_black, .46, .066, .008, 0, .062, .242);
  B(g, 'cx_skirt_rear', m.plastic_black, .46, .066, .008, 0, .062, -.242);
  B(g, 'cx_skirt_left', m.plastic_black, .008, .066, .46, -.242, .062, 0);
  B(g, 'cx_skirt_right', m.plastic_black, .008, .066, .46, .242, .062, 0);
  for (const sx of [-1, 1])
    C(g, `cx_skirt_fan_${sx}`, m.fan_dark, .024, .024, .006, sx * .12, .062, -.247, 'z', 16);
  B(g, 'cx_deck', m.alu_dark, .46, .007, .46, 0, .099, 0);
  // frame: 4 posts, 2 rail rings, corner cubes
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    B(g, `cx_post_${sx}${sz}`, m.alu_dark, .02, .53, .02, sx * P, .295, sz * P);
    B(g, `cx_corner_b_${sx}${sz}`, m.plastic_black, .027, .027, .027, sx * P, .032, sz * P);
    B(g, `cx_corner_t_${sx}${sz}`, m.plastic_black, .027, .027, .027, sx * P, .558, sz * P);
  }
  for (const y of [.032, .558]) {
    const t = y < .1 ? 'b' : 't';
    B(g, `cx_rail_front_${t}`, m.alu_dark, .46, .02, .02, 0, y, P);
    B(g, `cx_rail_rear_${t}`, m.alu_dark, .46, .02, .02, 0, y, -P);
    B(g, `cx_rail_left_${t}`, m.alu_dark, .02, .02, .46, -P, y, 0);
    B(g, `cx_rail_right_${t}`, m.alu_dark, .02, .02, .46, P, y, 0);
  }
  // panels + door
  B(g, 'cx_panel_left', m.glass_smoke, .004, .45, .44, -.246, .33, 0);
  B(g, 'cx_panel_right', m.glass_smoke, .004, .45, .44, .246, .33, 0);
  B(g, 'cx_panel_rear', m.glass_smoke, .44, .45, .004, 0, .33, -.246);
  B(g, 'cx_panel_top', m.glass_smoke, .44, .004, .44, 0, .572, 0);
  B(g, 'cx_door', m.glass_smoke, .44, .44, .004, 0, .335, .248);
  for (const y of [.20, .47])
    B(g, `cx_hinge_${y}`, m.plastic_black, .018, .04, .014, -.215, y, .251);
  B(g, 'cx_handle', m.plastic_black, .014, .15, .014, .19, .335, .266);
  for (const y of [.27, .40])
    B(g, `cx_handle_standoff_${y}`, m.plastic_black, .01, .012, .012, .19, y, .256);
  // XY gantry
  for (const sx of [-1, 1]) {
    B(g, `cx_yrail_${sx > 0 ? 'r' : 'l'}`, m.steel, .01, .009, .44, sx * .228, .545, 0);
    B(g, `cx_xcarriage_${sx > 0 ? 'r' : 'l'}`, m.plastic_black, .032, .032, .05, sx * .222, .543, .03);
  }
  B(g, 'cx_xbeam', m.alu_dark, .40, .02, .02, 0, .543, .03);
  B(g, 'cx_xrail', m.steel, .38, .009, .009, 0, .543, .043);
  // belts: two stacked loops + idlers + A/B motors
  for (const [yb, t] of [[.550, 'a'], [.558, 'b']]) {
    B(g, `cx_belt_${t}_front`, m.belt, .40, .006, .002, 0, yb, .212);
    B(g, `cx_belt_${t}_rear`, m.belt, .40, .006, .002, 0, yb, -.212);
    B(g, `cx_belt_${t}_left`, m.belt, .002, .006, .40, -.212, yb, 0);
    B(g, `cx_belt_${t}_right`, m.belt, .002, .006, .40, .212, yb, 0);
  }
  for (const sx of [-1, 1]) {
    C(g, `cx_idler_f_${sx}`, m.steel, .008, .008, .026, sx * .212, .553, .212, 'y', 12);
    B(g, `cx_motor_${sx > 0 ? 'b' : 'a'}`, m.motor_black, .045, .045, .045, sx * .20, .518, -.20);
    C(g, `cx_pulley_${sx}`, m.steel, .008, .008, .024, sx * .20, .552, -.20, 'y', 12);
  }
  // toolhead
  B(g, 'cx_toolhead_body', m.plastic_teal, .065, .085, .048, 0, .505, .062);
  B(g, 'cx_toolhead_plate', m.plastic_black, .07, .07, .006, 0, .51, .036);
  fan(g, 'cx_toolhead_fan', m.fan_dark, m.plastic_dark, .042, 0, .51, .088, 'z');
  B(g, 'cx_blower_5015', m.plastic_teal, .018, .05, .045, .045, .49, .062);
  for (let i = 0; i < 4; i++)
    C(g, `cx_heatsink_fin_${i}`, m.alu, .011, .011, .0035, 0, .456 - i * .007, .062, 'y', 14);
  B(g, 'cx_heaterblock', m.alu, .016, .011, .023, 0, .432, .062);
  C(g, 'cx_nozzle', m.brass, .0055, .0018, .009, 0, .424, .062, 'y', 10);
  W(g, 'cx_umbilical', m.wire, [[0, .55, .062], [.02, .585, .01], [.01, .575, -.14], [0, .555, -.21]], .007);
  // bed on rear Z rails
  B(g, 'cx_bed_plate', m.alu, .30, .008, .30, 0, .408, .02);
  B(g, 'cx_bed_pei', m.pei, .294, .002, .294, 0, .413, .02);
  B(g, 'cx_bed_crossbar', m.plastic_black, .40, .02, .02, 0, .396, -.20);
  for (const sx of [-1, 1]) {
    B(g, `cx_bed_arm_${sx}`, m.plastic_black, .02, .014, .20, sx * .12, .398, -.09);
    B(g, `cx_zrail_${sx}`, m.steel, .012, .42, .008, sx * .228, .30, -.232);
    B(g, `cx_zcarriage_${sx}`, m.plastic_black, .03, .05, .022, sx * .215, .396, -.226);
    C(g, `cx_leadscrew_${sx}`, m.steel, .005, .005, .40, sx * .175, .32, -.215, 'y', 10);
    B(g, `cx_zmotor_${sx}`, m.motor_black, .042, .04, .042, sx * .175, .122, -.215);
  }
  // screen pod, LEDs, exhaust
  {
    const pod = new THREE.Group(); pod.name = 'cx_screen_asm';
    pod.position.set(.185, .50, .254); pod.rotation.y = -.12;
    B(pod, 'cx_screen_case', m.plastic_black, .10, .066, .016, 0, 0, 0);
    B(pod, 'cx_screen_glass', m.screen, .086, .052, .002, 0, 0, .009);
    g.add(pod);
  }
  for (const sx of [-1, 1])
    B(g, `cx_led_strip_${sx}`, m.led, .006, .40, .004, sx * .226, .34, .232);
  B(g, 'cx_exhaust_box', m.plastic_black, .10, .10, .028, 0, .49, -.262);
  C(g, 'cx_exhaust_fan', m.fan_dark, .036, .036, .008, 0, .49, -.278, 'z', 18);
  // rear spool + feed tube
  B(g, 'cx_spool_bracket', m.plastic_black, .024, .09, .03, 0, .345, -.262);
  C(g, 'cx_spool_rod', m.steel, .005, .005, .13, 0, .30, -.30, 'x', 10);
  spool(g, 'cx_spool', m, m.filament_teal, 0, .30, -.30);
  W(g, 'cx_feed_tube', m.wire, [[0, .30, -.39], [.03, .45, -.34], [.02, .565, -.26], [0, .57, -.22]], .003);
  return g;
}
